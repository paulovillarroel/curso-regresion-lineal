#' Panel de 4 graficos diagnosticos para un modelo OLS
#'
#' Genera un panel 2x2 con: (1) residuos vs valores ajustados, (2) QQ-plot,
#' (3) leverage vs residuos, y (4) distancia de Cook.
#'
#' @param mod Un objeto de clase \code{lm}.
#'
#' @return Invisible \code{NULL}. La funcion se usa por su efecto secundario
#'   (generar graficos).
#'
#' @examples
#' modelo <- lm(mpg ~ wt + hp, data = mtcars)
#' plot_diagnostico_ols(modelo)
#'
#' @importFrom stats rstandard fitted cooks.distance hatvalues coef
#' @importFrom graphics par plot abline lines legend
#'
#' @export
plot_diagnostico_ols <- function(mod) {
  opar <- par(mfrow = c(2, 2), mar = c(4.5, 4.5, 3, 1))
  on.exit(par(opar))

  res <- rstandard(mod)
  fit <- fitted(mod)
  n <- length(res)
  k <- length(coef(mod)) - 1
  cd <- cooks.distance(mod)
  hv <- hatvalues(mod)

  # 1. Residuos vs Fitted
  plot(
    fit,
    res,
    xlab = "Valores ajustados",
    ylab = "Residuos estandarizados",
    main = "Residuos vs Ajustados",
    pch = 20,
    col = "steelblue"
  )
  abline(h = 0, lty = 2, col = "red")
  lines(lowess(fit, res), col = "darkred", lwd = 2)

  # 2. QQ-plot
  qqnorm(res, main = "QQ-Plot de residuos", pch = 20, col = "steelblue")
  qqline(res, col = "red", lwd = 2)

  # 3. Leverage vs Residuos
  plot(
    hv,
    res,
    xlab = "Leverage (hat value)",
    ylab = "Residuos estandarizados",
    main = "Leverage vs Residuos",
    pch = 20,
    col = "steelblue"
  )
  abline(h = 0, lty = 2, col = "grey50")
  abline(v = 2 * (k + 1) / n, lty = 2, col = "red")
  legend(
    "topright",
    legend = paste0("Umbral: 2(k+1)/n = ", round(2 * (k + 1) / n, 3)),
    col = "red",
    lty = 2,
    cex = 0.8,
    bty = "n"
  )

  # 4. Cook's Distance
  plot(
    seq_along(cd),
    cd,
    type = "h",
    xlab = "Observacion",
    ylab = "Distancia de Cook",
    main = "Distancia de Cook",
    col = ifelse(cd > 4 / n, "red", "steelblue"),
    lwd = 1.5
  )
  abline(h = 4 / n, lty = 2, col = "red")
  legend(
    "topright",
    legend = paste0("Umbral: 4/n = ", round(4 / n, 4)),
    col = "red",
    lty = 2,
    cex = 0.8,
    bty = "n"
  )

  invisible(NULL)
}
