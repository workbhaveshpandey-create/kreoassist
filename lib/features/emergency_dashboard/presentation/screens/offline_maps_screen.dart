import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/widgets/app_notification.dart';

class OfflineMapsScreen extends StatefulWidget {
  const OfflineMapsScreen({super.key});

  @override
  State<OfflineMapsScreen> createState() => _OfflineMapsScreenState();
}

class _OfflineMapsScreenState extends State<OfflineMapsScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  bool _isLoading = true;
  bool _isDownloading = false;
  bool _isSelectingArea = false;
  double _downloadProgress = 0;
  int _cachedTiles = 0;
  String _statusMessage = "Loading map...";
  bool _fmtcInitialized = false;

  // Area selection
  LatLng? _selectionStart;
  LatLng? _selectionEnd;

  // Store reference
  FMTCStore? _store;

  // Animation
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      try {
        await FMTCObjectBoxBackend().initialise();
      } catch (e) {
        debugPrint('FMTC init: $e');
      }
      _fmtcInitialized = true;

      _store = FMTCStore('kreoassist_maps');
      await _store!.manage.create();

      try {
        _cachedTiles = await _store!.stats.length;
      } catch (e) {
        _cachedTiles = 0;
      }

      await _getCurrentLocation();

      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = _cachedTiles > 0
              ? "$_cachedTiles tiles saved"
              : "Ready to download";
        });
      }
    } catch (e) {
      debugPrint('Map init error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _fmtcInitialized = false;
          _statusMessage = "Online mode";
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        ).timeout(const Duration(seconds: 10));

        if (mounted) {
          setState(() {
            _currentLocation = LatLng(position.latitude, position.longitude);
          });
          await Future.delayed(const Duration(milliseconds: 500));
          try {
            _mapController.move(_currentLocation!, 14);
          } catch (e) {
            debugPrint('Map move error: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Location error: $e');
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(20.5937, 78.9629);
        });
      }
    }
  }

  void _startAreaSelection() {
    setState(() {
      _isSelectingArea = true;
      _selectionStart = null;
      _selectionEnd = null;
      _statusMessage = "Tap first corner";
    });

    AppNotification.info(context, "Tap on map to select first corner of area");
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    if (!_isSelectingArea) return;

    if (_selectionStart == null) {
      setState(() {
        _selectionStart = point;
        _statusMessage = "Tap second corner";
      });
      AppNotification.info(context, "Now tap the opposite corner");
    } else if (_selectionEnd == null) {
      setState(() {
        _selectionEnd = point;
        _isSelectingArea = false;
        _statusMessage = "Area selected";
      });
      _showDownloadConfirmation();
    }
  }

  void _showDownloadConfirmation() {
    if (_selectionStart == null || _selectionEnd == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _buildDownloadSheet(ctx),
    );
  }

  Widget _buildDownloadSheet(BuildContext ctx) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E293B),
            const Color(0xFF0F172A),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Icon with glow
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF3B82F6).withOpacity(0.2),
                    const Color(0xFF8B5CF6).withOpacity(0.2),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.download_for_offline_rounded,
                size: 48,
                color: Color(0xFF60A5FA),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              "Download for Offline?",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "This area will be available offline.\nEstimated size: 10-50 MB",
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            Row(
              children: [
                Expanded(
                  child: _buildSheetButton(
                    label: "Cancel",
                    onTap: () {
                      Navigator.pop(ctx);
                      _cancelSelection();
                    },
                    isPrimary: false,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSheetButton(
                    label: "Download",
                    icon: Icons.download_rounded,
                    onTap: () {
                      Navigator.pop(ctx);
                      _downloadSelectedArea();
                    },
                    isPrimary: true,
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetButton({
    required String label,
    IconData? icon,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                )
              : null,
          color: isPrimary ? null : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                isPrimary ? Colors.transparent : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: isPrimary ? Colors.white : Colors.white70,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _cancelSelection() {
    setState(() {
      _selectionStart = null;
      _selectionEnd = null;
      _statusMessage =
          _cachedTiles > 0 ? "$_cachedTiles tiles saved" : "Ready to download";
    });
  }

  Future<void> _downloadSelectedArea() async {
    if (!_fmtcInitialized || _store == null) {
      AppNotification.error(context, "Offline caching not available");
      return;
    }

    if (_selectionStart == null || _selectionEnd == null) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _statusMessage = "Preparing...";
    });

    try {
      final bounds = LatLngBounds(
        LatLng(
          _selectionStart!.latitude < _selectionEnd!.latitude
              ? _selectionStart!.latitude
              : _selectionEnd!.latitude,
          _selectionStart!.longitude < _selectionEnd!.longitude
              ? _selectionStart!.longitude
              : _selectionEnd!.longitude,
        ),
        LatLng(
          _selectionStart!.latitude > _selectionEnd!.latitude
              ? _selectionStart!.latitude
              : _selectionEnd!.latitude,
          _selectionStart!.longitude > _selectionEnd!.longitude
              ? _selectionStart!.longitude
              : _selectionEnd!.longitude,
        ),
      );

      final region = RectangleRegion(bounds);
      final downloadable = region.toDownloadable(
        minZoom: 10,
        maxZoom: 16,
        options: TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.kreoassist',
        ),
      );

      int downloaded = 0;
      const estimatedTiles = 500;

      setState(() {
        _statusMessage = "Downloading...";
      });

      await _store!.download
          .startForeground(
        region: downloadable,
        parallelThreads: 3,
        maxBufferLength: 100,
        skipExistingTiles: true,
      )
          .listen(
        (progress) {
          downloaded++;
          if (mounted && downloaded % 10 == 0) {
            setState(() {
              _downloadProgress = (downloaded / estimatedTiles).clamp(0.0, 1.0);
              _statusMessage = "Downloaded $downloaded tiles";
            });
          }
        },
        onError: (e) {
          debugPrint('Download error: $e');
        },
      ).asFuture();

      try {
        _cachedTiles = await _store!.stats.length;
      } catch (e) {
        // Ignore
      }

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _selectionStart = null;
          _selectionEnd = null;
          _statusMessage = "$_cachedTiles tiles saved";
        });

        AppNotification.success(context, "Area saved for offline use!");
      }
    } catch (e) {
      debugPrint('Download error: $e');
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusMessage = "Download failed";
          _selectionStart = null;
          _selectionEnd = null;
        });
        AppNotification.error(context, "Download failed. Try again.");
      }
    }
  }

  Future<void> _clearCache() async {
    if (_store == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF2F1A1A),
              const Color(0xFF1A0F0F),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.red.withOpacity(0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_forever_rounded,
                    size: 40, color: Color(0xFFF87171)),
              ),
              const SizedBox(height: 16),
              const Text(
                "Clear Map Cache?",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "This will delete $_cachedTiles cached tiles.\nYou'll need to re-download for offline use.",
                style: TextStyle(color: Colors.white60, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildSheetButton(
                      label: "Keep",
                      onTap: () => Navigator.pop(ctx),
                      isPrimary: false,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _store!.manage.reset();
                        setState(() {
                          _cachedTiles = 0;
                          _statusMessage = "Cache cleared";
                        });
                        if (mounted) {
                          AppNotification.success(context, "Cache cleared");
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF87171),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_rounded,
                                color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              "Clear",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          // Map
          if (!_isLoading)
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentLocation ?? LatLng(20.5937, 78.9629),
                initialZoom: 12,
                minZoom: 3,
                maxZoom: 18,
                onTap: _onMapTap,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.kreoassist',
                  tileProvider: _fmtcInitialized && _store != null
                      ? _store!.getTileProvider()
                      : NetworkTileProvider(),
                ),
                if (_selectionStart != null)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: _getSelectionPoints(),
                        color: const Color(0xFF3B82F6).withOpacity(0.2),
                        borderColor: const Color(0xFF3B82F6),
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                if (_currentLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentLocation!,
                        width: 80,
                        height: 80,
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                // Outer pulse
                                Container(
                                  width: 60 + (_pulseController.value * 20),
                                  height: 60 + (_pulseController.value * 20),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF3B82F6).withOpacity(
                                        0.1 - (_pulseController.value * 0.1)),
                                  ),
                                ),
                                // Middle ring
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF3B82F6)
                                        .withOpacity(0.2),
                                  ),
                                ),
                                // Center dot
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF3B82F6),
                                    border: Border.all(
                                        color: Colors.white, width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF3B82F6)
                                            .withOpacity(0.5),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
              ],
            ),

          // Loading
          if (_isLoading)
            Container(
              color: const Color(0xFF0A0A0A),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const CircularProgressIndicator(
                        color: Color(0xFF3B82F6),
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Loading Map...",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Top bar with glassmorphism
          _buildTopBar(),

          // Download progress overlay
          if (_isDownloading) _buildDownloadOverlay(),

          // Bottom controls
          if (!_isLoading) _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              children: [
                // Back button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
                const SizedBox(width: 12),

                // Title & Status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Offline Maps",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _cachedTiles > 0
                                  ? const Color(0xFF4ADE80)
                                  : _isSelectingArea
                                      ? const Color(0xFF60A5FA)
                                      : Colors.orange,
                              boxShadow: [
                                BoxShadow(
                                  color: (_cachedTiles > 0
                                          ? const Color(0xFF4ADE80)
                                          : Colors.orange)
                                      .withOpacity(0.5),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _statusMessage,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Clear cache button
                if (_cachedTiles > 0)
                  GestureDetector(
                    onTap: _clearCache,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.delete_outline_rounded,
                          color: Color(0xFFF87171), size: 22),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: -0.2);
  }

  Widget _buildDownloadOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1E293B),
                  const Color(0xFF0F172A),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withOpacity(0.2),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: _downloadProgress,
                        strokeWidth: 6,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF3B82F6)),
                      ),
                    ),
                    Text(
                      "${(_downloadProgress * 100).toInt()}%",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  "Downloading Map Tiles",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _statusMessage,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.8),
                  Colors.black.withOpacity(0.4),
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              children: [
                // Quick actions
                Row(
                  children: [
                    _buildQuickAction(
                      icon: Icons.my_location_rounded,
                      label: "My Location",
                      onTap: () {
                        _getCurrentLocation();
                        if (_currentLocation != null) {
                          try {
                            _mapController.move(_currentLocation!, 14);
                          } catch (e) {
                            debugPrint('Map move error: $e');
                          }
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    _buildQuickAction(
                      icon: Icons.zoom_in_rounded,
                      label: "Zoom In",
                      onTap: () {
                        try {
                          _mapController.move(
                            _mapController.camera.center,
                            _mapController.camera.zoom + 1,
                          );
                        } catch (e) {
                          debugPrint('Zoom error: $e');
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    _buildQuickAction(
                      icon: Icons.zoom_out_rounded,
                      label: "Zoom Out",
                      onTap: () {
                        try {
                          _mapController.move(
                            _mapController.camera.center,
                            _mapController.camera.zoom - 1,
                          );
                        } catch (e) {
                          debugPrint('Zoom error: $e');
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Main action button
                if (!_isDownloading)
                  GestureDetector(
                    onTap: _isSelectingArea
                        ? _cancelSelection
                        : _startAreaSelection,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        gradient: _isSelectingArea
                            ? null
                            : const LinearGradient(
                                colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                              ),
                        color: _isSelectingArea
                            ? Colors.white.withOpacity(0.1)
                            : null,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isSelectingArea
                              ? Colors.white24
                              : Colors.transparent,
                        ),
                        boxShadow: _isSelectingArea
                            ? null
                            : [
                                BoxShadow(
                                  color:
                                      const Color(0xFF3B82F6).withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isSelectingArea
                                ? Icons.close_rounded
                                : Icons.crop_free_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _isSelectingArea
                                ? "Cancel Selection"
                                : "Select Area to Download",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2);
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white70, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<LatLng> _getSelectionPoints() {
    if (_selectionStart == null) return [];
    final end = _selectionEnd ?? _selectionStart!;
    return [
      _selectionStart!,
      LatLng(_selectionStart!.latitude, end.longitude),
      end,
      LatLng(end.latitude, _selectionStart!.longitude),
    ];
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }
}
