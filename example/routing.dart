import 'dart:io';
import 'package:angel_route/angel_route.dart';
import 'package:hypertext/http.dart' as http;

final RegExp _straySlashes = new RegExp(r'(^/+)|(/+$)');

main() async {
  var port = 3000;
  var server = await http.Server.bind(InternetAddress.LOOPBACK_IP_V4, port);

  print('Now listening at http://localhost:$port');

  var router = createRouter();

  await for (http.RemoteClient client in server.onClient) {
    // This is essentially the routing setup used in the Angel framework,
    // although simplified. ;)
    var requestedUrl = client.request.url.replaceAll(_straySlashes, '');
    if (requestedUrl.isEmpty) requestedUrl = '/';

    var resolved = router.resolveAll(requestedUrl, requestedUrl,
        method: client.request.method);
    var pipeline = new MiddlewarePipeline(resolved);

    for (var handler in pipeline.handlers) {
      if (await handler(client.request, client.response) != true) break;
    }

    await client.response.toStream().pipe(client.connection);
  }
}

Router createRouter() {
  return new Router()
    ..get('/hello', (req, http.BaseResponse res) async {
      res.body.addAll('Hello, world!'.codeUnits);
    })
    ..all('*', (http.BaseRequest req, http.BaseResponse res) async {
      res
        ..statusCode = 404
        ..message = 'Not Found'
        ..body.addAll("No file exists at path '${req.url}'.".codeUnits);
    });
}
