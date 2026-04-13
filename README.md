# Diagnóstico Completo de Supuestos en Regresión Lineal (OLS)

Guía práctica y didáctica para diagnosticar, interpretar y corregir violaciones a los supuestos de regresión lineal por mínimos cuadrados ordinarios (OLS). Incluye funciones reutilizables en R, visualizaciones y un flujo completo de re-especificación de modelos. Orientado a profesionales de ciencia de datos, salud y gestión que buscan aplicar regresión con rigor estadístico.

## Qué cubre

El documento está estructurado como un flujo de trabajo completo:

**Fundamentos** — Teorema de Gauss-Markov, pruebas de hipótesis, p-values, errores Tipo I/II, Teorema Central del Límite aplicado a OLS, y una nota sobre identificación causal como paso previo al diagnóstico.

**Diagnóstico de los 5 supuestos clásicos + influencia:**

| Supuesto | Tests | Corrección |
|------------------------|------------------------|------------------------|
| Linealidad / especificación | RESET de Ramsey, CR-plots | Transformaciones, términos polinomiales |
| Normalidad de residuos | Shapiro-Wilk, Lilliefors, Jarque-Bera, Anderson-Darling | TCL (n grande), Box-Cox, bootstrap |
| Homocedasticidad | Breusch-Pagan, White | Errores robustos HC0–HC4, WLS |
| Independencia | Durbin-Watson, Breusch-Godfrey | Errores HAC (Newey-West) |
| Multicolinealidad | VIF, GVIF, Condition Number | Centrado, eliminación de variables |
| Influencia | Cook's D, leverage, residuos studentizados | Revisión caso a caso |

**Guía de especificación funcional** — 6 formas con fórmula, interpretación, ejemplo clínico y código R:

- Lineal (level-level), Log-lin (log-level), Lin-log (level-log), Log-log, Cuadrática, Interacciones (efectos modificadores).
- Guía de 3 pasos: teoría del fenómeno → diagnósticos → interpretabilidad para el usuario final.
- Diagrama de flujo (Mermaid) para troubleshooting de diagnósticos.

**Contenido adicional:**

