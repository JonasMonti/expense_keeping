# Visão geral

Aplicação de **gestão de despesas pessoais**: regista gastos e analisa-os por mês
e por ano, com gráficos e categorias. Funciona no browser e no telemóvel (instalável
como PWA). Uso pessoal, single-user.

## Stack

- **Linguagem:** Python (3.14)
- **Framework:** Streamlit (app numa única página)
- **Base de dados:** SQLAlchemy 2.0 — SQLite por defeito, PostgreSQL via `DATABASE_URL`
- **Gráficos:** Plotly (`graph_objects`, sem pandas)
- **PWA + deploy:** service worker injetado no Streamlit; systemd + túnel (ver `deploy/INSTALL.md`)

> Nota: este projeto **não** usa React/TypeScript/Tailwind. Se vires referências a isso,
> estão desatualizadas — a stack web é Python/Streamlit.

## App nativa (mobile/)

Existe também uma versão **nativa em Flutter** (Android + iOS) na pasta `mobile/`,
que replica a mesma identidade visual e funcionalidades, mas com **SQLite local no
dispositivo** (offline, single-user, sem servidor). Ver `mobile/README.md`.

- **Linguagem/Framework:** Dart / Flutter
- **BD:** sqflite (SQLite no dispositivo)
- **Gráficos:** fl_chart (donut + linha anual)
- **Toolchain:** instalada em espaço de utilizador (`~/.flutter-toolchain`, `~/Android/Sdk`);
  carregar com `source mobile/tool/env.sh` antes de `flutter build apk`.
- iOS só compila em macOS + Xcode (restrição da Apple).

A versão Streamlit e a versão Flutter partilham o mesmo modelo de dados conceptual
(Category, Expense) mas têm bases de dados **independentes** — não sincronizam.

## Estrutura

```
app.py              # Interface Streamlit: página única (header, modais, dashboard)
src/
  config.py         # Lê .env / variáveis de ambiente (DATABASE_URL, moeda)
  database.py       # Engine, sessão, criação de tabelas + categorias por defeito
  models.py         # Modelos Category e Expense (SQLAlchemy 2.0)
  repository.py     # CRUD e agregações (por mês, categoria, dia, ano)
  charts.py         # Gráficos Plotly (donut por categoria, linha anual)
  ui.py             # Tema (CSS) e componentes HTML; formatação de valores
scripts/
  setup_pwa.py      # Gera ícones/manifest/SW e torna a app instalável (idempotente)
  run.sh            # Arranca a app (usado pelo systemd)
  deploy.sh         # Auto-deploy: git pull + restart
deploy/             # Unidades systemd + guia de instalação (INSTALL.md)
.streamlit/config.toml  # Tema base do Streamlit
```

## Regras e convenções

1. **Tudo em Python/Streamlit.** Nada de frameworks JS.
2. **Identidade visual deliberada** (ver `src/ui.py`): acento esmeralda `#0F7B66`,
   tipografia Space Grotesk (números/títulos) + Inter (corpo), valores em algarismos
   tabulares. Despesas em tinta neutra, nunca a vermelho.
3. **Botões só com emoji**, nunca frases (usar `help=` para tooltip).
4. **Responsivo / mobile-first:** a app é usada sobretudo no telemóvel.
5. **Lógica de dados em `repository.py`**, não no `app.py`. Os gráficos recebem
   listas de dicts simples.
6. **Português (pt-PT)** em toda a interface.

## Comandos

```bash
# Ambiente
source .venv/bin/activate
pip install -r requirements.txt

# Correr localmente
streamlit run app.py            # http://localhost:8501

# Reaplicar a PWA (após reinstalar o streamlit)
python scripts/setup_pwa.py
```

## Base de dados

SQLite por defeito (`expenses.db`, ignorado pelo Git). Para PostgreSQL, define
`DATABASE_URL` no `.env` (ex.: `postgresql+psycopg://user:pass@host:5432/expenses`).
O esquema é criado automaticamente no arranque (`init_db`).
