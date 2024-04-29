import 'package:siberian_core/siberian_core.dart';

class NetworkException extends AppException {
  NetworkException(super.message);

  @override
  String toString() {
    return 'NetworkException{message: $message}';
  }
}

class NoNetworkException extends NetworkException {
  NoNetworkException(super.message);
}

class ServerException extends NetworkException {
  final int status;
  final String? knownCode;
  final dynamic data;

  ServerException(super.message, {required this.status, this.knownCode, this.data});

  @override
  String toString() {
    return 'ServerException{status: $status, knownCode: $knownCode, data: $data}';
  }
}

class BadCertificateException extends NetworkException {
  BadCertificateException(super.message);
}

class ForbiddenException extends NetworkException {
  ForbiddenException(super.message);
}

class UserNotFoundException extends NetworkException {
  UserNotFoundException(super.message);
}

class CancelledException extends NetworkException {
  CancelledException() : super('');

  @override
  String toString() {
    return 'CancelledException{}';
  }
}
