import '../../models/plugin.dart';
import '../../models/tool.dart';
import '../../models/tool_result.dart';
import '../../services/tool_registry.dart';
import '../../services/tool_executor.dart';
import '../../services/ssh_service.dart';

class TermuxPlugin {
  static const String id = 'termux';
  static const String name = 'Termux';
  static const String description =
      'Execute commands via Termux SSH (local/network)';

  static Plugin get plugin => Plugin(
        id: id,
        name: name,
        description: description,
        category: PluginCategory.execution,
        version: '2.0.0',
        author: 'Schatz',
        requiredPermissions: ['shell', 'storage'],
      );

  static List<Tool> get tools => [
        Tool(
          id: 'execute',
          name: 'Execute Command',
          description: 'Execute a shell command via SSH',
          pluginId: id,
          type: ToolType.execute,
          parameters: {
            'command': ToolParameter(
                name: 'command',
                description: 'Command to execute',
                type: ToolParameterType.string,
                required: true),
            'timeout': ToolParameter(
                name: 'timeout',
                description: 'Timeout in seconds',
                type: ToolParameterType.int),
          },
          requiresAuth: false,
        ),
        Tool(
          id: 'install',
          name: 'Install Package',
          description: 'Install a package via pkg/apt/pip/npm',
          pluginId: id,
          type: ToolType.execute,
          parameters: {
            'package': ToolParameter(
                name: 'package',
                description: 'Package name',
                type: ToolParameterType.string,
                required: true),
            'manager': ToolParameter(
                name: 'manager',
                description: 'Package manager',
                type: ToolParameterType.string,
                options: ['pkg', 'apt', 'pip', 'npm']),
          },
          requiresAuth: false,
        ),
        Tool(
          id: 'service.start',
          name: 'Start Service',
          description: 'Start a background service',
          pluginId: id,
          type: ToolType.execute,
          parameters: {
            'service': ToolParameter(
                name: 'service',
                description: 'Service name',
                type: ToolParameterType.string,
                required: true),
          },
          requiresAuth: false,
        ),
        Tool(
          id: 'service.stop',
          name: 'Stop Service',
          description: 'Stop a background service',
          pluginId: id,
          type: ToolType.execute,
          parameters: {
            'service': ToolParameter(
                name: 'service',
                description: 'Service name',
                type: ToolParameterType.string,
                required: true),
          },
          requiresAuth: false,
        ),
        Tool(
          id: 'service.status',
          name: 'Service Status',
          description: 'Check service status',
          pluginId: id,
          type: ToolType.read,
          parameters: {
            'service': ToolParameter(
                name: 'service',
                description: 'Service name',
                type: ToolParameterType.string,
                required: true),
          },
          requiresAuth: false,
        ),
        Tool(
          id: 'file.read',
          name: 'Read File',
          description: 'Read file contents',
          pluginId: id,
          type: ToolType.read,
          parameters: {
            'path': ToolParameter(
                name: 'path',
                description: 'File path',
                type: ToolParameterType.string,
                required: true),
          },
          requiresAuth: false,
        ),
        Tool(
          id: 'file.write',
          name: 'Write File',
          description: 'Write content to a file',
          pluginId: id,
          type: ToolType.write,
          parameters: {
            'path': ToolParameter(
                name: 'path',
                description: 'File path',
                type: ToolParameterType.string,
                required: true),
            'content': ToolParameter(
                name: 'content',
                description: 'File content',
                type: ToolParameterType.string,
                required: true),
          },
          requiresAuth: false,
        ),
        Tool(
          id: 'file.exists',
          name: 'Check File Exists',
          description: 'Check if a file or directory exists',
          pluginId: id,
          type: ToolType.read,
          parameters: {
            'path': ToolParameter(
                name: 'path',
                description: 'File path',
                type: ToolParameterType.string,
                required: true),
          },
          requiresAuth: false,
        ),
        Tool(
          id: 'list',
          name: 'List Directory',
          description: 'List directory contents',
          pluginId: id,
          type: ToolType.read,
          parameters: {
            'path': ToolParameter(
                name: 'path',
                description: 'Directory path',
                type: ToolParameterType.string),
          },
          requiresAuth: false,
        ),
      ];

