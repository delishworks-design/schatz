import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/routing/app_router.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.2),
                    AppTheme.secondaryColor.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(
                Icons.diamond,
                size: 60,
                color: AppTheme.primaryColor.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome to Schatz',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your AI companion, ready to chat',
              style: TextStyle(color: AppTheme.textSecondaryColor),
            ),
            const SizedBox(height: 32),
            _buildSuggestion(
              context,
              'Write a short story',
              Icons.edit,
            ),
            const SizedBox(height: 12),
            _buildSuggestion(
              context,
              'Explain quantum computing',
              Icons.science,
            ),
            const SizedBox(height: 12),
            _buildSuggestion(
              context,
              'Help me debug my code',
              Icons.code,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestion(BuildContext context, String text, IconData icon) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, AppRouter.chat, arguments: {'initialPrompt': text});
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.primaryColor),
            const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(color: AppTheme.textColor),
            ),
          ],
        ),
      ),
    );
  }
}