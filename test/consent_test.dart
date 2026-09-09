import 'package:flutter_test/flutter_test.dart';
import 'package:prism_puzzle/core/ads/consent.dart';

void main() {
  test('fake consent is repeatable and exposes privacy option calls', () async {
    final service = FakeConsentService(
      snapshot: const ConsentSnapshot(
        status: ConsentFlowStatus.obtained,
        canRequestAds: true,
        privacyOptionsRequired: true,
      ),
    );
    expect(await service.initialize(), isA<ConsentSnapshot>());
    expect(service.privacyOptionsRequired.value, isTrue);
    expect(await service.canRequestAds(), isTrue);
    await service.showPrivacyOptions();
    expect(service.initializeCalls, 1);
    expect(service.privacyOptionsCalls, 1);
    service.dispose();
  });
}
