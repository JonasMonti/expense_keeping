/// Folha que ouve o microfone e devolve a frase reconhecida.
///
/// Usada pelo botão 🎤 dentro da app (com a app já aberta). O texto devolvido
/// segue depois para [handleVoiceText], o mesmo caminho dos deep links da
/// Siri / Google Assistant.
library;

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../ui/theme.dart';

/// Abre o sheet de voz e devolve a frase reconhecida (null se cancelado/vazio).
Future<String?> captureVoice(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => const _VoiceCaptureSheet(),
  );
}

class _VoiceCaptureSheet extends StatefulWidget {
  const _VoiceCaptureSheet();
  @override
  State<_VoiceCaptureSheet> createState() => _VoiceCaptureSheetState();
}

class _VoiceCaptureSheetState extends State<_VoiceCaptureSheet> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  String _words = '';
  String _status = 'A preparar…';
  bool _listening = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final available = await _speech.initialize(
      onError: (e) {
        if (mounted) setState(() => _status = 'Não consegui ouvir. Tenta outra vez.');
      },
      onStatus: (s) {
        if ((s == 'done' || s == 'notListening') && _listening) _finish();
      },
    );
    if (!available) {
      if (mounted) {
        setState(() => _status =
            'Reconhecimento de voz indisponível neste dispositivo.');
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _listening = true;
      _status = 'A ouvir… diz a despesa';
    });
    await _speech.listen(
      onResult: (r) {
        if (!mounted) return;
        setState(() => _words = r.recognizedWords);
        if (r.finalResult) _finish();
      },
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        localeId: 'pt_PT',
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    final t = _words.trim();
    Navigator.of(context).pop(t.isEmpty ? null : t);
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _listening ? AppColors.accentSoft : AppColors.bg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text('🎤', style: TextStyle(fontSize: 32)),
          ),
          const SizedBox(height: 16),
          Text(_status,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: kBody, fontSize: 14, color: AppColors.muted)),
          const SizedBox(height: 8),
          Text(
            _words.isEmpty ? '“doze euros e cinquenta em alimentação”' : _words,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kBody,
              fontSize: 16,
              fontStyle: _words.isEmpty ? FontStyle.italic : FontStyle.normal,
              color: _words.isEmpty ? AppColors.muted : AppColors.ink,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _listening ? _finish : () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(_listening ? '✔️  Concluir' : 'Fechar',
                  style: const TextStyle(
                      fontFamily: kBody,
                      fontWeight: FontWeight.w600,
                      fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}
