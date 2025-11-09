import 'package:flutter/material.dart';
import 'package:airlink/shared/models/app_state.dart';

/// Cloud Sync Settings Dialog
class CloudSyncSettingsDialog extends StatelessWidget {
  const CloudSyncSettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cloud Sync Settings'),
      content: const Text('Cloud sync settings dialog'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Add Cloud Provider Dialog
class AddCloudProviderDialog extends StatelessWidget {
  const AddCloudProviderDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Cloud Provider'),
      content: const Text('Add cloud provider dialog'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Cloud Provider Settings Dialog
class CloudProviderSettingsDialog extends StatelessWidget {
  final CloudProvider provider;
  
  const CloudProviderSettingsDialog({
    super.key,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${provider.name} Settings'),
      content: const Text('Provider settings dialog'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Sync Job Details Dialog
class SyncJobDetailsDialog extends StatelessWidget {
  final SyncJob job;
  
  const SyncJobDetailsDialog({
    super.key,
    required this.job,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Job Details: ${job.name}'),
      content: const Text('Sync job details dialog'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Sync History Details Dialog
class SyncHistoryDetailsDialog extends StatelessWidget {
  final SyncHistoryItem item;
  
  const SyncHistoryDetailsDialog({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('History Details: ${item.id}'),
      content: const Text('Sync history details dialog'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
