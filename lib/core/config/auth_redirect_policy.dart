/// The web app uses hash routing. Its email callback returns to the same base
/// document, without copying route fragments, query tokens or credentials.
String webEmailRedirect(Uri page) {
  final local = ['localhost', '127.0.0.1', '::1'].contains(page.host);
  if (page.host.isEmpty ||
      page.userInfo.isNotEmpty ||
      !(page.scheme == 'https' || (page.scheme == 'http' && local))) {
    throw const FormatException(
      'Open Balance through HTTPS or a local development server.',
    );
  }
  return Uri(
    scheme: page.scheme,
    host: page.host,
    port: page.hasPort ? page.port : null,
    path: page.path.isEmpty ? '/' : page.path,
  ).toString();
}
