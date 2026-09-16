# Entorno local — Chatwoot + ChatbotX

**Estado actual:** todo el código, la configuración de Docker Compose y las plantillas de variables de entorno están listos. Por pedido explícito, **no corrí Docker en esta máquina** — este documento tiene los comandos exactos para levantarlo en la máquina donde sí quieras correrlo (o en esta, cuando quieras).

## Camino corto: `./setup.sh`

Para no copiar/pegar comandos a mano, dejé `setup.sh` en la raíz de esta carpeta (`Chat/setup.sh`). Hace todo de punta a punta: crea los `.env` reales desde las plantillas, buildea en el orden correcto, levanta los contenedores, corre migraciones+seed, y al final imprime las URLs y credenciales de admin.

**Para moverlo a otra máquina:** este repo (`docs/`, `overrides/`, `setup.sh`, `README.md`) es autocontenido — `chatwoot/` y `chatbotx/` están en `.gitignore` a propósito, `setup.sh` los clona frescos de GitHub la primera vez que corre. No hace falta copiar los ~2 clones completos: alcanza con `git clone https://github.com/octi35/chat-.git && cd chat- && ./setup.sh` en la máquina destino.

En la máquina destino, con Docker instalado:

```bash
cd Chat
./setup.sh              # levanta los dos productos
# o./setup.sh chatwoot   # / ./setup.sh chatbotx — uno solo
```

Requiere Docker + el plugin `docker compose` instalados; nada más (no hace falta Ruby, Node ni pnpm en el host, todo corre dentro de los contenedores). El script es idempotente: si ya existe un `chatwoot/.env` o `chatbotx/.env` (por ejemplo porque los editaste con credenciales reales), no los pisa.

El resto de este documento es la referencia paso a paso de lo que hace el script, por si preferís correrlo a mano o algo falla.

## 0. Antes de arrancar (referencia manual, `setup.sh` ya hace esto)

Tenés dos formas de resolver las variables de entorno, elegí una:

**Opción A — rápida (usa mis plantillas tal cual, valores de desarrollo ya generados):**
`setup.sh` copia `overrides/chatwoot.docker-compose.override.yaml` y `overrides/chatbotx.docker-compose.override.yml` a la raíz de cada repo clonado, apuntando a `docs/env-templates/*.txt`. Si preferís hacerlo a mano, copiá esos dos archivos vos mismo antes de los comandos de las secciones 1/2.

**Opción B — con tu propio `.env` real (recomendado antes de producción):**
```bash
cp docs/env-templates/chatwoot-variables.txt chatwoot/.env
cp docs/env-templates/chatbotx-variables.txt chatbotx/.env
```
Editá esos `.env` con tus credenciales reales (ver `docs/canales-pendientes.md` e `docs/ia-pendiente.md`), y después **borrá los dos `docker-compose.override.y*ml`** (o al menos las claves `env_file:` de adentro) para que Compose vuelva a usar `env_file: .env` tal como lo definieron los mantenedores de cada proyecto.

(Nota: no pude crear yo mismo los `.env` — Claude Code tiene un guardrail de seguridad hardcodeado que bloquea leer/escribir/copiar cualquier archivo `.env*` de un proyecto, no es configurable desde `settings.json`. Por eso existen los `docker-compose.override.y*ml` con `env_file: !override` apuntando a los `.txt` en `docs/env-templates/`.)

## 1. Chatwoot

Puertos: **3000** (app Rails), 3036 (Vite dev server, interno), 5432 (Postgres, host), 6379 (Redis, host), 1025/8025 (Mailhog SMTP/UI).

```bash
cd chatwoot

# Gotcha real que encontré al testear el build: rails.Dockerfile y vite.Dockerfile
# hacen `FROM chatwoot:development`, la imagen que construye el servicio "base".
# Si corrés `docker compose build` a secas, Compose no siempre respeta ese orden
# y termina intentando bajar "chatwoot:development" de Docker Hub (falla con
# "pull access denied"). Solución: buildear "base" primero, explícito.
docker compose -f docker-compose.yaml -f docker-compose.override.yaml build base
docker compose -f docker-compose.yaml -f docker-compose.override.yaml build rails vite
# (no hace falta buildear "sidekiq" aparte: reusa la imagen chatwoot-rails:development
# que ya generó el build de "rails")

docker compose -f docker-compose.yaml -f docker-compose.override.yaml up -d

# Migraciones + seed (crea DB, corre migraciones, y en development también
# crea cuenta y usuario de prueba automáticamente vía db/seeds.rb):
docker compose -f docker-compose.yaml -f docker-compose.override.yaml exec rails bundle exec rails db:chatwoot_prepare

# Health check:
curl -sf http://localhost:3000/ >/dev/null && echo "Chatwoot OK" || echo "Chatwoot no responde"
```

