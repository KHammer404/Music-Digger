import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';

/// Reusable full-screen error widget with retry button.
class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;

  const ErrorView({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final info = _errorInfo(error);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(info.icon, size: 64, color: info.color),
            const SizedBox(height: 16),
            Text(
              info.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            if (info.subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                info.subtitle!,
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('다시 시도'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static _ErrorInfo _errorInfo(Object error) {
    if (error is NetworkException) {
      return _ErrorInfo(
        icon: Icons.wifi_off,
        color: Colors.orange,
        title: error.message,
        subtitle: '인터넷 연결을 확인하고 다시 시도해주세요',
      );
    } else if (error is TimeoutException) {
      return _ErrorInfo(
        icon: Icons.timer_off,
        color: Colors.orange,
        title: error.message,
        subtitle: '잠시 후 다시 시도해주세요',
      );
    } else if (error is ServerException) {
      return _ErrorInfo(
        icon: Icons.cloud_off,
        color: Colors.redAccent,
        title: error.message,
        subtitle: '서버에 일시적인 문제가 있습니다',
      );
    } else if (error is NotFoundException) {
      return _ErrorInfo(
        icon: Icons.search_off,
        color: Colors.grey,
        title: error.message,
      );
    } else if (error is AppException) {
      return _ErrorInfo(
        icon: Icons.error_outline,
        color: Colors.redAccent,
        title: error.message,
      );
    } else {
      return _ErrorInfo(
        icon: Icons.error_outline,
        color: Colors.redAccent,
        title: '오류가 발생했습니다',
        subtitle: error.toString(),
      );
    }
  }
}

class _ErrorInfo {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;

  const _ErrorInfo({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
  });
}

/// Inline error banner for non-critical errors (e.g., load-more failures).
class ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorBanner({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withAlpha(50)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text('재시도'),
            ),
        ],
      ),
    );
  }
}
