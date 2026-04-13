# diagols — Guía para agentes LLM

Este documento describe el paquete R `diagols` para que un agente LLM pueda usarlo correctamente al asistir a un usuario con diagnóstico de regresión lineal (OLS).

## Qué es diagols

Paquete R que ejecuta una batería completa de tests diagnósticos sobre un modelo `lm()` y retorna resultados estructurados. Pensado para profesionales de salud y gestión que necesitan validar supuestos OLS antes de confiar en la inferencia (p-values, intervalos de confianza).

## Instalación

```r
pak::pak("paulovillarroel/curso-regresion-lineal")
```

Las dependencias se instalan automáticamente. Si ggplot2 y patchwork están instalados, los gráficos usan ggplot2; si no, usa base R.

## Funciones exportadas

### `diagnostico_ols(mod, alpha = 0.05, bg_order = 1)`

Función principal. Recibe un objeto `lm` y retorna un objeto de clase S3 `"dx_ols"`.

**Parámetros:**
- `mod`: objeto `lm` (resultado de `lm()`). NO acepta glm, lmer ni otros.
- `alpha`: nivel de significancia (default 0.05). Cambia los umbrales de decisión.
- `bg_order`: orden del test de Breusch-Godfrey. Valores comunes:
  - `1` (default): autocorrelación AR(1). Suficiente para corte transversal.
  - `7`: estacionalidad semanal (datos diarios, e.g., admisiones hospitalarias).
  - `12`: estacionalidad anual (datos mensuales, e.g., reportes epidemiológicos).
  - `4`: estacionalidad trimestral.

**Retorna:** objeto `"dx_ols"` (lista con clase). Al imprimirlo, muestra reporte en consola con semáforo. Contiene:

| Elemento | Tipo | Descripción |
|---|---|---|
| `resumen` | tibble (11 filas) | Una fila por test: supuesto, nombre del test, estadístico, p-value, decisión |
| `shapiro` | htest o NULL | Test de Shapiro-Wilk (NULL si n > 5000) |
| `lilliefors` | htest | Test de Lilliefors (KS corregido) |
| `jarque_bera` | htest | Test de Jarque-Bera |
| `breusch_pagan` | htest | Test de Breusch-Pagan (versión Koenker) |
| `reset` | htest | Test RESET de Ramsey |
| `breusch_godfrey` | htest | Test de Breusch-Godfrey |
| `vif` | numeric o matrix | VIF (numeric) o GVIF (matrix si hay categóricas). NULL si k < 2 |
| `condition_number` | numeric | CN de la matriz de diseño centrada/escalada. NA si k < 2 |
| `cooks` | named numeric | Distancia de Cook por observación |
| `leverage` | named numeric | Hat values por observación |
| `studentized_residuals` | named numeric | Residuos studentizados externos |
| `robust_se_cambio_pct` | named numeric | Cambio % en SE (HC3 vs OLS) por coeficiente |
| `flags` | named logical | Semáforo: TRUE = problema, FALSE = OK, NA = ambiguo |
| `model` | lm | El modelo original |
| `alpha` | numeric | Nivel de significancia usado |
| `bg_order` | numeric | Orden de BG usado |
| `n` | integer | Número de observaciones |
| `k` | integer | Número de predictores |
| `norm_rechazos` | integer | Cuántos tests de normalidad rechazan (0, 1, 2 o 3) |
| `influyentes` | integer | Observaciones con Cook's D > 4/n |
| `outliers_stud` | integer | Observaciones con |residuo studentizado| > 3 |
| `alto_leverage` | integer | Observaciones con hat value > 2(k+1)/n |

**Ejemplo:**

```r
library(diagols)
modelo <- lm(mpg ~ wt + hp + am, data = mtcars)
dx <- diagnostico_ols(modelo)

# El print se dispara automáticamente al mostrar dx
dx

# Acceder a resultados específicos
dx$resumen                    # tibble resumen
dx$flags                      # semáforo
dx$breusch_pagan$p.value      # p-value de BP
dx$robust_se_cambio_pct       # cambio en SE por coeficiente
```

### `print.dx_ols(x, ...)`

Método print para `dx_ols`. Se ejecuta automáticamente al mostrar el objeto. Imprime 7 secciones numeradas (Normalidad, Homocedasticidad, Especificación, Independencia, Multicolinealidad, Influencia, Comparación HC3) y un semáforo final.

No necesitas llamarlo explícitamente. Basta con `dx` o `print(dx)`.