- Ejemplos aplicados en gestión sanitaria: listas de espera (heterocedasticidad), tiempos de urgencia (autocorrelación), hospitales con comportamiento anómalo (outliers/leverage), mortalidad posquirúrgica (cuadrática), comorbilidades omitidas (OVB).
- Guía de lectura de gráficos ACF para detectar estacionalidad en datos temporales.
- Datos perdidos (NAs) y sesgo de selección: cómo `na.omit` silencioso puede sesgar el análisis.
- Calidad del dato: cuándo el problema es el proceso de captura, no el modelo.
- Distinción entre predicción e inferencia: por qué los supuestos importan para p-values pero no necesariamente para predicción.
- Bootstrap con `car::Boot` para inferencia sin asumir normalidad.
- WLS (mínimos cuadrados ponderados) para heterocedasticidad severa.
- Re-especificación iterativa con comparación AIC corregida por Jacobiano.
- Caso de uso: la "cola larga" de las listas de espera y cuándo ir más allá de OLS (GLM).
- Referencias complementarias: [The Effect](https://theeffectbook.net/) y [Causal Inference in R](https://www.r-causal.org/) con capítulos específicos.

## Paquete `diagols` (v0.2.2)

Las funciones diagnósticas están disponibles como paquete R instalable directamente desde este repositorio:

``` r
# Instalar
pak::pak("paulovillarroel/curso-regresion-lineal")

# Actualizar a la última versión (si ya lo tenías instalado)
pak::pak("paulovillarroel/curso-regresion-lineal", upgrade = TRUE)
```

Las dependencias se instalan automáticamente. Si `ggplot2` y `patchwork` están instalados, los gráficos los usan; si no, usa base R.

### Uso básico

``` r
library(diagols)

modelo <- lm(mpg ~ wt + hp, data = mtcars)
dx <- diagnostico_ols(modelo)          # S3 class "dx_ols": calcula todo, imprime semáforo
dx$resumen                              # tibble con todos los tests
dx$flags                                # semáforo lógico
```

### Integración tidy con augment()

``` r
library(dplyr)
augment(dx, mtcars) |>                  # pega .cooksd, .hat, .std.resid al dataset
  filter(.cooksd_flag | .outlier_flag)  # filtra observaciones problemáticas
```

### Gráficos ggplot2 personalizables

``` r
p <- plot_diagnostico_ols(dx)           # acepta lm o dx_ols
p & ggplot2::theme_minimal()            # & aplica tema a los 4 paneles
```

### Comparación de modelos con AIC corregido

``` r
# Compara modelos con distinta variable dependiente (Y vs log(Y))
# Aplica corrección Jacobiana automáticamente
m1 <- lm(mpg ~ wt + hp, data = mtcars)
m2 <- lm(log(mpg) ~ log(wt) + hp, data = mtcars)

comparar_modelos(m1, m2)
# Retorna tibble con AIC corregido, delta_AIC, flags diagnósticos y n_problemas
```

### Estacionalidad

``` r
# Para datos diarios con patrón semanal:
diagnostico_ols(modelo, bg_order = 7)
```

### Funciones exportadas

| Función | Descripción |
|---|---|
| `diagnostico_ols(mod, alpha, bg_order)` | Ejecuta todos los tests, retorna objeto S3 `dx_ols` |
| `print.dx_ols(x)` | Imprime reporte en consola con semáforo (se ejecuta automáticamente) |
| `augment(x, data)` | Pega diagnósticos por observación al dataset (estilo broom) |
| `comparar_modelos(...)` | Compara 2+ modelos: AIC con corrección Jacobiana automática + flags |
| `plot_diagnostico_ols(mod)` | Panel 2x2: residuos vs fitted, QQ-plot, leverage, Cook's D |

Tests incluidos: Shapiro-Wilk, Lilliefors, Jarque-Bera, Breusch-Pagan, RESET, Breusch-Godfrey, VIF/GVIF, Condition Number, Cook's D, leverage, residuos studentizados, comparación OLS vs HC3.

Para documentación completa dirigida a agentes LLM, ver [AGENTS.md](AGENTS.md). Para changelog, ver [NEWS.md](NEWS.md).

## Dataset

Usa el dataset `Auto` del paquete `ISLR2` (392 automóviles, 1970–1982).

## Configuración del entorno

Para tener R, Quarto y las herramientas necesarias correctamente instaladas y configuradas, se recomienda seguir la guía de configuración de entorno de desarrollo: <https://paulovillarroel.github.io/configuracion-entorno/>

### Requisitos mínimos

-   [R](https://cran.r-project.org/) (\>= 4.1)
-   [Quarto CLI](https://github.com/quarto-dev/quarto-cli) (\>= 1.3) — necesario para renderizar el documento desde terminal. [Instrucciones de instalación](https://quarto.org/docs/get-started/)

### Paquetes de R

Se usa [pak](https://pak.r-lib.org/) para instalar dependencias (más rápido y con mejor manejo de versiones que `install.packages()`):

``` r
# Instalar pak si no lo tienes
install.packages("pak")

# Instalar todas las dependencias del proyecto
pak::pak(c("lmtest", "car", "nortest", "tseries", "sandwich", "ISLR2"))
```

## Instalación local

``` bash
# Clonar el repositorio
git clone https://github.com/paulovillarroel/curso-regresion-lineal.git
cd curso-regresion-lineal

# Instalar paquetes de R con pak
Rscript -e 'if (!requireNamespace("pak", quietly = TRUE)) install.packages("pak"); pak::pak(c("lmtest", "car", "nortest", "tseries", "sandwich", "ISLR2"))'

# Renderizar el documento
quarto render supuestos_regresion_lineal.qmd

# Abrir en el navegador
open _site/supuestos_regresion_lineal.html   # macOS
xdg-open _site/supuestos_regresion_lineal.html  # Linux
```

También puedes abrir `supuestos_regresion_lineal.qmd` directamente en tu IDE y renderizar desde ahí. IDE recomendado: [Positron](https://positron.posit.co/) — el nuevo IDE de Posit diseñado para ciencia de datos con soporte nativo para R, Python y Quarto. También funciona con RStudio o VS Code (con la extensión de Quarto).

## Licencia

CC BY 4.0 — Paulo Villarroel / Hazla con Datos