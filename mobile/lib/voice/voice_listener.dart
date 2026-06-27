/// Escuta de voz "mãos-livres" enquanto a app está aberta.
///
/// Não há botão nem palavra-chave: a app fica à escuta contínua e, a cada frase,
/// **só age se ela parecer mesmo um comando** (tem um valor ou um verbo como
/// "apaga"/"edita") — ver [_looksLikeCommand]. Assim conversa de fundo não cria
/// despesas. O utilizador pode silenciar a qualquer momento (bateria /
/// privacidade) — ver [enabled]/[toggle].
///
/// Limite incontornável: nenhuma app pode ouvir antes de ser aberta nem em
/// segundo plano (iOS proíbe; Android exige serviço dedicado que gasta bateria).
library;

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../data/repository.dart';
import 'voice_intake.dart';

enum VoiceStatus { idle, listening, heard, off, unavailable }

class VoiceListener with ChangeNotifier {
  VoiceListener(this.repo);
  final Repository repo;

  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _initialized = false;
  bool _available = false;
  bool _enabled = true; // o utilizador pode silenciar
  bool _foreground = true;
  bool _sessionActive = false;

  /// Locale efetivo do reconhecedor (o `pt` que existir mesmo no aparelho).
  /// Null → deixa o motor escolher o do sistema. Forçar um locale inexistente
  /// (ex.: "pt_PT" num motor que só tem "pt-BR") faz a escuta não transcrever.
  String? _localeId;

  /// Texto acumulado na sessão atual (parciais incluídos) e flag de despacho,
  /// para tratar o comando mesmo quando o resultado "final" não chega a disparar.
  String _pending = '';
  bool _handled = false;

  VoiceStatus status = VoiceStatus.idle;
  String lastHeard = '';

  /// Último erro do motor de voz (diagnóstico; ex.: "error_no_match").
  String? lastError;

  bool get enabled => _enabled;
  bool get available => _available;

  /// Arranca a escuta (pede permissão na 1.ª vez). Chamar no initState.
  Future<void> start() async {
    if (!_initialized) {
      _available = await _speech.initialize(
        onError: (e) {
          lastError = e.errorMsg;
          _onSessionEnded();
        },
        onStatus: (s) {
          if (s == 'done' || s == 'notListening') _onSessionEnded();
        },
      );
      _initialized = true;
      if (_available) await _pickLocale();
    }
    if (!_available) {
      _set(VoiceStatus.unavailable);
      return;
    }
    _listen();
  }

  /// Escolhe o melhor locale português disponível no reconhecedor do aparelho:
  /// prefere pt-PT, aceita qualquer pt-*, e cai no locale do sistema se não houver.
  Future<void> _pickLocale() async {
    try {
      final locales = await _speech.locales();
      stt.LocaleName? pick;
      for (final l in locales) {
        final id = l.localeId.toLowerCase().replaceAll('-', '_');
        if (id == 'pt_pt') {
          pick = l;
          break;
        }
        if (id.startsWith('pt')) pick ??= l;
      }
      _localeId = pick?.localeId; // null → locale do sistema
    } catch (_) {
      _localeId = null;
    }
  }

  /// Ciclo de vida da app: parar em segundo plano, retomar à frente.
  void onForeground() {
    _foreground = true;
    if (_enabled && _available) start();
  }

  void onBackground() {
    _foreground = false;
    _speech.stop();
    _sessionActive = false;
    _set(VoiceStatus.off);
  }

  /// Silenciar / reativar a escuta (válvula de escape do utilizador).
  void toggle() {
    _enabled = !_enabled;
    if (_enabled) {
      start();
    } else {
      _speech.stop();
      _sessionActive = false;
      _set(VoiceStatus.off);
    }
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  // ------------------------------------------------------------------ //
  Future<void> _listen() async {
    if (!_available || !_enabled || !_foreground || _sessionActive) return;
    _sessionActive = true;
    _pending = '';
    _handled = false;
    _set(VoiceStatus.listening);
    await _speech.listen(
      onResult: (r) {
        lastHeard = r.recognizedWords;
        _pending = r.recognizedWords;
        if (r.finalResult && !_handled) {
          _handled = true;
          _handle(r.recognizedWords);
        } else {
          notifyListeners();
        }
      },
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        localeId: _localeId,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  void _onSessionEnded() {
    _sessionActive = false;
    // Em alguns motores Android a sessão acaba (notListening/timeout) sem que o
    // resultado "final" dispare. Se ouvimos algo e ainda não foi tratado, trata
    // agora — senão o comando perdia-se em silêncio.
    if (!_handled && _pending.trim().isNotEmpty) {
      _handled = true;
      _handle(_pending);
    }
    if (!_enabled || !_foreground) {
      _set(_enabled ? VoiceStatus.idle : VoiceStatus.off);
      return;
    }
    // Reinicia o ciclo (escuta contínua) com uma pequena pausa.
    Future<void>.delayed(const Duration(milliseconds: 600), _listen);
  }

  Future<void> _handle(String phrase) async {
    final text = phrase.trim();
    if (text.isEmpty) return;

    // Sem palavra-chave: aceita qualquer frase, mas só age se parecer um
    // comando (tem valor ou verbo). Evita que fala de fundo crie despesas ou
    // abra o formulário sozinho.
    if (!_looksLikeCommand(text)) return;

    _set(VoiceStatus.heard);
    await handleVoiceText(repo, text);
  }

  /// Heurística leve: a frase parece um comando de despesa?
  ///   • criar → tem um número (dígito ou por extenso) ou a palavra "euros";
  ///   • apagar/editar → tem um dos verbos de ação.
  /// (A interpretação fina fica para o [VoiceCommand]/[ExpenseParser].)
  static bool _looksLikeCommand(String text) => _commandSignal.hasMatch(
      _stripAccents(text.toLowerCase()));

  static final RegExp _commandSignal = RegExp(
      r'\d'
      r'|\b(euros?|eur)\b'
      r'|\b(zero|um|uma|dois|duas|tres|quatro|cinco|seis|sete|oito|nove|dez|onze|doze|treze|catorze|quatorze|quinze|dezasseis|dezesseis|dezassete|dezessete|dezoito|dezanove|dezenove|vinte|trinta|quarenta|cinquenta|sessenta|setenta|oitenta|noventa|cem|cento|duzentos|trezentos|quinhentos|mil)\b'
      r'|\b(apaga|apagar|apague|cancela|cancelar|cancele|anula|anular|anule|elimina|eliminar|elimine|remove|remover)\b'
      r'|\b(edita|editar|edite|altera|alterar|altere|muda|mudar|mude|corrige|corrigir|atualiza|atualizar|troca|trocar)\b');

  void _set(VoiceStatus s) {
    status = s;
    notifyListeners();
  }

  static String _stripAccents(String s) {
    const map = {
      'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a',
      'é': 'e', 'ê': 'e', 'í': 'i', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ú': 'u',
      'ç': 'c',
    };
    final b = StringBuffer();
    for (final ch in s.split('')) {
      b.write(map[ch] ?? ch);
    }
    return b.toString();
  }
}
