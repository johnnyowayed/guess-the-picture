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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bannerAd == null) {
      _loadBanner();
    }
  }

  Future<void> _loadBanner() async {
    final width = MediaQuery.sizeOf(context).width.truncate();
    final adSize = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    if (!mounted || adSize == null) {
      return;
    }

    final banner = BannerAd(
      adUnitId: AdService.instance.bannerAdUnitId,
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );

    await banner.load();
    if (!mounted) {
      banner.dispose();
      return;
    }

    setState(() {
      _bannerAd = banner;
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
        height: bannerHeight + 18,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
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
