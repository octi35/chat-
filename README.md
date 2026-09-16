# Whitelabel Chatwoot + ChatbotX

Capa de orquestación para levantar [Chatwoot](https://github.com/chatwoot/chatwoot) (atención al cliente omnicanal) y [ChatbotX](https://github.com/ChatbotXIO/ChatbotX) (constructor de flujos/broadcast con IA) en Docker, como base de un servicio whitelabel de atención al cliente + automatización de marketing por WhatsApp/Instagram/Facebook con IA para pymes.

Este repo **no vendorea el código de los dos productos** — `setup.sh` los clona frescos desde GitHub la primera vez que corre. Acá vive solo la configuración de Docker Compose, las plantillas de variables de entorno y la documentación del setup.

## Levantar todo

Con Docker y el plugin `docker compose` instalados:

```bash
./setup.sh              # clona, buildea y levanta los dos productos
./setup.sh chatwoot      # o uno solo a la vez
./setup.sh chatbotx
```

Al terminar imprime las URLs y credenciales del usuario admin de prueba de cada uno.

## Documentación

- [`docs/estado-del-sistema.md`](docs/estado-del-sistema.md) — punto de partida: qué hay, qué falta, checklist
- [`docs/entorno-local.md`](docs/entorno-local.md) — detalle de lo que hace `setup.sh`, comandos manuales, gotchas de build
- [`docs/licencias.md`](docs/licencias.md) — auditoría de licencias de ambos proyectos (MIT vs. Enterprise/Commercial), con cita textual
- [`docs/canales-pendientes.md`](docs/canales-pendientes.md) — credenciales de WhatsApp/Instagram/Facebook: qué falta, dónde va, pasos previos en Meta for Developers
- [`docs/ia-pendiente.md`](docs/ia-pendiente.md) — claves de proveedores de IA (Captain en Chatwoot, multi-proveedor en ChatbotX)
- [`docs/whitelabel.md`](docs/whitelabel.md) — qué archivo editar cuando se defina la marca (nombre/logo/colores), y el límite Enterprise de ChatbotX para marca por cliente
- [`docs/env-templates/`](docs/env-templates/) — plantillas completas de `.env` para cada producto
- [`overrides/`](overrides/) — overrides de Docker Compose que aplica `setup.sh` (puertos, `.env`)

## Estado

Setup y documentación completos; sin credenciales reales de Meta/IA cargadas todavía (placeholders). Ver el checklist en `docs/estado-del-sistema.md`.
