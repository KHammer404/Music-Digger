import 'package:equatable/equatable.dart';

enum ExportStatus { idle, exporting, exported, importing, imported, error }

class ExportState extends Equatable {
  final ExportStatus status;
  final String? message;
  final String? errorMessage;

  const ExportState({
    this.status = ExportStatus.idle,
    this.message,
    this.errorMessage,
  });

  ExportState copyWith({
    ExportStatus? status,
    String? message,
    String? errorMessage,
  }) {
    return ExportState(
      status: status ?? this.status,
      message: message,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, message, errorMessage];
}
