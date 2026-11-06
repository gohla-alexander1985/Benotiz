import 'dart:math';

class MathEngine {
  static final MathEngine instance = MathEngine._internal();
  MathEngine._internal();

  /// Solves mathematical expressions, equations, word problems, or geometric tasks.
  String solve(String rawQuery) {
    final query = rawQuery.trim();
    if (query.isEmpty) return 'Keine mathematische Aufgabe angegeben.';

    // 1. Try Word Problems: Percentages (e.g., "15% von 200", "200 + 19% MwSt")
    final percentResult = _tryPercentageWordProblems(query);
    if (percentResult != null) return percentResult;

    // 2. Try Word Problems: Interest calculation (Zinsrechnung)
    final interestResult = _tryInterestCalculation(query);
    if (interestResult != null) return interestResult;

    // 3. Try Word Problems: Rule of three (Dreisatz)
    final ruleOfThreeResult = _tryRuleOfThree(query);
    if (ruleOfThreeResult != null) return ruleOfThreeResult;

    // 4. Try Geometry: Circle, Rectangle, Triangle, Pythagoras
    final geometryResult = _tryGeometryProblems(query);
    if (geometryResult != null) return geometryResult;

    // 5. Try Linear Equations (e.g., "2x + 6 = 18", "3x = 24")
    final equationResult = _tryLinearEquation(query);
    if (equationResult != null) return equationResult;

    // 6. Try Formula Completion or Physics Law
    final formulaMatch = _tryFormulaCompletion(query);
    if (formulaMatch != null) return formulaMatch;

    // 7. General Arithmetic Evaluator (supports +, -, *, /, ^, %, sqrt, parentheses)
    final arithmeticResult = _tryArithmeticEvaluation(query);
    if (arithmeticResult != null) return arithmeticResult;

    // 8. Fallback structured guidance
    return '🧮 **Mathematische Formelhilfe:**\n\n'
        '• Eingegebener Ausdruck: `$query`\n\n'
        '**Unterstützte lokale Berechnungen:**\n'
        '• **Grundrechenarten:** z.B. `(45 + 15) * 8 / 2` oder `2^8 + sqrt(144)`\n'
        '• **Prozente:** z.B. `15% von 850` oder `250 + 19% MwSt` oder `120 - 20% Rabatt`\n'
        '• **Gleichungen:** z.B. `3x + 12 = 48` oder `2x = 36`\n'
        '• **Geometrie:** z.B. `Kreis r=5` oder `Rechteck 12 x 8` oder `Dreieck g=10, h=6`\n'
        '• **Finanzen:** z.B. `Zinsen für 5000 € bei 3.5% über 4 Jahre`\n'
        '• **Formeln:** z.B. `a^2 + b^2` oder `(a+b)^2` oder `U = R * I`\n\n'
        '*(Tipp: Für freie Textfragen und Symbolrechnung kannst du in den Einstellungen deinen Google Gemini API-Schlüssel hinterlegen!)*';
  }

  /// Completes or explains standard mathematical / physics formulas
  String completeFormula(String rawFormula) {
    final formula = rawFormula.trim();
    if (formula.isEmpty) return 'Keine Formel zur Ergänzung angegeben.';

    final match = _tryFormulaCompletion(formula);
    if (match != null) return match;

    // Try evaluation if it's an expression
    final eval = _tryArithmeticEvaluation(formula);
    if (eval != null) return eval;

    return '🧮 **Formel-Ergänzung:**\n\n'
        '• Eingegebene Formel: `$formula`\n\n'
        '**Mögliche Ergänzungen je nach Fachgebiet:**\n'
        '• **Geometrie:** Satz des Pythagoras: `a² + b² = c²`\n'
        '• **Algebra:** 1. Binomische Formel: `(a + b)² = a² + 2ab + b²`\n'
        '• **Elektrotechnik:** Ohmsches Gesetz: `U = R · I` | Leistung: `P = U · I`\n'
        '• **Physik:** Kraft: `F = m · a` | Geschwindigkeit: `v = s / t`\n\n'
        '*(Tipp: Richte deinen kostenlosen Google Gemini API-Schlüssel ein, um beliebige Formeln symbolisch analysieren zu lassen!)*';
  }

