# Diagnóstico Completo de Supuestos en Regresión Lineal (OLS)

Guía práctica y didáctica para diagnosticar, interpretar y corregir violaciones a los supuestos de regresión lineal por mínimos cuadrados ordinarios (OLS). Incluye funciones reutilizables en R, visualizaciones y un flujo completo de re-especificación de modelos. Orientado a profesionales de ciencia de datos, salud y gestión que buscan aplicar regresión con rigor estadístico.

## Qué cubre

El documento está estructurado como un flujo de trabajo completo:

**Fundamentos** — Teorema de Gauss-Markov, pruebas de hipótesis, p-values, errores Tipo I/II, Teorema Central del Límite aplicado a OLS, y una nota sobre identificación causal como paso previo al diagnóstico.

**Diagnóstico de los 5 supuestos clásicos + influencia:**

| Supuesto | Tests | Corrección |
|------------------------|------------------------|------------------------|
| Linealidad / especificación | RESET de Ramsey, CR-plots | Transformaciones, términos polinomiales |
| Normalidad de residuos | Shapiro-Wilk, Lilliefors, Jarque-Bera, Anderson-Darling | TCL (n grande), Box-Cox |
| Homocedasticidad | Breusch-Pagan, White | Errores robustos HC0–HC4 |
| Independencia | Durbin-Watson, Breusch-Godfrey | Errores HAC (Newey-West) |
| Multicolinealidad | VIF, GVIF, Condition Number | Centrado, eliminación de variables |
| Influencia | Cook's D, leverage, residuos studentizados | Revisión caso a caso |

**Contenido adicional:**

- Ejemplos aplicados en contextos clínicos y organizacionales (estadía hospitalaria, mortalidad, comorbilidades omitidas).
- Guía de lectura de gráficos ACF para detectar estacionalidad en datos temporales.
- Discusión sobre calidad del dato: cuándo el problema es el proceso de captura, no el modelo.
- Re-especificación iterativa de modelos con comparación AIC corregida por Jacobiano.
- Referencia complementaria a [The Effect](https://theeffectbook.net/) para identificación causal.

## Paquete `diagols`

Las funciones `diagnostico_ols()` y `plot_diagnostico_ols()` están disponibles como paquete de R instalable directamente desde este repositorio:

``` r
pak::pak("paulovillarroel/curso-regresion-lineal")
```

Las dependencias (`lmtest`, `car`, `nortest`, `tseries`, `sandwich`) se instalan automáticamente.

``` r
library(diagols)

modelo <- lm(mpg ~ wt + hp, data = mtcars)
diagnostico_ols(modelo)
plot_diagnostico_ols(modelo)

# Para datos con estacionalidad semanal:
diagnostico_ols(modelo, bg_order = 7)
```

`diagnostico_ols()` ejecuta Shapiro-Wilk, Lilliefors, Jarque-Bera, Breusch-Pagan, RESET, Breusch-Godfrey, VIF, Condition Number, Cook's D, leverage y residuos studentizados. Imprime un semáforo en consola y retorna una lista con todos los objetos de cada test.

`plot_diagnostico_ols()` genera un panel 2x2: residuos vs fitted, QQ-plot, leverage vs residuos, y distancia de Cook.

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