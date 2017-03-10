import 'dart:isolate';
import 'package:hypertext/hypertext.dart' as http;

main(args, SendPort port) {
  var parser = new http.Parser();

  var recv = new ReceivePort();

  recv.listen((List data) async {
    var ip = data.first;
    var request = parser.parse(data.last);
  });

  port.send(recv.sendPort);
}
