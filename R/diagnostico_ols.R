#' Diagnostico completo de supuestos OLS
#'
#' Ejecuta una bateria de tests sobre un modelo \code{lm} y retorna un objeto
#' de clase \code{"dx_ols"} con todos los resultados. Al imprimirlo, muestra
#' un reporte en consola con semaforo.
#'
#' @param mod Un objeto de clase \code{lm}.
#' @param alpha Nivel de significancia para las decisiones (default 0.05).
#' @param bg_order Orden del test de Breusch-Godfrey. Usar 1 para AR(1),
#'   7 para estacionalidad semanal (datos diarios), 12 para anual (datos
#'   mensuales), etc.
#'
#' @return Un objeto de clase \code{"dx_ols"} (lista) con los siguientes
#'   elementos:
#' \describe{
#'   \item{resumen}{\code{tibble} con una fila por test (supuesto, estadistico,
#'     p-value, decision).}
#'   \item{shapiro}{Objeto del test de Shapiro-Wilk (\code{NULL} si n > 5000).}
#'   \item{lilliefors}{Objeto del test de Lilliefors (KS corregido).}
#'   \item{jarque_bera}{Objeto del test de Jarque-Bera.}
#'   \item{breusch_pagan}{Objeto del test de Breusch-Pagan.}
#'   \item{reset}{Objeto del test RESET de Ramsey.}
#'   \item{breusch_godfrey}{Objeto del test de Breusch-Godfrey.}
#'   \item{vif}{Valores VIF/GVIF (\code{NULL} si k < 2).}
#'   \item{condition_number}{Condition Number de la matriz de diseno.}
#'   \item{cooks}{Distancias de Cook para cada observacion.}
#'   \item{leverage}{Hat values para cada observacion.}
#'   \item{studentized_residuals}{Residuos studentizados (externos).}
#'   \item{robust_se_cambio_pct}{Cambio porcentual en SE (HC3 vs OLS).}
#'   \item{flags}{Vector logico del semaforo resumen.}
#'   \item{model}{El modelo original.}
#'   \item{alpha}{Nivel de significancia usado.}
#'   \item{bg_order}{Orden de BG usado.}
#' }
#'
#' @examples
#' modelo <- lm(mpg ~ wt + hp, data = mtcars)
#' dx <- diagnostico_ols(modelo)
#' dx$resumen
#'
#' # Para datos con estacionalidad semanal:
#' # dx <- diagnostico_ols(modelo, bg_order = 7)
#'
#' # Augment: pegar diagnosticos al dataset original
#' # augment(dx, mtcars)
#'
#' @importFrom stats resid coef shapiro.test model.matrix fitted rstudent
#'   hatvalues cooks.distance
#' @importFrom lmtest bptest resettest bgtest coeftest
#' @importFrom car vif
#' @importFrom sandwich vcovHC
#' @importFrom nortest lillie.test
#' @importFrom tseries jarque.bera.test
#' @importFrom tibble tibble
#'
#' @export
diagnostico_ols <- function(mod, alpha = 0.05, bg_order = 1) {
  pkgs <- c("lmtest", "car", "sandwich", "nortest", "tseries")
  falta <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(falta) > 0) {
    stop(
      "Paquete(s) requerido(s) no instalado(s): ",
      paste(falta, collapse = ", "),
      "\n  Instalar con: install.packages(c(\"",
      paste(falta, collapse = "\", \""),
      "\"))",
      call. = FALSE
    )
  }

  res <- resid(mod)
  n <- length(res)
  k <- length(coef(mod)) - 1

  # 1. Normalidad
  sw <- if (n <= 5000) shapiro.test(res) else NULL
  lil <- nortest::lillie.test(res)
  jb <- tseries::jarque.bera.test(res)

  norm_pvals <- c(
    if (!is.null(sw)) sw$p.value,
    lil$p.value,
    jb$p.value
  )
  norm_rechazos <- sum(norm_pvals < alpha)

  # 2. Homocedasticidad
  bp <- lmtest::bptest(mod)

  # 3. Especificacion (RESET)
  rs <- lmtest::resettest(mod, power = 2:3, type = "fitted")

  # 4. Independencia
  bg <- lmtest::bgtest(mod, order = bg_order)

  # 5. Multicolinealidad
  vif_vals <- NULL
  max_vif <- NA
  max_name <- NA
  cn <- NA
  if (k >= 2) {
    vif_vals <- car::vif(mod)
    if (is.matrix(vif_vals)) {
      gvif_adj <- vif_vals[, "GVIF^(1/(2*Df))"]
      max_vif <- max(gvif_adj^2)
      max_name <- rownames(vif_vals)[which.max(gvif_adj)]
    } else {
      max_vif <- max(vif_vals)
      max_name <- names(which.max(vif_vals))
    }
    X <- model.matrix(mod)
    X_cs <- scale(X[, -1, drop = FALSE])
    eig <- eigen(crossprod(X_cs), only.values = TRUE)$values
    cn <- sqrt(max(eig) / min(eig))
  }

  # 6. Influencia
  cd <- cooks.distance(mod)
  umbral_cook <- 4 / n
  influyentes <- sum(cd > umbral_cook, na.rm = TRUE)
  max_cook <- which.max(cd)

  hv <- hatvalues(mod)
  umbral_lev <- 2 * (k + 1) / n
  alto_leverage <- sum(hv > umbral_lev, na.rm = TRUE)

  stud_res <- rstudent(mod)
  outliers_stud <- sum(abs(stud_res) > 3, na.rm = TRUE)

  # 7. OLS vs HC3
  ols_se <- coef(summary(mod))[, "Std. Error"]
  rob_ct <- lmtest::coeftest(mod, vcov = sandwich::vcovHC(mod, type = "HC3"))
  rob_se <- rob_ct[, "Std. Error"]
  cambio_pct <- ifelse(
    ols_se > .Machine$double.eps,
    round((rob_se / ols_se - 1) * 100, 1),
    NA_real_
  )

  # Flags (semaforo)
  flags <- c(
    "No normalidad" = if (norm_rechazos >= 2) TRUE else if (norm_rechazos == 1) NA else FALSE,
    "Heterocedasticidad" = unname(bp$p.value < alpha),
    "Mala especificacion" = unname(rs$p.value < alpha),
    "Autocorrelacion" = unname(bg$p.value < alpha),
    "Multicolinealidad" = if (!is.na(max_vif)) (max_vif > 5 | cn > 30) else NA,
    "Alta influencia" = any(cd > 1, na.rm = TRUE),
    "Outliers" = outliers_stud > 0
  )

  # Resumen como tibble
  resumen <- tibble::tibble(
    supuesto = c(
      "Normalidad (SW)", "Normalidad (Lilliefors)", "Normalidad (JB)",
      "Homocedasticidad", "Especificacion", "Independencia",
      "Multicolinealidad (VIF)", "Multicolinealidad (CN)",
      "Influencia (Cook)", "Outliers (stud. res.)", "Alto leverage"
    ),
    test = c(
      if (!is.null(sw)) "Shapiro-Wilk" else "N/A (n > 5000)",
      "Lilliefors", "Jarque-Bera", "Breusch-Pagan", "RESET (Ramsey)",
      "Breusch-Godfrey",
      if (!is.na(max_vif)) paste0("VIF max: ", max_name) else "N/A (k=1)",
      if (!is.na(cn)) "Condition Number" else "N/A (k=1)",
      "Cook's D", "Residuos studentizados", "Hat values"
    ),
    estadistico = round(c(
      if (!is.null(sw)) sw$statistic else NA,
      lil$statistic, jb$statistic, bp$statistic, rs$statistic, bg$statistic,
      max_vif, cn, max(cd, na.rm = TRUE), max(abs(stud_res)), max(hv)
    ), 4),
    p_value = c(
      if (!is.null(sw)) sw$p.value else NA,
      lil$p.value, jb$p.value, bp$p.value, rs$p.value, bg$p.value,
      NA, NA, NA, NA, NA
    ),
    decision = c(
      if (!is.null(sw)) ifelse(sw$p.value < alpha, "Rechaza H0", "No rechaza H0") else "N/A",
      ifelse(lil$p.value < alpha, "Rechaza H0", "No rechaza H0"),
      ifelse(jb$p.value < alpha, "Rechaza H0", "No rechaza H0"),
      ifelse(bp$p.value < alpha, "Rechaza H0", "No rechaza H0"),
      ifelse(rs$p.value < alpha, "Rechaza H0", "No rechaza H0"),
      ifelse(bg$p.value < alpha, "Rechaza H0", "No rechaza H0"),
      if (!is.na(max_vif)) ifelse(max_vif > 5, "VIF > 5", "OK") else "N/A",
      if (!is.na(cn)) ifelse(cn > 30, "CN > 30", "OK") else "N/A",
      ifelse(any(cd > 1, na.rm = TRUE), "D > 1",
             ifelse(influyentes > 0, "Revisar", "OK")),
      ifelse(outliers_stud > 0, paste0(outliers_stud, " obs."), "OK"),
      ifelse(alto_leverage > 0, paste0(alto_leverage, " obs."), "OK")
    )
  )

  result <- list(
    resumen = resumen,
    shapiro = sw,
    lilliefors = lil,
    jarque_bera = jb,
    breusch_pagan = bp,
    reset = rs,
    breusch_godfrey = bg,
    vif = vif_vals,
    condition_number = cn,
    cooks = cd,
    leverage = hv,
    studentized_residuals = stud_res,
    robust_se_cambio_pct = cambio_pct,
    flags = flags,
    model = mod,
    alpha = alpha,
    bg_order = bg_order,
    n = n,
    k = k,
    norm_rechazos = norm_rechazos,
    influyentes = influyentes,
    outliers_stud = outliers_stud,
    alto_leverage = alto_leverage
  )
  class(result) <- "dx_ols"
  result
}
