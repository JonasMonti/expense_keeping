/// Escuta de voz "mãos-livres" enquanto a app está aberta.
///
/// Não há botão para ouvir: ao abrir/retomar a app, escuta logo **um** comando
/// (sem palavra-chave); depois fica à escuta contínua e só age quando a frase
/// começa por uma **palavra-chave** ("despesas …"). O utilizador pode silenciar
/// a qualquer momento (poupar bateria / privacidade) — ver [enabled]/[toggle].
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

  /// Palavras-chave que abrem a escuta contínua (sem acentos, minúsculas).
  static const List<String> wakeWords = ['despesas', 'despesa'];

  bool _initialized = false;
  bool _available = false;
  bool _enabled = true; // o utilizador pode silenciar
  bool _foreground = true;
  bool _sessionActive = false;
  bool _freeCommand = true; // próxima frase é comando livre (logo após abrir)

  VoiceStatus status = VoiceStatus.idle;
  String lastHeard = '';

  bool get enabled => _enabled;
  bool get available => _available;

  /// Arranca a escuta (pede permissão na 1.ª vez). Chamar no initState.
  Future<void> start() async {
    if (!_initialized) {
      _available = await _speech.initialize(
        onError: (_) => _onSessionEnded(),
        onStatus: (s) {
          if (s == 'done' || s == 'notListening') _onSessionEnded();
        },
      );
      _initialized = true;
    }
    if (!_available) {
      _set(VoiceStatus.unavailable);
      return;
    }
    _freeCommand = true; // ao (re)começar, o 1.º comando é livre
    _listen();
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
    _set(VoiceStatus.listening);
    await _speech.listen(
      onResult: (r) async {
        lastHeard = r.recognizedWords;
        if (r.finalResult) {
          await _handle(r.recognizedWords);
        } else {
          notifyListeners();
        }
      },
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        localeId: 'pt_PT',
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  void _onSessionEnded() {
    _sessionActive = false;
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

    String? command;
    if (_freeCommand) {
      command = text; // logo após abrir: comando livre, sem palavra-chave
    } else {
      command = _stripWake(text); // depois: exige palavra-chave
    }
    _freeCommand = false;

    if (command == null || command.isEmpty) return;
    _set(VoiceStatus.heard);
    await handleVoiceText(repo, command);
  }

  /// Devolve o comando depois da palavra-chave, ou null se não houver.
  String? _stripWake(String text) {
    final lower = _stripAccents(text.toLowerCase());
    for (final w in wakeWords) {
      final idx = lower.indexOf(w);
      if (idx >= 0 && idx <= 3) {
        // palavra-chave no início
        return text
            .substring(idx + w.length)
            .replaceFirst(RegExp(r'^[\s,.:;!?-]+'), '')
            .trim();
      }
    }
    return null;
  }

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
