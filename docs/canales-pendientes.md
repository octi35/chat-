# Canales pendientes de conectar — WhatsApp, Instagram, Facebook Messenger

Este documento lista, para Chatwoot y para ChatbotX, exactamente qué credenciales hacen falta, dónde se pegan, y qué pasos hay que hacer antes en Meta for Developers / Meta Business Suite. **Ninguna de estas credenciales se completó en esta sesión** — son datos que tenés que conseguir vos en Meta.

Importante (ver `docs/licencias.md` para el detalle completo): en Chatwoot, el envío de plantillas de WhatsApp para campañas (`send_template`) es código Enterprise. El resto de lo listado abajo (mensajería básica de los 3 canales) es MIT en ambos proyectos.

## Dónde vive cada credencial (resumen de arquitectura)

- **Chatwoot**: casi todas las credenciales de canal son *instalación-wide* (un solo Facebook/Instagram App ID+Secret para toda la instancia), configuradas en **Super Admin → Settings → Installation Configs** (`/super_admin/installation_configs` una vez logueado como superadmin), respaldadas por la tabla `InstallationConfig`. El archivo `config/installation_config.yml` sólo define los defaults/placeholders vacíos; no hay que tocar ese archivo. WhatsApp es la excepción: cada inbox de WhatsApp guarda su propio `api_key`/`phone_number_id`/`business_account_id` en `provider_config`, cargado al crear el inbox desde el Dashboard (Settings → Inboxes → Add Inbox → WhatsApp).
- **ChatbotX**: las credenciales de Meta (WhatsApp, Messenger, Instagram) se guardan cifradas en la tabla `PlatformCredential`, configurables desde la UI en **`/admin/platform-credentials`** (super admin) o **`/manage/platform-credentials`** (reseller/owner). No van en `.env`.

## 1. WhatsApp Business Cloud API

### Chatwoot
- **Dónde se pega:** Dashboard → Settings → Inboxes → Add Inbox → WhatsApp → provider "WhatsApp Cloud". Campos del formulario (persisten en `channel_whatsapp.provider_config`):
  - `phone_number` (el número de WhatsApp Business, con código de país)
  - `provider_config.api_key` → el **token de acceso permanente** (system user access token) de tu WABA
  - `provider_config.phone_number_id` → Phone Number ID de Meta
  - `provider_config.business_account_id` → WhatsApp Business Account ID (WABA ID)
  - `provider_config.webhook_verify_token` → **lo genera Chatwoot solo** (no lo pegás vos); tenés que copiarlo desde el inbox creado y pegarlo en la config del webhook en Meta.
  - Callback URL del webhook a configurar en Meta: `https://<tu-dominio-chatwoot>/webhooks/whatsapp/<phone_number>`
- **Pasos previos en Meta for Developers:**
  1. Crear una app de tipo "Business" en https://developers.facebook.com/apps
  2. Agregar el producto "WhatsApp" a la app
  3. Verificar el negocio en Meta Business Suite (Business Verification) — obligatorio para salir de modo test y mandar mensajes a números no agregados como testers
  4. Agregar/confirmar el número de teléfono de WhatsApp Business
  5. Generar un **token de acceso permanente** (via System User en Business Settings, con permiso `whatsapp_business_messaging` y `whatsapp_business_management`) — el token temporal de 24hs que da el Quickstart no sirve para producción
  6. Copiar Phone Number ID y WABA ID desde WhatsApp → API Setup

### ChatbotX
- **Dónde se pega:** `/admin/platform-credentials` (o `/manage/platform-credentials`) → WhatsApp. Campos (`packages/database/src/partials/credential.ts`, tipo `whatsapp`):
  - `clientId` (App ID de Meta)
  - `clientSecret` (App Secret de Meta)
  - `version` (versión de Graph API, ej. `v23.0`)
  - `configId` (Configuration ID del flujo de Embedded Signup)
  - `systemUserId` y `systemUserToken` (usuario del sistema y su token permanente)
  - `businessId` (opcional) y `businessName`
  - `verifyToken` (lo elegís vos, cualquier string; se usa para validar el webhook)
- **Pasos previos en Meta:** los mismos 1–6 de arriba, más: configurar el flujo de **Embedded Signup** en la app de Meta (WhatsApp → Configuration → Embedded Signup) para obtener el `configId`, ya que ChatbotX usa ese flujo para que cada cliente final conecte su propio número desde la UI.

