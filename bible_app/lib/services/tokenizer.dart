import 'dart:collection';
import 'package:flutter/services.dart';
import '../core/constants.dart';

/// BERT WordPiece tokenizer for all-MiniLM-L6-v2.
/// Handles uncased, subword tokenization with [CLS]/[SEP] special tokens.
class BertTokenizer {
  BertTokenizer._(this._vocab);

  final Map<String, int> _vocab;

  static BertTokenizer? _instance;

  static Future<BertTokenizer> load() async {
    if (_instance != null) return _instance!;
    final raw = await rootBundle.loadString(AppConstants.vocabAssetPath);
    final lines = raw.split('\n');
    final vocab = HashMap<String, int>();
    for (int i = 0; i < lines.length; i++) {
      final token = lines[i].trim();
      if (token.isNotEmpty) {
        vocab[token] = i;
      }
    }
    _instance = BertTokenizer._(vocab);
    return _instance!;
  }

  static const _clsToken = '[CLS]';
  static const _sepToken = '[SEP]';
  static const _padToken = '[PAD]';
  static const _unkToken = '[UNK]';

  /// Returns (inputIds, attentionMask, tokenTypeIds) each of length [maxLen].
  ({List<int> inputIds, List<int> attentionMask, List<int> tokenTypeIds})
      encode(String text, {int maxLen = AppConstants.maxSeqLength}) {
    final tokens = <String>[_clsToken];
    for (final word in _basicTokenize(text.toLowerCase())) {
      tokens.addAll(_wordpieceTokenize(word));
    }
    tokens.add(_sepToken);

    // Truncate to maxLen
    if (tokens.length > maxLen) tokens.removeRange(maxLen - 1, tokens.length - 1);

    final ids = tokens.map((t) => _vocab[t] ?? _vocab[_unkToken]!).toList();
    final padId = _vocab[_padToken] ?? 0;
    final attentionMask = List.filled(maxLen, 0);
    final inputIds = List.filled(maxLen, padId);
    final tokenTypeIds = List.filled(maxLen, 0);

    for (int i = 0; i < ids.length && i < maxLen; i++) {
      inputIds[i] = ids[i];
      attentionMask[i] = 1;
    }

    return (
      inputIds: inputIds,
      attentionMask: attentionMask,
      tokenTypeIds: tokenTypeIds,
    );
  }

  List<String> _basicTokenize(String text) {
    final buf = StringBuffer();
    final tokens = <String>[];

    void flush() {
      if (buf.isNotEmpty) {
        tokens.add(buf.toString());
        buf.clear();
      }
    }

    for (final ch in text.runes) {
      final c = String.fromCharCode(ch);
      if (_isPunctuation(ch) || _isWhitespace(ch)) {
        flush();
        if (_isPunctuation(ch)) tokens.add(c);
      } else {
        buf.write(c);
      }
    }
    flush();
    return tokens.where((t) => t.isNotEmpty).toList();
  }

  List<String> _wordpieceTokenize(String word) {
    if (word.length > 200) return [_unkToken];
    if (_vocab.containsKey(word)) return [word];

    final tokens = <String>[];
    int start = 0;
    while (start < word.length) {
      int end = word.length;
      String? found;
      while (start < end) {
        final substr =
            (start == 0 ? '' : '##') + word.substring(start, end);
        if (_vocab.containsKey(substr)) {
          found = substr;
          break;
        }
        end--;
      }
      if (found == null) return [_unkToken];
      tokens.add(found);
      start = end;
    }
    return tokens;
  }

  bool _isWhitespace(int ch) =>
      ch == 0x20 || ch == 0x09 || ch == 0x0A || ch == 0x0D;

  bool _isPunctuation(int ch) {
    if ((ch >= 33 && ch <= 47) ||
        (ch >= 58 && ch <= 64) ||
        (ch >= 91 && ch <= 96) ||
        (ch >= 123 && ch <= 126)) return true;
    // CJK and other Unicode punctuation
    if (ch == 0x00B7) return true;
    if (ch >= 0x2000 && ch <= 0x206F) return true;
    if (ch >= 0x2E00 && ch <= 0x2E7F) return true;
    if (ch >= 0x3000 && ch <= 0x303F) return true;
    if (ch >= 0xFF01 && ch <= 0xFF0F) return true;
    if (ch >= 0xFF1A && ch <= 0xFF20) return true;
    if (ch >= 0xFF3B && ch <= 0xFF40) return true;
    if (ch >= 0xFF5B && ch <= 0xFF65) return true;
    return false;
  }
}
