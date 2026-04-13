#' Pegar diagnosticos a nivel de observacion al dataset original
#'
#' Estilo \code{broom::augment()}: retorna el dataset original con columnas
#' adicionales de diagnostico (.cooksd, .hat, .std.resid) para facilitar
#' filtros rapidos en pipelines tidy.
#'
#' @param x Un objeto de clase \code{"dx_ols"} (creado por
#'   \code{\link{diagnostico_ols}}).
#' @param data Data frame original usado para ajustar el modelo. Si no se
#'   proporciona, se intenta extraer del modelo con \code{model.frame()}.
#' @param ... Argumentos adicionales (ignorados).
#'
#' @return Un \code{tibble} con las columnas originales mas:
#' \describe{
#'   \item{.fitted}{Valores ajustados del modelo.}
#'   \item{.resid}{Residuos del modelo.}
#'   \item{.std.resid}{Residuos studentizados (externos).}
#'   \item{.hat}{Leverage (hat values).}
#'   \item{.cooksd}{Distancia de Cook.}
#'   \item{.cooksd_flag}{TRUE si Cook's D > 4/n.}
#'   \item{.leverage_flag}{TRUE si hat value > 2(k+1)/n.}
#'   \item{.outlier_flag}{TRUE si |residuo studentizado| > 3.}
#' }
#'
#' @examples
#' modelo <- lm(mpg ~ wt + hp, data = mtcars)
#' dx <- diagnostico_ols(modelo)
#' datos_dx <- augment(dx)
#'
#' # Filtrar observaciones problematicas
#' # library(dplyr)
#' # datos_dx |> filter(.cooksd_flag | .outlier_flag)
#'
#' @importFrom stats fitted resid model.frame
#' @importFrom tibble as_tibble
#'
#' @export
augment.dx_ols <- function(x, data = NULL, ...) {
  mod <- x$model
  if (is.null(data)) {
    data <- model.frame(mod)
  }

  n <- x$n
  k <- x$k

  result <- tibble::as_tibble(data)
  result$.fitted <- fitted(mod)
  result$.resid <- resid(mod)
  result$.std.resid <- x$studentized_residuals
  result$.hat <- x$leverage
  result$.cooksd <- x$cooks

  result$.cooksd_flag <- x$cooks > (4 / n)
  result$.leverage_flag <- x$leverage > (2 * (k + 1) / n)
  result$.outlier_flag <- abs(x$studentized_residuals) > 3

  result
}

#' @rdname augment.dx_ols
#' @export
augment <- function(x, ...) {
  UseMethod("augment")
}
