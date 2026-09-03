class TokenEstimator {
  static int estimate(String text) {
    if (text.isEmpty) return 0;
    final words = text.split(RegExp(r'\s+'));
    return (words.length * 1.33).ceil();
  }

  static int estimateMessages(List<Map<String, String>> messages) {
    int total = 0;
    for (final message in messages) {
      total += estimate(message['content'] ?? '');
      total += 4; // Overhead per message
    }
    total += 2; // Reply priming
    return total;
  }
}
