import 'dart:io';
import 'dart:isolate';
import 'package:hypertext/hypertext.dart';

main() {
  for (int i = 1; i < Platform.numberOfProcessors; i++)
    Isolate.spawn(serverMain, i);
  serverMain(0);
}

void serverMain(int isolateId) {
  var server = new Server(new HttpDriver('127.0.0.1', 3000, shared: true));
  server.start();
  print('Listening at http://${server.driver.host}:${server.driver.port}');

  server.onRequest.listen((rq) {
    String content, reasonPhrase = 'OK';
    int status = 200;

    switch (rq.url) {
      case '/':
        content = 'Hello from $isolateId!';
        break;
      case '/help':
        content = 'No help available yet.';
        break;
      default:
        status = 404;
        reasonPhrase = 'Not Found';
        content = 'No file exists at "${rq.url}".';
        break;
    }

    var sink = rq.sendHeaders(status, reasonPhrase, {
      'content-length': content.length.toString(),
      'content-type': 'text/plain'
    });

    sink
      ..write(content)
      ..close();
  });
}
