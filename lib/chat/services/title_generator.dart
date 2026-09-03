class TitleGenerator {
  static Future<String?> generate(String firstMessage) async {
    try {
      final words = firstMessage.split(RegExp(r'\s+'));
      if (words.length <= 5) return firstMessage;
      return '${words.take(5).join(' ')}...';
    } catch (_) {
      return null;
    }
  }
}