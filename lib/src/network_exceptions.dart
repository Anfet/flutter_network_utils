import 'package:siberian_core/siberian_core.dart';

class NetworkException extends AppException {
  NetworkException(super.message);
}

class NoNetworkException extends NetworkException {
  NoNetworkException(super.message);
}

class ServerException extends NetworkException {
  final int status;
  final String? knownCode;
  final dynamic data;

  ServerException(super.message, {required this.status, this.knownCode, this.data});
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
