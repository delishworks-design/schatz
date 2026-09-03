class ShellEscaper {
  ShellEscaper._();

  static final _shellMetacharRegex = RegExp(r'[`$;|&<>!#{}()\[\]\'"\\]');

  static String escapeShellArg(String input) {
    if (input.isEmpty) return "''";
    if (!_shellMetacharRegex.hasMatch(input)) return input;
    return "'${input.replaceAll("'", "'\\''")}'";
  }

  static String sanitizePackageName(String input) {
    return input.replaceAll(RegExp(r'[^a-zA-Z0-9._\-+]'), '');
  }

  static String sanitizeServiceName(String input) {
    return input.replaceAll(RegExp(r'[^a-zA-Z0-9._\-]'), '');
  }

  static String sanitizePath(String input) {
    final sanitized = input.replaceAll(RegExp(r'[`$;|&<>!#{}()\[\]\'"\\]'), '');
    if (sanitized.contains('..')) return sanitized.replaceAll('..', '');
    return sanitized;
  }
}
