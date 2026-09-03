import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../models/activity_step.dart';

class ActivityTrace extends StatefulWidget {
  final List<ActivityStep> steps;
  final bool isExpanded;
  final VoidCallback? onToggle;
  final int tokenCount;
  final Duration? elapsed;
  
  const ActivityTrace({
    super.key,
    required this.steps,
    this.isExpanded = false,
    this.onToggle,
    this.tokenCount = 0,
    this.elapsed,
  });
  
  @override
  State<ActivityTrace> createState() => _ActivityTraceState();
}

class _ActivityTraceState extends State<ActivityTrace> {
  late bool _isExpanded;
  
  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpanded;
  }
  
  @override
  void didUpdateWidget(ActivityTrace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      _isExpanded = widget.isExpanded;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) return const SizedBox.shrink();
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          top: BorderSide(color: AppTheme.borderColor.withOpacity(0.3)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          if (_isExpanded) _buildStepsList(),
        ],
      ),
    );
  }
  
  Widget _buildHeader() {
    final completedCount = widget.steps.where((s) => s.status == ActivityStepStatus.completed).length;
    final inProgressCount = widget.steps.where((s) => s.status == ActivityStepStatus.inProgress).length;
    final hasError = widget.steps.any((s) => s.status == ActivityStepStatus.error);
    
    return InkWell(
      onTap: () {
        setState(() => _isExpanded = !_isExpanded);
        widget.onToggle?.call();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            if (inProgressCount > 0)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (hasError)
              const Icon(Icons.error_outline, size: 12, color: AppTheme.errorColor)
            else
              Icon(Icons.check_circle, size: 12, color: AppTheme.successColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _getStatusText(completedCount, inProgressCount, hasError),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ),
            if (widget.tokenCount > 0)
              Text(
                '${widget.tokenCount} tokens',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            if (widget.elapsed != null) ...[
              const SizedBox(width: 8),
              Text(
                _formatDuration(widget.elapsed!),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(
              _isExpanded ? Icons.expand_less : Icons.expand_more,
              size: 16,
              color: AppTheme.textSecondaryColor,
            ),
          ],
        ),
      ),
    );
  }
  
  String _getStatusText(int completed, int inProgress, bool hasError) {
    if (hasError) return 'Error occurred';
    if (inProgress > 0) return 'Processing...';
    if (completed == widget.steps.length) return 'Complete';
    return '$completed/${widget.steps.length} steps';
  }
  
  Widget _buildStepsList() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 150),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
        itemCount: widget.steps.length,
        itemBuilder: (context, index) {
          final step = widget.steps[index];
          return _buildStepItem(step);
        },
      ),
    );
  }
  
  Widget _buildStepItem(ActivityStep step) {
    Color statusColor;
    switch (step.status) {
      case ActivityStepStatus.pending:
        statusColor = AppTheme.textSecondaryColor;
        break;
      case ActivityStepStatus.inProgress:
        statusColor = AppTheme.primaryColor;
        break;
      case ActivityStepStatus.completed:
        statusColor = AppTheme.successColor;
        break;
      case ActivityStepStatus.error:
        statusColor = AppTheme.errorColor;
        break;
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            step.statusIcon,
            style: TextStyle(
              color: statusColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              step.name,
              style: TextStyle(
                fontSize: 11,
                color: step.status == ActivityStepStatus.inProgress
                    ? AppTheme.textColor
                    : AppTheme.textSecondaryColor,
              ),
            ),
          ),
          if (step.durationText.isNotEmpty)
            Text(
              step.durationText,
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondaryColor,
              ),
            ),
        ],
      ),
    );
  }
  
  String _formatDuration(Duration duration) {
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds}s';
    }
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }
}
