import 'dart:async';
import 'headers.dart';
import 'version.dart';

abstract class BaseResponse {
  List<int> get body;
  Headers get headers;
  int get statusCode;
  String get message;
  Version get version;
  set statusCode(int statusCode);
  set message(String message);
  set version(Version version);

  List<int> toBytes() => toHttp().codeUnits;

  Stream<List<int>> toStream() async* {
    yield toBytes();
  }

  String toHttp() {
    var buf = new StringBuffer()..writeln('$version $statusCode $message');
    headers.toValueMap().forEach((k, v) => buf.writeln('$k: $v'));
    buf.writeln();

    if (body?.isNotEmpty == true) {
      body.forEach(buf.writeCharCode);
      buf.writeln();
    }

    return buf.toString();
  }
}