  static void register() {
    final registry = ToolRegistry();
    registry.registerPluginTools(id, tools);

    final executor = ToolExecutorService();
    executor.registerExecutor(id, 'execute', _executeCommand);
    executor.registerExecutor(id, 'install', _installPackage);
    executor.registerExecutor(id, 'service.start', _startService);
    executor.registerExecutor(id, 'service.stop', _stopService);
    executor.registerExecutor(id, 'service.status', _serviceStatus);
    executor.registerExecutor(id, 'file.read', _readFile);
    executor.registerExecutor(id, 'file.write', _writeFile);
    executor.registerExecutor(id, 'file.exists', _fileExists);
    executor.registerExecutor(id, 'list', _listDirectory);

    SSHService.instance.autoConnect();
  }

  static final _sanitizePattern = RegExp(r'[`$;|&<>!#{}()\[\]\\]');

  static String _sanitizeInput(String input) {
    return input
        .replaceAll(_sanitizePattern, '')
        .replaceAll('"', '')
        .replaceAll("'", '');
  }

  static Future<SSHResult> _exec(String command,
      {int timeoutSeconds = 30}) async {
    final ssh = SSHService.instance;

    if (!ssh.isConnected) {
      await ssh.autoConnect();
    }

    return await ssh.executeWithRetry(
      command,
      timeout: Duration(seconds: timeoutSeconds),
    );
  }

  static Future<bool> checkConnection() async {
    return await SSHService.instance.testConnection();
  }

  static Future<ToolResult> _executeCommand(Map<String, dynamic> params) async {
    try {
      final command = params['command'];
      final timeout = params['timeout'] ?? 30;

      final result = await _exec(command, timeoutSeconds: timeout);

      if (result.isSuccess) {
        return ToolResult.success(
          result.stdout.isNotEmpty
              ? result.stdout
              : 'Command executed successfully',
          data: {
            'exitCode': result.exitCode,
            'stdout': result.stdout,
            'stderr': result.stderr,
            'duration': result.duration.inMilliseconds,
          },
        );
      } else {
        return ToolResult.failure(
          'Command failed (exit code ${result.exitCode}): ${result.stderr}',
        );
      }
    } catch (e) {
      return ToolResult.failure('Failed to execute command: $e');
    }
  }

  static Future<ToolResult> _installPackage(Map<String, dynamic> params) async {
    try {
      final package = _sanitizeInput(params['package']);
      final manager = params['manager'] ?? 'pkg';

      String command;
      switch (manager) {
        case 'apt':
          command = 'apt update && apt install -y $package';
          break;
        case 'pip':
          command = 'pip install $package';
          break;
        case 'npm':
          command = 'npm install -g $package';
          break;
        default:
          command = 'pkg install -y $package';
      }

      final result = await _exec(command, timeoutSeconds: 120);

      if (result.isSuccess) {
        return ToolResult.success(
          'Package $package installed successfully',
          data: {'stdout': result.stdout, 'stderr': result.stderr},
        );
      } else {
        return ToolResult.failure(
            'Failed to install package: ${result.stderr}');
      }
    } catch (e) {
      return ToolResult.failure('Failed to install package: $e');
    }
  }

  static Future<ToolResult> _startService(Map<String, dynamic> params) async {
    try {
      final service = _sanitizeInput(params['service']);
      final result = await _exec('sv start $service');

      if (result.isSuccess) {
        return ToolResult.success('Service $service started');
      } else {
        return ToolResult.failure('Failed to start service: ${result.stderr}');
      }
    } catch (e) {
      return ToolResult.failure('Failed to start service: $e');
    }
  }

  static Future<ToolResult> _stopService(Map<String, dynamic> params) async {
    try {
      final service = _sanitizeInput(params['service']);
      final result = await _exec('sv stop $service');

      if (result.isSuccess) {
        return ToolResult.success('Service $service stopped');
      } else {
        return ToolResult.failure('Failed to stop service: ${result.stderr}');
      }
    } catch (e) {
      return ToolResult.failure('Failed to stop service: $e');
    }
  }