  // ===========================================================================
  // 1. Percentage & Financial Calculations
  // ===========================================================================
  String? _tryPercentageWordProblems(String q) {
    // "15% von 200" or "15 Prozent von 200" or "Was ist 15% von 200?"
    final vonMatch = RegExp(r'(?:was\s+ist\s+)?(\d+(?:[.,]\d+)?)\s*(?:%|prozent)\s+von\s+(\d+(?:[.,]\d+)?)', caseSensitive: false).firstMatch(q);
    if (vonMatch != null) {
      final p = _parseDouble(vonMatch.group(1)!);
      final g = _parseDouble(vonMatch.group(2)!);
      if (p != null && g != null) {
        final w = (p / 100) * g;
        return '🧮 **Prozentwert-Berechnung:**\n\n'
            '• **Aufgabe:** $p % von ${_formatNum(g)}\n'
            '• **Formel:** `W = G · (p / 100)`\n'
            '• **Rechenweg:** ${_formatNum(g)} · ($p / 100) = ${_formatNum(g)} · ${_formatNum(p / 100)}\n\n'
            '👉 **Endergebnis: ${_formatNum(w)}**';
      }
    }

    // "200 + 19% MwSt" or "200 + 19%" or "200 plus 19%"
    final plusMatch = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:\+|\bplus\b|\binkl\.?\b|\bmit\b)\s*(\d+(?:[.,]\d+)?)\s*(?:%|prozent)', caseSensitive: false).firstMatch(q);
    if (plusMatch != null) {
      final g = _parseDouble(plusMatch.group(1)!);
      final p = _parseDouble(plusMatch.group(2)!);
      if (g != null && p != null) {
        final delta = g * (p / 100);
        final total = g + delta;
        return '🧮 **Aufschlag- & Prozentrechnung:**\n\n'
            '• **Grundwert (Netto):** ${_formatNum(g)}\n'
            '• **Aufschlag ($p %):** ${_formatNum(delta)}\n'
            '• **Rechenweg:** ${_formatNum(g)} · (1 + $p / 100) = ${_formatNum(g)} · ${_formatNum(1 + p / 100)}\n\n'
            '👉 **Endergebnis (Brutto / Gesamt): ${_formatNum(total)}**';
      }
    }

