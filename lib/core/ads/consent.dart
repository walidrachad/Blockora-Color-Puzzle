import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

enum ConsentFlowStatus { unknown, notRequired, required, obtained, failed }

@immutable
class ConsentSnapshot {
  const ConsentSnapshot({
    required this.status,
    required this.canRequestAds,
    required this.privacyOptionsRequired,
    this.error,
  });

  const ConsentSnapshot.unknown()
    : status = ConsentFlowStatus.unknown,
      canRequestAds = false,
      privacyOptionsRequired = false,
      error = null;

  final ConsentFlowStatus status;
  final bool canRequestAds;
  final bool privacyOptionsRequired;
  final String? error;
}

abstract class ConsentService {
  ValueListenable<bool> get privacyOptionsRequired;

  Future<ConsentSnapshot> initialize();

  Future<ConsentSnapshot> showPrivacyOptions();

  Future<bool> canRequestAds();

  void dispose();
}

/// UMP adapter. The app supplies [tagForUnderAgeOfConsent] only after the
/// owner confirms the actual audience and legal setup; null deliberately means
/// this code does not guess.
class GoogleConsentService implements ConsentService {
  GoogleConsentService({this.tagForUnderAgeOfConsent});

  final bool? tagForUnderAgeOfConsent;
  final ValueNotifier<bool> _privacyOptionsRequired = ValueNotifier(false);
  Future<ConsentSnapshot>? _initializeFuture;
  ConsentSnapshot _snapshot = const ConsentSnapshot.unknown();
  bool _privacyFormInFlight = false;

  @override
  ValueListenable<bool> get privacyOptionsRequired => _privacyOptionsRequired;

  @override
  Future<ConsentSnapshot> initialize() {
    return _initializeFuture ??= _initializeOnce();
  }

  Future<ConsentSnapshot> _initializeOnce() async {
    if (!_isMobile) {
      return _snapshot = const ConsentSnapshot(
        status: ConsentFlowStatus.notRequired,
        canRequestAds: false,
        privacyOptionsRequired: false,
      );
    }

    final completer = Completer<ConsentSnapshot>();
    final params = ConsentRequestParameters(
      tagForUnderAgeOfConsent: tagForUnderAgeOfConsent,
    );
    void finish([String? error]) {
      unawaited(
        _readSnapshot(error).then((value) {
          if (!completer.isCompleted) completer.complete(value);
        }),
      );
    }

    try {
      ConsentInformation.instance.requestConsentInfoUpdate(params, () {
        unawaited(
          ConsentForm.loadAndShowConsentFormIfRequired((formError) {
            finish(formError?.message);
          }),
        );
      }, (error) => finish(error.message));
    } catch (error) {
      finish('$error');
    }
    return completer.future;
  }

  Future<ConsentSnapshot> _readSnapshot(String? error) async {
    try {
      final canRequest = await ConsentInformation.instance.canRequestAds();
      final options = await ConsentInformation.instance
          .getPrivacyOptionsRequirementStatus();
      _privacyOptionsRequired.value =
          options == PrivacyOptionsRequirementStatus.required;
      final status = await ConsentInformation.instance.getConsentStatus();
      return _snapshot = ConsentSnapshot(
        status: error == null
            ? switch (status) {
                ConsentStatus.notRequired => ConsentFlowStatus.notRequired,
                ConsentStatus.obtained => ConsentFlowStatus.obtained,
                ConsentStatus.required => ConsentFlowStatus.required,
                ConsentStatus.unknown => ConsentFlowStatus.unknown,
              }
            : ConsentFlowStatus.failed,
        canRequestAds: canRequest,
        privacyOptionsRequired: _privacyOptionsRequired.value,
        error: error,
      );
    } catch (readError) {
      return _snapshot = ConsentSnapshot(
        status: ConsentFlowStatus.failed,
        canRequestAds: false,
        privacyOptionsRequired: _privacyOptionsRequired.value,
        error: error ?? '$readError',
      );
    }
  }

  @override
  Future<ConsentSnapshot> showPrivacyOptions() async {
    if (!_isMobile || _privacyFormInFlight) return _snapshot;
    _privacyFormInFlight = true;
    final completer = Completer<void>();
    try {
      await ConsentForm.showPrivacyOptionsForm((_) {
        if (!completer.isCompleted) completer.complete();
      });
      await completer.future;
    } catch (error) {
      _privacyFormInFlight = false;
      return _snapshot = ConsentSnapshot(
        status: ConsentFlowStatus.failed,
        canRequestAds: false,
        privacyOptionsRequired: _privacyOptionsRequired.value,
        error: '$error',
      );
    }
    _privacyFormInFlight = false;
    return _readSnapshot(null);
  }

  @override
  Future<bool> canRequestAds() async {
    if (!_isMobile) return false;
    try {
      return await ConsentInformation.instance.canRequestAds();
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() => _privacyOptionsRequired.dispose();
}

class FakeConsentService implements ConsentService {
  FakeConsentService({
    ConsentSnapshot snapshot = const ConsentSnapshot(
      status: ConsentFlowStatus.obtained,
      canRequestAds: true,
      privacyOptionsRequired: false,
    ),
  }) : _snapshot = snapshot,
       _privacyOptionsRequired = ValueNotifier(snapshot.privacyOptionsRequired);

  final ConsentSnapshot _snapshot;
  final ValueNotifier<bool> _privacyOptionsRequired;
  int initializeCalls = 0;
  int privacyOptionsCalls = 0;

  @override
  ValueListenable<bool> get privacyOptionsRequired => _privacyOptionsRequired;

  @override
  Future<ConsentSnapshot> initialize() async {
    initializeCalls++;
    return _snapshot;
  }

  @override
  Future<ConsentSnapshot> showPrivacyOptions() async {
    privacyOptionsCalls++;
    return _snapshot;
  }

  @override
  Future<bool> canRequestAds() async => _snapshot.canRequestAds;

  @override
  void dispose() => _privacyOptionsRequired.dispose();
}

bool get _isMobile =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;
