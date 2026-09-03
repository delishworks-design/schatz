class ToolResult {
  final bool success;
  final String content;
  final Map<String, dynamic>? data;
  final String? error;
  final String? toolId;
  final Duration? executionTime;

  const ToolResult({
    required this.success,
    required this.content,
    this.data,
    this.error,
    this.toolId,
    this.executionTime,
  });

  factory ToolResult.success(String content,
      {Map<String, dynamic>? data, String? toolId, Duration? executionTime}) {
    return ToolResult(
      success: true,
      content: content,
      data: data,
      toolId: toolId,
      executionTime: executionTime,
    );
  }

  factory ToolResult.failure(String error, {String? toolId}) {
    return ToolResult(
      success: false,
      content: '',
      error: error,
      toolId: toolId,
    );
  }

  String get executionTimeText {
    if (executionTime == null) return '';
    if (executionTime!.inMilliseconds < 1000) {
      return '${executionTime!.inMilliseconds}ms';
    }
    return '${(executionTime!.inMilliseconds / 1000).toStringAsFixed(1)}s';
  }

  Map<String, dynamic> toJson() => {
        'success': success,
        'content': content,
        'data': data,
        'error': error,
        'toolId': toolId,
        'executionTimeMs': executionTime?.inMilliseconds,
      };

  factory ToolResult.fromJson(Map<String, dynamic> json) {
    return ToolResult(
      success: json['success'] ?? false,
      content: json['content'] ?? '',
      data: json['data'],
      error: json['error'],
      toolId: json['toolId'],
      executionTime: json['executionTimeMs'] != null
          ? Duration(milliseconds: json['executionTimeMs'])
          : null,
    );
  }
}
