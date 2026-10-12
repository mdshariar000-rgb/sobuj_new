import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/config/app_config.dart';

void main() {
  test('share links point at the public site, not the API', () {
    expect(AppConfig.webBaseUrl, 'https://codecell.site');
    expect(AppConfig.listingShareUrl(34), 'https://codecell.site/l/34');
    expect(AppConfig.profileShareUrl(93), 'https://codecell.site/u/93');
  });
}
