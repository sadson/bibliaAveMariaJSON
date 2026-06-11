/// Parses free-form Bible references typed by the user.
///
/// Handles formats like:
///   Jo 4,7 · Jo 4:7 · João 4:7 · joao 4,7
///   São João 4:7 · sao joao 4:7
///   João capítulo 4 versículo 7 · joao cap 4 vers 7
///   1Jo 2,3 · 1 Jo 2,3 · I João 2,3 · i joao 2,3
///   Sl 23 · Salmo 23 (chapter only — no verse)

class ParsedRef {
  const ParsedRef({required this.bookId, required this.chapter, this.verse});
  final int bookId;
  final int chapter;
  final int? verse;
}

class BibleRefParser {
  // ── Normalisation (same logic as BertTokenizer) ──────────────────────────

  static String _norm(String s) {
    const m = {
      'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
      'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
      'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
      'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
      'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c', 'ñ': 'n', 'ý': 'y',
    };
    final buf = StringBuffer();
    for (final cp in s.toLowerCase().runes) {
      if (cp >= 0x0300 && cp <= 0x036F) continue; // strip combining marks
      final c = String.fromCharCode(cp);
      buf.write(m[c] ?? c);
    }
    return buf.toString();
  }

  // ── Alias map: normalised alias → book DB id ─────────────────────────────
  //
  // Sorted longest-first at runtime (see _sorted) so that a longer alias
  // like "1 jo" is tried before the shorter "jo".

