class TextAnalysisEngine {
  static final TextAnalysisEngine instance = TextAnalysisEngine._internal();
  TextAnalysisEngine._internal();

  static const Set<String> _germanStopWords = {
    'der', 'die', 'das', 'und', 'ist', 'in', 'für', 'von', 'mit', 'zu', 'auf',
    'den', 'des', 'dem', 'dass', 'ein', 'eine', 'einer', 'einem', 'einen', 'eines',
    'nicht', 'auch', 'es', 'an', 'als', 'nach', 'wie', 'im', 'bei', 'aus', 'um',
    'aber', 'wird', 'werden', 'sind', 'war', 'wurde', 'haben', 'hat', 'hatte',
    'vor', 'über', 'durch', 'man', 'nur', 'noch', 'sehr', 'so', 'oder', 'sie',
    'er', 'wir', 'ihr', 'ich', 'du', 'ihnen', 'ihre', 'ihrem', 'ihren', 'sein',
    'seine', 'seinem', 'seinen', 'dies', 'diese', 'dieser', 'diesem', 'diesen',
    'kann', 'können', 'soll', 'sollen', 'muss', 'müssen', 'hier', 'dort', 'da',
    'zur', 'vom', 'beim', 'ins', 'zum', 'am', 'unter', 'zwischen'
  };

  /// Performs a thorough, structured, and insightful local text analysis.
  String analyze(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) return 'Kein Text zur Analyse vorhanden.';

    // 1. Basic Stats
    final words = text
        .split(RegExp(r'\s+'))
        .map((w) => w.replaceAll(RegExp(r'[^\wöäüßÖÄÜ]'), ''))
        .where((w) => w.isNotEmpty)
        .toList();

    final wordCount = words.length;
    final charCount = text.length;
    final paragraphs = text.split(RegExp(r'\n\s*\n')).where((p) => p.trim().isNotEmpty).length;

    // 2. Sentences extraction
    final rawSentences = text
        .split(RegExp(r'(?<=[.!?])\s+|\n+'))
        .map((s) => s.trim())
        .where((s) => s.length > 5)
        .toList();

    final sentenceCount = max(1, rawSentences.length);
    final avgWordsPerSentence = (wordCount / sentenceCount).toStringAsFixed(1);
    final readingTimeMinutes = max(1, (wordCount / 200).ceil());

    // 3. Keyword Extraction (Word Frequency excluding Stop Words)
    final wordFreq = <String, int>{};
    for (final w in words) {
      final lower = w.toLowerCase();
      if (lower.length > 3 && !_germanStopWords.contains(lower) && !RegExp(r'^\d+$').hasMatch(lower)) {
        final capitalized = w.length > 1 ? '${w[0].toUpperCase()}${w.substring(1)}' : w;
        wordFreq[capitalized] = (wordFreq[capitalized] ?? 0) + 1;
      }
    }

    final sortedKeywords = wordFreq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topKeywords = sortedKeywords.take(6).map((e) => e.key).toList();

    // 4. Extractive Executive Summary (Sentence Scoring)
    final scoredSentences = <_ScoredSentence>[];
    for (int i = 0; i < rawSentences.length; i++) {
      final s = rawSentences[i];
      double score = 0;
      final sWords = s.toLowerCase().split(RegExp(r'\s+'));

      for (final sw in sWords) {
        final clean = sw.replaceAll(RegExp(r'[^\wöäüß]'), '');
        final count = wordFreq[clean.length > 1 ? '${clean[0].toUpperCase()}${clean.substring(1)}' : clean] ?? 0;
        score += count;
      }

      // Position bonuses
      if (i == 0) score *= 1.35; // First sentence bonus
      if (i == rawSentences.length - 1 && rawSentences.length > 2) score *= 1.15; // Conclusion bonus

      // Ideal length normalization (10-25 words)
      if (sWords.length >= 8 && sWords.length <= 30) score *= 1.2;

      scoredSentences.add(_ScoredSentence(sentence: s, score: score, index: i));
    }

    scoredSentences.sort((a, b) => b.score.compareTo(a.score));
    final summaryCount = min(3, max(1, (rawSentences.length * 0.4).ceil()));
    final bestSentences = scoredSentences.take(summaryCount).toList()
      ..sort((a, b) => a.index.compareTo(b.index)); // Keep chronological order

    // 5. Action Items & Commitments Detection
    final actionItemKeywords = RegExp(
      r'\b(muss|müssen|soll|sollen|wichtig|dringend|prüfen|abstimmen|erledigen|kontaktieren|einreichen|besprechen|vorbereiten|termin|terminiert|bis|deadline|aufgabe|senden|anrufen|freigeben)\b',
      caseSensitive: false,
    );

