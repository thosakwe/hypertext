import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'headers.dart';
import 'remote_client.dart';
import 'parser.dart';
import 'request.dart';
import 'response.dart';
import 'version.dart';

// Todo: Handle syntax errors
class Server {
  Parser _parser;
  final bool debug;
  final Encoding encoding;
  final io.ServerSocket connection;
  final Version version;

  StreamController<io.Socket> _onProtocolError =
      new StreamController<io.Socket>();
  StreamController<RemoteClient> _onClient =
      new StreamController<RemoteClient>();

  Stream<io.Socket> get onProtocolError => _onProtocolError.stream;
  Stream<RemoteClient> get onClient => _onClient.stream;

  Server(this.connection,
      {this.encoding: UTF8, this.version: HTTP_V11, this.debug: false})
      : _parser = new Parser(encoding: encoding, debug: debug);

  static Future<Server> bind(address, int port,
      {Encoding encoding: UTF8,
      Version version: HTTP_V11,
      bool debug: false}) async {
    var connection = await io.ServerSocket.bind(address, port);
    return new Server(connection, encoding: encoding, debug: debug)
      ..listen(connection);
  }

  factory Server.broadcast(io.ServerSocket connection,
          {Encoding encoding: UTF8, Version version: HTTP_V11}) =>
      new Server(connection, encoding: encoding, version: version)
        .._onClient = new StreamController<RemoteClient>.broadcast();

  void listen(Stream<io.Socket> stream) {
    stream.listen(handleClient)
      ..onDone(_onClient.close)
      ..onError(_onClient.addError);
  }

  void handleClient(io.Socket socket) {
    socket.listen((buf) {
      var request = _parser.parse(buf);

      if (request != null) {
        var rq = new Request(request);
        var rs = new Response()
          ..version = version
          ..headers.date = new DateTime.now();
        _onClient.add(new RemoteClient(socket, rq, rs));
      } else
        _onProtocolError.add(socket);
    });
  }
}

class Request implements BaseRequest {
  final BaseRequest _inner;

  Request(this._inner);

  @override
  List<int> get body => _inner.body;

  @override
  Headers get headers => _inner.headers;

  @override
  String get method => _inner.method;

  @override
  String get url => _inner.url;

  @override
  Version get version => _inner.version;

  @override
  String toHttp() => _inner.toHttp();
}

class Response extends BaseResponse {
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
}
