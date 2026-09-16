#!/usr/bin/env bash
# ==========================================================================
# Setup de un solo comando para levantar Chatwoot + ChatbotX en Docker.
# Autocontenido: si chatwoot/ o chatbotx/ no existen todavía en esta carpeta,
# los clona de GitHub. Pensado para correr en cualquier máquina con Docker,
# partiendo solo de lo que hay en este repo (docs/, overrides/, este script).
#
# Qué hace:
#   1) Clona chatwoot/ y chatbotx/ si no están (idempotente).
#   2) Copia el override de Docker Compose correspondiente desde overrides/
#      a la raíz de cada repo clonado.
#   3) Crea chatwoot/.env y chatbotx/.env reales a partir de las plantillas
#      en docs/env-templates/ (si todavía no existen — no pisa un .env que
#      ya hayas editado a mano).
#   4) Buildea las imágenes en el orden correcto (chatwoot tiene un gotcha
#      real: rails/vite Dockerfiles dependen de la imagen "base").
#   5) Levanta los dos stacks con `docker compose up -d`.
#   6) Corre migraciones + seed.
#   7) Hace health check y muestra URLs + credenciales del usuario admin de
#      prueba de cada producto.
#
# Uso:
#   ./setup.sh            # levanta los dos
#   ./setup.sh chatwoot   # solo Chatwoot
#   ./setup.sh chatbotx   # solo ChatbotX
# ==========================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-all}"

CHATWOOT_REPO="https://github.com/chatwoot/chatwoot.git"
CHATBOTX_REPO="https://github.com/ChatbotXIO/ChatbotX.git"

log() { printf '\n\033[1;36m==> %s\033[0m\n' "$1"; }
ok()  { printf '\033[1;32m✓ %s\033[0m\n' "$1"; }
warn() { printf '\033[1;33m! %s\033[0m\n' "$1"; }

command -v docker >/dev/null 2>&1 || { echo "Falta docker. Instalalo antes de seguir."; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "Falta el plugin 'docker compose'. Instalalo antes de seguir."; exit 1; }
command -v git >/dev/null 2>&1 || { echo "Falta git. Instalalo antes de seguir."; exit 1; }

clone_if_missing() {
  local dir="$1" repo="$2"
  if [ ! -d "$ROOT_DIR/$dir/.git" ]; then
    log "Clonando $repo -> $dir/"
    git clone --depth 1 "$repo" "$ROOT_DIR/$dir"
  else
    ok "$dir/ ya está clonado, no lo toco"
  fi
}

setup_chatwoot() {
  clone_if_missing chatwoot "$CHATWOOT_REPO"

  log "Chatwoot — preparando .env y override de Docker Compose"
  if [ ! -f "$ROOT_DIR/chatwoot/.env" ]; then
    cp "$ROOT_DIR/docs/env-templates/chatwoot-variables.txt" "$ROOT_DIR/chatwoot/.env"
    ok "Creado chatwoot/.env desde la plantilla (editalo después con tus credenciales reales de Meta/OpenAI)"
  else
    ok "chatwoot/.env ya existe, no lo toco"
  fi
  cp "$ROOT_DIR/overrides/chatwoot.docker-compose.override.yaml" "$ROOT_DIR/chatwoot/docker-compose.override.yaml"

  cd "$ROOT_DIR/chatwoot"

  log "Chatwoot — build (orden correcto: base primero, después rails+vite)"
  docker compose -f docker-compose.yaml -f docker-compose.override.yaml build base
  docker compose -f docker-compose.yaml -f docker-compose.override.yaml build rails vite

  log "Chatwoot — levantando contenedores"
  docker compose -f docker-compose.yaml -f docker-compose.override.yaml up -d

  log "Chatwoot — esperando a que Postgres responda"
  for i in $(seq 1 60); do
    if docker compose -f docker-compose.yaml -f docker-compose.override.yaml exec -T postgres pg_isready -U postgres >/dev/null 2>&1; then
      break
    fi
    sleep 2
  done

  log "Chatwoot — creando DB, migrando y seedeando (crea usuario admin de prueba)"
  docker compose -f docker-compose.yaml -f docker-compose.override.yaml exec -T rails bundle exec rails db:chatwoot_prepare

  log "Chatwoot — health check"
  for i in $(seq 1 30); do
    if curl -sf http://localhost:3000/ >/dev/null 2>&1; then
      ok "Chatwoot respondiendo en http://localhost:3000"
      break
    fi
    sleep 3
  done
}

setup_chatbotx() {
  clone_if_missing chatbotx "$CHATBOTX_REPO"

  log "ChatbotX — preparando .env y override de Docker Compose"
  if [ ! -f "$ROOT_DIR/chatbotx/.env" ]; then
    cp "$ROOT_DIR/docs/env-templates/chatbotx-variables.txt" "$ROOT_DIR/chatbotx/.env"
    ok "Creado chatbotx/.env desde la plantilla (editalo después con tus credenciales reales)"
  else
    ok "chatbotx/.env ya existe, no lo toco"
  fi
  cp "$ROOT_DIR/overrides/chatbotx.docker-compose.override.yml" "$ROOT_DIR/chatbotx/docker-compose.override.yml"

  cd "$ROOT_DIR/chatbotx"

  log "ChatbotX — build (Dockerfiles independientes entre sí, sin gotcha de orden)"
  docker compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.override.yml build

  log "ChatbotX — levantando contenedores"
  docker compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.override.yml up -d

  log "ChatbotX — esperando migración+seed automáticos del contenedor builder (RUN_DB_MIGRATE/RUN_DB_SEED=true)"
  READY=""
  for i in $(seq 1 40); do
    if curl -sf http://localhost:3123/api/health >/dev/null 2>&1; then
      READY=1
      break
    fi
    sleep 3
  done

  if [ -z "$READY" ]; then
    warn "El builder no respondió a tiempo — corriendo migración+seed a mano por las dudas"
    docker compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.override.yml exec -T builder pnpm --filter @chatbotx.io/database db:setup || true
  fi

  log "ChatbotX — health check"
  for i in $(seq 1 20); do
    if curl -sf http://localhost:3123/api/health >/dev/null 2>&1; then
      ok "ChatbotX respondiendo en http://localhost:3123"
      break
    fi
    sleep 3
  done
}

case "$TARGET" in
  chatwoot) setup_chatwoot ;;
  chatbotx) setup_chatbotx ;;
  all) setup_chatwoot; setup_chatbotx ;;
  *) echo "Uso: $0 [chatwoot|chatbotx|all]"; exit 1 ;;
esac

log "Listo"
cat <<EOF

Chatwoot:  http://localhost:3000   (admin: john@acme.inc / Password1!)
  Super Admin (canales/IA):  http://localhost:3000/super_admin

ChatbotX:  http://localhost:3123   (admin: demo@example.com / Demo@1234)
  Admin (canales/IA):        http://localhost:3123/admin

Próximo paso: cargar credenciales reales de WhatsApp/Instagram/Facebook y de
IA — ver docs/canales-pendientes.md y docs/ia-pendiente.md.
EOF
