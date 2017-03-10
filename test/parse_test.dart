import 'package:hypertext/hypertext.dart';
import 'package:test/test.dart';

main() {
  test('chrome', () async {
    var req = new Parser().parse('''GET / HTTP/1.1
Host: localhost:3000
Connection: keep-alive
Cache-Control: max-age=0
Upgrade-Insecure-Requests: 1
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/55.0.2883.95 Safari/537.36
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8
DNT: 1
Accept-Encoding: gzip, deflate, sdch, br
Accept-Language: en-US,en;q=0.8'''
        .codeUnits);

    expect(req, new isInstanceOf<Request>());
    expect(req.method, equals('GET'));
    expect(req.url, equals('/'));
    expect(req.version, equals(HTTP_V11));
    [
      'host',
      'connection',
      'cache-control',
      'upgrade-insecure-requests',
      'user-agent',
      'accept',
      'dnt',
      'accept-encoding',
      'accept-language'
    ].forEach((header) => expect(req.headers.has(header), isTrue));

    [
      'gzip',
      'deflate',
      'sdch',
      'br'
    ].forEach((enc) => expect(req.headers['accept-encoding'], contains(enc)));
    expect(req.headers.value('conNECTIoN'), equals('keep-alive'));
    expect(req.headers['user-agent']?.first, startsWith('Mozilla'));
    print(req.toHttp());
  });
}
