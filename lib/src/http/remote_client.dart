import 'dart:io';
import 'request.dart';
import 'response.dart';

class RemoteClient {
  final Socket connection;
  final BaseRequest request;
  final BaseResponse response;

  RemoteClient(this.connection, this.request, this.response);
}