### `augment(x, data = NULL, ...)`

Pega diagnósticos a nivel de observación al dataset original. Estilo `broom::augment()`.

**Parámetros:**
- `x`: objeto `dx_ols`.
- `data`: data frame original. Si es NULL, se extrae del modelo con `model.frame()`.

**Retorna:** tibble con las columnas originales MÁS:

| Columna | Tipo | Descripción |
|---|---|---|
| `.fitted` | numeric | Valores ajustados |
| `.resid` | numeric | Residuos |
| `.std.resid` | numeric | Residuos studentizados externos |
| `.hat` | numeric | Leverage (hat values) |
| `.cooksd` | numeric | Distancia de Cook |
| `.cooksd_flag` | logical | TRUE si Cook's D > 4/n |
| `.leverage_flag` | logical | TRUE si hat value > 2(k+1)/n |
| `.outlier_flag` | logical | TRUE si |residuo studentizado| > 3 |

**Ejemplo:**

```r
datos_dx <- augment(dx, mtcars)

# Filtrar observaciones problemáticas
library(dplyr)
datos_dx |> filter(.cooksd_flag | .outlier_flag)

# Ver las 5 observaciones más influyentes
datos_dx |> arrange(desc(.cooksd)) |> head(5)
```

Si el modelo se ajustó con un subset o con NAs eliminados, pasa el dataset completo como `data` para evitar errores de dimensión.

### `plot_diagnostico_ols(mod)`

Panel de 4 gráficos diagnósticos.

**Parámetros:**
- `mod`: objeto `lm` O `dx_ols` (acepta ambos).

**Comportamiento:**
- Si ggplot2 y patchwork están instalados → panel ggplot2 personalizable.
- Si no están instalados → panel base R (funcionalidad idéntica, sin personalización).

**Gráficos generados:**
1. Residuos vs Valores Ajustados (linealidad + homocedasticidad)
2. QQ-Plot de residuos (normalidad)
3. Leverage vs Residuos (puntos influyentes potenciales)
4. Distancia de Cook (influencia real)

**Ejemplo con personalización ggplot2:**

```r
p <- plot_diagnostico_ols(dx)

# & aplica a TODOS los paneles (convención patchwork)
# + solo aplicaría al último panel
p & ggplot2::theme_minimal()
p & ggplot2::theme_bw(base_size = 14)
```

### `comparar_modelos(..., alpha = 0.05, bg_order = 1)`

Compara 2+ modelos `lm` con AIC corregido por Jacobiano y flags diagnósticos.

**Parámetros:**
- `...`: dos o más objetos `lm`.
- `alpha`, `bg_order`: se pasan a `diagnostico_ols()` internamente.

**Detección automática de log(Y):** Parsea la fórmula de cada modelo. Si la variable dependiente está envuelta en `log()`, aplica la corrección Jacobiana: `AIC_corregido = AIC_log + 2 * sum(log(y_original))`. Esto permite comparar modelos con Y contra modelos con log(Y) en la misma escala — algo que `AIC()` de base R y `performance::compare_performance()` no hacen.

**Retorna:** tibble con una fila por modelo:

| Columna | Descripción |
|---|---|
| `modelo` | Fórmula como texto |
| `n`, `k` | Observaciones y predictores |
| `AIC` | AIC (corregido si log_y = TRUE) |
| `delta_AIC` | Diferencia respecto al mejor (0 = mejor) |
| `log_y` | TRUE si la variable dependiente tiene log() |
| `especificacion` ... `outliers` | Flags de cada diagnóstico (TRUE = problema) |
| `n_problemas` | Conteo total de flags TRUE |

**Ejemplo:**

```r
comp <- comparar_modelos(modelo_lineal, modelo_quad, modelo_log)
comp

# El mejor modelo tiene delta_AIC = 0 y menor n_problemas
comp |> dplyr::arrange(delta_AIC)
```

**Interpretación de delta_AIC:**
- delta < 2: modelos esencialmente equivalentes
- delta 4–7: evidencia moderada a favor del mejor
- delta > 10: modelo sustancialmente peor

## Flujo de trabajo recomendado para el agente

### 1. Diagnóstico inicial

```r
library(diagols)
modelo <- lm(y ~ x1 + x2 + x3, data = datos)
dx <- diagnostico_ols(modelo)
```

### 2. Interpretar el semáforo

```r
dx$flags
```

