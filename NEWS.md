# diagols 0.2.0

## Nueva función: `comparar_modelos()`

- Compara 2+ modelos `lm` en una sola tabla: AIC, delta-AIC, y flags diagnósticos.
- **Detecta automáticamente `log(Y)`** en la fórmula y aplica corrección Jacobiana al AIC — permite comparar modelos con Y vs log(Y) en la misma escala.
- Columna `n_problemas` cuenta cuántos flags están en TRUE para cada modelo.
- Retorna tibble listo para pipelines tidy.

## Arquitectura

- **Clase S3 `dx_ols`**: `diagnostico_ols()` ahora retorna un objeto con clase propia. La lógica de cálculo está separada de la lógica de impresión (`print.dx_ols()`), siguiendo el estándar de R.
- **Integración tidy**: el resumen se retorna como `tibble` en vez de `data.frame`. Nueva función `augment()` que pega diagnósticos a nivel de observación (`.cooksd`, `.hat`, `.std.resid`) al dataset original con flags booleanos (`.cooksd_flag`, `.leverage_flag`, `.outlier_flag`), compatible con pipelines `dplyr`.
- **Gráficos ggplot2**: `plot_diagnostico_ols()` usa `ggplot2` + `patchwork` si están instalados (permite personalización con `+ theme_*()`). Fallback automático a base R si no están disponibles.
- **`plot_diagnostico_ols()` acepta objetos `dx_ols`** además de objetos `lm`.

## Tests incluidos en `diagnostico_ols()`

- Normalidad: Shapiro-Wilk, Lilliefors, Jarque-Bera (decisión por mayoría).
- Homocedasticidad: Breusch-Pagan (Koenker).
- Especificación: RESET de Ramsey.
- Independencia: Breusch-Godfrey con `bg_order` configurable.
- Multicolinealidad: VIF/GVIF + Condition Number (centrado/escalado).
- Influencia: Cook's D, leverage (hat values), residuos studentizados.
- Comparación OLS vs errores robustos HC3.

## Dependencias

- **Imports**: lmtest, car, nortest, tseries, sandwich, tibble.
- **Suggests**: ggplot2, patchwork.

---

# diagols 0.1.0

- Versión inicial con funciones `diagnostico_ols()` y `plot_diagnostico_ols()`.
- Función monolítica: cálculo e impresión en una sola función.
- Resumen como `data.frame` base.
- Gráficos con base R (`par(mfrow)`).
- Parámetro `bg_order` para Breusch-Godfrey configurable.
