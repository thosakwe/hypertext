library hypertext.http;

import 'package:http_parser/http_parser.dart' show MediaType;
export 'package:http_parser/http_parser.dart' show MediaType;
export 'headers.dart';
export 'parser.dart';
export 'request.dart';
export 'response.dart';
export 'version.dart';

abstract class MediaTypes {
  static final MediaType HTML =
      new MediaType('text', 'html', {'charset': 'utf8'});
  static final MediaType JSON =
      new MediaType('application', 'json', {'charset': 'utf8'});
  static final MediaType TEXT =
      new MediaType('text', 'plain', {'charset': 'utf8'});
}
