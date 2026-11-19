# Marca Finaid

| Archivo | Uso |
| --- | --- |
| `finaid-logo.svg` | Ícono completo (README, tiendas, redes). |
| `finaid-mark-mono.svg` | Marca en un solo color (`currentColor`). |

**Concepto.** Una "F" de Finaid con un punto de notificación: la app convierte los
avisos de tu banco en finanzas ordenadas.

**Colores.**

| Token | Hex |
| --- | --- |
| Verde azulado claro | `#14A58C` |
| Verde azulado oscuro | `#0A4F45` |
| Ámbar (punto) | `#FFC24B` |
| Semilla del tema Material | `#0E7C6B` |

**Geometría.** Lienzo de 108 × 108 (el del ícono adaptativo de Android). La marca vive
en la zona segura de 66 dp; en el ícono plano se amplía 1,3× desde el centro.

En Android el ícono está en `android/app/src/main/res/` (`ic_launcher_finaid*`, con
versión monocromática para íconos temáticos) y en Flutter en
`lib/presentation/widgets/finaid_logo.dart`.
