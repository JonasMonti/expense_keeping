# 💰 As Minhas Despesas

Aplicação em Python (Streamlit) para registar despesas e analisar gastos mensais
com gráficos e categorias. Funciona no **browser** e adapta-se ao **telemóvel**.

## Funcionalidades

- ➕ Registar despesas (valor, categoria, data, descrição)
- 📊 Dashboard com totais do mês, repartição por categoria (donut + barras),
  gasto por dia e evolução dos últimos meses
- 🧾 Histórico mensal com eliminação de despesas
- 🏷️ Gestão de categorias (nome, emoji, cor usada nos gráficos)

## Instalação

```bash
cd expense_keeping
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Executar

```bash
streamlit run app.py
```

Abre no browser em `http://localhost:8501`. Para aceder do telemóvel na mesma
rede, usa o "Network URL" que o Streamlit mostra no arranque.

## Base de dados

Por defeito usa **SQLite** (ficheiro `expenses.db` criado automaticamente) — não
precisa de configuração.

Para usar **PostgreSQL**:

1. Instala o driver: `pip install "psycopg[binary]"`
2. Copia `.env.example` para `.env` e define:
   ```
   DATABASE_URL=postgresql+psycopg://user:password@localhost:5432/expenses
   ```

A app cria as tabelas e as categorias por defeito na primeira execução.

## Estrutura

```
app.py              # Interface Streamlit (navegação + páginas)
src/
  config.py         # Leitura de .env / variáveis de ambiente
  database.py       # Engine, sessão e inicialização do esquema
  models.py         # Modelos Category e Expense (SQLAlchemy)
  repository.py     # CRUD e agregações para os gráficos
  charts.py         # Gráficos Plotly
```
