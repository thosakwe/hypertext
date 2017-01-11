import 'dart:io';
import 'package:hypertext/http.dart' as http;

main() async {
  var port = 3000;
  var server = await http.Server.bind(InternetAddress.LOOPBACK_IP_V4, port);

  print('Now listening at http://localhost:$port');

  await for (http.RemoteClient client in server.onClient) {
    // Copy headers
    print(client.request.headers.toValueMap());
    client.response.headers.addAll(client.request.headers);
    await client.response.toStream().pipe(client.connection);
  }
}
