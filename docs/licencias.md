# Auditoría de licencias — Chatwoot y ChatbotX

Fecha de auditoría: 2026-09-16. Basada en un `git clone --depth 1` de la rama por defecto de cada repo en esa fecha.

## Resumen ejecutivo

| Proyecto | Licencia base | Canal / feature | ¿MIT o Enterprise? |
|---|---|---|---|
| Chatwoot | MIT (raíz) + Enterprise License (`enterprise/`) | WhatsApp Cloud API — enviar/recibir mensajes | **MIT** (`app/models/channel/whatsapp.rb`, `app/services/whatsapp/`) |
| Chatwoot | | WhatsApp — envío de plantillas (`send_template`) y grabación de llamadas | **Enterprise** (`enterprise/app/models/enterprise/channel/whatsapp.rb`) |
| Chatwoot | | Instagram — enviar/recibir mensajes | **MIT**, sin overlay enterprise |
| Chatwoot | | Facebook Messenger — enviar/recibir mensajes | **MIT**, sin overlay enterprise |
| Chatwoot | | Captain (agente IA) — lógica de generación de respuestas, prompts, tools | **Enterprise** (ver detalle abajo) |
| ChatbotX | MIT (raíz) + Commercial License (`apps/builder/src/enterprise/`) | Community Edition (builder, worker, integrations, CLI, MCP server) | **MIT** |
| ChatbotX | | Código bajo `apps/builder/src/enterprise/` y `packages/database/src/schema/enterprise/` | **Commercial License** (no AGPL — ver nota) |

## 1. ChatbotX

### 1.1 Texto de las licencias

`LICENSE` (raíz, copyright AhaChat LLC):

> "Content outside of the above mentioned directories or restrictions above is available under the MIT license as defined below."
> "All content that resides under the 'apps/builder/src/enterprise' directory of this repository (Commercial License) is licensed under the license defined in 'apps/builder/src/enterprise/LICENSE'."

`README.md` (sección "## License"):

> "ChatbotX' Community Edition is released as open source under the [MIT License] ... and enterprise features are released under [Commercial License]"

`AGENTS.md`:

> "**License:** Community Edition is **MIT**; enterprise-specific code may fall under a separate commercial license (see `apps/builder/src/enterprise/LICENSE`)."

`apps/builder/src/enterprise/LICENSE` y `packages/database/src/schema/enterprise/LICENSE` (idénticos, "The ChatbotX Commercial License"):

> "Open Source vs. Commercial Licensing: This Commercial License applies only to the part of this Software that is not distributed under the MIT License. The Open Source version of ChatbotX is licensed under the MIT License."

### 1.2 Sobre la supuesta contradicción MIT vs AGPLv3

El prompt original suponía una contradicción entre el README (Community = MIT) y `apps/builder/src/enterprise/LICENSE` (que mencionaría AGPLv3). **No encontré esa contradicción en el código clonado hoy**: hice `grep -ril "agpl"` sobre todo el repo `chatbotx/` y no hubo ningún resultado. Los dos archivos `enterprise/LICENSE` que existen en el repo (`apps/builder/src/enterprise/LICENSE` y `packages/database/src/schema/enterprise/LICENSE`) usan textualmente "The ChatbotX Commercial License", no AGPLv3, y son consistentes entre sí y con el README y AGENTS.md.

**Conclusión:** con el estado actual del repo, no hay bloqueo de licencia por contradicción — el criterio es simple: todo lo que está fuera de las carpetas `.../enterprise/` es MIT; todo lo que está dentro es Commercial License de AhaChat LLC. Si el usuario tenía en mente una versión anterior del repo donde sí figuraba AGPLv3, esa referencia ya no está presente; no se tomó ninguna acción sobre código bajo `enterprise/` sin confirmación.

### 1.3 Carpetas enterprise detectadas (no tocar sin autorización)

- `apps/builder/src/enterprise/`
- `packages/database/src/schema/enterprise/`

El build de esta sesión usa exclusivamente el código fuera de esas carpetas (Community Edition).

### 1.4 Hallazgo crítico para el plan de negocio: el whitelabel dinámico es Enterprise

Investigando la infraestructura de whitelabeling (ver `docs/whitelabel.md` para el detalle completo) encontré que **la marca por tenant/cliente (nombre, logo, favicon, dominio propio, tema, CSS/JS custom, templates de email) sólo se aplica si `hasEnterpriseFeatures()` es `true`**. La lógica está en `packages/business/src/platform/settings.ts` (`applyTenantSetting`):

> ```ts
> name: enterpriseFeaturesEnabled
>   ? (setting.brandName ?? defaults.name)
>   : defaults.name,
> ```

Y los defaults sin Enterprise son literalmente hardcodeados:

> ```ts
> name: "ChatbotX",
> logoLightUrl: `${derived.appUrl}/brand/logo_white.svg`,
> logoDarkUrl: `${derived.appUrl}/brand/logo_black.svg`,
> faviconUrl: `${derived.appUrl}/brand/icon_black.svg`,
> ```

Es decir: en Community Edition, **no existe forma de darle una marca distinta a cada cliente pyme** vía configuración o UI — eso vive en `apps/builder/src/enterprise/features/platform-branding/` y las rutas `/admin/(enterprise)/(non-cloud)/branding` y `/manage/(enterprise)/branding`, todas bajo la carpeta enterprise. Lo único que se puede personalizar sin licencia Enterprise es una marca **única y global** para toda la instalación, editando a mano los 3 archivos SVG + favicon en `apps/builder/public/brand/` y (opcionalmente) el string `"ChatbotX"` hardcodeado en `packages/business/src/platform/settings.ts` — esto último ya es editar código fuente MIT, no configuración.