    final detectedActionItems = <String>[];
    for (final s in rawSentences) {
      if (actionItemKeywords.hasMatch(s)) {
        detectedActionItems.add(s);
      }
    }

    // 6. Readability & Tone Analysis
    final isUrgent = RegExp(r'\b(dringend|sofort|eilig|asap|kritisch|prio|deadline)\b', caseSensitive: false).hasMatch(text);

    // Approximate Flesch-Reading-Ease for German
    int syllableCount = 0;
    for (final w in words) {
      final matches = RegExp(r'[aeiouyäöü]+', caseSensitive: false).allMatches(w);
      syllableCount += max(1, matches.length);
    }
    final asl = wordCount / sentenceCount;
    final asw = syllableCount / max(1, wordCount);
    final fleschIndex = (180 - asl - (58.5 * asw)).clamp(0, 100).toInt();

    String readabilityText;
    if (fleschIndex >= 70) {
      readabilityText = 'Leicht verständlich (Alltagssprache, gut zugänglich)';
    } else if (fleschIndex >= 50) {
      readabilityText = 'Gut verständlich (Standard-Sprachniveau)';
    } else if (fleschIndex >= 35) {
      readabilityText = 'Anspruchsvoll (Fach- oder Geschäftssprache)';
    } else {
      readabilityText = 'Sehr komplex (Verschachtelte Sätze / Fachtermini)';
    }

    // 7. Compose Comprehensive Markdown Report
    final buffer = StringBuffer();
    buffer.writeln('📋 **Textanalyse & Zusammenfassung**\n');

    // Executive Summary
    buffer.writeln('### 📌 Kernaussagen (Executive Summary):');
    for (final bs in bestSentences) {
      buffer.writeln('• ${bs.sentence}');
    }
    buffer.writeln();

    // Key Topics / Tags
    if (topKeywords.isNotEmpty) {
      buffer.writeln('### 🏷️ Zentrale Schlagwörter & Themen:');
      buffer.writeln(topKeywords.map((k) => '`#$k`').join('   '));
      buffer.writeln();
    }

    // Action Items / Detected Tasks
    if (detectedActionItems.isNotEmpty) {
      buffer.writeln('### ⚡ Erkannte Handlungsfelder & Aufgaben:');
      for (final act in detectedActionItems.take(4)) {
        buffer.writeln('• [ ] $act');
      }
      buffer.writeln();
    }

    // Structure & Metrics
    buffer.writeln('### 📊 Kennzahlen & Lesbarkeit:');
    buffer.writeln('• **Umfang:** $wordCount Wörter, $charCount Zeichen, $sentenceCount Sätze, $paragraphs Absätze (Ø $avgWordsPerSentence Wörter/Satz)');
    buffer.writeln('• **Lesedauer:** ca. $readingTimeMinutes Minute${readingTimeMinutes > 1 ? "n" : ""}');
    buffer.writeln('• **Lesbarkeitsindex:** $fleschIndex / 100 ➔ $readabilityText');
    buffer.writeln('• **Priorität:** ${isUrgent ? "🚨 Dringend (Signale im Text erkannt)" : " Normal"}');

    return buffer.toString();
  }

  /// Improves grammar, formatting and structure locally
  String improve(String text) {
    if (text.trim().isEmpty) return text;

    final lines = text.split('\n');
    final formattedLines = <String>[];

    for (var line in lines) {
      var trimmed = line.trim();
      if (trimmed.isEmpty) {
        formattedLines.add('');
        continue;
      }

      // Capitalize first character of line if it's a letter
      if (trimmed.isNotEmpty && RegExp(r'^[a-zäöü]').hasMatch(trimmed)) {
        trimmed = trimmed[0].toUpperCase() + trimmed.substring(1);
      }

      // Normalize multiple spaces
      trimmed = trimmed.replaceAll(RegExp(r'[ \t]{2,}'), ' ');

      // Normalize bullet points
      if (RegExp(r'^[-*•]\s+').hasMatch(trimmed)) {
        trimmed = '• ${trimmed.replaceAll(RegExp(r'^[-*•]\s+'), '')}';
      }

      formattedLines.add(trimmed);
    }

    return formattedLines.join('\n');
  }

  int min(int a, int b) => a < b ? a : b;
  int max(int a, int b) => a > b ? a : b;
}

class _ScoredSentence {
  final String sentence;
  final double score;
  final int index;

  _ScoredSentence({
    required this.sentence,
    required this.score,
    required this.index,
  });
}
