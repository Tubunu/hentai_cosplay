class JsUnpacker {
  /// Unpacks a Dean Edwards packed script block.
  /// Returns the unpacked code string, or null if no valid packer patterns are found.
  static String? unpack(String scriptText) {
    if (!scriptText.contains('eval(function')) {
      return null;
    }

    String? packed;
    int a = 0;
    int c = 0;
    List<String> keysStr = [];

    // Find the '.split(' call for key dictionary
    final splitMatches = [
      scriptText.indexOf(".split('|')"),
      scriptText.indexOf('.split("|")'),
      scriptText.indexOf(".split(/\\|/)"),
    ];
    int splitIdx = -1;
    for (final idx in splitMatches) {
      if (idx != -1 && (splitIdx == -1 || idx < splitIdx)) {
        splitIdx = idx;
      }
    }

    if (splitIdx != -1) {
      try {
        final beforeSplit = scriptText.substring(0, splitIdx).trim();
        final quoteChar = beforeSplit.endsWith("'") ? "'" : (beforeSplit.endsWith('"') ? '"' : '');
        if (quoteChar.isNotEmpty) {
          final keyStart = beforeSplit.lastIndexOf(quoteChar, beforeSplit.length - 2);
          if (keyStart != -1) {
            final rawKeys = beforeSplit.substring(keyStart + 1, beforeSplit.length - 1);
            keysStr = rawKeys.split('|');

            // Now parse 'a' and 'c' which precede the keys string
            final beforeKeys = beforeSplit.substring(0, keyStart).trim();
            final cleanedBeforeKeys = beforeKeys.endsWith(',') ? beforeKeys.substring(0, beforeKeys.length - 1).trim() : beforeKeys;
            
            // Extract the last two comma-separated integer tokens
            final lastComma = cleanedBeforeKeys.lastIndexOf(',');
            if (lastComma != -1) {
              final cStr = cleanedBeforeKeys.substring(lastComma + 1).trim();
              c = int.tryParse(cStr) ?? 0;
              
              final prevComma = cleanedBeforeKeys.lastIndexOf(',', lastComma - 1);
              if (prevComma != -1) {
                final aStr = cleanedBeforeKeys.substring(prevComma + 1, lastComma).trim();
                a = int.tryParse(aStr) ?? 0;

                // Everything before prevComma is the payload!
                var rawPayload = cleanedBeforeKeys.substring(0, prevComma).trim();
                final funcEndIdx = rawPayload.indexOf('}(');
                if (funcEndIdx != -1) {
                  rawPayload = rawPayload.substring(funcEndIdx + 2).trim();
                } else {
                  final openParen = rawPayload.indexOf('(');
                  if (openParen != -1) {
                    rawPayload = rawPayload.substring(openParen + 1).trim();
                  }
                }

                // Strip surrounding quotes
                if ((rawPayload.startsWith("'") && rawPayload.endsWith("'")) ||
                    (rawPayload.startsWith('"') && rawPayload.endsWith('"'))) {
                  packed = rawPayload.substring(1, rawPayload.length - 1);
                } else {
                  packed = rawPayload;
                }
              }
            }
          }
        }
      } catch (_) {}
    }

    if (packed == null || a <= 1 || a > 62 || c <= 0 || c > 200000) {
      return null;
    }

    // Convert base-10 to base-N (supports full Base62: 0-9, a-z, A-Z)
    String toBase(int n, int base) {
      const digits = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
      if (n == 0) return '0';
      var s = '';
      while (n > 0) {
        s = digits[n % base] + s;
        n = n ~/ base;
      }
      return s;
    }

    // Build the lookup table for words
    final lookup = <String, String>{};
    for (var i = 0; i < c; i++) {
      final baseStr = toBase(i, a);
      lookup[baseStr] = (i < keysStr.length && keysStr[i].isNotEmpty) 
          ? keysStr[i] 
          : baseStr;
    }

    // Replace all matching base-N words with their lookup values
    final wordRegex = RegExp(r'\b\w+\b');
    return packed.replaceAllMapped(wordRegex, (m) {
      final word = m.group(0)!;
      return lookup.containsKey(word) ? lookup[word]! : word;
    });
  }
}