  static const Map<String, int> _raw = {
    // ── Antigo Testamento ──────────────────────────────────────────────────
    // 1 Gênesis
    'genesis': 1, 'gen': 1, 'gn': 1,
    // 2 Êxodo
    'exodo': 2, 'exo': 2, 'ex': 2,
    // 3 Levítico
    'levitico': 3, 'lev': 3, 'lv': 3,
    // 4 Números
    'numeros': 4, 'num': 4, 'nm': 4,
    // 5 Deuteronômio
    'deuteronomio': 5, 'deut': 5, 'deu': 5, 'dt': 5,
    // 6 Josué
    'josue': 6, 'jos': 6, 'js': 6,
    // 7 Juízes
    'juizes': 7, 'jui': 7, 'jz': 7,
    // 8 Rute
    'rute': 8, 'rut': 8, 'rt': 8,
    // 9 I Samuel
    '1 samuel': 9, 'i samuel': 9, '1 sam': 9, '1sam': 9, '1 sm': 9, '1sm': 9,
    // 10 II Samuel
    '2 samuel': 10, 'ii samuel': 10, '2 sam': 10, '2sam': 10, '2 sm': 10, '2sm': 10,
    // 11 I Reis
    '1 reis': 11, 'i reis': 11, '1 rs': 11, '1rs': 11,
    // 12 II Reis
    '2 reis': 12, 'ii reis': 12, '2 rs': 12, '2rs': 12,
    // 13 I Crônicas
    '1 cronicas': 13, 'i cronicas': 13, '1 cr': 13, '1cr': 13,
    // 14 II Crônicas
    '2 cronicas': 14, 'ii cronicas': 14, '2 cr': 14, '2cr': 14,
    // 15 Esdras
    'esdras': 15, 'esd': 15, 'ed': 15,
    // 16 Neemias
    'neemias': 16, 'nee': 16, 'ne': 16,
    // 17 Tobias
    'tobias': 17, 'tob': 17, 'tb': 17,
    // 18 Judite
    'judite': 18, 'jdt': 18,
    // 19 Ester
    'ester': 19, 'est': 19, 'et': 19,
    // 20 Jó — "jo" is reserved for São João; use "jb" or "job"
    'job': 20, 'jb': 20,
    // 21 Salmos
    'salmos': 21, 'salmo': 21, 'sal': 21, 'sl': 21, 'ps': 21,
    // 22 I Macabeus
    '1 macabeus': 22, 'i macabeus': 22, '1 mac': 22, '1mac': 22, '1 mc': 22, '1mc': 22,
    // 23 II Macabeus
    '2 macabeus': 23, 'ii macabeus': 23, '2 mac': 23, '2mac': 23, '2 mc': 23, '2mc': 23,
    // 24 Provérbios
    'proverbios': 24, 'prov': 24, 'pv': 24,
    // 25 Eclesiastes
    'eclesiastes': 25, 'ecl': 25, 'qo': 25, 'ec': 25,
    // 26 Cântico dos Cânticos
    'cantico dos canticos': 26, 'cantico': 26, 'can': 26, 'ct': 26,
    // 27 Sabedoria
    'sabedoria': 27, 'sab': 27, 'sb': 27,
    // 28 Eclesiástico
    'eclesiastico': 28, 'siracides': 28, 'eclo': 28, 'sir': 28,
    // 29 Isaías
    'isaias': 29, 'isa': 29, 'is': 29,
    // 30 Jeremias
    'jeremias': 30, 'jer': 30, 'jr': 30,
    // 31 Lamentações
    'lamentacoes': 31, 'lam': 31, 'lm': 31,
    // 32 Baruc
    'baruc': 32, 'bar': 32, 'br': 32,
    // 33 Ezequiel
    'ezequiel': 33, 'eze': 33, 'ez': 33,
    // 34 Daniel
    'daniel': 34, 'dan': 34, 'dn': 34,
    // 35 Oséias
    'oseias': 35, 'os': 35,
    // 36 Joel
    'joel': 36, 'jl': 36,
    // 37 Amós
    'amos': 37, 'am': 37,
    // 38 Abdias
    'abdias': 38, 'abd': 38, 'ab': 38,
    // 39 Jonas
    'jonas': 39, 'jon': 39, 'jn': 39,
    // 40 Miquéias
    'miqueias': 40, 'mic': 40, 'mq': 40,
    // 41 Naum
    'naum': 41, 'na': 41,
    // 42 Habacuc
    'habacuc': 42, 'hab': 42,
    // 43 Sofonias
    'sofonias': 43, 'sof': 43, 'sf': 43,
    // 44 Ageu
    'ageu': 44, 'ag': 44,
    // 45 Zacarias
    'zacarias': 45, 'zac': 45, 'zc': 45,
    // 46 Malaquias
    'malaquias': 46, 'mal': 46, 'ml': 46,

    // ── Novo Testamento ────────────────────────────────────────────────────
    // 47 São Mateus
    'sao mateus': 47, 'mateus': 47, 'mat': 47, 'mt': 47,
    // 48 São Marcos
    'sao marcos': 48, 'marcos': 48, 'mar': 48, 'mc': 48, 'mk': 48,
    // 49 São Lucas
    'sao lucas': 49, 'lucas': 49, 'luc': 49, 'lc': 49, 'lk': 49,
    // 50 São João — "jo" is the standard Portuguese abbreviation
    'sao joao': 50, 'joao': 50, 'jo': 50,
    // 51 Atos dos Apóstolos
    'atos dos apostolos': 51, 'atos': 51, 'at': 51,
    // 52 Romanos
    'romanos': 52, 'rom': 52, 'rm': 52,
    // 53 I Coríntios
    '1 corintios': 53, 'i corintios': 53, '1 cor': 53, '1cor': 53, '1 co': 53, '1co': 53,
    // 54 II Coríntios
    '2 corintios': 54, 'ii corintios': 54, '2 cor': 54, '2cor': 54, '2 co': 54, '2co': 54,
    // 55 Gálatas
    'galatas': 55, 'gal': 55, 'gl': 55,
    // 56 Efésios
    'efesios': 56, 'efe': 56, 'ef': 56,
    // 57 Filipenses
    'filipenses': 57, 'fil': 57, 'fp': 57,
    // 58 Colossenses
    'colossenses': 58, 'col': 58, 'cl': 58,
    // 59 I Tessalonicenses
    '1 tessalonicenses': 59, 'i tessalonicenses': 59, '1 tes': 59, '1tes': 59, '1 ts': 59, '1ts': 59,
    // 60 II Tessalonicenses
    '2 tessalonicenses': 60, 'ii tessalonicenses': 60, '2 tes': 60, '2tes': 60, '2 ts': 60, '2ts': 60,
    // 61 I Timóteo
    '1 timoteo': 61, 'i timoteo': 61, '1 tim': 61, '1tim': 61, '1 tm': 61, '1tm': 61,
    // 62 II Timóteo
    '2 timoteo': 62, 'ii timoteo': 62, '2 tim': 62, '2tim': 62, '2 tm': 62, '2tm': 62,
    // 63 Tito
    'tito': 63, 'tit': 63, 'tt': 63,
    // 64 Filêmon
    'filemon': 64, 'flm': 64, 'fm': 64,
    // 65 Hebreus
    'hebreus': 65, 'heb': 65, 'hb': 65,
    // 66 São Tiago
    'sao tiago': 66, 'tiago': 66, 'tia': 66, 'tg': 66,
    // 67 I São Pedro
    '1 pedro': 67, 'i pedro': 67, 'i sao pedro': 67, '1 ped': 67, '1ped': 67, '1 pe': 67, '1pe': 67,
    // 68 II São Pedro
    '2 pedro': 68, 'ii pedro': 68, 'ii sao pedro': 68, '2 ped': 68, '2ped': 68, '2 pe': 68, '2pe': 68,
    // 69 I São João
    'i sao joao': 69, 'i joao': 69, '1 joao': 69, '1joao': 69, '1 jo': 69, '1jo': 69,
    // 70 II São João
    'ii sao joao': 70, 'ii joao': 70, '2 joao': 70, '2joao': 70, '2 jo': 70, '2jo': 70,
    // 71 III São João
    'iii sao joao': 71, 'iii joao': 71, '3 joao': 71, '3joao': 71, '3 jo': 71, '3jo': 71,
    // 72 São Judas
    'sao judas': 72, 'judas': 72, 'jd': 72,
    // 73 Apocalipse
    'apocalipse': 73, 'apo': 73, 'rv': 73, 'ap': 73,
  };

