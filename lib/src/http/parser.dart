import 'dart:async';
import 'dart:convert';
import 'package:hypertext/src/http/response.dart';
import 'package:string_scanner/string_scanner.dart';
import 'headers.dart';
import 'request.dart';
import 'version.dart';

final RegExp _start =
    new RegExp(r'([A-Z]+) (\/([^\s]*)) (([A-Z]+)\/([0-9]+)\.([0-9]+))');
final RegExp _header = new RegExp(r'([A-Za-z-]+)\s*:\s*([^\n]+)');

// Todo: Handle syntax errors
class Parser implements StreamTransformer<List<int>, Request> {
  final bool debug;
  final Encoding encoding;

  Parser({this.encoding: UTF8, this.debug: false});

  void printDebug(Object object) {
    if (debug) print(object);
  }

  @override
  Stream<Request> bind(Stream<List<int>> stream) {
    var ctrl = new StreamController<Request>();

    var sub = stream.listen((buf) {
      var request = parse(buf);
      if (request != null) ctrl.add(request);
    });

    sub
      ..onDone(ctrl.close)
      ..onError(ctrl.addError);

    return ctrl.stream;
  }

  Request parse(List<int> buf) {
    var scanner = new StringScanner(encoding.decode(buf));

    while (!scanner.isDone) {
      if (scanner.scan(_start)) {
        var request = new _BaseRequestImpl(scanner.lastMatch[1],
            scanner.lastMatch[2], new Version.parse(scanner.lastMatch[4]));
        printDebug(
            'Request: ${request.method} ${request.url} ${request.version}');

        while (!scanner.isDone) {
          if (scanner.scan(_header)) {
            String key = scanner.lastMatch[1].toLowerCase().trim();

            List<String> values;

            if (key == 'user-agent') {
              values = [scanner.lastMatch[2]];
            } else {
              values = scanner.lastMatch[2]
                  .split(',')
                  .where((str) => str.isNotEmpty)
                  .map((str) => str.trim())
                  .toList();
            }

            printDebug('Found header: $key => $values');
            request.headers.set(key, values);

            // Headers must be followed by a newline
            if (!scanner.scan('\n')) break;
          } else
            scanner.readChar();
        }

        return request
          .._data = buf.skip(scanner.position).toList()
          ..headers._lock()
          ..close();
      } else
        scanner.readChar();
    }

    return null;
  }
}

class _BaseRequestImpl extends Request {
  final StreamController<List<int>> _ctrl = new StreamController<List<int>>();
  List<int> _data;

  @override
  final _UnmodifiableHeaders headers = new _UnmodifiableHeaders();

  @override
  final String method, url;

  @override
  final Version version;

  @override
  List<int> get body => _data;

  _BaseRequestImpl(this.method, this.url, this.version);

  @override
  Response get response => null;

  close() {
    _ctrl
      ..add(_data)
      ..close();
  }

  @override
  StreamSubscription<List<int>> listen(void onData(List<int> event),
      {Function onError, void onDone(), bool cancelOnError}) {
    return _ctrl.stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError == true);
  }
}

class _UnmodifiableHeaders extends Headers {
  bool _locked = false;

  StateError _error() => new StateError('Cannot change unmodifiable headers.');

  void _lock() {
    _locked = true;
  }

  @override
  set contentType(type) {
    if (_locked) throw _error();
    super.contentType = type;
  }

  @override
  set date(date) {
    if (_locked) throw _error();
    super.date = date;
  }

  @override
  void set(key, value) {
    if (_locked)
      throw _error();
    else
      super.set(key, value);
  }

  @override
  void remove(key) {
    if (_locked)
      throw _error();
    else
      super.remove(key);
  }
}
