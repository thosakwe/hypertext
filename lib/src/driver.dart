import 'dart:isolate';
import 'dart:typed_data';
import 'dart-ext:hypertext';

/// A TCP server that asynchronously listens for incoming connections, and
class HttpDriver {
  static const int messageBegin = 0,
      messageComplete = 1,
      url = 2,
      headerField = 3,
      headerValue = 4,
      body = 5,
      upgrade = 6,
      upgradedMessage = 7;

  static const int DELETE = 0,
      GET = 1,
      HEAD = 2,
      POST = 3,
      PUT = 4,
      CONNECT = 5,
      OPTIONS = 6,
      TRACE = 7,
      COPY = 8,
      LOCK = 9,
      MKCOL = 10,
      MOVE = 11,
      PROPFIND = 12,
      PROPPATCH = 13,
      SEARCH = 14,
      UNLOCK = 15,
      BIND = 16,
      REBIND = 17,
      UNBIND = 18,
      ACL = 19,
      REPORT = 20,
      MKACTIVITY = 21,
      CHECKOUT = 22,
      MERGE = 23,
      MSEARCH = 24,
      NOTIFY = 25,
      SUBSCRIBE = 26,
      UNSUBSCRIBE = 27,
      PATCH = 28,
      PURGE = 29,
      MKCALENDAR = 30,
      LINK = 31,
      UNLINK = 32,
      SOURCE = 33;

  static List _Server_init(String host, int port, bool ipv6, bool shared,
      SendPort sendPort, int backlog) native "Server_init";

  final String host;
  final int port;
  final bool ipv6;
  final bool shared;
  final int backlog;
  void Function(int) onMessageBegin, onUpgrade;

  /// Called with:
  /// * sockfd
  /// * HTTP Method
  /// * HTTP major
  /// * HTTP minor
  /// * InternetAddress data
  void Function(int, int, int, int, Uint8List) onMessageComplete;
  void Function(int, String) onUrl, onHeaderField, onHeaderValue;
  void Function(int, Uint8List) onBody, onUpgradedMessage;

  bool _open = false;
  int _pointer, _shared_index;
  SendPort _outPort;
  RawReceivePort _recv;

  HttpDriver(this.host, this.port,
      {this.ipv6: false, this.shared: false, this.backlog: 10});

  static String _addressToString(Uint8List address, bool ipv6)
      native "Server_addressToString";

  static String addressToString(Uint8List address, {bool ipv6: false}) =>
      _addressToString(address, ipv6);

  static String methodToString(int method) {
    switch (method) {
      case DELETE:
        return 'DELETE';
      case GET:
        return 'GET';
      case HEAD:
        return 'HEAD';
      case POST:
        return 'POST';
      case PUT:
        return 'PUT';
      case CONNECT:
        return 'CONNECT';
      case OPTIONS:
        return 'OPTIONS';
      case PATCH:
        return 'PATCH';
      case PURGE:
        return 'PURGE';
      default:
        throw new ArgumentError('Unknown method $method.');
    }
  }

  void close() {
    _outPort.send([_recv.sendPort, _pointer, 1, _outPort]);
  }

  void start() {
    if (_open) return;
    _open = true;
    _recv = new RawReceivePort()..handler = _handle;
    var result =
        _Server_init(host, port, ipv6, shared, _recv.sendPort, backlog);
    _pointer = result[0];
    _outPort = result[1];
    _shared_index = result[2];

    // Send the listen command...
    _outPort.send([_recv.sendPort, _pointer, 0, _shared_index]);
  }

  void write(int sockfd, Uint8List data) {
    _outPort.send([_recv.sendPort, _pointer, 2, sockfd, data]);
  }

  void closeSocket(int sockfd) {
    _outPort.send([_recv.sendPort, _pointer, 3, sockfd]);
  }

  void _handle(x) {
    if (x is String) {
      close();
      throw new StateError(x);
    } else if (x is List && x.length >= 2) {
      int sockfd = x[0], command = x[1];
      //print(x);

      switch (command) {
        case messageBegin:
          if (onMessageBegin != null) onMessageBegin(sockfd);
          break;
        case messageComplete:
          if (onMessageComplete != null)
            onMessageComplete(sockfd, x[2], x[3], x[4], x[5]);
          break;
        case upgrade:
          if (onUpgrade != null) onUpgrade(sockfd);
          break;
        case url:
          if (onUrl != null) onUrl(sockfd, x[2]);
          break;
        case headerField:
          if (onHeaderField != null) onHeaderField(sockfd, x[2]);
          break;
        case headerValue:
          if (onHeaderValue != null) onHeaderValue(sockfd, x[2]);
          break;
        case upgradedMessage:
          if (onUpgradedMessage != null) onUpgradedMessage(sockfd, x[2]);
          break;
      }
    }
  }
}
