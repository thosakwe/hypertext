import 'dart:io' show Platform;
import 'dart:isolate';
import 'package:hypertext/hypertext.dart';

void main() {
  for (int i = 1; i < Platform.numberOfProcessors; i++)
    Isolate.spawn(serverMain, i);

  serverMain(0);
}

void serverMain(int isolateId) {
  var server = new Server(new HttpDriver('127.0.0.1', 3000));
  server.start();
  print('Listening at http://${server.driver.host}:${server.driver.port}');

  server.onRequest.listen((rq) {
    String message;
    int status = 200;

    switch (rq.url) {
      case '/':
        message = 'Hello, world!';
        break;
      case '/help':
        message = 'No help available yet.';
        break;
      default:
        status = 404;
        message = 'No file exists at "${rq.url}".';
        break;
    }

    var sink = rq.sendHeaders(status, 'Not Found', {
      'content-length': message.length.toString(),
      'content-type': 'text/plain'
    });

    sink
      ..write(message)
      ..close();
  });
}
