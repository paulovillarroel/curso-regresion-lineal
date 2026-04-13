#' Diagnóstico completo de supuestos OLS
#'
#' Ejecuta una batería de tests sobre un modelo \code{lm} y retorna un reporte
#' en consola (con semáforo) y una lista con todos los objetos de cada test.
#'
#' @param mod Un objeto de clase \code{lm}.
#' @param alpha Nivel de significancia para las decisiones (default 0.05).
#' @param bg_order Orden del test de Breusch-Godfrey. Usar 1 para AR(1),
#'   7 para estacionalidad semanal (datos diarios), 12 para anual (datos
#'   mensuales), etc.
#'
#' @return Invisiblemente, una lista con los siguientes elementos:
#' \describe{
#'   \item{resumen}{Data frame con una fila por test (supuesto, estadístico,
#'     p-value, decisión).}
#'   \item{shapiro}{Objeto del test de Shapiro-Wilk (\code{NULL} si n > 5000).}
#'   \item{lilliefors}{Objeto del test de Lilliefors (KS corregido).}
#'   \item{jarque_bera}{Objeto del test de Jarque-Bera.}
#'   \item{breusch_pagan}{Objeto del test de Breusch-Pagan.}
#'   \item{reset}{Objeto del test RESET de Ramsey.}
#'   \item{breusch_godfrey}{Objeto del test de Breusch-Godfrey.}
#'   \item{vif}{Valores VIF/GVIF (\code{NULL} si k < 2).}
#'   \item{condition_number}{Condition Number de la matriz de diseño.}
#'   \item{cooks}{Distancias de Cook para cada observación.}
#'   \item{leverage}{Hat values para cada observación.}
#'   \item{studentized_residuals}{Residuos studentizados (externos).}
#'   \item{robust_se_cambio_pct}{Cambio porcentual en SE (HC3 vs OLS).}
#'   \item{flags}{Vector lógico del semáforo resumen.}
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
#' @importFrom stats resid coef shapiro.test model.matrix fitted rstudent
#'   hatvalues cooks.distance
#' @importFrom lmtest bptest resettest bgtest coeftest
#' @importFrom car vif
#' @importFrom sandwich vcovHC
#' @importFrom nortest lillie.test
#' @importFrom tseries jarque.bera.test
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

  cat("\n")
  cat("================================================================\n")
  cat("        DIAGNOSTICO DE SUPUESTOS OLS - RESUMEN\n")
  cat("================================================================\n")
  cat("Nivel de significancia:", alpha, "\n")

  res <- resid(mod)
  n <- length(res)
  k <- length(coef(mod)) - 1

  cat("n =", n, "| k =", k, "predictores\n")
  cat("----------------------------------------------------------------\n\n")

  # 1. Normalidad (con guard para n > 5000)
  sw <- NULL
  lil <- NULL
  jb <- NULL
  cat("1. NORMALIDAD\n")
  if (n <= 5000) {
    sw <- shapiro.test(res)
    cat(
      "   Shapiro-Wilk: W =",
      round(sw$statistic, 4),
      "| p =",
      format.pval(sw$p.value, digits = 4),
      "\n"
    )
  } else {
    cat("   Shapiro-Wilk: No aplicable (n > 5000). Usar QQ-plot.\n")
  }
  lil <- nortest::lillie.test(res)
  cat(
    "   Lilliefors (KS corregido): D =",
    round(lil$statistic, 4),
    "| p =",
    format.pval(lil$p.value, digits = 4),
    "\n"
  )
  jb <- tseries::jarque.bera.test(res)
  cat(
    "   Jarque-Bera: JB =",
    round(jb$statistic, 4),
    "| p =",
    format.pval(jb$p.value, digits = 4),
    "\n"
  )
  # Decision basada en mayoria de tests disponibles
  norm_pvals <- c(
    if (!is.null(sw)) sw$p.value,
    lil$p.value,
    jb$p.value
  )
  norm_rechazos <- sum(norm_pvals < alpha)
  cat(
    "   Decision:",
    ifelse(
      norm_rechazos >= 2,
      "Mayoria rechaza H0 -> Evidencia de no normalidad",
      ifelse(
        norm_rechazos == 1,
        "Resultado mixto -> Revisar QQ-plot",
        "No rechaza H0 -> Compatible con normalidad"
      )
    ),
    "\n\n"
  )

  # 2. Homocedasticidad
  bp <- lmtest::bptest(mod)
  cat("2. HOMOCEDASTICIDAD\n")
  cat(
    "   Breusch-Pagan: BP =",
    round(bp$statistic, 4),
    "| p =",
    format.pval(bp$p.value, digits = 4),
    "\n"
  )
  cat(
    "   Decision:",
    ifelse(
      bp$p.value < alpha,
      "Rechaza H0 -> Evidencia de heterocedasticidad",
      "No rechaza H0 -> Compatible con homocedasticidad"
    ),
    "\n\n"
  )

  # 3. Linealidad (RESET)
  rs <- lmtest::resettest(mod, power = 2:3, type = "fitted")
  cat("3. ESPECIFICACION (RESET de Ramsey)\n")
  cat(
    "   RESET: F =",
    round(rs$statistic, 4),
    "| p =",
    format.pval(rs$p.value, digits = 4),
    "\n"
  )
  cat(
    "   Decision:",
    ifelse(
      rs$p.value < alpha,
      "Rechaza H0 -> Posible mala especificacion (no linealidad u omision)",
      "No rechaza H0 -> Compatible con especificacion correcta"
    ),
    "\n\n"
  )

  # 4. Independencia
  bg <- lmtest::bgtest(mod, order = bg_order)
  cat("4. INDEPENDENCIA (no autocorrelacion)\n")
  cat(
    "   Breusch-Godfrey (orden", paste0(bg_order, "):"),
    "LM =",
    round(bg$statistic, 4),
    "| p =",
    format.pval(bg$p.value, digits = 4),
    "\n"
  )
  cat(
    "   Decision:",
    ifelse(
      bg$p.value < alpha,
      paste0("Rechaza H0 -> Evidencia de autocorrelacion (hasta orden ", bg_order, ")"),
      "No rechaza H0 -> Compatible con independencia"
    ),
    "\n"
  )
  if (bg_order == 1) {
    cat("   (Nota: order=1 detecta AR(1). Para estacionalidad, usar bg_order=7, 12, etc.)\n\n")
  } else {
    cat("   (Nota: relevante solo si los datos tienen orden temporal)\n\n")
  }

  # 5. Multicolinealidad (con manejo de GVIF y k=1)
  vif_vals <- NULL
  max_vif <- NA
  max_name <- NA
  cn <- NA
  cat("5. MULTICOLINEALIDAD\n")
  if (k < 2) {
    cat("   No aplicable (modelo con un solo predictor).\n\n")
  } else {
    vif_vals <- car::vif(mod)
    if (is.matrix(vif_vals)) {
      cat("   (GVIF -- variables categoricas detectadas)\n")
      gvif_adj <- vif_vals[, "GVIF^(1/(2*Df))"]
      max_vif <- max(gvif_adj^2)
      max_name <- rownames(vif_vals)[which.max(gvif_adj)]
    } else {
      max_vif <- max(vif_vals)
      max_name <- names(which.max(vif_vals))
    }
    cat(
      "   VIF maximo:",
      round(max_vif, 2),
      "(variable:",
      max_name,
      ")\n"
    )
    # Condition Number (sobre matriz centrada y escalada)
    X <- model.matrix(mod)
    X_cs <- scale(X[, -1, drop = FALSE])
    eig <- eigen(crossprod(X_cs), only.values = TRUE)$values
    cn <- sqrt(max(eig) / min(eig))
    cat("   Condition Number (centrado/escalado):", round(cn, 1), "\n")
    cat(
      "   Decision:",
      ifelse(
        max_vif > 5 | cn > 30,
        ifelse(
          max_vif > 5 & cn > 30,
          "VIF > 5 y CN > 30 -> Multicolinealidad problematica",
          ifelse(
            max_vif > 5,
            "VIF > 5 -> Posible multicolinealidad problematica",
            "CN > 30 -> Colinealidad severa (eigenvalores)"
          )
        ),
        "VIF <= 5 y CN <= 30 -> Sin multicolinealidad severa"
      ),
      "\n\n"
    )
  }

  # 6. Diagnostico de influencia (Cook's D + leverage + studentized residuals)
  cd <- cooks.distance(mod)
  umbral_cook <- 4 / n
  influyentes <- sum(cd > umbral_cook, na.rm = TRUE)
  max_cook <- which.max(cd)

  hv <- hatvalues(mod)
  umbral_lev <- 2 * (k + 1) / n
  alto_leverage <- sum(hv > umbral_lev, na.rm = TRUE)

  stud_res <- rstudent(mod)
  outliers_stud <- sum(abs(stud_res) > 3, na.rm = TRUE)

  cat("6. DIAGNOSTICO DE INFLUENCIA\n")
  cat(
    "   Cook's D > 4/n:",
    influyentes,
    "de",
    n,
    "obs.\n"
  )
  cat(
    "   Mas influyente:",
    names(max_cook),
    "(D =",
    round(cd[max_cook], 4),
    ")\n"
  )
  cat(
    "   Alto leverage (h > 2(k+1)/n):",
    alto_leverage,
    "obs.\n"
  )
  cat(
    "   Outliers (|residuo studentizado| > 3):",
    outliers_stud,
    "obs.\n"
  )
  cat(
    "   Decision:",
    ifelse(
      any(cd > 1, na.rm = TRUE),
      "D > 1 -> Observacion(es) altamente influyente(s)",
      ifelse(
        influyentes > 0 | outliers_stud > 0,
        paste0(
          influyentes, " obs. superan Cook 4/n, ",
          outliers_stud, " outliers -> Revisar manualmente"
        ),
        "Sin observaciones altamente influyentes"
      )
    ),
    "\n\n"
  )

  # 7. Comparacion OLS vs errores robustos (HC3)
  cat("7. COMPARACION: OLS vs ERRORES ROBUSTOS (HC3)\n")
  ols_se <- coef(summary(mod))[, "Std. Error"]
  rob_ct <- lmtest::coeftest(mod, vcov = sandwich::vcovHC(mod, type = "HC3"))
  rob_se <- rob_ct[, "Std. Error"]
  cambio_pct <- ifelse(
    ols_se > .Machine$double.eps,
    round((rob_se / ols_se - 1) * 100, 1),
    NA_real_
  )
  cat("   Cambio en errores estandar (HC3 vs OLS):\n")
  for (i in seq_along(cambio_pct)) {
    valor <- if (is.na(cambio_pct[i])) {
      "SE ~ 0 (no comparable)"
    } else {
      sprintf("%+.1f%%", cambio_pct[i])
    }
    cat(
      "     ",
      names(cambio_pct)[i],
      ":",
      valor,
      "\n"
    )
  }
  cat(
    "   Decision:",
    ifelse(
      any(abs(cambio_pct) > 20, na.rm = TRUE),
      "Cambios > 20% -> heterocedasticidad afecta la inferencia",
      "Cambios menores -> inferencia OLS estandar es razonable"
    ),
    "\n\n"
  )

  # Resumen tipo semaforo
  cat("================================================================\n")
  cat("RESUMEN DE DIAGNOSTICO\n")
  cat("----------------------------------------------------------------\n")
  flags <- c(
    "No normalidad" = if (norm_rechazos >= 2) TRUE else if (norm_rechazos == 1) NA else FALSE,
    "Heterocedasticidad" = unname(bp$p.value < alpha),
    "Mala especificacion" = unname(rs$p.value < alpha),
    "Autocorrelacion" = unname(bg$p.value < alpha),
    "Multicolinealidad" = if (!is.na(max_vif)) (max_vif > 5 | cn > 30) else NA,
    "Alta influencia" = any(cd > 1, na.rm = TRUE),
    "Outliers" = outliers_stud > 0
  )
  for (nm in names(flags)) {
    estado <- if (is.na(flags[nm])) {
      "[  ?  ]"
    } else if (flags[nm]) {
      "[REVISAR]"
    } else {
      "[  OK  ]"
    }
    cat(" ", estado, nm, "\n")
  }
  cat("----------------------------------------------------------------\n")
  cat("NOTA: Tests orientativos. SIEMPRE complementar con graficos.\n")
  cat("================================================================\n")

  # Dataframe resumen para integracion con tidyverse
  resumen <- data.frame(
    supuesto = c(
      "Normalidad (SW)",
      "Normalidad (Lilliefors)",
      "Normalidad (JB)",
      "Homocedasticidad",
      "Especificacion",
      "Independencia",
      "Multicolinealidad (VIF)",
      "Multicolinealidad (CN)",
      "Influencia (Cook)",
      "Outliers (stud. res.)",
      "Alto leverage"
    ),
    test = c(
      if (!is.null(sw)) "Shapiro-Wilk" else "N/A (n > 5000)",
      "Lilliefors",
      "Jarque-Bera",
      "Breusch-Pagan",
      "RESET (Ramsey)",
      "Breusch-Godfrey",
      if (!is.na(max_vif)) paste0("VIF max: ", max_name) else "N/A (k=1)",
      if (!is.na(cn)) "Condition Number" else "N/A (k=1)",
      "Cook's D",
      "Residuos studentizados",
      "Hat values"
    ),
    estadistico = round(
      c(
        if (!is.null(sw)) sw$statistic else NA,
        lil$statistic,
        jb$statistic,
        bp$statistic,
        rs$statistic,
        bg$statistic,
        max_vif,
        cn,
        max(cd, na.rm = TRUE),
        if (outliers_stud > 0) max(abs(stud_res)) else max(abs(stud_res)),
        max(hv)
      ),
      4
    ),
    p_value = c(
      if (!is.null(sw)) sw$p.value else NA,
      lil$p.value,
      jb$p.value,
      bp$p.value,
      rs$p.value,
      bg$p.value,
      NA,
      NA,
      NA,
      NA,
      NA
    ),
    decision = c(
      if (!is.null(sw)) {
        ifelse(sw$p.value < alpha, "Rechaza H0", "No rechaza H0")
      } else {
        "N/A"
      },
      ifelse(lil$p.value < alpha, "Rechaza H0", "No rechaza H0"),
      ifelse(jb$p.value < alpha, "Rechaza H0", "No rechaza H0"),
      ifelse(bp$p.value < alpha, "Rechaza H0", "No rechaza H0"),
      ifelse(rs$p.value < alpha, "Rechaza H0", "No rechaza H0"),
      ifelse(bg$p.value < alpha, "Rechaza H0", "No rechaza H0"),
      if (!is.na(max_vif)) ifelse(max_vif > 5, "VIF > 5", "OK") else "N/A",
      if (!is.na(cn)) ifelse(cn > 30, "CN > 30", "OK") else "N/A",
      ifelse(
        any(cd > 1, na.rm = TRUE),
        "D > 1",
        ifelse(influyentes > 0, "Revisar", "OK")
      ),
      ifelse(outliers_stud > 0, paste0(outliers_stud, " obs."), "OK"),
      ifelse(alto_leverage > 0, paste0(alto_leverage, " obs."), "OK")
    ),
    stringsAsFactors = FALSE
  )
  rownames(resumen) <- NULL

  # Retornar resultados invisiblemente
  invisible(list(
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
    flags = flags
  ))
}
