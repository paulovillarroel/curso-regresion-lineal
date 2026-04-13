#' Comparar modelos OLS con AIC corregido por Jacobiano y diagnosticos
#'
#' Recibe dos o mas modelos \code{lm} y retorna una tabla comparativa con AIC
#' (corregido automaticamente si algun modelo usa \code{log(Y)}), delta-AIC,
#' y el semaforo de \code{\link{diagnostico_ols}} para cada modelo.
#'
#' @param ... Dos o mas objetos \code{lm}.
#' @param alpha Nivel de significancia para los diagnosticos (default 0.05).
#' @param bg_order Orden del test de Breusch-Godfrey (default 1).
#'
#' @details
#' La funcion detecta automaticamente si la variable dependiente de algun
#' modelo esta envuelta en \code{log()} parseando la formula. Para esos modelos,
#' aplica la correccion Jacobiana al AIC:
#'
#' \deqn{AIC_{corregido} = AIC_{log} + 2 \sum_{i=1}^{n} \log(y_i)}
#'
#' donde \eqn{y_i} son los valores originales (no transformados) de la variable
#' dependiente. Esto permite comparar modelos con \eqn{Y} contra modelos con
#' \eqn{\log(Y)} en la misma escala.
#'
#' @return Un \code{tibble} con una fila por modelo y las siguientes columnas:
#' \describe{
#'   \item{modelo}{Formula del modelo como texto.}
#'   \item{n}{Numero de observaciones.}
#'   \item{k}{Numero de predictores.}
#'   \item{AIC}{AIC (corregido por Jacobiano si aplica).}
#'   \item{delta_AIC}{Diferencia respecto al mejor modelo (delta = 0).}
#'   \item{log_y}{TRUE si la variable dependiente esta transformada con log.}
#'   \item{especificacion}{Flag del test RESET.}
#'   \item{homocedasticidad}{Flag del test Breusch-Pagan.}
#'   \item{normalidad}{Flag de normalidad (mayoria de 3 tests).}
#'   \item{independencia}{Flag del test Breusch-Godfrey.}
#'   \item{multicolinealidad}{Flag de VIF/CN.}
#'   \item{influencia}{Flag de Cook's D > 1.}
#'   \item{outliers}{Flag de residuos studentizados > 3.}
#'   \item{n_problemas}{Conteo de flags TRUE (problemas detectados).}
#' }
#'
#' @examples
#' datos <- ISLR2::Auto
#' m1 <- lm(mpg ~ weight + year + origin, data = datos)
#'
#' datos$weight_c <- datos$weight - mean(datos$weight)
#' m2 <- lm(mpg ~ weight_c + I(weight_c^2) + year + origin, data = datos)
#' m3 <- lm(log(mpg) ~ log(weight) + year + origin, data = datos)
#'
#' comparar_modelos(m1, m2, m3)
#'
#' @importFrom stats AIC formula model.response model.frame
#' @importFrom tibble tibble
#'
#' @export
comparar_modelos <- function(..., alpha = 0.05, bg_order = 1) {
  modelos <- list(...)

  if (length(modelos) < 2) {
    stop("Se requieren al menos 2 modelos para comparar.", call. = FALSE)
  }

  # Verificar que todos sean lm
  es_lm <- vapply(modelos, inherits, logical(1), what = "lm")
  if (!all(es_lm)) {
    stop("Todos los argumentos deben ser objetos lm.", call. = FALSE)
  }

  # Detectar si la variable dependiente tiene log()
  detectar_log_y <- function(mod) {
    resp <- as.character(formula(mod)[[2]])
    # formula(mod)[[2]] puede ser un symbol (mpg) o un call (log(mpg))
    if (length(resp) == 1) return(FALSE)
    resp[1] == "log"
  }

  # Extraer valores originales de Y (sin transformar) para Jacobiano
  obtener_y_original <- function(mod) {
    y_mod <- model.response(model.frame(mod))
    if (detectar_log_y(mod)) {
      # Y en el modelo es log(y), necesitamos exp() para recuperar y original
      exp(y_mod)
    } else {
      y_mod
    }
  }

  # Calcular AIC corregido
  calcular_aic <- function(mod) {
    aic_crudo <- AIC(mod)
    if (detectar_log_y(mod)) {
      y_orig <- obtener_y_original(mod)
      aic_crudo + 2 * sum(log(y_orig))
    } else {
      aic_crudo
    }
  }

  # Correr diagnosticos y extraer datos
  nombres <- vapply(modelos, function(m) deparse(formula(m)), character(1))
  aics <- vapply(modelos, calcular_aic, numeric(1))
  log_flags <- vapply(modelos, detectar_log_y, logical(1))

  # Diagnosticos
  dxs <- lapply(modelos, diagnostico_ols, alpha = alpha, bg_order = bg_order)

  # Extraer flags de cada diagnostico
  extraer_flag <- function(dx, nombre) {
    f <- dx$flags[nombre]
    if (is.na(f)) return(NA)
    unname(f)
  }

  tibble::tibble(
    modelo = nombres,
    n = vapply(dxs, function(d) as.integer(d$n), integer(1)),
    k = vapply(dxs, function(d) as.integer(d$k), integer(1)),
    AIC = round(aics, 1),
    delta_AIC = round(aics - min(aics), 1),
    log_y = log_flags,
    especificacion = vapply(dxs, extraer_flag, logical(1), nombre = "Mala especificacion"),
    homocedasticidad = vapply(dxs, extraer_flag, logical(1), nombre = "Heterocedasticidad"),
    normalidad = vapply(dxs, function(d) {
      nr <- d$norm_rechazos
      if (nr >= 2) TRUE else if (nr == 1) NA else FALSE
    }, logical(1)),
    independencia = vapply(dxs, extraer_flag, logical(1), nombre = "Autocorrelacion"),
    multicolinealidad = vapply(dxs, function(d) {
      f <- d$flags["Multicolinealidad"]
      if (is.na(f)) NA else unname(f)
    }, logical(1)),
    influencia = vapply(dxs, extraer_flag, logical(1), nombre = "Alta influencia"),
    outliers = vapply(dxs, function(d) d$outliers_stud > 0, logical(1)),
    n_problemas = vapply(dxs, function(d) sum(d$flags == TRUE, na.rm = TRUE), integer(1))
  )
}