## 2. Instagram (mensajería directa)

### Chatwoot
- **Dónde se pega:**
  1. Instalación-wide en Super Admin → Installation Configs: `INSTAGRAM_APP_ID`, `INSTAGRAM_APP_SECRET`, `INSTAGRAM_VERIFY_TOKEN`
  2. Por cuenta: Dashboard → Settings → Inboxes → Add Inbox → Instagram → botón de conectar cuenta (OAuth); Chatwoot completa solo `access_token` e `instagram_id` en `channel_instagram` tras el login.
  - Callback del webhook (fijo, no por cuenta): `https://<tu-dominio-chatwoot>/webhooks/instagram`
- **Pasos previos en Meta:**
  1. En la misma app de Meta, agregar el producto "Instagram Graph API" (o "Instagram" según la versión del panel)
  2. Convertir/tener la cuenta de Instagram como cuenta profesional (Business o Creator) vinculada a una Página de Facebook
  3. Configurar el Webhook de Instagram con el `INSTAGRAM_VERIFY_TOKEN` que vas a cargar en Chatwoot
  4. Pedir los permisos `instagram_basic`, `instagram_manage_messages`, `pages_show_list` en el App Review de Meta (en modo desarrollo solo funciona con cuentas agregadas como testers)

### ChatbotX
- **Dónde se pega:** `/admin/platform-credentials` → Instagram (tipo `instagram`, mensajería directa vía Instagram Login) o "Instagram via Facebook" (tipo `instagramFacebook`, coexistencia con una Página de Facebook vinculada) — ChatbotX soporta ambos flujos, elegís cuál usar por workspace. Campos en ambos casos:
  - `clientId`, `clientSecret`, `version`, `verifyToken`
- **Pasos previos en Meta:** iguales a los de Chatwoot arriba (cuenta profesional de Instagram, permisos `instagram_basic`/`instagram_manage_messages`, App Review).

## 3. Facebook Messenger

### Chatwoot
- **Dónde se pega:**
  1. Instalación-wide: `FB_APP_ID`, `FB_APP_SECRET`, `FB_VERIFY_TOKEN` en Super Admin → Installation Configs
  2. Por página: Dashboard → Settings → Inboxes → Add Inbox → Facebook Messenger → conectar con Facebook (OAuth); Chatwoot completa `page_id`, `page_access_token`, `user_access_token` automáticamente.
  - El webhook lo maneja la gem `facebook-messenger` internamente al hacer el login OAuth; no hay que configurar manualmente la callback URL en Meta si usás el flujo de conexión de Chatwoot (Chatwoot se suscribe al webhook programáticamente con el App Secret).
- **Pasos previos en Meta:**
  1. Agregar el producto "Messenger" a la misma app de Meta
  2. Vincular la(s) Página(s) de Facebook de la pyme cliente a la app
  3. Pedir el permiso `pages_messaging` (y `pages_show_list`) en App Review para uso en producción con páginas que no sean admins/testers de la app

### ChatbotX
- **Dónde se pega:** `/admin/platform-credentials` → Messenger (tipo `messenger`). Campos:
  - `clientId`, `clientSecret`, `version`, `verifyToken`
  - `marketingMessagesConfigId` (opcional, solo si vas a usar Marketing Messages/broadcast fuera de la ventana de 24hs)
- **Pasos previos en Meta:** iguales a los de Chatwoot arriba.

## Checklist de lo que tenés que conseguir en Meta (una sola vez, sirve para ambos productos si usás la misma app de Meta)

- [ ] Cuenta de Meta Business (Business Manager) verificada
- [ ] Una app en developers.facebook.com de tipo Business, con los productos WhatsApp + Messenger + Instagram agregados
- [ ] Business Verification aprobada
- [ ] Al menos una Página de Facebook y una cuenta de Instagram profesional vinculada a esa página
- [ ] Un número de WhatsApp Business verificado
- [ ] System User con token permanente (`whatsapp_business_messaging`, `whatsapp_business_management`)
- [ ] App Review aprobado para: `pages_messaging`, `pages_show_list`, `instagram_basic`, `instagram_manage_messages`
- [ ] Configuration ID de Embedded Signup (solo si vas a dejar que cada cliente final conecte su propio número/página desde ChatbotX o Chatwoot, en vez de conectarlos vos a mano)

Con esas credenciales en mano, los tres canales se cargan desde las UIs de administración de cada producto (no hace falta editar código ni redeploy).
