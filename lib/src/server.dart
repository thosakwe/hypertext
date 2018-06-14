import 'dart:async';
import 'dart:typed_data';
import 'package:charcode/ascii.dart';
import 'driver.dart';

class Server {
  final HttpDriver driver;
  final StreamController<Request> _onRequest = new StreamController();
  final StreamController<UpgradedRequest> _onUpgradedRequest =
      new StreamController();
  final Map<int, StagingRequest> _staging = {};
  final Map<int, UpgradedRequest> _upgraded = {};

  StagingRequest _ensure(int sockfd) =>
      _staging.putIfAbsent(sockfd, () => new StagingRequest());

  Server(this.driver) {
    driver.onMessageBegin = _ensure;
    driver.onUrl = (sockfd, url) => _ensure(sockfd).url = url;
    driver.onHeaderField =
        (sockfd, field) => _ensure(sockfd).headerField = field;
    driver.onHeaderValue =
        (sockfd, value) => _ensure(sockfd).headerValue = value;
    driver.onBody = (sockfd, body) => _ensure(sockfd)._bodyStream.add(body);
    driver.onUpgradedMessage =
        (sockfd, data) => _upgraded[sockfd]?._stream?.add(data);
    driver.onUpgrade = (sockfd) => _onUpgradedRequest.add(
          _upgraded.putIfAbsent(
            sockfd,
            () => new UpgradedRequest._(this, sockfd, _ensure(sockfd)),
          ),
        );
    driver.onMessageComplete = (sockfd, method, major, minor, addrBytes) {
      var staging = _ensure(sockfd)
        ..addr = HttpDriver.addressToString(addrBytes, ipv6: driver.ipv6)
        ..major = major
        ..minor = minor
        ..method = HttpDriver.methodToString(method)
        .._bodyStream.close();
      _staging.remove(sockfd);
      _onRequest.add(new Request._(this, sockfd, staging));
    };
  }

  Stream<Request> get onRequest => _onRequest.stream;

  Stream<UpgradedRequest> get onUpgradedRequest => _onUpgradedRequest.stream;

  void close() {
    _onRequest.close();
    _onUpgradedRequest.close();
  }

  void start() {
    driver.start();
  }
}

class StagingRequest {
  final StreamController<Uint8List> _bodyStream = new StreamController();
  String addr;
  int major, minor;
  String url;
  String method;
  Map<String, String> headers = {};
  String headerField;

  Stream<Uint8List> get body => _bodyStream.stream;

  void set headerValue(String s) {
    if (headerField == null) return;
    headers[headerField] = s;
    headerField = null;
  }
}

class BaseRequest {
  final Server _server;
  final int _sockfd;
  final StagingRequest _staging;
  Map<String, String> _headers;
  HttpProtocolVersion _version;

  BaseRequest._(this._server, this._sockfd, this._staging);

  String get address => _staging.addr;

  String get url => _staging.url;

  String get method => _staging.method;

  HttpProtocolVersion get version =>
      _version ??= new HttpProtocolVersion(_staging.major, _staging.minor);

  Map<String, String> get headers =>
      _headers ??= new Map.unmodifiable(_staging.headers);

  Stream<Uint8List> get body => _staging.body;
}

class Request extends BaseRequest {
  bool _closed = false;

  Request._(Server server, int sockfd, StagingRequest staging)
      : super._(server, sockfd, staging);

  ResponseSink sendHeaders(
      int status, String reasonPhrase, Map<String, String> headers) {
    if (_closed)
      throw new StateError(
          'The sink for this response has already been opened.');
    _closed = true;
    var sink = new ResponseSink._(_sockfd, _server);
    sink.write('HTTP/1.1 $status $reasonPhrase\r\n');
    headers.forEach((k, v) => sink.write('$k: $v\r\n'));
    sink.add([$cr, $lf]);
    return sink;
  }
}

class UpgradedRequest extends BaseRequest {
  final StreamController<Uint8List> _stream = new StreamController();
  ResponseSink _sink;

  UpgradedRequest._(Server server, int sockfd, StagingRequest staging)
      : super._(server, sockfd, staging);

  Stream<Uint8List> get stream => _stream.stream;

  ResponseSink get sink => _sink ??= new ResponseSink._(_sockfd, _server, this);

  void _close() {
    _server._upgraded.remove(this);
    _stream.close();
  }
}

class HttpProtocolVersion {
  final int major, minor;

  HttpProtocolVersion(this.major, this.minor);
}

class ResponseSink implements StreamSink<List<int>>, StringSink {
  final Completer _done = new Completer();
  final int _sockfd;
  final Server _server;
  final UpgradedRequest _upgradedRequest;
  bool _closed = false;

  ResponseSink._(this._sockfd, this._server, [this._upgradedRequest]);

  Uint8List _ensureUint8List(List<int> list) {
    if (list is Uint8List) return list;
    if (list is Uint8ClampedList) return new Uint8List.view(list.buffer);
    return new Uint8List.fromList(list);
  }

  void _ensureOpen() {
    if (_closed)
      throw new StateError('This response sink has already been closed.');
  }

  @override
  void add(List<int> event) {
    if (event.isEmpty) return;
    _ensureOpen();
    var array = _ensureUint8List(event);
    /*print(new String.fromCharCodes(array)
        .replaceAll('\r', '\\r')
        .replaceAll('\n', '\\n'));
    */
    _server.driver.write(_sockfd, array);
  }

  @override
  void addError(Object error, [StackTrace stackTrace]) {
    Zone.current.handleUncaughtError(error, stackTrace);
  }

  @override
  Future addStream(Stream<List<int>> stream) => stream.forEach(add);

  @override
  Future close() {
    if (!_done.isCompleted || _closed) {
      add([$cr, $lf]);
      _upgradedRequest?._close();
      _closed = true;
      _done.complete();
    }

    return done;
  }

  @override
  Future get done => _done.isCompleted ? new Future.value() : _done.future;

  @override
  void write(Object obj) {
    add(obj.toString().codeUnits);
  }

  @override
  void writeAll(Iterable objects, [String separator = ""]) {
    if (objects.isNotEmpty) write(objects.join(separator));
  }

  @override
  void writeCharCode(int charCode) {
    _ensureOpen();
    _server.driver.write(_sockfd, new Uint8List(1)..[0] = charCode);
  }

  @override
  void writeln([Object obj = ""]) {
    var str = obj?.toString();

    if (str?.isNotEmpty != true)
      add([$lf]);
    else
      add(new List<int>.from(str.codeUnits)..add($lf));
  }
}
