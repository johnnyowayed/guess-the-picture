import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ad_service.dart';

class AppBannerAd extends StatefulWidget {
  const AppBannerAd({super.key});

  @override
  State<AppBannerAd> createState() => _AppBannerAdState();
}

class _AppBannerAdState extends State<AppBannerAd> {
  BannerAd? _bannerAd;
  bool _isLoading = false;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  bool _triedStandardBanner = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBanner());
  }

  Future<void> _loadBanner() async {
    if (!mounted || _isLoading || _bannerAd != null) {
      return;
    }

    _isLoading = true;

    final mediaQuery = MediaQuery.of(context);
    final availableWidth =
        mediaQuery.size.width -
        mediaQuery.padding.left -
        mediaQuery.padding.right;
    final width = availableWidth.truncate();
    if (width <= 0) {
      _isLoading = false;
      _scheduleRetry();
      return;
    }

    final adaptiveSize =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    if (!mounted) {
      _isLoading = false;
      return;
    }

    final adSize = adaptiveSize ?? AdSize.banner;
    final usingAdaptive = adaptiveSize != null;
    final banner = BannerAd(
      adUnitId: AdService.instance.bannerAdUnitId,
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          _retryCount = 0;
          _isLoading = false;
          _triedStandardBanner = false;
          debugPrint(
            '[BannerAd] loaded: unit=${AdService.instance.bannerAdUnitId} '
            'size=${ad.responseInfo?.loadedAdapterResponseInfo?.adSourceName ?? adSize.width}x${adSize.height}',
          );
          setState(() {
            _bannerAd = ad as BannerAd;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _isLoading = false;
          debugPrint(
            '[BannerAd] failed: unit=${AdService.instance.bannerAdUnitId} '
            'code=${error.code} domain=${error.domain} message=${error.message} '
            'adaptive=$usingAdaptive size=${adSize.width}x${adSize.height}',
          );

          if (usingAdaptive && !_triedStandardBanner) {
            _triedStandardBanner = true;
            _loadStandardBanner();
            return;
          }

          _scheduleRetry();
        },
      ),
    );

    banner.load();
  }

  void _loadStandardBanner() {
    if (!mounted || _isLoading || _bannerAd != null) {
      return;
    }
    _isLoading = true;

    final banner = BannerAd(
      adUnitId: AdService.instance.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          _retryCount = 0;
          _isLoading = false;
          debugPrint('[BannerAd] loaded with standard fallback size=320x50');
          setState(() {
            _bannerAd = ad as BannerAd;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _isLoading = false;
          debugPrint(
            '[BannerAd] standard fallback failed: code=${error.code} '
            'domain=${error.domain} message=${error.message}',
          );
          _scheduleRetry();
        },
      ),
    );

    banner.load();
  }

  void _scheduleRetry() {
    if (!mounted || _bannerAd != null || _retryCount >= _maxRetries) {
      return;
    }
    _retryCount++;
    final waitSeconds = (_retryCount * 15).clamp(15, 45);
    Future<void>.delayed(Duration(seconds: waitSeconds), () {
      if (mounted) {
        _loadBanner();
      }
    });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = _bannerAd;
    if (banner == null) {
      return const SizedBox.shrink();
    }

    final bannerWidth = banner.size.width.toDouble();
    final bannerHeight = banner.size.height.toDouble();

    return SafeArea(
      top: false,
      child: SizedBox(
        height: bannerHeight + 4,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 2, 0, 2),
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: bannerWidth,
              height: bannerHeight,
              child: AdWidget(ad: banner),
            ),
          ),
        ),
      ),
    );
  }
}
