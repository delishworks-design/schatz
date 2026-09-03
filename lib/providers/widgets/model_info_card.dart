import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../models/provider_profile.dart';

class ModelInfoCard extends StatelessWidget {
  final ProviderModel model;
  final String? providerName;
  final bool isSelected;
  final VoidCallback? onTap;
  
  const ModelInfoCard({
    super.key,
    required this.model,
    this.providerName,
    this.isSelected = false,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 8),
              _buildCapabilities(),
              if (model.contextLength != null) ...[
                const SizedBox(height: 8),
                _buildContextLength(),
              ],
              if (model.description != null) ...[
                const SizedBox(height: 8),
                _buildDescription(),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.smart_toy, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                model.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              if (providerName != null)
                Text(
                  providerName!,
                  style: const TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        if (isSelected)
          const Icon(Icons.check_circle, color: AppTheme.primaryColor),
      ],
    );
  }
  
  Widget _buildCapabilities() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        if (model.supportsVision)
          _buildChip('Vision', Icons.visibility),
        if (model.supportsAudio)
          _buildChip('Audio', Icons.mic),
        if (model.supportsStreaming)
          _buildChip('Streaming', Icons.sync),
        if (model.supportsToolCalling)
          _buildChip('Tools', Icons.build),
      ],
    );
  }
  
  Widget _buildChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.primaryColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildContextLength() {
    final length = model.contextLength!;
    final displayLength = length >= 1000 ? '${(length / 1000).toStringAsFixed(1)}K' : '$length';
    
    return Row(
      children: [
        const Icon(Icons.straighten, size: 16, color: AppTheme.textSecondaryColor),
        const SizedBox(width: 8),
        Text(
          'Context: $displayLength tokens',
          style: const TextStyle(
            color: AppTheme.textSecondaryColor,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  Widget _buildDescription() {
    return Text(
      model.description!,
      style: const TextStyle(
        color: AppTheme.textSecondaryColor,
        fontSize: 12,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
