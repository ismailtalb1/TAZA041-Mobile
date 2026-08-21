import '../models.dart';

class CatalogSearchMatch {
  const CatalogSearchMatch({
    required this.product,
    required this.score,
    required this.fuzzy,
  });

  final Product product;
  final double score;
  final bool fuzzy;
}

final class CatalogSearch {
  static String normalize(String? value) {
    var text = (value ?? '').toLowerCase();
    const replacements = <String, String>{
      'أ': 'ا',
      'إ': 'ا',
      'آ': 'ا',
      'ى': 'ي',
      'ة': 'ه',
      'ؤ': 'و',
      'ئ': 'ي',
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
    };
    for (final entry in replacements.entries) {
      text = text.replaceAll(entry.key, entry.value);
    }
    return text
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
        .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static List<CatalogSearchMatch> rank(
    Iterable<Product> products,
    String rawQuery,
  ) {
    final query = normalize(rawQuery);
    if (query.isEmpty) {
      return products
          .map((product) =>
              CatalogSearchMatch(product: product, score: 1, fuzzy: false))
          .toList(growable: false);
    }

    final matches = products
        .map((product) {
          final searchText = _searchText(product);
          final score = _score(product, query);
          return CatalogSearchMatch(
            product: product,
            score: score,
            fuzzy: !searchText.contains(query),
          );
        })
        .where((match) => match.score >= .54)
        .toList();
    matches.sort((left, right) => right.score.compareTo(left.score));
    return matches;
  }

  static String? bestCorrection(
    List<CatalogSearchMatch> matches,
    String rawQuery, {
    required bool arabic,
  }) {
    if (matches.isEmpty || !matches.first.fuzzy) return null;
    return arabic ? matches.first.product.nameAr : matches.first.product.nameEn;
  }

  static double _score(Product product, String query) {
    final names = normalize('${product.nameAr} ${product.nameEn}');
    final descriptions =
        normalize('${product.descriptionAr} ${product.descriptionEn}');
    final nameScore = _scoreText(names, query);
    final descriptionScore = _scoreText(descriptions, query) * .6;
    return nameScore > descriptionScore ? nameScore : descriptionScore;
  }

  static String _searchText(Product product) => normalize(
        '${product.nameAr} ${product.nameEn} '
        '${product.descriptionAr} ${product.descriptionEn}',
      );

  static double _scoreText(String text, String query) {
    if (text.isEmpty || query.isEmpty) return 0;
    if (text == query) return 1;
    if (text.contains(query)) return .96;

    final needles = query.split(' ');
    final candidates = text.split(' ');
    var sum = 0.0;
    for (final needle in needles) {
      var best = 0.0;
      for (final candidate in candidates) {
        if (candidate == needle) {
          best = 1;
          break;
        }
        if (candidate.runes.length >= 3 &&
            needle.runes.length >= 3 &&
            (candidate.contains(needle) || needle.contains(candidate))) {
          if (best < .88) best = .88;
          continue;
        }
        final maxLength = candidate.runes.length > needle.runes.length
            ? candidate.runes.length
            : needle.runes.length;
        if (maxLength < 3) continue;
        final score = 1 - (_distance(needle, candidate) / maxLength);
        if (score > best) best = score;
      }
      sum += best;
    }
    return sum / needles.length;
  }

  static int _distance(String left, String right) {
    final a = left.runes.toList(growable: false);
    final b = right.runes.toList(growable: false);
    final row = List<int>.generate(b.length + 1, (index) => index);
    for (var i = 1; i <= a.length; i++) {
      var previous = row[0];
      row[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final saved = row[j];
        final deletion = row[j] + 1;
        final insertion = row[j - 1] + 1;
        final replacement = previous + (a[i - 1] == b[j - 1] ? 0 : 1);
        row[j] = [deletion, insertion, replacement]
            .reduce((smallest, value) => value < smallest ? value : smallest);
        previous = saved;
      }
    }
    return row[b.length];
  }
}
