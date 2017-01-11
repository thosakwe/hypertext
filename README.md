# hypertext
[![version 0.0.0](https://img.shields.io/badge/pub-v0.0.0-red.svg)](https://pub.dartlang.org/packages/hypertext)
[![build status](https://travis-ci.org/thosakwe/hypertext.svg)](https://travis-ci.org/thosakwe/hypertext)

Alternative HTTP protocol library for Dart. The main difference here
is that the developer gets a lot more freedom than with the
`dart:io` implementation.

HTTP/2 support will come in the future.

Much of this library will work cross-platform, save for the `Server` class, as
it depends on the `dart:io` `ServerSocket` class.

## Why?
This package only exists for the case in which the current `dart:io`
HTTP server API's are removed, say in Dart 2.0.0.

I doubt this will ever happen, but if it does, frameworks like
[Angel](https://angel-dart.github.io), won't suddenly explode.

Also, `hypertext` is really useful for, say, writing a proxy,
because requests and responses can instantly be exported `toHttp()`.
Writing reverse proxies with Dart for me has been cumbersome so far.

## Missing Features
- Cookies
- WebSockets (although that would likely be another package, which would
connect to `web_socket_channel`)

The following are deliberately left out:
- Sessions

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: http://github.com/thosakwe/hypertext/issues
