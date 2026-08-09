// A published release, reduced to the parts the update screen needs.
class ReleaseModel {
  const ReleaseModel({
    required this.version,
    required this.notes,
    required this.url,
    required this.assetName,
    this.downloadUrl,
    this.size = 0,
    this.publishedAt,
  });

  factory ReleaseModel.fromJson(
    Map<String, dynamic> json, {
    required String assetName,
  }) {
    String? downloadUrl;
    int size = 0;

    final assets = json['assets'];
    if (assets is List) {
      for (final asset in assets) {
        if (asset is Map && asset['name'] == assetName) {
          downloadUrl = asset['browser_download_url'] as String?;
          size = (asset['size'] as num?)?.toInt() ?? 0;
          break;
        }
      }
    }

    final published = json['published_at'];
    return ReleaseModel(
      // tags are bare versions like 0.0.1, but tolerate a v prefix in case one
      // ever gets pushed that way
      version: (json['tag_name'] as String? ?? '').replaceFirst(
        RegExp(r'^v'),
        '',
      ),
      notes: (json['body'] as String? ?? '').trim(),
      url: json['html_url'] as String? ?? '',
      assetName: assetName,
      downloadUrl: downloadUrl,
      size: size,
      publishedAt: published is String ? DateTime.tryParse(published) : null,
    );
  }

  final String version;

  /// The release notes, as markdown.
  final String notes;
  final String url;
  final String assetName;
  final String? downloadUrl;
  final int size;
  final DateTime? publishedAt;

  bool isNewerThan(String current) => compareVersions(version, current) > 0;

  // Compares two dotted versions. A version that will not parse, which is what
  // a build from source can report, counts as older than anything published,
  // so the update button offers the newest release rather than doing nothing.
  static int compareVersions(String a, String b) {
    final left = _parse(a);
    final right = _parse(b);
    if (left == null) return -1;
    if (right == null) return 1;
    for (var i = 0; i < 3; i++) {
      if (left[i] != right[i]) return left[i].compareTo(right[i]);
    }
    return 0;
  }

  static List<int>? _parse(String value) {
    var text = value.trim();
    if (text.startsWith('v')) text = text.substring(1);

    // a build suffix such as 0.0.1+1 or a prerelease tail is not compared,
    // only the three numbers in front of it
    final cut = text.indexOf(RegExp(r'[-+]'));
    if (cut >= 0) text = text.substring(0, cut);

    final parts = text.split('.');
    if (parts.length != 3) return null;

    final out = <int>[];
    for (final part in parts) {
      final number = int.tryParse(part);
      if (number == null) return null;
      out.add(number);
    }
    return out;
  }
}
