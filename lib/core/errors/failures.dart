import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  const Failure({required this.message, this.code});
  
  final String message;
  final String? code;
  
  @override
  List<Object?> get props => [message, code];
}

class NetworkFailure extends Failure {
  const NetworkFailure({required super.message, super.code});
}

class DiscoveryFailure extends Failure {
  const DiscoveryFailure({required super.message, super.code});
}

class TransferFailure extends Failure {
  const TransferFailure({required super.message, super.code});
}

class CryptoFailure extends Failure {
  const CryptoFailure({required super.message, super.code});
}

class PermissionFailure extends Failure {
  const PermissionFailure({required super.message, super.code});
}

class FileFailure extends Failure {
  const FileFailure({required super.message, super.code});
}

class UnknownFailure extends Failure {
  const UnknownFailure({required super.message, super.code});
}