No toqué ni activé nada de `apps/builder/src/enterprise/features/platform-branding/`. Esto queda pendiente de tu decisión — ver el checklist en `docs/whitelabel.md`.

## 2. Chatwoot

### 2.1 Texto de las licencias

`LICENSE` (raíz, copyright Chatwoot Inc.):

> "All content that resides under the 'enterprise/' directory of this repository, if that directory exists, is licensed under the license defined in 'enterprise/LICENSE'."
> "Content outside of the above mentioned directories or restrictions above is available under the 'MIT Expat' license as defined below."

`enterprise/LICENSE` ("The Chatwoot Enterprise license"):

> "This software ... may only be used in production, if you (and any entity that you represent) have agreed to, and are in compliance with, the Chatwoot Subscription Terms of Service ... or ... have a valid Chatwoot Enterprise License for the correct number of user seats ... Notwithstanding the foregoing, you may copy and modify the Software for development and testing purposes, without requiring a subscription."

Es decir: el código de `enterprise/` se puede correr localmente para desarrollo/pruebas sin licencia (como hicimos en esta sesión), pero **usarlo en producción para atender clientes reales requiere una suscripción Enterprise de Chatwoot**.

### 2.2 ¿WhatsApp, Instagram y Facebook dependen de `enterprise/`?

Investigación por código (no solo por nombre de carpeta):

- **WhatsApp Business Cloud API** (`app/models/channel/whatsapp.rb`, `app/services/whatsapp/send_on_whatsapp_service.rb`, `app/services/whatsapp/incoming_message_whatsapp_cloud_service.rb`, `app/controllers/webhooks/whatsapp_controller.rb`) — **MIT**. Envío y recepción de mensajes de texto/multimedia funciona con este código.
  - `enterprise/app/models/enterprise/channel/whatsapp.rb` agrega vía `prepend_mod_with` **solamente** `send_template` (envío de plantillas de WhatsApp Business, usado para campañas salientes/broadcast) y ajustes de grabación de llamadas (`Concerns::CallRecordingSettings`). Eso sí requiere Enterprise.
- **Instagram** (`app/models/channel/instagram.rb`, `app/services/instagram/`, `app/controllers/webhooks/instagram_controller.rb`) — **100% MIT**. No existe ningún archivo bajo `enterprise/` relacionado a Instagram.
- **Facebook Messenger** (`app/models/channel/facebook_page.rb`) — **100% MIT**. No existe ningún archivo bajo `enterprise/` relacionado a Facebook/Messenger.
- **Captain (agente IA)** — **mixto, con la parte crítica en Enterprise**:
  - `lib/captain/` (raíz, MIT) contiene servicios auxiliares: `summary_service.rb`, `follow_up_service.rb`, `reply_suggestion_service.rb`, `label_suggestion_service.rb`, `rewrite_service.rb`, `csat_utility_analysis_service.rb`, `overview_summary_service.rb`, `tool_instrumentation.rb`.
  - `enterprise/lib/captain/` (Enterprise License) contiene el **motor real de generación de respuestas del agente**: `prompt_renderer.rb`, `response_schema.rb`, `conversation_completion_service.rb`, todos los `tools/` (handoff, resolver conversación, agregar nota privada, FAQ lookup, HTTP tool, etc.) y todos los templates de prompts (`prompts/assistant.liquid`, etc.).
  - `config/application.rb` agrega `enterprise/lib` y `enterprise/app` a los `eager_load_paths` **siempre** (no hay flag que lo desactive), así que el código enterprise se carga igual en cualquier instalación self-hosted. Legalmente, correrlo en producción para atender clientes reales de todas formas requiere la suscripción Enterprise citada arriba.

**Implicación práctica para el plan de negocio:** los tres canales de mensajería (WhatsApp, Instagram, Facebook) se pueden ofrecer en producción sin pagar licencia Enterprise de Chatwoot, siempre que no se use el envío de plantillas de WhatsApp vía `send_template` para campañas de broadcast. **Captain como agente IA de atención automática sí depende del código Enterprise** para generar respuestas — no se puede ofrecer "Captain" a clientes en producción sin una suscripción Enterprise de Chatwoot. No se activó ni tocó código de `enterprise/` en esta sesión sin dejarlo documentado aquí.

### 2.3 Carpeta enterprise (no tocar sin autorización)

- `chatwoot/enterprise/` completa.

## 3. Pendiente de decisión del usuario

- **Chatwoot Enterprise / Captain**: si se quiere ofrecer el agente IA "Captain" a los clientes finales del whitelabel, hay que conseguir una suscripción Enterprise de Chatwoot (https://www.chatwoot.com/terms-of-service/) o evaluar reemplazar Captain por un bot construido a medida (BuilderBot, fase 2) o por los agentes IA de ChatbotX, que sí son MIT.
- **Chatwoot Enterprise / WhatsApp templates**: si se necesita mandar plantillas de WhatsApp para marketing saliente (broadcast), también requiere Enterprise. Alternativa: usar el broadcasting nativo de ChatbotX (MIT) para esa función en lugar del de Chatwoot.
- **ChatbotX Enterprise**: no se detectó bloqueo; solo evitar tocar `apps/builder/src/enterprise/` y `packages/database/src/schema/enterprise/` sin licencia comercial.
