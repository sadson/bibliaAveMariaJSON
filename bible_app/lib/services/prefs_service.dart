import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LastRead {
  final int bookId;
  final int chapterId;
  final int? verseId;
  final String label;

  const LastRead({
    required this.bookId,
    required this.chapterId,
    this.verseId,
    required this.label,
  });
}

class PrefsService {
  static PrefsService? _instance;
  final SharedPreferences _prefs;

  PrefsService._(this._prefs);

  static PrefsService get instance {
    if (_instance == null) {
      throw StateError(
        'PrefsService has not been initialized. Call PrefsService.load() first.',
      );
    }
    return _instance!;
  }

  static Future<PrefsService> load() async {
    if (_instance != null) return _instance!;
    final prefs = await SharedPreferences.getInstance();
    _instance = PrefsService._(prefs);
    return _instance!;
  }

  // ---------------------------------------------------------------------------
  // Keys
  // ---------------------------------------------------------------------------

  static const _keyLastReadBookId = 'last_read_book_id';
  static const _keyLastReadChapterId = 'last_read_chapter_id';
  static const _keyLastReadVerseId = 'last_read_verse_id';
  static const _keyLastReadLabel = 'last_read_label';
  static const _keySearchHistory = 'search_history';
  static const _keyThemeMode = 'theme_mode';
  static const _keyFontSize = 'font_size';
  static const _maxSearchHistory = 10;
  static const _defaultFontSize = 17.0;

  // ---------------------------------------------------------------------------
  // Resume reading
  // ---------------------------------------------------------------------------

  Future<void> saveLastRead(
    int bookId,
    int chapterId,
    int chapterNumber,
    String bookName, {
    int? verseId,
  }) async {
    final label = '$bookName $chapterNumber';
    await _prefs.setInt(_keyLastReadBookId, bookId);
    await _prefs.setInt(_keyLastReadChapterId, chapterId);
    await _prefs.setString(_keyLastReadLabel, label);
    if (verseId != null) {
      await _prefs.setInt(_keyLastReadVerseId, verseId);
    } else {
      await _prefs.remove(_keyLastReadVerseId);
    }
  }

  LastRead? getLastRead() {
    final bookId = _prefs.getInt(_keyLastReadBookId);
    final chapterId = _prefs.getInt(_keyLastReadChapterId);
    final label = _prefs.getString(_keyLastReadLabel);

    if (bookId == null || chapterId == null || label == null) return null;

    final verseId = _prefs.getInt(_keyLastReadVerseId);

    return LastRead(
      bookId: bookId,
      chapterId: chapterId,
      verseId: verseId,
      label: label,
    );
  }

  // ---------------------------------------------------------------------------
  // Search history
  // ---------------------------------------------------------------------------

  Future<void> saveSearchQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final history = getSearchHistory();
    history.remove(trimmed);
    history.insert(0, trimmed);

    final capped = history.take(_maxSearchHistory).toList();
    await _prefs.setStringList(_keySearchHistory, capped);
  }

  List<String> getSearchHistory() {
    return List<String>.from(
      _prefs.getStringList(_keySearchHistory) ?? <String>[],
    );
  }

  Future<void> clearSearchHistory() async {
    await _prefs.remove(_keySearchHistory);
  }

  // ---------------------------------------------------------------------------
  // Theme mode
  // ---------------------------------------------------------------------------

  Future<void> saveThemeMode(ThemeMode mode) async {
    await _prefs.setString(_keyThemeMode, mode.name);
  }

  ThemeMode getThemeMode() {
    final name = _prefs.getString(_keyThemeMode);
    return ThemeMode.values.firstWhere(
      (m) => m.name == name,
      orElse: () => ThemeMode.system,
    );
  }

  // ---------------------------------------------------------------------------
  // Font size
  // ---------------------------------------------------------------------------

  Future<void> saveFontSize(double size) async {
    await _prefs.setDouble(_keyFontSize, size);
  }

  double getFontSize() {
    return _prefs.getDouble(_keyFontSize) ?? _defaultFontSize;
  }
}