  static final _sorted = _buildSorted();
  static List<MapEntry<String, int>> _buildSorted() {
    return _raw.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
  }

  // ── Public API ────────────────────────────────────────────────────────────

  static ParsedRef? parse(String query) {
    final q = _norm(query.trim());
    for (final entry in _sorted) {
      final alias = entry.key;
      if (!q.startsWith(alias)) continue;

      // Word boundary: what follows the alias must be a space, digit, or EOS
      final after = q.substring(alias.length);
      if (after.isNotEmpty) {
        final next = after.codeUnitAt(0);
        final isSpace = next == 0x20;
        final isDigit = next >= 0x30 && next <= 0x39;
        if (!isSpace && !isDigit) continue;
      } else {
        continue; // alias with no chapter — not useful
      }

      final cv = _parseCV(after.trim());
      if (cv != null) {
        return ParsedRef(bookId: entry.value, chapter: cv.$1, verse: cv.$2);
      }
    }
    return null;
  }

  // ── Chapter / verse parsing ───────────────────────────────────────────────

  static (int, int?)? _parseCV(String s) {
    var rest = s;

    // Strip optional chapter keyword: "capitulo 2" → "2"
    rest = rest.replaceFirst(RegExp(r'^cap(?:itulo)?\s+'), '');

    final chapM = RegExp(r'^(\d{1,3})').firstMatch(rest);
    if (chapM == null) return null;
    final chapter = int.parse(chapM.group(1)!);
    rest = rest.substring(chapM.end).trim();

    if (rest.isEmpty) return (chapter, null);

    // Verse separators: , : . or "versiculo"/"vers"/"v." then a number
    final verseM = RegExp(
      r'^(?:[,:.]\s*|vers(?:iculo)?\s+|v\.\s*)(\d{1,3})',
    ).firstMatch(rest);
    if (verseM != null) return (chapter, int.parse(verseM.group(1)!));

    return (chapter, null);
  }
}
