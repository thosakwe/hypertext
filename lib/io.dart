import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:charcode/ascii.dart';
import 'hypertext.dart';
export 'hypertext.dart';

// Todo: Handle syntax errors
class Server extends Stream<Request> implements StreamConsumer<io.Socket> {
  final bool debug;
  final Encoding encoding;
  final io.ServerSocket connection;
  final Version version;
  bool _open = true;
  Parser _parser;

  StreamController<io.Socket> _onProtocolError =
      new StreamController<io.Socket>();
  StreamController<Request> _onClient = new StreamController<Request>();

  Stream<io.Socket> get onProtocolError => _onProtocolError.stream;

  Server(this.connection,
      {this.encoding: UTF8, this.version: HTTP_V11, this.debug: false})
      : _parser = new Parser(encoding: encoding, debug: debug);

  static Future<Server> bind(address, int port,
      {Encoding encoding: UTF8,
      Version version: HTTP_V11,
      bool debug: false}) async {
    var connection = await io.ServerSocket.bind(address, port);
    return new Server(connection, encoding: encoding, debug: debug)
      ..addStream(connection);
  }

  factory Server.broadcast(io.ServerSocket connection,
          {Encoding encoding: UTF8, Version version: HTTP_V11}) =>
      new Server(connection, encoding: encoding, version: version)
        .._onClient = new StreamController<Request>.broadcast();

  Future addStream(Stream<io.Socket> stream) {
    if (!_open) throw new StateError('Cannot add stream to closed server.');

    var c = new Completer();

    stream.listen(handleClient)
      ..onDone(() {
        _onClient.close();
        c.complete();
      })
      ..onError((e, st) {
        _onClient.addError(e, st);
        c.completeError(e, st);
      });

    return c.future;
  }

  Future close() async {
    _open = false;
    _onClient.close();
    _onProtocolError.close();
    await connection.close();
  }

  void handleClient(io.Socket socket) {
    socket.listen((buf) {
      var request = _parser.parse(buf);

      if (request != null) {
        var rs = new _ResponseImpl(socket)
          ..version = version
          ..headers.date = new DateTime.now();
        _onClient.add(new _RequestImpl(request, rs));
      } else
        _onProtocolError.add(socket);
    });
  }

  @override
  StreamSubscription<Request> listen(void onData(Request event),
          {Function onError, void onDone(), bool cancelOnError}) =>
      _onClient.stream.listen(onData,
          onError: onError,
          onDone: onDone,
          cancelOnError: cancelOnError == true);
}

class _RequestImpl extends Request {
  final StreamController<List<int>> _ctrl = new StreamController<List<int>>();
  final Request _inner;
  final _ResponseImpl _response;

  _RequestImpl(this._inner, this._response);

  @override
  List<int> get body => _inner.body;

  @override
  Headers get headers => _inner.headers;

  @override
  String get method => _inner.method;

  @override
  Response get response => _response;

  @override
  String get url => _inner.url;

  @override
  Version get version => _inner.version;

  @override
  String toHttp() => _inner.toHttp();

  @override
  StreamSubscription<List<int>> listen(void onData(List<int> event),
      {Function onError, void onDone(), bool cancelOnError}) {
    _ctrl.close();
    return _ctrl.stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError == true);
  }
}

class _ResponseImpl extends Response {
  final io.Socket _socket;
  bool _open = true;

  _ResponseImpl(this._socket);

  @override
  final List<int> body = [];

  @override
  final Headers headers = new Headers();

  @override
  String message = 'OK';

  @override
  int statusCode = io.HttpStatus.OK;

  @override
  Version version = HTTP_V11;

  @override
  Future addStream(Stream<List<int>> stream) {
    if (!_open) throw new StateError('Cannot write to a closed response.');

    var c = new Completer();
    stream.listen(body.addAll,
        cancelOnError: true, onError: c.completeError, onDone: c.complete);
    return c.future;
  }

  @override
  Future close() async {
    _open = false;

    if (!headers.containsKey('content-length')) {
      headers['content-length'] = body.length.toString();
    }

    await toStream().pipe(_socket);
  }

  @override
  void write(Object obj) {
    body.addAll(obj?.toString()?.codeUnits ?? []);
  }

  @override
  void writeAll(Iterable objects, [String separator = ""]) {
    write(objects.join(separator ?? ''));
  }

  @override
  void writeCharCode(int charCode) {
    body.add(charCode);
  }

  @override
  void writeln([Object obj = ""]) {
    write(obj ?? '');
    body.addAll([$cr, $lf]);
  }
}
