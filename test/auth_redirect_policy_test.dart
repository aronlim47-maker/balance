import 'package:balance/core/config/auth_redirect_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Production web callback keeps site/subpath and strips tokens/routes',
    () {
      expect(
        webEmailRedirect(
          Uri.parse(
            'https://balance.example/balance/?code=private#/reset-password',
          ),
        ),
        'https://balance.example/balance/',
      );
      expect(
        webEmailRedirect(Uri.parse('https://balance.example/#/quests')),
        'https://balance.example/',
      );
    },
  );
  test('Local callback preserves development port', () {
    expect(
      webEmailRedirect(Uri.parse('http://localhost:8080/#/account-help')),
      'http://localhost:8080/',
    );
    expect(
      webEmailRedirect(Uri.parse('http://127.0.0.1:8080/?token=private')),
      'http://127.0.0.1:8080/',
    );
  });
  test('Reject insecure public pages and credential-bearing URLs', () {
    for (final url in [
      'http://balance.example/',
      'file:///index.html',
      'https://user:password@balance.example/',
    ]) {
      expect(() => webEmailRedirect(Uri.parse(url)), throwsFormatException);
    }
  });
}
