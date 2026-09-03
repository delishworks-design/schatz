import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../models/plugin.dart';
import '../services/plugin_service.dart';
import '../services/ssh_service.dart';

class PluginSettingsScreen extends StatefulWidget {
  final String pluginId;

  const PluginSettingsScreen({super.key, required this.pluginId});

  @override
  State<PluginSettingsScreen> createState() => _PluginSettingsScreenState();
}

class _PluginSettingsScreenState extends State<PluginSettingsScreen> {
  final PluginService _pluginService = PluginService();
  Plugin? _plugin;
  bool _isLoading = true;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _obscureFields = {};

  @override
  void initState() {
    super.initState();
    _loadPlugin();
  }

  Future<void> _loadPlugin() async {
    final plugins = await _pluginService.getInstalledPlugins();
    final plugin = plugins.where((p) => p.id == widget.pluginId).firstOrNull;

    if (!mounted) return;
    if (plugin != null) {
      setState(() {
        _plugin = plugin;
        _isLoading = false;
      });
      _initControllers();
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _initControllers() {
    final settings = _getSettingsForPlugin();
    for (final setting in settings) {
      final value =
          _plugin?.settings[setting['key']] ?? setting['defaultValue'] ?? '';
      _controllers[setting['key']] =
          TextEditingController(text: value.toString());
      if (setting['type'] == 'password') {
        _obscureFields[setting['key']] = true;
      }
    }
  }

  List<Map<String, dynamic>> _getSettingsForPlugin() {
    switch (widget.pluginId) {
      case 'github':
        return [
          {
            'key': 'token',
            'label': 'Personal Access Token',
            'type': 'password',
            'required': true
          },
          {
            'key': 'default_owner',
            'label': 'Default Owner',
            'type': 'text',
            'required': false
          },
        ];
      case 'stripe':
        return [
          {
            'key': 'secret_key',
            'label': 'Secret Key',
            'type': 'password',
            'required': true
          },
          {
            'key': 'publishable_key',
            'label': 'Publishable Key',
            'type': 'password',
            'required': false
          },
        ];
      case 'supabase':
        return [
          {
            'key': 'url',
            'label': 'Project URL',
            'type': 'text',
            'required': true
          },
          {
            'key': 'anon_key',
            'label': 'Anonymous Key',
            'type': 'password',
            'required': true
          },
        ];
      case 'vercel':
        return [
          {
            'key': 'token',
            'label': 'API Token',
            'type': 'password',
            'required': true
          },
        ];
      case 'netlify':
        return [
          {
            'key': 'token',
            'label': 'Personal Access Token',
            'type': 'password',
            'required': true
          },
        ];
      case 'railway':
        return [
          {
            'key': 'token',
            'label': 'API Token',
            'type': 'password',
            'required': true
          },
        ];
      case 'firebase':
        return [
          {
            'key': 'project_id',
            'label': 'Project ID',
            'type': 'text',
            'required': true
          },
          {
            'key': 'service_account_key',
            'label': 'Service Account Key (JSON)',
            'type': 'password',
            'required': true
          },
        ];
      case 'cloudflare':
        return [
          {
            'key': 'api_token',
            'label': 'API Token',
            'type': 'password',
            'required': true
          },
          {
            'key': 'zone_id',
            'label': 'Zone ID',
            'type': 'text',
            'required': false
          },
        ];
      case 'termux':
        return [
          {
            'key': 'ssh_host',
            'label': 'SSH Host',
            'type': 'text',
            'defaultValue': '127.0.0.1'
          },
          {
            'key': 'ssh_port',
            'label': 'SSH Port',
            'type': 'number',
            'defaultValue': '8022'
          },
          {
            'key': 'ssh_username',
            'label': 'SSH Username',
            'type': 'text',
            'defaultValue': 'u0_a361'
          },
          {
            'key': 'ssh_password',
            'label': 'SSH Password',
            'type': 'password',
            'defaultValue': '111'
          },
        ];
      default:
        return [
          {
            'key': 'api_key',
            'label': 'API Key',
            'type': 'password',
            'required': true
          },
        ];
    }
  }

  Future<void> _saveSettings() async {
    if (_plugin == null) return;

    final settings = <String, dynamic>{};
    for (final entry in _controllers.entries) {
      settings[entry.key] = entry.value.text;
    }

    await _pluginService.updatePluginSettings(_plugin!.id, settings);

    if (widget.pluginId == 'termux') {
      final config = SSHConfig(
        host: _controllers['ssh_host']?.text ?? '127.0.0.1',
        port: int.tryParse(_controllers['ssh_port']?.text ?? '8022') ?? 8022,
        username: _controllers['ssh_username']?.text ?? 'u0_a361',
        password: _controllers['ssh_password']?.text ?? '111',
      );
      await SSHService.instance.saveConfig(config);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('${_plugin?.name ?? 'Plugin'} Settings'),
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text('Save'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildPluginInfo(),
                const SizedBox(height: 24),
                _buildSettingsSection(),
                const SizedBox(height: 24),
                _buildDangerZone(),
              ],
            ),
    );
  }

  Widget _buildPluginInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.extension, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_plugin?.name ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    'v${_plugin?.version ?? ''}',
                    style: const TextStyle(
                        color: AppTheme.textSecondaryColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            Switch(
              value: _plugin?.enabled ?? false,
              onChanged: (value) async {
                await _pluginService.togglePlugin(_plugin!.id, value);
                if (!mounted) return;
                setState(() {
                  _plugin = _plugin!.copyWith(enabled: value);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection() {
    final settings = _getSettingsForPlugin();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CONFIGURATION',
          style: const TextStyle(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.w600,
            fontSize: 12,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        ...settings.map((setting) => _buildSettingField(setting)),
        if (widget.pluginId == 'termux') ...[
          const SizedBox(height: 16),
          _buildTestConnectionButton(),
        ],
      ],
    );
  }

  Widget _buildTestConnectionButton() {
    return OutlinedButton.icon(
      onPressed: _testSSHConnection,
      icon: const Icon(Icons.wifi_find, size: 18),
      label: const Text('Test SSH Connection'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.primaryColor,
        side: BorderSide(color: AppTheme.primaryColor),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Future<void> _testSSHConnection() async {
    final host = _controllers['ssh_host']?.text ?? '127.0.0.1';
    final port = int.tryParse(_controllers['ssh_port']?.text ?? '8022') ?? 8022;
    final username = _controllers['ssh_username']?.text ?? 'u0_a361';
    final password = _controllers['ssh_password']?.text ?? '111';

    final config = SSHConfig(
      host: host,
      port: port,
      username: username,
      password: password,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Testing SSH connection...')),
      );
    }

    final ssh = SSHService.instance;
    final connected = await ssh.connect(config: config);

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      if (connected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SSH connection successful!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'SSH connection failed. Check host, port, and credentials.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSettingField(Map<String, dynamic> setting) {
    final key = setting['key'] as String;
    final label = setting['label'] as String;
    final type = setting['type'] as String;
    final required = setting['required'] as bool? ?? false;
    final controller = _controllers[key];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
              if (required)
                const Text(' *', style: TextStyle(color: AppTheme.errorColor)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            obscureText: _obscureFields[key] ?? false,
            keyboardType:
                type == 'number' ? TextInputType.number : TextInputType.text,
            decoration: InputDecoration(
              hintText: 'Enter ${label.toLowerCase()}',
              suffixIcon: type == 'password'
                  ? IconButton(
                      icon: Icon(
                        _obscureFields[key] == true
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: AppTheme.textSecondaryColor,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureFields[key] = !(_obscureFields[key] ?? false);
                        });
                      },
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DANGER ZONE',
          style: TextStyle(
            color: AppTheme.errorColor,
            fontWeight: FontWeight.w600,
            fontSize: 12,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.delete, color: AppTheme.errorColor),
            title: const Text('Uninstall Plugin',
                style: TextStyle(color: AppTheme.errorColor)),
            subtitle: const Text('Remove this plugin and all its data'),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Uninstall Plugin'),
                  content: Text(
                      'Are you sure you want to uninstall ${_plugin?.name}?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Uninstall',
                          style: TextStyle(color: AppTheme.errorColor)),
                    ),
                  ],
                ),
              );

              if (confirmed == true && mounted) {
                await _pluginService.uninstallPlugin(_plugin!.id);
                Navigator.pop(context);
              }
            },
          ),
        ),
      ],
    );
  }
}
