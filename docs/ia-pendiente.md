# Claves de IA pendientes — Chatwoot (Captain) y ChatbotX

## Chatwoot — Captain

**Importante primero:** según `docs/licencias.md`, el motor de generación de respuestas de Captain (`enterprise/lib/captain/`: prompts, tools, `response_schema.rb`, `conversation_completion_service.rb`) es código **Enterprise**, no MIT. Aunque técnicamente carga en cualquier instalación self-hosted (`config/application.rb` agrega `enterprise/` a los eager load paths siempre), usarlo en producción para atender clientes reales requiere una suscripción Enterprise de Chatwoot. Cargar la API key de abajo sirve para **probar Captain en desarrollo/testing local** (permitido sin suscripción, ver la licencia), no para ofrecerlo comercialmente todavía.

- **Dónde se pega:** Dashboard → Super Admin → Settings → Installation Configs (`/super_admin/installation_configs`), no en `.env` directamente (aunque `.env` puede usarse como fallback de primera carga, ver abajo).
- **Variables/config:**
  - `CAPTAIN_OPEN_AI_API_KEY` — API key de OpenAI (tipo `secret`)
  - `CAPTAIN_OPEN_AI_MODEL` — modelo a usar (default `gpt-4.1-mini` si se deja vacío)
  - `CAPTAIN_OPEN_AI_ENDPOINT` — opcional, para usar un endpoint compatible con OpenAI que no sea el oficial (ej. Azure OpenAI, un proxy propio)
  - `CAPTAIN_EMBEDDING_MODEL` — opcional, default `text-embedding-3-small` (para la base de conocimiento de Captain)
  - `CAPTAIN_FIRECRAWL_API_KEY` — opcional, solo si vas a usar el crawler de FireCrawl para importar documentación web a la base de conocimiento
- **Proveedor probado:** Captain sólo soporta la API de OpenAI (o cualquier servicio compatible con su API vía `CAPTAIN_OPEN_AI_ENDPOINT`) — no tiene soporte nativo para Claude/Gemini/DeepSeek. Como placeholder dejé `CAPTAIN_OPEN_AI_API_KEY=` vacío en `.env`; hay que pegar ahí una API key real de OpenAI (`sk-...`) para probarlo.
- **Precedencia ENV vs DB (corregido tras revisar el código del initializer):** `config/initializers/ai_agents.rb` lee `CAPTAIN_OPEN_AI_API_KEY` con `InstallationConfig.find_by(...)` **directo a la base**, sin pasar por `GlobalConfigService` — a diferencia de `FB_VERIFY_TOKEN`/`FB_APP_SECRET` (que sí aceptan la variable de entorno como fallback de primera carga vía `GlobalConfigService.load`), **la clave de Captain no se puede precargar por `.env`**. Hay que cargarla siempre desde Dashboard → Super Admin → Installation Configs después del primer arranque, y como este initializer corre una sola vez al bootear el proceso Rails, hace falta reiniciar el contenedor `rails` (o `sidekiq`) después de guardar la key para que Captain la tome.

## ChatbotX

ChatbotX sí soporta múltiples proveedores de IA de forma nativa (`packages/ai/src/core/factory.ts`): OpenAI, Google Gemini, Anthropic Claude, DeepSeek y OpenRouter.

- **Dónde se pega (clave por defecto de la plataforma):** `.env` en la raíz del repo — estas son las claves que usa el sistema como fallback/plan por defecto para todos los workspaces que no traen su propia clave (BYOK):
  - `OPENAI_API_KEY`
  - `GOOGLE_GENERATIVE_AI_API_KEY` (Gemini)
  - `ANTHROPIC_API_KEY` (Claude)
  - `DEEPSEEK_API_KEY`
  - `OPENROUTER_API_KEY`
- **Dónde se pega (clave propia por workspace, BYOK):** cada workspace puede cargar su propia API key desde Settings → Integrations → el proveedor de IA correspondiente, dentro de la app (`apps/builder`), guardada cifrada — no en `.env`.
- **Proveedor recomendado para probar el placeholder:** `ANTHROPIC_API_KEY` con Claude, ya que es el que se usa en este mismo flujo de trabajo y no requiere configuración adicional más allá de la key; alternativamente `OPENAI_API_KEY` si preferís mantener consistencia con Captain en Chatwoot (ambos productos podrían compartir la misma cuenta de OpenAI si eso simplifica la facturación).
- No se probó ninguna key real en esta sesión — los placeholders en `.env` quedan vacíos y comentados.

## Resumen — qué conseguir

- [ ] Una API key de OpenAI (`sk-...`) — para Captain en Chatwoot (obligatoria si querés probarlo) y/o como proveedor por defecto en ChatbotX
- [ ] (Opcional, según qué proveedor prefieras ofrecer en ChatbotX) API key de Anthropic, Google AI Studio (Gemini), DeepSeek u OpenRouter
- [ ] Evaluar si el costo de IA lo asume la plataforma (clave propia, plan por defecto) o cada cliente final trae la suya (BYOK) — ChatbotX soporta ambos modelos, Chatwoot/Captain solo el modelo de clave única de la instalación
