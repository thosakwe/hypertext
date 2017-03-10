import 'dart:io';
import 'package:hypertext/io.dart' as http;

main() async {
  var port = 3000;
  var server = await http.Server.bind(InternetAddress.LOOPBACK_IP_V4, port);
  print('Now listening at http://localhost:$port');

  await for (var request in server) {
    var res = request.response;

    // Send some HTML
    res
    ..headers.contentType = http.MediaTypes.HTML
      ..write('''
    <!DOCTYPE html>
    <html>
      <head>
        <title>Hello World</title>
      </head>
      <body>
        <h1>Hello World</h1>
        <p>Welcome to `package:hypertext`.
      </body>
    </html>
    ''');

    await res.close();
  }
}
