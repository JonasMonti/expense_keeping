#!/usr/bin/env bash
# Auto-deploy: vai buscar a versão nova ao Git e reinicia a app.
# Chamado periodicamente pelo timer systemd (expenses-update.timer).
set -euo pipefail
cd "$(dirname "$0")/.."

if ! git fetch --quiet origin 2>/dev/null; then
  echo "Sem remoto 'origin' configurado — nada a fazer."
  exit 0
fi

UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)
if [ -z "$UPSTREAM" ]; then
  echo "Sem upstream configurado (git branch --set-upstream-to=origin/main)."
  exit 0
fi

LOCAL=$(git rev-parse @)
REMOTE=$(git rev-parse "$UPSTREAM")
if [ "$LOCAL" = "$REMOTE" ]; then
  echo "Já está atualizado ($(git rev-parse --short @))."
  exit 0
fi

echo "Nova versão detetada. A atualizar..."
git pull --ff-only
source .venv/bin/activate
pip install -q -r requirements.txt
python scripts/setup_pwa.py        # reaplica a PWA (caso o streamlit tenha sido reinstalado)
systemctl --user restart expenses.service
echo "Atualizado para $(git rev-parse --short @)."