    // "500 - 20% Rabatt" or "500 - 20%" or "500 abzüglich 20%"
    final minusMatch = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:\-|\bminus\b|\babzüglich\b|\brabatt\b)\s*(\d+(?:[.,]\d+)?)\s*(?:%|prozent)', caseSensitive: false).firstMatch(q);
    if (minusMatch != null) {
      final g = _parseDouble(minusMatch.group(1)!);
      final p = _parseDouble(minusMatch.group(2)!);
      if (g != null && p != null) {
        final rabatt = g * (p / 100);
        final total = g - rabatt;
        return '🧮 **Rabatt- & Prozentabzug:**\n\n'
            '• **Ausgangswert:** ${_formatNum(g)}\n'
            '• **Abzug ($p % Rabatt):** -${_formatNum(rabatt)}\n'
            '• **Rechenweg:** ${_formatNum(g)} · (1 - $p / 100) = ${_formatNum(g)} · ${_formatNum(1 - p / 100)}\n\n'
            '👉 **Endergebnis nach Abzug: ${_formatNum(total)}**';
      }
    }

    return null;
  }

  // ===========================================================================
  // 2. Interest Calculation (Zinsrechnung)
  // ===========================================================================
  String? _tryInterestCalculation(String q) {
    // "Zinsen für 5000 € bei 3.5% über 4 Jahre"
    final zinsMatch = RegExp(
      r'zinsen\s+(?:für\s+)?(\d+(?:[.,]\d+)?)\s*(?:€|euro)?\s*bei\s*(\d+(?:[.,]\d+)?)\s*%\s*(?:über\s*)?(\d+(?:[.,]\d+)?)\s*(jahr|jahre|jahren|monat|monate|monaten)?',
      caseSensitive: false,
    ).firstMatch(q);

    if (zinsMatch != null) {
      final k = _parseDouble(zinsMatch.group(1)!);
      final p = _parseDouble(zinsMatch.group(2)!);
      final t = _parseDouble(zinsMatch.group(3)!) ?? 1.0;
      final unit = zinsMatch.group(4)?.toLowerCase() ?? 'jahr';
      final isMonths = unit.startsWith('monat');

      if (k != null && p != null) {
        final timeInYears = isMonths ? (t / 12) : t;
        final zinsen = k * (p / 100) * timeInYears;
        final endkapital = k + zinsen;

        return '🧮 **Zinsberechnung (Einfache Zinsen):**\n\n'
            '• **Startkapital (K):** ${_formatNum(k)} €\n'
            '• **Zinssatz (p):** $p % p.a.\n'
            '• **Laufzeit (t):** $t ${isMonths ? "Monate" : "Jahre"}\n'
            '• **Formel:** `Z = K · (p / 100) · t`\n'
            '• **Rechenweg:** ${_formatNum(k)} · ${p / 100} · $timeInYears = ${_formatNum(zinsen)} €\n\n'
            '👉 **Zinsertrag: ${_formatNum(zinsen)} €**\n'
            '👉 **Gesamtkapital nach Laufzeit: ${_formatNum(endkapital)} €**';
      }
    }
    return null;
  }

  // ===========================================================================
  // 3. Rule of Three (Dreisatz)
  // ===========================================================================
  String? _tryRuleOfThree(String q) {
    // "Wenn 5 Stück 25 € kosten, wie viel kosten 8 Stück?"
    final dMatch = RegExp(
      r'wenn\s+(\d+(?:[.,]\d+)?)\s*(?:stück|teile|kg|m|liter)?\s*(?:kosten\s*)?(\d+(?:[.,]\d+)?)\s*(?:€|euro)?(?:\s*kosten)?.*?(?:wie\s+viel|was).*?(\d+(?:[.,]\d+)?)',
      caseSensitive: false,
    ).firstMatch(q);

    if (dMatch != null) {
      final n1 = _parseDouble(dMatch.group(1)!);
      final v1 = _parseDouble(dMatch.group(2)!);
      final n2 = _parseDouble(dMatch.group(3)!);

      if (n1 != null && v1 != null && n2 != null && n1 > 0) {
        final perUnit = v1 / n1;
        final result = perUnit * n2;
        return '🧮 **Dreisatz-Berechnung:**\n\n'
            '1. **Gegeben:** $n1 Einheiten entsprechen ${_formatNum(v1)}\n'
            '2. **Wert pro Einheit (1):** ${_formatNum(v1)} / $n1 = ${_formatNum(perUnit)}\n'
            '3. **Gesuchter Wert ($n2 Einheiten):** $n2 · ${_formatNum(perUnit)} = ${_formatNum(result)}\n\n'
            '👉 **Endergebnis: ${_formatNum(result)}**';
      }
    }
    return null;
  }

  // ===========================================================================
  // 4. Geometry Problems
  // ===========================================================================
  String? _tryGeometryProblems(String q) {
    // Kreis: "Kreis r=5" or "Kreis radius 5" or "Kreis d=10"
    final kreisMatch = RegExp(r'kreis.*?(?:r|radius)\s*(?:=|:|\s)\s*(\d+(?:[.,]\d+)?)', caseSensitive: false).firstMatch(q);
    if (kreisMatch != null) {
      final r = _parseDouble(kreisMatch.group(1)!);
      if (r != null) {
        final a = pi * r * r;
        final u = 2 * pi * r;
        return '🧮 **Kreisberechnung:**\n\n'
            '• **Radius (r):** ${_formatNum(r)}\n'
            '• **Durchmesser (d):** ${_formatNum(2 * r)}\n'
            '• **Flächeninhalt (A = π · r²):** π · ${_formatNum(r)}² = **${_formatNum(a)}**\n'
            '• **Umfang (U = 2 · π · r):** 2 · π · ${_formatNum(r)} = **${_formatNum(u)}**';
      }
    }

    // Rechteck: "Rechteck 12 x 8" or "Rechteck a=12, b=8"
    final rechteckMatch = RegExp(r'rechteck.*?(?:a\s*=\s*)?(\d+(?:[.,]\d+)?)\s*(?:x|\*|\bmal\b|,|und|b\s*=\s*)\s*(?:b\s*=\s*)?(\d+(?:[.,]\d+)?)', caseSensitive: false).firstMatch(q);
    if (rechteckMatch != null) {
      final a = _parseDouble(rechteckMatch.group(1)!);
      final b = _parseDouble(rechteckMatch.group(2)!);
      if (a != null && b != null) {
        final flaeche = a * b;
        final umfang = 2 * (a + b);
        final diag = sqrt(a * a + b * b);
        return '🧮 **Rechteck-Berechnung:**\n\n'
            '• **Seiten:** a = ${_formatNum(a)}, b = ${_formatNum(b)}\n'
            '• **Flächeninhalt (A = a · b):** ${_formatNum(a)} · ${_formatNum(b)} = **${_formatNum(flaeche)}**\n'
            '• **Umfang (U = 2 · (a + b)):** 2 · (${_formatNum(a)} + ${_formatNum(b)}) = **${_formatNum(umfang)}**\n'
            '• **Diagonale (d = √(a² + b²)):** **${_formatNum(diag)}**';
      }
    }

    // Pythagoras: "Pythagoras a=3, b=4" or "Pythagoras 3, 4"
    final pythMatch = RegExp(r'(?:pythagoras|dreieck rechtwinklig).*?(\d+(?:[.,]\d+)?).*?(\d+(?:[.,]\d+)?)', caseSensitive: false).firstMatch(q);
    if (pythMatch != null) {
      final a = _parseDouble(pythMatch.group(1)!);
      final b = _parseDouble(pythMatch.group(2)!);
      if (a != null && b != null) {
        final c = sqrt(a * a + b * b);
        return '🧮 **Satz des Pythagoras (Hypotenuse):**\n\n'
            '• **Kathete a:** ${_formatNum(a)}\n'
            '• **Kathete b:** ${_formatNum(b)}\n'
            '• **Formel:** `c² = a² + b²` ➔ `c = √(a² + b²)`\n'
            '• **Rechnung:** √(${_formatNum(a)}² + ${_formatNum(b)}²) = √(${_formatNum(a * a)} + ${_formatNum(b * b)}) = √(${_formatNum(a * a + b * b)})\n\n'
            '👉 **Hypotenuse c: ${_formatNum(c)}**';
      }
    }

    return null;
  }

  // ===========================================================================
  // 5. Linear Equations (ax + b = c)
  // ===========================================================================
  String? _tryLinearEquation(String q) {
    if (!q.contains('=') || !q.toLowerCase().contains('x')) return null;

    final sanitized = q.replaceAll(' ', '');
    // Match "2x+6=18" or "3x-5=10" or "4x=20"
    final match = RegExp(r'^([+\-]?\d*(?:[.,]\d+)?)x([+\-]\d+(?:[.,]\d+)?)?=([+\-]?\d+(?:[.,]\d+)?)$', caseSensitive: false).firstMatch(sanitized);
    if (match != null) {
      String aStr = match.group(1) ?? '1';
      if (aStr.isEmpty || aStr == '+') aStr = '1';
      if (aStr == '-') aStr = '-1';
      final a = _parseDouble(aStr) ?? 1.0;

      final bStr = match.group(2);
      final b = bStr != null ? (_parseDouble(bStr) ?? 0.0) : 0.0;

      final c = _parseDouble(match.group(3)!) ?? 0.0;

      if (a != 0) {
        final rightAfterB = c - b;
        final x = rightAfterB / a;

        return '🧮 **Lineare Gleichung lösen:**\n\n'
            '• **Gleichung:** `$q`\n'
            '1. Terme ohne x auf die rechte Seite bringen:\n'
            '   `$a · x = ${_formatNum(c)} ${b >= 0 ? "- ${_formatNum(b)}" : "+ ${_formatNum(-b)}"} = ${_formatNum(rightAfterB)}`\n'
            '2. Durch den Koeffizienten vor x (${_formatNum(a)}) teilen:\n'
            '   `x = ${_formatNum(rightAfterB)} / ${_formatNum(a)}`\n\n'
            '👉 **Lösung: x = ${_formatNum(x)}**';
      }
    }
    return null;
  }

  // ===========================================================================
  // 6. Formula Completion & Laws
  // ===========================================================================
  String? _tryFormulaCompletion(String q) {
    final lower = q.toLowerCase().replaceAll(' ', '');

    if (lower == 'a^2+b^2' || lower == 'a²+b²' || lower == 'a^2+b^2=') {
      return '🧮 **Satz des Pythagoras:**\n\n'
          '• **Vervollständigung:** `a² + b² = c²`\n'
          '• **Bedeutung:** In einem rechtwinkligen Dreieck ist die Summe der Flächen der Kathetenquadrate (a² und b²) gleich der Fläche des Hypotenusenquadrats (c²).\n'
          '• **Umstellung nach c:** `c = √(a² + b²)`';
    }

    if (lower == '(a+b)^2' || lower == '(a+b)²') {
      return '🧮 **1. Binomische Formel (Plus-Formel):**\n\n'
          '• **Ausmultipliziert:** `(a + b)² = a² + 2ab + b²`\n'
          '• **Erklärung:** Quadrat des ersten Glieds (a²) plus doppeltes Produkt beider Glieder (2ab) plus Quadrat des zweiten Glieds (b²).';
    }

    if (lower == '(a-b)^2' || lower == '(a-b)²') {
      return '🧮 **2. Binomische Formel (Minus-Formel):**\n\n'
          '• **Ausmultipliziert:** `(a - b)² = a² - 2ab + b²`\n'
          '• **Erklärung:** Quadrat des ersten Glieds (a²) minus doppeltes Produkt (2ab) plus Quadrat des zweiten Glieds (b²).';
    }

    if (lower == '(a+b)(a-b)' || lower == '(a-b)(a+b)') {
      return '🧮 **3. Binomische Formel (Plus-Minus-Formel):**\n\n'
          '• **Ausmultipliziert:** `(a + b) · (a - b) = a² - b²`\n'
          '• **Erklärung:** Die gemischten Terme (+ab und -ab) heben sich auf, übrig bleibt die Differenz der beiden Quadrate.';
    }

    if (lower.startsWith('u=r') || lower == 'u=r*i' || lower == 'u/i') {
      return '🧮 **Ohmsches Gesetz (Elektrotechnik):**\n\n'
          '• **Formel:** `U = R · I`\n'
          '• **Größen:**\n'
          '  - `U` = Elektrische Spannung (in Volt, V)\n'
          '  - `R` = Elektrischer Widerstand (in Ohm, Ω)\n'
          '  - `I` = Elektrische Stromstärke (in Ampere, A)\n'
          '• **Umstellungen:** `R = U / I` | `I = U / R`';
    }

    if (lower.startsWith('p=u') || lower == 'p=u*i') {
      return '🧮 **Elektrische Leistung:**\n\n'
          '• **Formel:** `P = U · I`\n'
          '• **Größen:** `P` = Leistung in Watt (W), `U` = Spannung in Volt (V), `I` = Stromstärke in Ampere (A).\n'
          '• **Mit Widerstand:** `P = I² · R` bzw. `P = U² / R`';
    }

    if (lower.startsWith('f=m') || lower == 'f=m*a') {
      return '🧮 **2. Newtonsches Gesetz (Grundgesetz der Mechanik):**\n\n'
          '• **Formel:** `F = m · a`\n'
          '• **Größen:** `F` = Kraft (in Newton, N), `m` = Masse (in kg), `a` = Beschleunigung (in m/s²).';
    }

    if (lower.startsWith('e=m') || lower == 'e=mc^2' || lower == 'e=mc²') {
      return '🧮 **Einsteins Masse-Energie-Äquivalenz:**\n\n'
          '• **Formel:** `E = m · c²`\n'
          '• **Größen:** `E` = Energie (Joule), `m` = Masse (kg), `c` = Lichtgeschwindigkeit (≈ 299.792.458 m/s).';
    }

    if (lower.startsWith('v=s') || lower == 'v=s/t') {
      return '🧮 **Geschwindigkeit:**\n\n'
          '• **Formel:** `v = s / t`\n'
          '• **Größen:** `v` = Geschwindigkeit (m/s oder km/h), `s` = Strecke (Meter oder km), `t` = Zeit (Sekunden oder Stunden).\n'
          '• **Umstellungen:** `s = v · t` | `t = s / v`';
    }

    return null;
  }

  // ===========================================================================
  // 7. General Arithmetic Evaluator (Shunting-Yard & Stack Evaluation)
  // ===========================================================================
  String? _tryArithmeticEvaluation(String q) {
    try {
      // Normalize input: replace commas with dots, remove German question words if any
      String expr = q.replaceAll(',', '.');
      expr = expr.replaceAll('×', '*').replaceAll('·', '*');
      expr = expr.replaceAll('÷', '/').replaceAll(':', '/');

      // Check if it has any arithmetic operator or sqrt
      if (!RegExp(r'[+\-*/^]|sqrt|pi', caseSensitive: false).hasMatch(expr)) {
        return null;
      }

      // Handle functions like sqrt(144) -> 12
      expr = expr.replaceAllMapped(RegExp(r'sqrt\s*\(\s*(\d+(?:\.\d+)?)\s*\)', caseSensitive: false), (m) {
        final val = double.tryParse(m.group(1)!);
        return val != null ? sqrt(val).toString() : m.group(0)!;
      });
      expr = expr.replaceAllMapped(RegExp(r'wurzel\s+aus\s+(\d+(?:\.\d+)?)', caseSensitive: false), (m) {
        final val = double.tryParse(m.group(1)!);
        return val != null ? sqrt(val).toString() : m.group(0)!;
      });

      expr = expr.replaceAll(RegExp(r'pi|π', caseSensitive: false), pi.toString());

      // Strip non-math characters
      final sanitized = expr.replaceAll(RegExp(r'[^0-9+\-*/^().]'), '');
      if (sanitized.isEmpty) return null;

      final val = _evaluateExpression(sanitized);
      if (val != null) {
        return '🧮 **Berechnungsergebnis:**\n\n'
            '• **Eingabe:** `$q`\n'
            '• **Rechenausdruck:** `$sanitized`\n\n'
            '👉 **Endergebnis: ${_formatNum(val)}**';
      }
    } catch (_) {}
    return null;
  }

  double? _evaluateExpression(String expr) {
    try {
      final tokens = _tokenize(expr);
      if (tokens.isEmpty) return null;
      final rpn = _toRpn(tokens);
      return _evalRpn(rpn);
    } catch (_) {
      return null;
    }
  }

  List<String> _tokenize(String expr) {
    final tokens = <String>[];
    int i = 0;
    while (i < expr.length) {
      final ch = expr[i];
      if (ch == ' ') {
        i++;
        continue;
      }
      if ('+-*/^()'.contains(ch)) {
        // Handle unary minus
        if (ch == '-' && (tokens.isEmpty || tokens.last == '(' || '+-*/^'.contains(tokens.last))) {
          // Unary minus: read number
          i++;
          final start = i;
          while (i < expr.length && (RegExp(r'[0-9.]').hasMatch(expr[i]))) {
            i++;
          }
          final numStr = expr.substring(start, i);
          tokens.add('-$numStr');
          continue;
        }
        tokens.add(ch);
        i++;
      } else if (RegExp(r'[0-9.]').hasMatch(ch)) {
        final start = i;
        while (i < expr.length && RegExp(r'[0-9.]').hasMatch(expr[i])) {
          i++;
        }
        tokens.add(expr.substring(start, i));
      } else {
        i++;
      }
    }
    return tokens;
  }

  List<String> _toRpn(List<String> tokens) {
    final output = <String>[];
    final opStack = <String>[];

    final precedence = {'+': 1, '-': 1, '*': 2, '/': 2, '^': 3};

    for (final token in tokens) {
      if (double.tryParse(token) != null) {
        output.add(token);
      } else if ('+-*/^'.contains(token)) {
        while (opStack.isNotEmpty &&
            opStack.last != '(' &&
            (precedence[opStack.last] ?? 0) >= (precedence[token] ?? 0)) {
          output.add(opStack.removeLast());
        }
        opStack.add(token);
      } else if (token == '(') {
        opStack.add(token);
      } else if (token == ')') {
        while (opStack.isNotEmpty && opStack.last != '(') {
          output.add(opStack.removeLast());
        }
        if (opStack.isNotEmpty && opStack.last == '(') {
          opStack.removeLast();
        }
      }
    }

    while (opStack.isNotEmpty) {
      output.add(opStack.removeLast());
    }

    return output;
  }

  double? _evalRpn(List<String> rpn) {
    final stack = <double>[];

    for (final token in rpn) {
      final num = double.tryParse(token);
      if (num != null) {
        stack.add(num);
      } else if (stack.length >= 2) {
        final b = stack.removeLast();
        final a = stack.removeLast();
        switch (token) {
          case '+':
            stack.add(a + b);
            break;
          case '-':
            stack.add(a - b);
            break;
          case '*':
            stack.add(a * b);
            break;
          case '/':
            if (b == 0) return null;
            stack.add(a / b);
            break;
          case '^':
            stack.add(pow(a, b).toDouble());
            break;
        }
      }
    }

    return stack.isNotEmpty ? stack.single : null;
  }

  double? _parseDouble(String str) {
    final clean = str.trim().replaceAll(',', '.');
    return double.tryParse(clean);
  }

  String _formatNum(num val) {
    if (val.isInfinite || val.isNaN) return 'Ungültig';
    if (val == val.roundToDouble()) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(2).replaceAll('.', ',');
  }
}
