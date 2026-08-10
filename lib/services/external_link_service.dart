import 'package:url_launcher/url_launcher.dart';

/// Opens trusted catalogue links using the platform's normal browser or app.
///
/// Callers retain a clipboard fallback so a missing browser or phone handler
/// never turns an important civic-information action into a dead end.
class ExternalLinkService {
  const ExternalLinkService();

  Future<bool> open(String value) async {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme) {
      return false;
    }

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }
}
