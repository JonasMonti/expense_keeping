# Despesas — app nativa (Flutter)

Versão **nativa** (Android + iOS) da app de gestão de despesas. Mesma identidade
visual e mesmas funcionalidades da versão Streamlit, mas com **base de dados SQLite
local no dispositivo** (funciona totalmente offline, single-user).

## O que faz

- Registar e eliminar despesas (swipe para a esquerda no histórico para eliminar)
- Registar receitas (ordenado, subsídio…) por origem; recorrentes automáticas todos os meses
- Saldo atual ("quanto tens agora"): valor inicial numa data + receitas − despesas
- Dashboard do mês: saldo, KPIs (receitas/despesas/líquido), nº de despesas, média/dia, maior categoria
- Donut por categoria/origem + lista com barras; linha anual receitas vs despesas
- Linha de evolução anual (Jan→Dez), com o mês selecionado destacado
- Gerir categorias (nome, emoji, cor) — 8 categorias criadas por defeito
- Definições: saldo inicial e receitas recorrentes
- Seletor de mês/ano
- Tudo em português (pt-PT), valores em formato `1 234,56 €`

## Estrutura

```
lib/
  main.dart              # arranque + tema + localização pt-PT
  models/models.dart     # Category, Expense, ExpenseView, agregados
  data/
    database.dart        # sqflite: esquema + categorias por defeito
    repository.dart      # CRUD e agregações (espelha repository.py)
  ui/
    theme.dart           # paleta esmeralda, tipografia, cardDecoration
    format.dart          # formatação pt-PT (1 234,56 €), meses
    widgets.dart         # Hero, KPIs, CategoryBars, ExpenseRow, chips
    home_page.dart       # ecrã único (dashboard)
    add_expense_sheet.dart
    categories_page.dart
  charts/
    donut.dart           # donut por categoria (fl_chart)
    year_line.dart       # linha anual (fl_chart)
assets/fonts/            # Space Grotesk (variável) + Inter
tool/env.sh              # PATH/JAVA_HOME/ANDROID_SDK_ROOT da toolchain local
```

## Compilar (Android)

A toolchain foi instalada em espaço de utilizador (sem root). Carrega o ambiente
e compila:

```bash
source mobile/tool/env.sh
cd mobile
flutter pub get
flutter build apk --release        # APK em build/app/outputs/flutter-apk/app-release.apk
```

Instalar no telemóvel Android (depurar por USB ativado):

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

…ou copia o `.apk` para o telemóvel e abre-o (permitir "instalar de fontes
desconhecidas").

## Compilar (iOS)

**Requer macOS + Xcode** — a Apple não permite compilar iOS em Linux. Num Mac:

```bash
flutter build ios --release        # ou abrir ios/Runner.xcworkspace no Xcode
```

Para instalar no teu iPhone sem App Store: assina com a tua Apple ID gratuita no
Xcode (a app expira a cada 7 dias) ou usa uma conta Apple Developer paga.

## Base de dados

SQLite local, ficheiro `expenses.db` na pasta de dados da app (criado no primeiro
arranque, com as 8 categorias por defeito). Single-user, sem servidor.