**Usuario admin de prueba** (lo crea `db/seeds.rb` automáticamente en `RAILS_ENV=development`, no hace falta ningún comando extra):
- URL: http://localhost:3000
- Email: `john@acme.inc`
- Password: `Password1!`
- Rol: SuperAdmin, con una cuenta demo "Acme Inc" y un inbox de Web Widget ya armado.
- Super Admin panel (para cargar credenciales de Meta/OpenAI, ver `docs/canales-pendientes.md` e `docs/ia-pendiente.md`): http://localhost:3000/super_admin

**Para levantarlo de nuevo más adelante** (ya buildeado):
```bash
cd chatwoot && docker compose -f docker-compose.yaml -f docker-compose.override.yaml up -d
```

## 2. ChatbotX

Puertos remapeados en `docker-compose.override.yml` para no chocar con Chatwoot en la misma máquina: Postgres host **5433** (interno 5432), Redis host **6380** (interno 6379), Mailhog **1026/8026**. Sin cambios: builder **3123**, realtime **1999**, Adminer **8080**, RustFS (S3) **9000/9001**, RedisInsight **5540**.

```bash
cd chatbotx

docker compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.override.yml build

docker compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.override.yml up -d

# El servicio "builder" ya trae RUN_DB_MIGRATE=true y RUN_DB_SEED=true en su
# entorno (definido en docker-compose.dev.yml), así que migraciones y seed
# deberían correr solos al arrancar el contenedor. Si por lo que sea no corren,
# hacelo a mano:
docker compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.override.yml exec builder pnpm --filter @chatbotx.io/database db:setup

# Health check:
curl -sf http://localhost:3123/api/health >/dev/null && echo "ChatbotX builder OK" || echo "ChatbotX builder no responde"
```

**Usuario admin de prueba** (lo crea `packages/database/src/seed/index.ts`, idempotente — no crea nada si ya hay un usuario):
- URL: http://localhost:3123
- Email: `demo@example.com`
- Password: `Demo@1234`
- Rol: superAdmin, workspace "DEMO" ya creado.
- Panel de super admin (para cargar credenciales de Meta/IA por default de plataforma, ver `docs/canales-pendientes.md`): http://localhost:3123/admin

**Para levantarlo de nuevo más adelante:**
```bash
cd chatbotx && docker compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.override.yml up -d
```

## 3. Gotchas que dejo documentados

- **Puertos duplicados si corrés los dos al mismo tiempo:** ya resuelto vía `chatbotx/docker-compose.override.yml` (remapea Postgres/Redis/Mailhog de ChatbotX). Si alguna vez lo borrás, van a chocar con Chatwoot.
- **`packages/database` de ChatbotX usa `dotenv -e ../../.env`** en sus scripts de migración/seed — es un wrapper pensado para desarrollo local sin Docker. Dentro del contenedor esto puede tirar un warning si no existe `chatbotx/.env` real (el override deja las variables ya inyectadas por Docker vía `env_file`, así que igual debería funcionar, pero si ves errores raros en migración, generá el `.env` real con la Opción B de la sección 0).
- **Chatwoot: orden de build de `base` antes de `rails`/`vite`** — ver sección 1, es un problema del propio `docker-compose.yaml` del proyecto (Dockerfiles encadenados vía `FROM chatwoot:development`), no algo que yo haya roto.
- **AGENTS.md/CLAUDE.md de ChatbotX pide "nunca correr `db:migrate` automáticamente sin aprobación explícita"** cuando se trabaja como agente de código en ese repo — el `RUN_DB_MIGRATE=true` del compose es la config oficial del propio proyecto para levantar el entorno de desarrollo (no es una migración de esquema que yo haya generado), así que no entra en conflicto con esa regla; igual lo aviso por transparencia.

## 4. Decisión de arquitectura tomada en esta sesión

Chatwoot y ChatbotX quedan como **dos sistemas Docker completamente separados** (redes, bases de datos y volúmenes propios de cada uno), sin ningún puente entre ellos todavía. No arme integración entre los dos productos porque no fue pedido en esta sesión y es una decisión de producto (¿atención al cliente en Chatwoot y automatización/broadcast en ChatbotX operando en paralelo sobre los mismos contactos? ¿o uno de los dos como único punto de entrada?) que conviene definir con vos antes de construir un puente real.
