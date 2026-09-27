import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/game_config.dart';

/// Rewarded video ads. The player always chooses to watch; there are no
/// forced interstitials (see design doc 13.4).
abstract class AdsService {
  Future<void> init();

  /// Shows a rewarded ad. Completes with true if the reward was earned.
  Future<bool> showRewarded(BuildContext context, String placement);

  /// Whether a "Privacy options" entry must be offered (GDPR/UMP).
  bool get privacyOptionsRequired;
  Future<void> showPrivacyOptions();
}

/// Stand-in used in tests, on unsupported platforms, and as a fallback
/// when no ad is available. Shows a short placeholder "ad".
class SimulatedAdsService implements AdsService {
  SimulatedAdsService({this.seconds = 3});

  final int seconds;

  @override
  Future<void> init() async {}

  @override
  bool get privacyOptionsRequired => false;

  @override
  Future<void> showPrivacyOptions() async {}

  @override
  Future<bool> showRewarded(BuildContext context, String placement) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SimulatedAd(seconds: seconds),
    );
    return result ?? false;
  }
}

class _SimulatedAd extends StatefulWidget {
  const _SimulatedAd({required this.seconds});

  final int seconds;

  @override
  State<_SimulatedAd> createState() => _SimulatedAdState();
}

class _SimulatedAdState extends State<_SimulatedAd> {
  late int _left = widget.seconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _left--);
      if (_left <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF231A35),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ad break',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Icon(Icons.play_circle_fill, color: Colors.white, size: 64),
            const SizedBox(height: 12),
            const Text(
              'Rewarded video placeholder',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 16),
            if (_left > 0)
              Text(
                'Reward in $_left...',
                style: const TextStyle(color: Colors.white70),
              )
            else
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Claim reward'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Google AdMob rewarded ads with UMP consent (GDPR) handling. Uses Google's
/// public test ad units from `economy.json` until real ones are configured.
class AdMobAdsService implements AdsService {
  AdMobAdsService(this.economy)
    : _fallback = SimulatedAdsService(seconds: economy.simulatedAdSeconds);

  final EconomyConfig economy;
  final SimulatedAdsService _fallback;
  RewardedAd? _ad;
  bool _loading = false;
  bool _canRequestAds = false;
  bool _privacyRequired = false;

  static bool get supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  String get _unitId =>
      economy.rewardedUnitIds[Platform.isIOS ? 'ios' : 'android'] ?? '';

  @override
  bool get privacyOptionsRequired => _privacyRequired;

  @override
  Future<void> init() async {
    final consentDone = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((error) {
          if (error != null) debugPrint('Consent form: ${error.message}');
        });
        if (!consentDone.isCompleted) consentDone.complete();
      },
      (error) {
        debugPrint('Consent info: ${error.message}');
        if (!consentDone.isCompleted) consentDone.complete();
      },
    );
    await consentDone.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {},
    );
    _canRequestAds = await ConsentInformation.instance.canRequestAds();
    _privacyRequired =
        await ConsentInformation.instance
            .getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required;
    if (_canRequestAds) {
      await MobileAds.instance.initialize();
      _load();
    }
  }

  void _load() {
    if (_loading || _ad != null || !_canRequestAds) return;
    _loading = true;
    RewardedAd.load(
      adUnitId: _unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded ad failed to load: ${error.message}');
          _loading = false;
          Future.delayed(const Duration(seconds: 30), _load);
        },
      ),
    );
  }

  @override
  Future<bool> showRewarded(BuildContext context, String placement) async {
    final ad = _ad;
    if (ad == null) {
      _load();
      if (economy.adsFallbackToSimulated) {
        return _fallback.showRewarded(context, placement);
      }
      return false;
    }
    _ad = null;
    final done = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!done.isCompleted) done.complete(earned);
        _load();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (!done.isCompleted) done.complete(false);
        _load();
      },
    );
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    return done.future;
  }

  @override
  Future<void> showPrivacyOptions() async {
    await ConsentForm.showPrivacyOptionsForm((error) {
      if (error != null) debugPrint('Privacy options: ${error.message}');
    });
  }
}
