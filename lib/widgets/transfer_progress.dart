import 'package:flutter/material.dart';

/// Transfer progress widget
/// TODO: Implement real-time progress updates and file transfer status
class TransferProgress extends StatelessWidget {
  final String fileName;
  final double progress;
  final String status;
  final String? speed;
  final String? timeRemaining;

  const TransferProgress({
    super.key,
    required this.fileName,
    required this.progress,
    required this.status,
    this.speed,
    this.timeRemaining,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.file_upload, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fileName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress == 1.0 ? Colors.green : Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  status,
                  style: TextStyle(
                    color: progress == 1.0 ? Colors.green : Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (speed != null) Text(speed!),
              ],
            ),
            if (timeRemaining != null) ...[
              const SizedBox(height: 4),
              Text(
                'Time remaining: $timeRemaining',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
