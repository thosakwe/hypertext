import 'package:http_parser/http_parser.dart';

class Headers {
  final Map<String, List<String>> _headers = {};

  MediaType get contentType => _headers.containsKey('content-type')
      ? new MediaType.parse(_headers['content-type'].join())
      : null;

  void set contentType(MediaType type) => set('content-type', type.mimeType);

  DateTime get date => _headers.containsKey('date')
      ? parseHttpDate(_headers['date'].join())
      : null;

  void set date(DateTime date) => set('date', formatHttpDate(date));

  List<String> operator [](String key) => get(key);

  void operator []=(String key, value) => set(key, value);

  void addAll(other) {
    if (other is Headers)
      addAll(other.toMap());
    else if (other is Map<String, dynamic>)
      other.forEach(set);
    else
      throw new ArgumentError(
          'Can only add a Map or a Headers instance to headers.');
  }

  void clear() => _headers.clear();

  List<String> get(String key) {
    var k = key.toLowerCase();
    if (_headers.containsKey(k))
      return new List<String>.unmodifiable(_headers[k]);
    return null;
  }

  bool has(String key) => get(key) != null;

  void remove(String key) {
    _headers.remove(key);
  }

  void set(String key, value) {
    if (value is! Iterable<String> && value is! String)
      throw new ArgumentError(
          'Headers must be set to either strings, of an iterable thereof.');
    List<String> values =
        value is Iterable<String> ? value.toList() : [value.toString()];

    var k = key.toLowerCase();
    if (_headers.containsKey(k))
      _headers[k].addAll(values);
    else
      _headers[k] = values;
  }

  String value(String key, {String separator: ','}) =>
      has(key) ? get(key).join(separator) : null;

  Map<String, List<String>> toMap() =>
      new Map<String, List<String>>.unmodifiable(_headers);

  Map<String, String> toValueMap({String separator: ','}) {
    Map<String, String> out = {};
    _headers.forEach((k, v) => out[k] = v.join(separator));
    return out;
  }
}
