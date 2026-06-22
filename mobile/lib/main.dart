/// Gestão de Despesas — app nativa (Flutter). Single-user, offline (SQLite local).
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'ui/home_page.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DespesasApp());
}

class DespesasApp extends StatelessWidget {
  const DespesasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'As Minhas Despesas',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // Interface e date pickers em pt-PT.
      locale: const Locale('pt'),
      supportedLocales: const [Locale('pt'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomePage(),
    );
  }
}
