# Comandos por voz 🎤

A app é mãos-livres: **não há botão para ouvir**. Funciona assim:

1. **Ao abrir a app**, começa logo a ouvir **um** comando (sem palavra-chave).
2. **Enquanto a app está aberta**, fica à escuta contínua e só age quando a frase
   começa pela palavra-chave **"despesas …"** (ex.: *"despesas, apaga a última"*).
3. O indicador de microfone (canto inferior direito) mostra o estado e serve para
   **silenciar/reativar** a escuta (poupar bateria ou por privacidade) — não para
   "começar a ouvir", que é automático.
4. **Sem abrir a app**, pelo assistente do telemóvel (Siri / Google Assistant),
   que entrega a frase à app por um *deep link*.

> **Porque não ouve antes de abrir / em segundo plano?** Em iPhone/Android *normais*,
> nenhuma app de terceiros pode ouvir o microfone sempre em segundo plano (o iOS
> proíbe-o; o Android só com um serviço que gasta muita bateria). A "palavra mágica"
> tipo "Ok Google" só existe porque é o *sistema operativo* a ouvir. Por isso a
> escuta da app só acontece com a app aberta, e para fora dela usa-se o assistente.

> **Nota:** com a escuta contínua ligada, o telemóvel pode emitir o "beep" do sistema
> a cada reinício de sessão e gasta mais bateria. Silencia no indicador 🎤 quando não
> precisares.

## Como falar

A voz faz **tudo**: criar, apagar e editar despesas.

### Criar

Diz o valor, a categoria, (opcional) a descrição e (opcional) a data:

- *"Cria despesa de doze euros e cinquenta em alimentação, descrição almoço com colegas"*
- *"Gastei 15,90 na categoria transportes, descrição passe mensal"*
- *"Gastei vinte e cinco euros em saúde ontem"*
- *"Trinta euros lazer há 3 dias"*

Regras:

- **Valor:** dígitos (`12,50`) ou por extenso (`doze euros e cinquenta`). É obrigatório —
  sem valor, a app abre o formulário já preenchido para acabares à mão.
- **Categoria:** diz `categoria <nome>` ou simplesmente o nome (ex.: *"em alimentação"*).
  Maiúsculas e acentos são indiferentes. Se não bater com nenhuma, vai para **Outros**.
- **Descrição:** diz `descrição <texto>` (ou `descrição é <texto>`). É opcional.
- **Data:** opcional, por defeito é hoje. Reconhece `hoje`, `ontem`, `anteontem`,
  `há N dias`, `há uma semana`, `dia N` (ex.: *"dia 5"*), `dia N de <mês>` e os
  dias da semana (*"na quarta"* → a quarta mais recente).

### Apagar

Atua sempre sobre a **última despesa registada**:

- *"Apaga a última despesa"* · *"Cancela isso"* · *"Anula a última"*

### Editar

Também sobre a **última despesa**. Diz o que queres mudar:

- *"Muda o valor da última para 20 euros"*
- *"Muda a categoria da última para transportes"*
- *"Muda a data da última para ontem"*
- *"Edita a última despesa"* (sem indicar o quê → abre o formulário preenchido)

### Recorrentes

Cria uma despesa que se repete todos os meses:

- *"Renda de 500 euros em casa todo o dia 1"*
- *"Cria recorrente de 30 euros em transportes"* (sem dia → usa o dia de hoje)
- *"15 euros lazer mensalmente"*

Para **ver, pausar ou apagar** recorrentes, abre o formulário de nova despesa e
toca em *"🔁 Ver despesas recorrentes"* (também há o interruptor *"Repetir todos
os meses"* ao criar uma despesa normal).

Em todos os casos aparece uma faixa **"Anular"** durante alguns segundos, caso a
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
