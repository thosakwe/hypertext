const HTTP_V10 = const Version(1, 0);
const HTTP_V11 = const Version(1, 1);
const HTTP_V20 = const Version(2, 0);
final RegExp _version = new RegExp(r'([A-Z]+)\/([0-9]+)\.([0-9]+)');

class Version {
  final int major, minor;
  final String protocol;

  const Version(this.major, this.minor, {this.protocol: 'HTTP'});

  operator ==(other) =>
      other is Version &&
      other.protocol == protocol &&
      other.major == major &&
      other.minor == minor;

  factory Version.parse(String versionString) {
    var m = _version.firstMatch(versionString);

    if (m == null)
      throw new ArgumentError(
          'Invalid version string. Expected format: "HTTP/1.1", "FOO/3.7"');

    return new Version(int.parse(m[2]), int.parse(m[3]), protocol: m[1]);
  }

  bool isBackwardsCompatibleWith(Version other) =>
      other.major == major && other.minor <= minor;

  String toString() => '$protocol/$major.$minor';
}
