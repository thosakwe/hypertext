import 'package:hypertext/hypertext.dart';

void main() {
  var server = new Server(new HttpDriver('127.0.0.1', 3000));
  server.start();
  print('Listening at http://${server.driver.host}:${server.driver.port}');

  server.onRequest.listen((rq) {
    String content, reasonPhrase = 'OK';
    int status = 200;

    switch (rq.url) {
      case '/':
        content = 'Hello, world!';
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
