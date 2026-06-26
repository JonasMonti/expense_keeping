# Registar despesas por voz 🎤

A app aceita despesas ditadas por voz de duas formas:

1. **Botão 🎤 dentro da app** — abre a app, toca no microfone (canto inferior
   direito), dita a frase e a despesa é criada.
2. **Sem abrir a app**, pelo assistente do telemóvel (Siri / Google Assistant),
   que entrega a frase à app por um *deep link*.

> **Porque não há "palavra mágica" própria?** Em iPhone/Android *normais*, nenhuma
> app de terceiros pode ouvir o microfone sempre em segundo plano (o iOS proíbe-o;
> o Android só com um serviço que gasta muita bateria). Por isso usamos o assistente
> do sistema — que já tem licença para estar sempre a ouvir — como gatilho.

## Como falar

Diz o valor, a categoria e (opcional) a descrição. Exemplos que funcionam:

- *"Cria despesa de doze euros e cinquenta em alimentação, descrição almoço com colegas"*
- *"Gastei 15,90 na categoria transportes, descrição passe mensal"*
- *"Vinte e cinco euros em saúde"*
- *"Trinta euros lazer"*

Regras:

- **Valor:** dígitos (`12,50`) ou por extenso (`doze euros e cinquenta`). É obrigatório —
  sem valor, a app abre o formulário já preenchido para acabares à mão.
- **Categoria:** diz `categoria <nome>` ou simplesmente o nome (ex.: *"em alimentação"*).
  Maiúsculas e acentos são indiferentes. Se não bater com nenhuma, vai para **Outros**.
- **Descrição:** diz `descrição <texto>` (ou `descrição é <texto>`). É opcional.
- A **data** é sempre hoje.

Depois de criar, aparece uma faixa **"Anular"** durante alguns segundos, caso a
transcrição tenha saído errada.

---

## iPhone (Siri) — passo a passo

1. Abre a app **Atalhos** (Shortcuts).
2. Toca em **+** para criar um atalho novo.
3. Adiciona a ação **"Ditar texto"** (Dictate Text).
4. Adiciona a ação **"Abrir URL"** (Open URLs) e escreve:
   ```
   despesas://add?text=
   ```
   A seguir ao `=`, insere a variável **"Texto ditado"** (o resultado do passo 3).
5. Dá-lhe o nome **"Nova despesa"** e grava.
6. Pronto: diz *"Hey Siri, Nova despesa"*, dita a frase, e a despesa é criada.

> Dica: no atalho podes ativar *"Mostrar ao executar"* a Off para ser mais rápido,
> e adicioná-lo ao ecrã de bloqueio ou ao **Back Tap** (Definições → Acessibilidade
> → Toque → Tocar na parte de trás).

## Android (Google Assistant / atalho)

O deep link `despesas://add?text=...` funciona; o que varia é como o disparas:

- **Via atalho de ecrã** (mais fiável): usa uma app como *Shortcut Maker* (ou as
  Rotinas do telemóvel) para criar um atalho que:
  1. faça **reconhecimento de voz** (speech-to-text), e
  2. abra o URL `despesas://add?text=<resultado>`.
- **Via Google Assistant:** cria uma **Rotina** que abra esse URL. Nota honesta: no
  Android a integração do Assistant com apps de terceiros é mais manual e instável
  que os Atalhos da Siri — se for complicado, usa antes o **botão 🎤 dentro da app**.

### Testar o deep link (programador)

Com o telemóvel ligado por USB e a app instalada:

```bash
adb shell am start -a android.intent.action.VIEW \
  -d "despesas://add?text=doze euros e cinquenta em alimentação descrição almoço" \
  pt.despesas.despesas
```

## Formato estruturado (opcional)

Se preferires montar o atalho por campos em vez de uma frase só, a app também aceita:

```
despesas://add?amount=12.50&category=Alimentação&description=almoço
```
