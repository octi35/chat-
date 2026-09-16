# Infraestructura de whitelabeling — qué editar cuando definas la marca

Todavía no definiste nombre de marca, colores ni logo — este documento no inventa nada de eso. Lo que hace es mapear **exactamente qué archivo/config tenés que tocar en cada producto** el día que decidas el branding, y qué diferencia de alcance hay entre Chatwoot y ChatbotX (importante para tu modelo de negocio, ver la sección de comparación al final).

## Chatwoot — 100% configurable sin tocar código (MIT)

Toda la marca de Chatwoot vive en la tabla `InstallationConfig`, editable desde **Dashboard → Super Admin → Settings → Installation Configs** (`/super_admin/installation_configs`), sembrada con placeholders desde `config/installation_config.yml` (no hace falta ni conviene editar ese YAML a mano; es sólo el default de fábrica).

| Config | Qué controla | Default actual |
|---|---|---|
| `INSTALLATION_NAME` | Nombre que aparece en dashboard/título | `Chatwoot` (placeholder) |
| `LOGO` | Logo del dashboard/login | `/brand-assets/logo.svg` |
| `LOGO_DARK` | Logo en modo oscuro | `/brand-assets/logo_dark.svg` |
| `LOGO_THUMBNAIL` | Favicon (512×512) | `/brand-assets/logo_thumbnail.svg` |
| `BRAND_NAME` | Nombre usado en emails y en el widget de chat | `Chatwoot` |
| `BRAND_URL` | URL del "Powered by" en emails | `https://www.chatwoot.com` |
| `WIDGET_BRAND_URL` | URL del "Powered by" en el widget | `https://www.chatwoot.com` |
| `TERMS_URL` / `PRIVACY_URL` | Links legales en signup/dashboard | chatwoot.com |
| `DISPLAY_MANIFEST` | Mostrar favicons/metadata por defecto de Chatwoot | `true` (poné `false` para ocultarlos) |

Si `LOGO`/`LOGO_DARK`/`LOGO_THUMBNAIL` apuntan a un path bajo `/brand-assets/`, hay que reemplazar los archivos físicos en `chatwoot/public/brand-assets/` (o subir los tuyos a algún storage y poner la URL completa en el config — ambos funcionan, `LOGO` acepta URL absoluta).

**Importante:** en Chatwoot no hay marca *por cliente/tenant* — es una configuración global de la instalación. Si cada pyme necesita su propia marca, tenés que correr una instancia de Chatwoot por cliente (separadas), no una sola compartida.

Nota de colores: no encontré un `INSTALLATION_CONFIG` para paleta de colores — Chatwoot deriva sus colores desde `tailwind.config.js` en build-time (mencionado también en `AGENTS.md`), así que cambiar colores sí requiere editar ese archivo y rebuildear, a diferencia de nombre/logo que son runtime.

## ChatbotX — marca global editable en Community, marca por cliente requiere Enterprise

Ver el hallazgo completo en `docs/licencias.md` (sección 1.4). Resumen:

- **Community Edition (MIT, lo que tenés corriendo ahora):** la marca es **global y hardcodeada**. No hay UI ni variable de entorno para cambiarla. Cuando definas tu marca, hay que:
  1. Reemplazar los 4 archivos estáticos en `chatbotx/apps/builder/public/brand/`: `logo.svg`, `logo_black.svg`, `logo_white.svg`, `favicon` (y sus variantes dentro de esa carpeta)
  2. Editar el string hardcodeado en `chatbotx/packages/business/src/platform/settings.ts`, función `buildDefaults` (línea ~51): `name: "ChatbotX"` → tu nombre real. En la misma función también están `policyUrl`/`termsOfServiceUrl` (apuntan a `chatbotx.io` por defecto) por si querés cambiarlos.
  3. Rebuildear el contenedor `builder` para que tome los cambios (no es hot-config, es código).
  - Esto aplica **una sola marca para toda la instalación**, igual que Chatwoot.

- **Enterprise/Cloud:** `apps/builder/src/enterprise/features/platform-branding/` habilita una UI (`/manage/(enterprise)/branding` para el reseller, `/admin/(enterprise)/(non-cloud)/branding` para self-hosted no-cloud) donde se sube logo claro/oscuro/favicon y se define nombre, tema, CSS/JS custom y templates de email **por tenant**, más dominio propio por cliente (`CustomDomain` + `Tenant`, también enterprise). Esto es lo que necesitás si el plan es que cada pyme tenga su propio dominio y logo dentro de una única instalación de ChatbotX que vos operás — y requiere la licencia comercial de AhaChat LLC.

## Qué decisión te queda pendiente

1. **¿Un Chatwoot/ChatbotX por cliente pyme, o una instancia compartida para todos?**
   - Por cliente → la marca global gratuita de cada producto alcanza (una marca = una instalación = un cliente), pero implica más infraestructura para mantener por cliente.
   - Compartida → en Chatwoot la marca sigue siendo global igual (no hay multi-tenant de marca ni pagando), en ChatbotX necesitás Enterprise para que cada cliente vea su propio logo/dominio.
2. Cuando tengas nombre/logo/colores definitivos, avisame y edito los 3 lugares de arriba (Installation Configs de Chatwoot vía script/seed, y los 2 puntos de ChatbotX) en un solo paso.