Lógica de decisión:
- `flags["Mala especificacion"] == TRUE` → **Prioridad 1**. El modelo tiene forma funcional incorrecta. No diagnosticar nada más hasta corregir (transformar X, agregar cuadrático, log).
- `flags["Heterocedasticidad"] == TRUE` → Si RESET pasa, usar errores HC3. Si RESET también falla, el problema puede ser especificación, no heterocedasticidad real.
- `flags["Alta influencia"] == TRUE` → Hay observaciones con Cook's D > 1. Investigar con `augment()`.
- `flags["Outliers"] == TRUE` → Hay residuos studentizados > 3. Investigar plausibilidad.
- `flags["No normalidad"] == TRUE` → Solo preocupante si n < 100. Con n grande, TCL compensa.
- `flags["Autocorrelacion"] == TRUE` → Solo relevante si los datos tienen orden temporal.
- `flags["Multicolinealidad"] == TRUE` → VIF > 5 o CN > 30. Revisar si hay variables redundantes.

### 3. Investigar observaciones problemáticas

```r
library(dplyr)
aug <- augment(dx, datos)
aug |> filter(.cooksd_flag) |> select(id, y, x1, .cooksd, .std.resid)
```

### 4. Comparar modelos

```r
# Si RESET falla, probar correcciones
modelo2 <- lm(log(y) ~ log(x1) + x2, data = datos)

# comparar_modelos() corre diagnostico_ols() internamente,
# detecta log(Y) y aplica corrección Jacobiana al AIC
comp <- comparar_modelos(modelo, modelo2)
comp

# El mejor modelo tiene delta_AIC = 0 y menor n_problemas
# Si delta_AIC < 2: modelos equivalentes
# Si delta_AIC > 10: diferencia sustancial
```

### 5. Visualizar

```r
plot_diagnostico_ols(modelo)   # modelo original
plot_diagnostico_ols(modelo2)  # modelo corregido
```

## Casos especiales que el agente debe manejar

### Modelo con 1 solo predictor
VIF y Condition Number no aplican (k < 2). La función los reporta como N/A automáticamente.

### n > 5000
Shapiro-Wilk no se ejecuta (limitación del test). Lilliefors y Jarque-Bera sí funcionan. La función reporta Shapiro como "N/A (n > 5000)".

### Variables categóricas en el modelo
`car::vif()` retorna una matriz GVIF en vez de un vector. La función lo maneja internamente y reporta GVIF^(1/(2*Df)) al cuadrado como VIF equivalente.

### Datos con NAs
`lm()` elimina filas con NAs silenciosamente (`na.omit`). Si el usuario pasa el dataset completo a `augment()`, las dimensiones no coincidirán. Solución: pasar `model.frame(modelo)` como data, o usar el default (que hace esto automáticamente).

### bg_order para datos de salud
- Admisiones hospitalarias diarias → `bg_order = 7` (patrón semanal)
- Reportes epidemiológicos mensuales → `bg_order = 12` (patrón anual)
- Datos de corte transversal sin orden temporal → `bg_order = 1` (default), interpretar con cautela

## Errores comunes que el agente debe prevenir

1. **Pasar un glm a diagnostico_ols()**: solo acepta `lm`. Para GLM, usar otros paquetes.
2. **Comparar R² entre modelo lineal y log**: si la variable dependiente cambia (Y vs log(Y)), R² no es comparable. Usar `comparar_modelos()` que aplica la corrección Jacobiana automáticamente.
3. **Eliminar outliers mecánicamente**: antes de eliminar, verificar plausibilidad clínica y evaluar impacto con/sin la observación.
4. **Interpretar BG en corte transversal**: si los datos no tienen orden temporal, un BG significativo no indica autocorrelación real.
5. **Confundir normalidad de Y con normalidad de errores**: el supuesto es sobre los residuos del modelo ajustado, no sobre la distribución de Y.

## Dependencias

**Requeridas (Imports):** lmtest, car, nortest, tseries, sandwich, tibble.

**Opcionales (Suggests):** ggplot2, patchwork (para gráficos modernos).

## Referencia del curso

Este paquete acompaña el curso "Diagnóstico Completo de Supuestos en Regresión Lineal (OLS)" disponible en https://github.com/paulovillarroel/curso-regresion-lineal. El documento Quarto contiene la teoría, las fórmulas, los ejemplos con datos reales (dataset Auto de ISLR2) y ejemplos aplicados a contextos de salud.
