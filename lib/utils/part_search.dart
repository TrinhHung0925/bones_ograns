import '../model/anatomy_part.dart';

const _accents = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

final Map<int, String> _fold = {
  for (final entry in _accents.entries)
    for (final rune in entry.value.runes) rune: entry.key,
};

/// Lower case without Vietnamese diacritics: "Xương Đùi" -> "xuong dui".
String foldVietnamese(String text) {
  final buffer = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    buffer.write(_fold[rune] ?? String.fromCharCode(rune));
  }
  return buffer.toString();
}

/// Accent-insensitive search over Vietnamese and English part names. Every
/// query word must appear in either name; exact and prefix matches rank first.
class PartSearchIndex {
  PartSearchIndex(Iterable<AnatomyPart> parts)
    : _entries = [for (final p in parts) _Entry(p, foldVietnamese(p.nameVi ?? ''), foldVietnamese(p.name))];

  final List<_Entry> _entries;

  List<AnatomyPart> search(String query) {
    final q = foldVietnamese(query).trim().replaceAll(RegExp(r'\s+'), ' ');
    if (q.isEmpty) return const [];
    final words = q.split(' ');
    final hits = <(int, _Entry)>[];
    for (final e in _entries) {
      if (!words.every((w) => e.vi.contains(w) || e.en.contains(w))) continue;
      hits.add((e.rank(q, words), e));
    }
    hits.sort((a, b) {
      final byRank = a.$1.compareTo(b.$1);
      if (byRank != 0) return byRank;
      final byLength = a.$2.shown.length.compareTo(b.$2.shown.length);
      if (byLength != 0) return byLength;
      return a.$2.shown.compareTo(b.$2.shown);
    });
    return [for (final hit in hits) hit.$2.part];
  }
}

class _Entry {
  _Entry(this.part, this.vi, this.en) : shown = vi.isEmpty ? en : vi;

  final AnatomyPart part;
  final String vi;
  final String en;
  final String shown;

  /// 0 exact name, 1 name starts with the query, 2 every word starts a word
  /// of a name, 3 anything else.
  int rank(String q, List<String> words) {
    if (vi == q || en == q) return 0;
    if (vi.startsWith(q) || en.startsWith(q)) return 1;
    bool startsWords(String name) {
      if (name.isEmpty) return false;
      final nameWords = name.split(RegExp(r'[\s\-(),]+'));
      return words.every((w) => nameWords.any((n) => n.startsWith(w)));
    }

    if (startsWords(vi) || startsWords(en)) return 2;
    return 3;
  }
}
