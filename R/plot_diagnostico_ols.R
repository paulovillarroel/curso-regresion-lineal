#' Panel de 4 graficos diagnosticos para un modelo OLS
#'
#' Genera un panel 2x2 con: (1) residuos vs valores ajustados, (2) QQ-plot,
#' (3) leverage vs residuos, y (4) distancia de Cook.
#'
#' Si \code{ggplot2} y \code{patchwork} estan instalados, usa graficos ggplot2
#' (personalizables con \code{+ theme_*()}). Si no, usa graficos base R.
#'
#' @param mod Un objeto de clase \code{lm} o \code{"dx_ols"}.
#'
#' @return Invisiblemente, el objeto patchwork (si ggplot2 disponible) o
#'   \code{NULL} (base R). La funcion se usa por su efecto secundario
#'   (generar graficos).
#'
#' @examples
#' modelo <- lm(mpg ~ wt + hp, data = mtcars)
#' plot_diagnostico_ols(modelo)
#'
#' # Personalizar con ggplot2 (si esta instalado):
#' # p <- plot_diagnostico_ols(modelo)
#' # p & ggplot2::theme_minimal()
#'
#' @importFrom stats rstandard fitted cooks.distance hatvalues coef qqnorm
#'   qqline
#' @importFrom graphics par plot abline lines legend
#'
#' @export
plot_diagnostico_ols <- function(mod) {
  # Si recibe un objeto dx_ols, extraer el modelo

  if (inherits(mod, "dx_ols")) mod <- mod$model

  use_gg <- requireNamespace("ggplot2", quietly = TRUE) &&
    requireNamespace("patchwork", quietly = TRUE)

  if (use_gg) {
    plot_ggplot(mod)
  } else {
    plot_base(mod)
  }
}

# --- ggplot2 + patchwork version ---
plot_ggplot <- function(mod) {
  ggplot2 <- asNamespace("ggplot2")
  patchwork <- asNamespace("patchwork")

  res <- rstandard(mod)
  fit <- fitted(mod)
  n <- length(res)
  k <- length(coef(mod)) - 1
  cd <- cooks.distance(mod)
  hv <- hatvalues(mod)
  umbral_cook <- 4 / n
  umbral_lev <- 2 * (k + 1) / n

  df <- data.frame(
    fitted = fit,
    residuals = res,
    leverage = hv,
    cooks = cd,
    obs = seq_along(res),
    cook_flag = cd > umbral_cook
  )

  # 1. Residuos vs Fitted
  p1 <- ggplot2::ggplot(df, ggplot2::aes(x = .data$fitted, y = .data$residuals)) +
    ggplot2::geom_point(color = "steelblue", alpha = 0.7) +
    ggplot2::geom_hline(yintercept = 0, linetype = 2, color = "red") +
    ggplot2::geom_smooth(method = "loess", formula = y ~ x,
                         se = FALSE, color = "darkred", linewidth = 1) +
    ggplot2::labs(x = "Valores ajustados", y = "Residuos estandarizados",
                  title = "Residuos vs Ajustados") +
    ggplot2::theme_bw()

  # 2. QQ-plot
  p2 <- ggplot2::ggplot(df, ggplot2::aes(sample = .data$residuals)) +
    ggplot2::stat_qq(color = "steelblue", alpha = 0.7) +
    ggplot2::stat_qq_line(color = "red", linewidth = 1) +
    ggplot2::labs(x = "Cuantiles teoricos", y = "Cuantiles muestrales",
                  title = "QQ-Plot de residuos") +
    ggplot2::theme_bw()

  # 3. Leverage vs Residuos
  p3 <- ggplot2::ggplot(df, ggplot2::aes(x = .data$leverage, y = .data$residuals)) +
    ggplot2::geom_point(color = "steelblue", alpha = 0.7) +
    ggplot2::geom_hline(yintercept = 0, linetype = 2, color = "grey50") +
    ggplot2::geom_vline(xintercept = umbral_lev, linetype = 2, color = "red") +
    ggplot2::labs(x = "Leverage (hat value)", y = "Residuos estandarizados",
                  title = "Leverage vs Residuos",
                  caption = paste0("Umbral: 2(k+1)/n = ", round(umbral_lev, 3))) +
    ggplot2::theme_bw()

  # 4. Cook's Distance
  p4 <- ggplot2::ggplot(df, ggplot2::aes(x = .data$obs, y = .data$cooks,
                                          color = .data$cook_flag)) +
    ggplot2::geom_segment(ggplot2::aes(xend = .data$obs, yend = 0), linewidth = 0.8) +
    ggplot2::geom_hline(yintercept = umbral_cook, linetype = 2, color = "red") +
    ggplot2::scale_color_manual(values = c("FALSE" = "steelblue", "TRUE" = "red"),
                                guide = "none") +
    ggplot2::labs(x = "Observacion", y = "Distancia de Cook",
                  title = "Distancia de Cook",
                  caption = paste0("Umbral: 4/n = ", round(umbral_cook, 4))) +
    ggplot2::theme_bw()

  combined <- (p1 + p2) / (p3 + p4)
  print(combined)
  invisible(combined)
}

# --- Base R fallback ---
plot_base <- function(mod) {
  opar <- par(mfrow = c(2, 2), mar = c(4.5, 4.5, 3, 1))
  on.exit(par(opar))

  res <- rstandard(mod)
  fit <- fitted(mod)
  n <- length(res)
  k <- length(coef(mod)) - 1
  cd <- cooks.distance(mod)
  hv <- hatvalues(mod)

  # 1. Residuos vs Fitted
  plot(fit, res, xlab = "Valores ajustados", ylab = "Residuos estandarizados",
       main = "Residuos vs Ajustados", pch = 20, col = "steelblue")
  abline(h = 0, lty = 2, col = "red")
  lines(lowess(fit, res), col = "darkred", lwd = 2)

  # 2. QQ-plot
  qqnorm(res, main = "QQ-Plot de residuos", pch = 20, col = "steelblue")
  qqline(res, col = "red", lwd = 2)

  # 3. Leverage vs Residuos
  plot(hv, res, xlab = "Leverage (hat value)", ylab = "Residuos estandarizados",
       main = "Leverage vs Residuos", pch = 20, col = "steelblue")
  abline(h = 0, lty = 2, col = "grey50")
  abline(v = 2 * (k + 1) / n, lty = 2, col = "red")
  legend("topright", legend = paste0("Umbral: 2(k+1)/n = ", round(2 * (k + 1) / n, 3)),
         col = "red", lty = 2, cex = 0.8, bty = "n")

  # 4. Cook's Distance
  plot(seq_along(cd), cd, type = "h", xlab = "Observacion", ylab = "Distancia de Cook",
       main = "Distancia de Cook", col = ifelse(cd > 4 / n, "red", "steelblue"), lwd = 1.5)
  abline(h = 4 / n, lty = 2, col = "red")
  legend("topright", legend = paste0("Umbral: 4/n = ", round(4 / n, 4)),
         col = "red", lty = 2, cex = 0.8, bty = "n")

  invisible(NULL)
}
