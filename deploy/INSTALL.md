# Instalar no telemóvel + auto-update

Modelo: a app corre no **teu PC** como serviço, é exposta com **HTTPS por um túnel**,
e instalas no telemóvel como **PWA** ("Adicionar ao ecrã principal"). Quando publicas
uma atualização no Git, o PC apanha-a sozinho e reinicia — o telemóvel carrega a versão
nova no arranque seguinte. **Não há lojas nem revisões.**

> HTTPS é obrigatório para a PWA instalar e atualizar. Por isso o túnel (que dá HTTPS)
> não é opcional — em `http://192.168...` o telemóvel não a instala como deve ser.

---

## 1. Pôr o código no Git (origem das atualizações)

```bash
cd ~/workspace/code/expense_keeping
# (o repo já está iniciado; cria o repositório no GitHub e liga-o)
git remote add origin git@github.com:O_TEU_USER/expense_keeping.git
git push -u origin main
```

A partir daqui, o teu fluxo de atualização é: **editar → `git commit` → `git push`**.

---

## 2. Correr como serviço (systemd do utilizador, sem sudo)

```bash
# Permite que os serviços corram mesmo com a sessão fechada
loginctl enable-linger "$USER"

# Instala as units
mkdir -p ~/.config/systemd/user
cp deploy/expenses.service          ~/.config/systemd/user/
cp deploy/expenses-update.service   ~/.config/systemd/user/
cp deploy/expenses-update.timer     ~/.config/systemd/user/

systemctl --user daemon-reload
systemctl --user enable --now expenses.service        # arranca a app
systemctl --user enable --now expenses-update.timer   # liga o auto-deploy

# Ver estado / logs
systemctl --user status expenses.service
journalctl --user -u expenses.service -f
```

A app fica em `http://localhost:8501`. O timer corre o `deploy.sh` a cada 2 minutos:
faz `git pull`, reinstala dependências se mudaram, reaplica a PWA e reinicia a app.

---

## 3. Expor com HTTPS (escolhe UMA opção)

### Opção A — Tailscale (recomendado: não precisa de domínio)

```bash
# instalar: sudo pacman -S tailscale && sudo systemctl enable --now tailscaled
tailscale up                 # autentica (abre o browser)
tailscale serve 8501         # privado: só nos teus dispositivos com Tailscale
#   ou
tailscale funnel 8501        # público na internet
```

Dá um URL estável tipo `https://o-teu-pc.a-tua-tailnet.ts.net`.
Com `serve`, o telemóvel precisa da app Tailscale instalada e na mesma conta.

### Opção B — Cloudflare Tunnel (precisa de domínio no Cloudflare)

```bash
# instalar: sudo pacman -S cloudflared
cloudflared tunnel login
cloudflared tunnel create despesas
cloudflared tunnel route dns despesas despesas.oteudominio.com
cloudflared tunnel run --url http://localhost:8501 despesas
```

URL estável: `https://despesas.oteudominio.com`.
(`cloudflared tunnel --url http://localhost:8501` dá um URL aleatório `*.trycloudflare.com`
— serve para testar, mas muda a cada arranque, por isso não é bom para PWA.)

---

## 4. Instalar no telemóvel

Abre o URL HTTPS no telemóvel e:

- **Android (Chrome):** menu ⋮ → *Adicionar ao ecrã principal* / *Instalar app*.
- **iPhone (Safari):** botão Partilhar → *Adicionar ao ecrã principal*.

Fica com ícone próprio (o "€" esmeralda) e abre em ecrã inteiro, como uma app.

---

## 5. Como funciona o auto-update

```
editas no PC → git commit → git push
        ↓ (em até 2 min)
expenses-update.timer → deploy.sh → git pull + restart
        ↓
abres a app no telemóvel → carrega a versão nova
```

O service worker é *network-first*: vai sempre buscar a versão atual ao servidor,
usando a cache apenas como recurso offline. Por isso as atualizações aparecem sozinhas.

---

## Base de dados

Como corre no teu PC (disco persistente), o **SQLite** (`expenses.db`) basta e os dados
ficam contigo. Está em `.gitignore`, por isso **não** vai para o GitHub. Faz cópias de
segurança desse ficheiro de vez em quando. Para PostgreSQL, define `DATABASE_URL` no `.env`.
