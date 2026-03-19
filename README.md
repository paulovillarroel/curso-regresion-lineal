# Diagnóstico Completo de Supuestos en Regresión Lineal (OLS)

Guía práctica y didáctica para diagnosticar, interpretar y corregir violaciones a los supuestos de regresión lineal por mínimos cuadrados ordinarios (OLS). Incluye funciones reutilizables en R, visualizaciones y un flujo completo de re-especificación de modelos.

## Qué cubre

El documento está estructurado como un flujo de trabajo completo:

**Fundamentos** — marco conceptual de pruebas de hipótesis, p-values, errores Tipo I/II y el Teorema Central del Límite aplicado a OLS.

**Diagnóstico de los 6 supuestos clásicos:**

| Supuesto | Tests | Corrección |
|---|---|---|
| Linealidad / especificación | RESET de Ramsey, CR-plots | Transformaciones, términos polinomiales |
| Normalidad de residuos | Shapiro-Wilk, Lilliefors, Jarque-Bera, Anderson-Darling | TCL (n grande), Box-Cox |
| Homocedasticidad | Breusch-Pagan, White | Errores robustos HC0–HC4 |
| Independencia | Durbin-Watson, Breusch-Godfrey | Errores HAC (Newey-West) |
| Multicolinealidad | VIF, GVIF, Condition Number | Centrado, eliminación de variables |
| Influencia | Cook's D, leverage, residuos studentizados | Revisión caso a caso |

**Funciones reutilizables:**

- `diagnostico_ols(mod)` — ejecuta todos los tests, imprime semáforo de resultados, retorna dataframe resumen y objetos de cada test.
- `plot_diagnostico_ols(mod)` — panel 2x2 con residuos vs fitted, QQ-plot, leverage y Cook's distance.

## Dataset

Usa el dataset `Auto` del paquete `ISLR2` (392 automóviles, 1970–1982).

## Configuración del entorno

Para tener R, Quarto y las herramientas necesarias correctamente instaladas y configuradas, se recomienda seguir la guía de configuración de entorno de desarrollo: [https://paulovillarroel.github.io/configuracion-entorno/](https://paulovillarroel.github.io/configuracion-entorno/)

### Requisitos mínimos

- [R](https://cran.r-project.org/) (>= 4.1)
- [Quarto CLI](https://github.com/quarto-dev/quarto-cli) (>= 1.3) — necesario para renderizar el documento desde terminal. [Instrucciones de instalación](https://quarto.org/docs/get-started/)

### Paquetes de R

Se usa [pak](https://pak.r-lib.org/) para instalar dependencias (más rápido y con mejor manejo de versiones que `install.packages()`):

```r
# Instalar pak si no lo tienes
install.packages("pak")

# Instalar todas las dependencias del proyecto
pak::pak(c("lmtest", "car", "nortest", "tseries", "sandwich", "ISLR2"))
```

## Instalación local

```bash
# Clonar el repositorio
git clone https://github.com/<tu-usuario>/curso-regresion-lineal.git
cd curso-regresion-lineal

# Instalar paquetes de R con pak
Rscript -e 'if (!requireNamespace("pak", quietly = TRUE)) install.packages("pak"); pak::pak(c("lmtest", "car", "nortest", "tseries", "sandwich", "ISLR2"))'

# Renderizar el documento
quarto render supuestos_regresion_lineal.qmd

# Abrir en el navegador
open supuestos_regresion_lineal.html   # macOS
xdg-open supuestos_regresion_lineal.html  # Linux
```

También puedes abrir `supuestos_regresion_lineal.qmd` directamente en tu IDE y renderizar desde ahí. IDE recomendado: [Positron](https://positron.posit.co/) — el nuevo IDE de Posit diseñado para ciencia de datos con soporte nativo para R, Python y Quarto. También funciona con RStudio o VS Code (con la extensión de Quarto).

## Licencia

CC BY 4.0 — Paulo Villarroel / Hazla con Datos
