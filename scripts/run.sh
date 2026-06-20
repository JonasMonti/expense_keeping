#!/usr/bin/env bash
# Arranca a app (usado pelo serviço systemd).
set -euo pipefail
cd "$(dirname "$0")/.."
source .venv/bin/activate
exec streamlit run app.py \
  --server.address 0.0.0.0 \
  --server.port 8501 \
  --server.headless true \
  --browser.gatherUsageStats false
