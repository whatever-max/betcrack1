import 'dart:async';
import 'package:flutter/material.dart';
import '../models/banner_item_model.dart'; // CRUCIAL: Ensure this path is correct and model is complete

class HomeBannerCarousel extends StatefulWidget {
  final List<BannerItem> banners;
  final Function(BannerItem) onBannerTap;

  const HomeBannerCarousel({
    super.key,
    required this.banners,
    required this.onBannerTap,
  });

  @override
  State<HomeBannerCarousel> createState() => _HomeBannerCarouselState();
}

class _HomeBannerCarouselState extends State<HomeBannerCarousel> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    print("HomeBannerCarousel: initState called. Initial banners length: ${widget.banners.length}");
    _pageController = PageController(initialPage: 0, viewportFraction: 0.88);
    _attemptStartAutoScroll();
  }

  @override
  void didUpdateWidget(covariant HomeBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    print("HomeBannerCarousel: didUpdateWidget called. New banners: ${widget.banners.length}, Old banners: ${oldWidget.banners.length}");

    bool hadBanners = oldWidget.banners.isNotEmpty;
    bool hasBanners = widget.banners.isNotEmpty;

    if (hasBanners && !hadBanners) {
      print("HomeBannerCarousel: Banners appeared.");
      _currentPage = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      _startAutoScroll();
    } else if (!hasBanners && hadBanners) {
      print("HomeBannerCarousel: Banners disappeared.");
      _timer?.cancel();
    } else if (hasBanners && widget.banners.length != oldWidget.banners.length) {
      print("HomeBannerCarousel: Number of banners changed.");
      _timer?.cancel();
      _currentPage = 0; // Reset to avoid out-of-bounds with new length
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      _startAutoScroll(); // Restart with new length
    }
  }

  void _attemptStartAutoScroll() {
    // This allows calling from initState before pageController might have clients fully ready
    // or if banners are populated immediately.
    if (widget.banners.isNotEmpty) {
      // Give a very slight delay for PageController to attach if needed,
      // especially if called directly from initState.
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) { // Check mounted again after delay
          _startAutoScroll();
        }
      });
    } else {
      print("HomeBannerCarousel: AttemptStartAutoScroll - No banners to scroll initially.");
    }
  }

  void _startAutoScroll() {
    _timer?.cancel();
    if (!mounted || widget.banners.isEmpty || !_pageController.hasClients) {
      print("HomeBannerCarousel: Auto-scroll NOT started (mounted: $mounted, bannersEmpty: ${widget.banners.isEmpty}, hasClients: ${_pageController.hasClients})");
      return;
    }

    if (widget.banners.length <= 1) { // Also check here before starting timer
      print("HomeBannerCarousel: Auto-scroll not started, 1 or no banners.");
      return;
    }

    print("HomeBannerCarousel: Starting auto-scroll with ${widget.banners.length} banners. CurrentPage: $_currentPage");

    _timer = Timer.periodic(const Duration(seconds: 7), (Timer timer) {
      if (!mounted || widget.banners.isEmpty || !_pageController.hasClients) {
        print("HomeBannerCarousel: Stopping auto-scroll in timer callback (state changed).");
        timer.cancel();
        return;
      }

      if (widget.banners.length <= 1) { // If banners reduced to 1 or 0 during timer
        print("HomeBannerCarousel: Stopping auto-scroll, 1 or no banners remaining.");
        timer.cancel();
        return;
      }

      _currentPage = (_currentPage + 1) % widget.banners.length;

      // Ensure page controller still has clients (it should, but good check)
      if (_pageController.hasClients) {
        print("HomeBannerCarousel: Animating to page $_currentPage");
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOutCubic,
        );
      } else {
        print("HomeBannerCarousel: PageController no longer has clients in timer. Stopping scroll.");
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    print("HomeBannerCarousel: dispose called.");
    _pageController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // This check is good, but HomeScreen should ideally not build this if banners are empty.
    if (widget.banners.isEmpty) {
      print("HomeBannerCarousel: Build called with empty banners, returning SizedBox.shrink().");
      return const SizedBox.shrink();
    }
    print("HomeBannerCarousel: Build called with ${widget.banners.length} banners.");

    return Column(
      children: [
        SizedBox(
          height: 180.0,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.banners.length,
            onPageChanged: (int page) {
              if (mounted) {
                print("HomeBannerCarousel: Page changed by user/animation to $page. Resetting timer.");
                setState(() {
                  _currentPage = page;
                });
                _timer?.cancel(); // Cancel existing timer
                _startAutoScroll(); // Restart it to respect the new position after user interaction
              }
            },
            itemBuilder: (context, index) {
              final banner = widget.banners[index];
              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double value = 1.0;
                  if (_pageController.position.haveDimensions) {
                    double pageValue = _pageController.page ?? _currentPage.toDouble(); // Use _currentPage as a fallback
                    pageValue = pageValue.clamp(0.0, (widget.banners.length - 1).toDouble());
                    value = pageValue - index;
                    value = (1 - (value.abs() * 0.2)).clamp(0.8, 1.0);
                  }
                  return Center(
                    child: SizedBox(
                      height: Curves.easeOut.transform(value) * 180,
                      width: MediaQuery.of(context).size.width * 0.85,
                      child: child,
                    ),
                  );
                },
                child: GestureDetector(
                  onTap: () {
                    print("HomeBannerCarousel: Banner tapped (index $index: ${banner.id}). Pausing scroll.");
                    _timer?.cancel();
                    widget.onBannerTap(banner);
                    // Resume scroll after a delay, giving time for user to return from detail screen
                    Future.delayed(const Duration(seconds: 10), () {
                      if (mounted && widget.banners.isNotEmpty) { // Check mounted & banners again
                        print("HomeBannerCarousel: Attempting to resume auto-scroll after tap delay.");
                        _startAutoScroll();
                      }
                    });
                  },
                  child: Card(
                    elevation: 4.0,
                    margin: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                            banner.imageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Colors.grey[300],
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              print("HomeBannerCarousel: Error loading image ${banner.imageUrl} - $error");
                              return Container(
                                color: Colors.grey[300],
                                child: const Center(
                                    child: Icon(Icons.broken_image_outlined, size: 50, color: Colors.grey)),
                              );
                            }
                        ),
                        if (banner.title != null && banner.title!.isNotEmpty)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12.0, vertical: 10.0),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                    colors: [
                                      Colors.black.withOpacity(0.8),
                                      Colors.black.withOpacity(0.0)
                                    ],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    stops: const [0.0, 0.9]),
                              ),
                              child: Text(
                                banner.title!,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17.0,
                                    fontWeight: FontWeight.w600,
                                    shadows: [Shadow(blurRadius: 2.0, color: Colors.black54)]),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.banners.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.banners.length, (index) {
              return Container(
                width: 8.0,
                height: 8.0,
                margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 3.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == index
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.secondary.withOpacity(0.4),
                ),
              );
            }),
          ),
      ],
    );
  }
}

