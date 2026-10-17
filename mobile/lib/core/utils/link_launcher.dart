import 'package:injectable/injectable.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens links, email and WhatsApp, and shares text. Behind an interface so blocs stay testable.
abstract interface class LinkLauncher {
  Future<bool> openInApp(String url);
  Future<bool> openExternal(String url);
  Future<bool> email(String address, {String? subject});
  Future<void> share(String text, {String? subject});
}

@LazySingleton(as: LinkLauncher)
class UrlLinkLauncher implements LinkLauncher {
  @override
  Future<bool> openInApp(String url) => _open(url, LaunchMode.inAppBrowserView);

  @override
  Future<bool> openExternal(String url) => _open(url, LaunchMode.externalApplication);

  @override
  Future<bool> email(String address, {String? subject}) =>
      launchUrl(Uri(scheme: 'mailto', path: address, queryParameters: subject == null ? null : {'subject': subject}));

  @override
  Future<void> share(String text, {String? subject}) => Share.share(text, subject: subject);

  Future<bool> _open(String url, LaunchMode mode) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) return false;
    try {
      return await launchUrl(uri, mode: mode);
    } catch (_) {
      return launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }
}
