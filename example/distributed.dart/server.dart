import 'dart:io';
import 'dart:isolate';
import 'package:hypertext/io.dart' as http;

final Uri cluster = Platform.script.resolve('cluster.dart');

main() async {
  List<SendPort> sendPorts = [];
  int index = 0;
  int nInstances = 5;
  var recv = new ReceivePort();
  Map<String, Socket> table = {};

  for (int i = 0; i < nInstances; i++) {
    var isolate = await Isolate.spawnUri(cluster, [], recv.sendPort);
  }

  var server = await ServerSocket.bind('localhost', 3000);

  recv.listen((data) async {
    if (data is SendPort)
      sendPorts.add(data);
    else if (data is List) {
      var socket = table[data.first];
      socket.add(data.last);
      await socket.flush();
      await socket.close();
    }
  });

  server.listen((socket) async {
    var ip = socket.remoteAddress.address;
    table[ip] = socket;

    socket.listen((buf) {
      SendPort port;

      if (index++ < sendPorts.length)
        port = sendPorts[index];
      else {
        port = sendPorts[index = 0];
      }

      port.send([ip, buf]);
    })
      ..onDone(() {
        table.remove(ip);
      });
  });
}
