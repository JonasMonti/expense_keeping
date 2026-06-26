/// Captura uma fatura (câmara ou galeria), reconhece o texto no dispositivo
/// (Google ML Kit, offline) e interpreta-o com [ReceiptParser].
///
/// Tudo acontece localmente — nenhuma imagem sai do telemóvel, mantendo a
/// filosofia offline / single-user da app.
library;

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../ui/theme.dart';
import 'receipt_parser.dart';

/// Abre o seletor de origem (câmara/galeria), lê a fatura e devolve os campos
/// extraídos. Devolve null se o utilizador cancelar ou se nada for reconhecido.
Future<ParsedReceipt?> scanReceipt(BuildContext context) async {
  final source = await _pickSource(context);
  if (source == null || !context.mounted) return null;

  final picker = ImagePicker();
  final XFile? file;
  try {
    file = await picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 2200,
    );
  } catch (_) {
    if (context.mounted) {
      _toast(context, 'Não foi possível aceder à câmara/galeria.');
    }
    return null;
  }
  if (file == null || !context.mounted) return null;

  // Indicador enquanto o ML Kit processa a imagem.
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(
      child: CircularProgressIndicator(color: AppColors.accent),
    ),
  );

  ParsedReceipt? parsed;
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final input = InputImage.fromFilePath(file.path);
    final result = await recognizer.processImage(input);
    parsed = ReceiptParser.parse(result.text);
  } catch (_) {
    parsed = null;
  } finally {
    await recognizer.close();
  }

  if (!context.mounted) return null;
  Navigator.of(context, rootNavigator: true).pop(); // fecha o indicador

  if (parsed == null || (parsed.amount == null && parsed.description.isEmpty)) {
    _toast(context, 'Não consegui ler a fatura. Tenta uma foto mais nítida.');
    return null;
  }
  return parsed;
}

Future<ImageSource?> _pickSource(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          ListTile(
            leading: const Text('📷', style: TextStyle(fontSize: 22)),
            title: const Text('Tirar foto',
                style: TextStyle(fontFamily: kBody, fontSize: 15)),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Text('🖼️', style: TextStyle(fontSize: 22)),
            title: const Text('Escolher da galeria',
                style: TextStyle(fontFamily: kBody, fontSize: 15)),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}
