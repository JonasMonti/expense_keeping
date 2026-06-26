/// Gestão de Despesas — app nativa (Flutter). Single-user, offline (SQLite local).
library;

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/repository.dart';
import 'ui/home_page.dart';
import 'ui/theme.dart';
import 'voice/voice_intake.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DespesasApp());
}

class DespesasApp extends StatefulWidget {
  const DespesasApp({super.key});

  @override
  State<DespesasApp> createState() => _DespesasAppState();
}

class _DespesasAppState extends State<DespesasApp> {
  final _repo = Repository();
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    // Deep link de arranque (app aberta a frio pelo atalho) + os seguintes.
    _appLinks.getInitialLink().then(_onLink);
    _linkSub = _appLinks.uriLinkStream.listen(_onLink);
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  /// Trata `despesas://add?text=<frase>` (principal) e o formato estruturado
  /// `despesas://add?amount=12.50&category=Alimentação&description=...`.
  void _onLink(Uri? uri) {
    if (uri == null || uri.host != 'add') return;
    final q = uri.queryParameters;
    final text = q['text'];
    if (text != null && text.trim().isNotEmpty) {
      handleVoiceText(_repo, text);
      return;
    }
    // Formato estruturado: monta uma frase equivalente para o mesmo parser.
    final parts = <String>[
      if ((q['amount'] ?? '').isNotEmpty) '${q['amount']} euros',
      if ((q['category'] ?? '').isNotEmpty) 'categoria ${q['category']}',
      if ((q['description'] ?? '').isNotEmpty) 'descrição ${q['description']}',
    ];
    if (parts.isNotEmpty) handleVoiceText(_repo, parts.join(' '));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'As Minhas Despesas',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
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
