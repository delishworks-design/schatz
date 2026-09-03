import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/routing/app_router.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _buildSection('Providers', [
            _buildTile(
              icon: Icons.api,
              title: 'Manage Providers',
              subtitle: 'Add, edit, and configure AI providers',
              onTap: () => Navigator.pushNamed(context, AppRouter.providerManager),
            ),
          ]),
          _buildSection('Generation', [
            _buildTile(
              icon: Icons.tune,
              title: 'Generation Settings',
              subtitle: 'Temperature, max tokens, streaming',
              onTap: () {},
            ),
            _buildSwitch(
              icon: Icons.swap_horiz,
              title: 'Provider Fallback',
              subtitle: 'Try next provider on failure',
              value: false,
              onChanged: (value) {},
            ),
          ]),
          _buildSection('Personality', [
            _buildTile(
              icon: Icons.person,
              title: 'Persona',
              subtitle: 'Schatz Default',
              onTap: () {},
            ),
            _buildTile(
              icon: Icons.psychology,
              title: 'System Prompt',
              subtitle: 'Customize Schatz\'s behavior',
              onTap: () {},
            ),
          ]),
          _buildSection('Voice', [
            _buildTile(
              icon: Icons.mic,
              title: 'Speech-to-Text',
              subtitle: 'Language and settings',
              onTap: () {},
            ),
            _buildTile(
              icon: Icons.volume_up,
              title: 'Text-to-Speech',
              subtitle: 'Voice, speed, auto-speak',
              onTap: () {},
            ),
          ]),
          _buildSection('Appearance', [
            _buildTile(
              icon: Icons.dark_mode,
              title: 'Theme',
              subtitle: 'Dark mode',
              onTap: () {},
            ),
            _buildTile(
              icon: Icons.format_size,
              title: 'Font Size',
              subtitle: 'Medium',
              onTap: () {},
            ),
          ]),
          _buildSection('Storage', [
            _buildTile(
              icon: Icons.storage,
              title: 'Model Manager',
              subtitle: 'Manage offline models',
              onTap: () {},
            ),
            _buildTile(
              icon: Icons.delete_sweep,
              title: 'Clear Cache',
              subtitle: 'Free up storage space',
              onTap: () {},
            ),
          ]),
          _buildSection('Plugins', [
            _buildTile(
              icon: Icons.extension,
              title: 'Plugin Manager',
              subtitle: 'Manage installed plugins and tools',
              onTap: () => Navigator.pushNamed(context, AppRouter.pluginManager),
            ),
            _buildTile(
              icon: Icons.store,
              title: 'Plugin Marketplace',
              subtitle: 'Browse and install new plugins',
              onTap: () => Navigator.pushNamed(context, AppRouter.pluginMarketplace),
            ),
          ]),
          _buildSection('Backup', [
            _buildTile(
              icon: Icons.upload,
              title: 'Export Data',
              subtitle: 'Export chats and settings',
              onTap: () {},
            ),
            _buildTile(
              icon: Icons.download,
              title: 'Import Data',
              subtitle: 'Import from backup',
              onTap: () {},
            ),
          ]),
          _buildSection('About', [
            _buildTile(
              icon: Icons.info,
              title: 'About Schatz',
              subtitle: 'Version 1.0.0',
              onTap: () {},
            ),
            _buildTile(
              icon: Icons.privacy_tip,
              title: 'Privacy',
              subtitle: 'How your data is handled',
              onTap: () {},
            ),
            _buildTile(
              icon: Icons.code,
              title: 'Open Source Licenses',
              subtitle: 'Third-party dependencies',
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'Schatz',
                applicationVersion: '1.0.0',
              ),
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
  
  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
  
  Widget _buildTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondaryColor),
      onTap: onTap,
    );
  }
  
  Widget _buildSwitch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon, color: AppTheme.primaryColor),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
      ),
      value: value,
      onChanged: onChanged,
      thumbColor: WidgetStateProperty.all(AppTheme.primaryColor),
    );
  }
}
