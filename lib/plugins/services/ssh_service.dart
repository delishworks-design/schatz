import 'dart:async';
import 'package:dartssh2/dartssh2.dart';
import '../../core/security/secure_storage.dart';

class SSHResult {
  final int exitCode;
  final String stdout;
  final String stderr;
  final Duration duration;

  const SSHResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.duration,
  });

  bool get isSuccess => exitCode == 0;
}

class SSHConfig {
  final String host;
  final int port;
  final String username;
  final String? password;

  const SSHConfig({
    required this.host,
    required this.port,
    required this.username,
    this.password,
  });

  Map<String, dynamic> toJson() => {
    'host': host,
    'port': port,
    'username': username,
    'password': password,
  };

  factory SSHConfig.fromJson(Map<String, dynamic> json) => SSHConfig(
    host: json['host'] ?? '127.0.0.1',
    port: json['port'] ?? 8022,
    username: json['username'] ?? 'u0_a361',
    password: json['password'] ?? '',
  );

  static const defaultConfig = SSHConfig(
    host: '127.0.0.1',
    port: 8022,
    username: 'u0_a361',
    password: '',
  );
}

class SSHService {
  static SSHService? _instance;
  static SSHService get instance => _instance ??= SSHService._();
  SSHService._();

  SSHClient? _client;
  SSHConfig? _config;
  bool _isConnected = false;
  bool _isConnecting = false;
  DateTime? _lastActivity;

  bool get isConnected => _isConnected && _client != null;
  SSHConfig? get config => _config;
  DateTime? get lastActivity => _lastActivity;

  Future<SSHConfig> loadConfig() async {
    final storage = SecureStorage();
    final host = await storage.read('ssh_host') ?? '127.0.0.1';
    final port = int.tryParse(await storage.read('ssh_port') ?? '8022') ?? 8022;
    final username = await storage.read('ssh_username') ?? 'u0_a361';
    final password = await storage.read('ssh_password') ?? '';
    
    return SSHConfig(
      host: host,
      port: port,
      username: username,
      password: password,
    );
  }

  Future<void> saveConfig(SSHConfig config) async {
    _config = config;
    final storage = SecureStorage();
    await storage.write('ssh_host', config.host);
    await storage.write('ssh_port', config.port.toString());
    await storage.write('ssh_username', config.username);
    if (config.password != null) {
      await storage.write('ssh_password', config.password!);
    }
  }

  Future<bool> connect({SSHConfig? config}) async {
    if (_isConnecting) return false;
    _isConnecting = true;
    try {
      await disconnect();
      
      _config = config ?? await loadConfig();
      
      final socket = await SSHSocket.connect(
        _config!.host,
        _config!.port,
        timeout: const Duration(seconds: 10),
      );

      _client = SSHClient(
        socket,
        username: _config!.username,
        onPasswordRequest: () => _config!.password ?? '',
      );

      _isConnected = true;
      _lastActivity = DateTime.now();
      
      return true;
    } catch (e) {
      _isConnected = false;
      _client = null;
      return false;
    } finally {
      _isConnecting = false;
    }
  }

  Future<void> disconnect() async {
    try {
      _client?.close();
    } catch (_) {}
    _client = null;
    _isConnected = false;
  }

  Future<SSHResult> execute(String command, {Duration? timeout}) async {
    if (!isConnected) {
      final connected = await connect();
      if (!connected) {
        return const SSHResult(
          exitCode: -1,
          stdout: '',
          stderr: 'Failed to connect to SSH server',
          duration: Duration.zero,
        );
      }
    }

    final stopwatch = Stopwatch()..start();
    
    try {
      final session = await _client!.execute(command);
      
      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();
      
      final stdoutSub = session.stdout.listen((data) {
        stdoutBuffer.write(String.fromCharCodes(data));
      });
      
      final stderrSub = session.stderr.listen((data) {
        stderrBuffer.write(String.fromCharCodes(data));
      });
      
      final effectiveTimeout = timeout ?? const Duration(seconds: 30);
      await session.done.timeout(
        effectiveTimeout,
        onTimeout: () async {
          await stdoutSub.cancel();
          await stderrSub.cancel();
          try { session.close(); } catch (_) {}
        },
      );
      
      await stdoutSub.cancel();
      await stderrSub.cancel();
      
      stopwatch.stop();
      _lastActivity = DateTime.now();
      
      return SSHResult(
        exitCode: 0,
        stdout: stdoutBuffer.toString(),
        stderr: stderrBuffer.toString(),
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      
      if (e is TimeoutException) {
        return SSHResult(
          exitCode: -1,
          stdout: '',
          stderr: 'Command timed out',
          duration: stopwatch.elapsed,
        );
      }
      
      _isConnected = false;
      
      return SSHResult(
        exitCode: -1,
        stdout: '',
        stderr: 'SSH error: $e',
        duration: stopwatch.elapsed,
      );
    }
  }

  Future<SSHResult> executeWithRetry(String command, {Duration? timeout, int maxRetries = 2}) async {
    SSHResult? lastResult;
    for (int i = 0; i <= maxRetries; i++) {
      lastResult = await execute(command, timeout: timeout);
      if (lastResult.isSuccess || i == maxRetries) {
        return lastResult;
      }
      await connect();
    }
    return lastResult!;
  }

  Future<bool> testConnection({SSHConfig? config}) async {
    try {
      await connect(config: config);
      final result = await execute('echo "connection_test"', timeout: const Duration(seconds: 5));
      return result.isSuccess && result.stdout.contains('connection_test');
    } catch (_) {
      return false;
    }
  }

  Future<void> dispose() async {
    await disconnect();
    _config = null;
    _instance = null;
  }

  Future<bool> autoConnect() async {
    try {
      final config = await loadConfig();
      return await connect(config: config);
    } catch (_) {
      return false;
    }
  }
}
