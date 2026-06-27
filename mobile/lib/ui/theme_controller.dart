/// Preferência de tema (claro / escuro / seguir o sistema), persistida.
///
/// Por defeito segue o sistema; o utilizador pode forçar Claro ou Escuro. A
/// escolha guarda-se em [SharedPreferences] (preferência de UI local — não vai
/// no backup da base de dados, que só guarda dados).
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Instância global (mesmo padrão dos outros singletons de UI da app).
final themeController = ThemeController();

class ThemeController extends ChangeNotifier {
  static const _key = 'theme_mode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  /// Lê a preferência guardada (chamar uma vez no arranque).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    _mode = ThemeMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => ThemeMode.system,
    );
    notifyListeners();
  }

  /// Define e persiste o modo.
  Future<void> set(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}
