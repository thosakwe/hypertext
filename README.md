# hypertext
[![Pub](https://img.shields.io/pub/v/hypertext.svg)](https://pub.dartlang.org/packages/hypertext)
[![build status](https://travis-ci.org/thosakwe/hypertext.svg)](https://travis-ci.org/thosakwe/hypertext)

Bare-metal, native-code, multi-threaded HTTP server for Dart.

`package:hypertext` entirely skips over `dart:io` and deals directly with
Berkeley sockets, and handling connections using
[Joyent's optimized C HTTP parser](https://github.com/nodejs/http-parser).

**WARNING: This package is still highly experimental, and should not
be used in production. You've been warned!!!**

## Why?
There are several valid reasons for an alternative HTTP server library in Dart:
  * Dart is a good, sane language, and having a fast stack written entirely in
  one language can help many people work faster.
  * The canonical implementation is good, but could better/much faster.
  * Isolates in Dart are slower and heavier than system threads, which is not as good
  for high-volume Web services.
  * Dart is not *officially* supported on the server side.

## How it works
All networking and HTTP parsing in `package:hypertext` is handled within a Dart
[native extension](lib/src/hypertext.cc). Incoming data is sent back to Dart by means
of the `HttpDriver` class.

The goal of `HttpDriver` is truly to be just a *driver* for HTTP serving, and by no means
a complete server. See the [`Server` class](#high-level-server) for that instead.

*Note that the `HttpDriver` is not an elegant API, and it's more likely that you will
build high-level servers on top of it.*

`HttpDriver` provides all of the [`http-parser callbacks`](https://github.com/nodejs/http-parser#callbacks),
except for `on_headers_complete`. Use these to asynchronously process requests.

`HttpDriver`'s `write` method, along with its callbacks, directly pass to you an `int`
corresponding to the socket's descriptor on your system. Therefore, `write` operations
push data directly to the native socket, and not to any sort of buffer. High-level
implementations should keep this in consideration.

In addition, `HttpDriver` supports a `shared` flag, so that multiple isolates can concurrently
process requests from the same server. A simple round-robin strategy is used to cycle through
multiple listeners.

## High-level server
`package:hypertext` also provides a higher-level `Server` class that builds
on top of `HttpDriver`.

*Note that `Server` does not provide mechanisms like session management or cookies.*

Here is the simplest example:

```dart
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
```

`Server` also supports upgraded requests; however, at this time, there is no built-in
functionality surrounding the WebSocket protocol, as it would involve additional complication
that, truthfully, should not be in a package designed to give a low-level interface to the Web.

Look into `package:web_socket_channel`:
https://pub.dartlang.org/packages/web_socket_channel

```dart
main() {
    server.onUpgradedRequest.listen((upgraded) {
      // Do something...
    });
}
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker](http://github.com/thosakwe/hypertext/issues).
