class AppException implements Exception {
  const AppException({required this.message, this.code});
  
  final String message;
  final String? code;
  
  @override
  String toString() => 'AppException: $message${code != null ? ' (Code: $code)' : ''}';
}

class NetworkException extends AppException {
  const NetworkException({required super.message, super.code});
}

class DiscoveryException extends AppException {
  const DiscoveryException({required super.message, super.code});
}

class TransferException extends AppException {
  const TransferException({required super.message, super.code});
}

class CryptoException extends AppException {
  const CryptoException({required super.message, super.code});
}

class PermissionException extends AppException {
  const PermissionException({required super.message, super.code});
}

class FileException extends AppException {
  const FileException({required super.message, super.code});
}

class ProtocolException extends AppException {
  const ProtocolException({required super.message, super.code});
}