  static Future<ToolResult> _serviceStatus(Map<String, dynamic> params) async {
    try {
      final service = _sanitizeInput(params['service']);
      final result = await _exec('sv status $service');

      return ToolResult.success(
        'Service status: ${result.stdout.trim()}',
        data: {'status': result.stdout.trim()},
      );
    } catch (e) {
      return ToolResult.failure('Failed to get service status: $e');
    }
  }

  static Future<ToolResult> _readFile(Map<String, dynamic> params) async {
    try {
      final path = params['path'];
      if (!_isSafePath(path)) {
        return ToolResult.failure(
          'Path traversal is not allowed: $path',
        );
      }
      final escapedPath = path.replaceAll("'", "'\\''");
      final result = await _exec("cat '$escapedPath'");

      if (result.isSuccess) {
        return ToolResult.success(
          result.stdout,
          data: {'path': path, 'size': result.stdout.length},
        );
      } else {
        return ToolResult.failure('Failed to read file: ${result.stderr}');
      }
    } catch (e) {
      return ToolResult.failure('Failed to read file: $e');
    }
  }

  static Future<ToolResult> _writeFile(Map<String, dynamic> params) async {
    try {
      final path = params['path'];
      final content = params['content'];

      if (!_isSafePath(path)) {
        return ToolResult.failure(
          'Path traversal is not allowed: $path',
        );
      }

      final escapedPath = path.replaceAll("'", "'\\''");
      final escapedContent = content.replaceAll("'", "'\\''");
      final result =
          await _exec("cat > '$escapedPath' << 'EOF'\n$escapedContent\nEOF");

      if (result.isSuccess) {
        return ToolResult.success(
          'File written successfully',
          data: {'path': path},
        );
      } else {
        return ToolResult.failure('Failed to write file: ${result.stderr}');
      }
    } catch (e) {
      return ToolResult.failure('Failed to write file: $e');
    }
  }

  static Future<ToolResult> _fileExists(Map<String, dynamic> params) async {
    try {
      final path = params['path'];
      if (!_isSafePath(path)) {
        return ToolResult.failure(
          'Path traversal is not allowed: $path',
        );
      }
      final escapedPath = path.replaceAll("'", "'\\''");
      final result = await _exec(
          "test -e '$escapedPath' && echo 'exists' || echo 'not_exists'");

      final exists = result.stdout.trim() == 'exists';

      return ToolResult.success(
        exists ? 'File exists' : 'File does not exist',
        data: {'path': path, 'exists': exists},
      );
    } catch (e) {
      return ToolResult.failure('Failed to check file: $e');
    }
  }

  static Future<ToolResult> _listDirectory(Map<String, dynamic> params) async {
    try {
      final path = params['path'] ?? '.';
      if (!_isSafePath(path)) {
        return ToolResult.failure(
          'Path traversal is not allowed: $path',
        );
      }
      final escapedPath = path.replaceAll("'", "'\\''");
      final result = await _exec("ls -la '$escapedPath'");

      if (result.isSuccess) {
        final items = result.stdout
            .trim()
            .split('\n')
            .skip(1)
            .map((line) {
              final parts = line.split(RegExp(r'\s+'));
              if (parts.length >= 9) {
                return {
                  'permissions': parts[0],
                  'name': parts.sublist(8).join(' '),
                  'type': parts[0].startsWith('d') ? 'directory' : 'file',
                };
              }
              return null;
            })
            .where((item) => item != null)
            .toList();

        return ToolResult.success(
          'Found ${items.length} items',
          data: {'path': path, 'items': items},
        );
      } else {
        return ToolResult.failure('Failed to list directory: ${result.stderr}');
      }
    } catch (e) {
      return ToolResult.failure('Failed to list directory: $e');
    }
  }

  static bool _isSafePath(String path) {
    final normalized = path.replaceAll(RegExp(r'\\|/'), '/');
    return !normalized.contains('..');
  }
}
