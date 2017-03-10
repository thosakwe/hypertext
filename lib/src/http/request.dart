import 'dart:async';
import 'headers.dart';
import 'response.dart';
import 'version.dart';

abstract class Request extends Stream<List<int>> {
  List<int> get body;
  Headers get headers;
  String get method;
  Response get response;
  String get url;
  Version get version;

  String toHttp() {
    var buf = new StringBuffer()..writeln('$method $url $version');
    headers.toValueMap().forEach((k, v) => buf.writeln('$k: $v'));
    buf.writeln();

    if (body?.isNotEmpty == true) {
      body.forEach(buf.writeCharCode);
      buf.writeln();
    }

    return buf.toString();
  }
}
