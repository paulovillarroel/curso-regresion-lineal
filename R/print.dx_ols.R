#' Imprimir reporte de diagnostico OLS
#'
#' Metodo print para objetos de clase \code{"dx_ols"}. Muestra el reporte
#' completo en consola con semaforo de resultados.
#'
#' @param x Un objeto de clase \code{"dx_ols"} (creado por
#'   \code{\link{diagnostico_ols}}).
#' @param ... Argumentos adicionales (ignorados).
#'
#' @return Invisiblemente, el objeto \code{x}.
#'
#' @export
print.dx_ols <- function(x, ...) {
  alpha <- x$alpha
  bg_order <- x$bg_order
  n <- x$n
  k <- x$k

  cat("\n")
  cat("================================================================\n")
  cat("        DIAGNOSTICO DE SUPUESTOS OLS - RESUMEN\n")
  cat("================================================================\n")
  cat("Nivel de significancia:", alpha, "\n")
  cat("n =", n, "| k =", k, "predictores\n")
  cat("----------------------------------------------------------------\n\n")

  # 1. Normalidad
  cat("1. NORMALIDAD\n")
  sw <- x$shapiro
  if (!is.null(sw)) {
    cat("   Shapiro-Wilk: W =", round(sw$statistic, 4),
        "| p =", format.pval(sw$p.value, digits = 4), "\n")
  } else {
    cat("   Shapiro-Wilk: No aplicable (n > 5000). Usar QQ-plot.\n")
  }
  cat("   Lilliefors (KS corregido): D =", round(x$lilliefors$statistic, 4),
      "| p =", format.pval(x$lilliefors$p.value, digits = 4), "\n")
  cat("   Jarque-Bera: JB =", round(x$jarque_bera$statistic, 4),
      "| p =", format.pval(x$jarque_bera$p.value, digits = 4), "\n")
  nr <- x$norm_rechazos
  cat("   Decision:",
      ifelse(nr >= 2, "Mayoria rechaza H0 -> Evidencia de no normalidad",
             ifelse(nr == 1, "Resultado mixto -> Revisar QQ-plot",
                    "No rechaza H0 -> Compatible con normalidad")),
      "\n\n")

  # 2. Homocedasticidad
  bp <- x$breusch_pagan
  cat("2. HOMOCEDASTICIDAD\n")
  cat("   Breusch-Pagan: BP =", round(bp$statistic, 4),
      "| p =", format.pval(bp$p.value, digits = 4), "\n")
  cat("   Decision:", ifelse(bp$p.value < alpha,
      "Rechaza H0 -> Evidencia de heterocedasticidad",
      "No rechaza H0 -> Compatible con homocedasticidad"), "\n\n")

  # 3. Especificacion
  rs <- x$reset
  cat("3. ESPECIFICACION (RESET de Ramsey)\n")
  cat("   RESET: F =", round(rs$statistic, 4),
      "| p =", format.pval(rs$p.value, digits = 4), "\n")
  cat("   Decision:", ifelse(rs$p.value < alpha,
      "Rechaza H0 -> Posible mala especificacion",
      "No rechaza H0 -> Compatible con especificacion correcta"), "\n\n")

  # 4. Independencia
  bg <- x$breusch_godfrey
  cat("4. INDEPENDENCIA (no autocorrelacion)\n")
  cat("   Breusch-Godfrey (orden", paste0(bg_order, "):"),
      "LM =", round(bg$statistic, 4),
      "| p =", format.pval(bg$p.value, digits = 4), "\n")
  cat("   Decision:", ifelse(bg$p.value < alpha,
      paste0("Rechaza H0 -> Evidencia de autocorrelacion (hasta orden ", bg_order, ")"),
      "No rechaza H0 -> Compatible con independencia"), "\n")
  if (bg_order == 1) {
    cat("   (Nota: order=1 detecta AR(1). Para estacionalidad, usar bg_order=7, 12, etc.)\n\n")
  } else {
    cat("   (Nota: relevante solo si los datos tienen orden temporal)\n\n")
  }

  # 5. Multicolinealidad
  cat("5. MULTICOLINEALIDAD\n")
  if (k < 2) {
    cat("   No aplicable (modelo con un solo predictor).\n\n")
  } else {
    max_vif <- max(x$resumen$estadistico[x$resumen$supuesto == "Multicolinealidad (VIF)"],
                   na.rm = TRUE)
    vif_name <- sub("VIF max: ", "", x$resumen$test[x$resumen$supuesto == "Multicolinealidad (VIF)"])
    if (is.matrix(x$vif)) cat("   (GVIF -- variables categoricas detectadas)\n")
    cat("   VIF maximo:", round(max_vif, 2), "(variable:", vif_name, ")\n")
    cat("   Condition Number (centrado/escalado):", round(x$condition_number, 1), "\n")
    cn <- x$condition_number
    cat("   Decision:", ifelse(max_vif > 5 | cn > 30,
        ifelse(max_vif > 5 & cn > 30, "VIF > 5 y CN > 30 -> Multicolinealidad problematica",
               ifelse(max_vif > 5, "VIF > 5 -> Posible multicolinealidad problematica",
                      "CN > 30 -> Colinealidad severa (eigenvalores)")),
        "VIF <= 5 y CN <= 30 -> Sin multicolinealidad severa"), "\n\n")
  }

  # 6. Influencia
  cd <- x$cooks
  cat("6. DIAGNOSTICO DE INFLUENCIA\n")
  cat("   Cook's D > 4/n:", x$influyentes, "de", n, "obs.\n")
  max_cook <- which.max(cd)
  cat("   Mas influyente:", names(max_cook), "(D =", round(cd[max_cook], 4), ")\n")
  cat("   Alto leverage (h > 2(k+1)/n):", x$alto_leverage, "obs.\n")
  cat("   Outliers (|residuo studentizado| > 3):", x$outliers_stud, "obs.\n")
  cat("   Decision:", ifelse(any(cd > 1, na.rm = TRUE),
      "D > 1 -> Observacion(es) altamente influyente(s)",
      ifelse(x$influyentes > 0 | x$outliers_stud > 0,
             paste0(x$influyentes, " obs. superan Cook 4/n, ",
                    x$outliers_stud, " outliers -> Revisar manualmente"),
             "Sin observaciones altamente influyentes")), "\n\n")

  # 7. OLS vs HC3
  cat("7. COMPARACION: OLS vs ERRORES ROBUSTOS (HC3)\n")
  cat("   Cambio en errores estandar (HC3 vs OLS):\n")
  cambio <- x$robust_se_cambio_pct
  for (i in seq_along(cambio)) {
    valor <- if (is.na(cambio[i])) "SE ~ 0 (no comparable)" else sprintf("%+.1f%%", cambio[i])
    cat("     ", names(cambio)[i], ":", valor, "\n")
  }
  cat("   Decision:", ifelse(any(abs(cambio) > 20, na.rm = TRUE),
      "Cambios > 20% -> heterocedasticidad afecta la inferencia",
      "Cambios menores -> inferencia OLS estandar es razonable"), "\n\n")

  # Semaforo
  cat("================================================================\n")
  cat("RESUMEN DE DIAGNOSTICO\n")
  cat("----------------------------------------------------------------\n")
  for (nm in names(x$flags)) {
    estado <- if (is.na(x$flags[nm])) "[  ?  ]"
              else if (x$flags[nm]) "[REVISAR]"
              else "[  OK  ]"
    cat(" ", estado, nm, "\n")
  }
  cat("----------------------------------------------------------------\n")
  cat("NOTA: Tests orientativos. SIEMPRE complementar con graficos.\n")
  cat("================================================================\n")

  invisible(x)
}
