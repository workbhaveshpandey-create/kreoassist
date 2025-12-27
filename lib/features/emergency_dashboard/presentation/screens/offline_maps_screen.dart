import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class OfflineMapsScreen extends StatefulWidget {
  const OfflineMapsScreen({super.key});

  @override
  State<OfflineMapsScreen> createState() => _OfflineMapsScreenState();
}

class _OfflineMapsScreenState extends State<OfflineMapsScreen> {
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

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      // Initialize FMTC with error handling (may already be initialized)
      try {
        await FMTCObjectBoxBackend().initialise();
      } catch (e) {
        // Already initialized is OK
        debugPrint('FMTC init: $e');
      }
      _fmtcInitialized = true;

      // Create or get store
      _store = FMTCStore('kreoassist_maps');
      await _store!.manage.create();

      // Get cached tile count
      try {
        _cachedTiles = await _store!.stats.length;
      } catch (e) {
        _cachedTiles = 0;
      }

      // Get current location
      await _getCurrentLocation();

      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = _cachedTiles > 0
              ? "$_cachedTiles tiles cached"
              : "Tap 'Select Area' to download";
        });
      }
    } catch (e) {
      debugPrint('Map init error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _fmtcInitialized = false;
          _statusMessage = "Online mode (caching unavailable)";
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
          // Delay to ensure map is ready
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
      // Default to India center
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
      _statusMessage = "Tap two corners to select area";
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Tap on map to select first corner"),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF2196F3),
      ),
    );
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    if (!_isSelectingArea) return;

    if (_selectionStart == null) {
      setState(() {
        _selectionStart = point;
        _statusMessage = "Now tap second corner";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Now tap the opposite corner"),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    } else if (_selectionEnd == null) {
      setState(() {
        _selectionEnd = point;
        _isSelectingArea = false;
        _statusMessage = "Area selected! Ready to download";
      });
      _showDownloadConfirmation();
    }
  }

  void _showDownloadConfirmation() {
    if (_selectionStart == null || _selectionEnd == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.download_for_offline,
                size: 48, color: Color(0xFF4CAF50)),
            const SizedBox(height: 16),
            const Text(
              "Download Selected Area?",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "This will download map tiles for offline use.\nEstimated size: 10-50 MB depending on area.",
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _selectionStart = null;
                        _selectionEnd = null;
                        _statusMessage = _cachedTiles > 0
                            ? "$_cachedTiles tiles cached"
                            : "Tap 'Select Area' to download";
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text("Cancel"),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _downloadSelectedArea();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.download),
                    label: const Text("Download"),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadSelectedArea() async {
    if (!_fmtcInitialized || _store == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Offline caching not available"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectionStart == null || _selectionEnd == null) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _statusMessage = "Preparing download...";
    });

    try {
      // Create bounds from selection
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

      // Download tiles for zoom levels 10-16
      final downloadable = region.toDownloadable(
        minZoom: 10,
        maxZoom: 16,
        options: TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.kreoassist',
        ),
      );

      int downloaded = 0;
      // Estimate based on zoom levels and area size
      const estimatedTiles = 500; // Safe default

      if (estimatedTiles > 10000) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Area too large! Please select smaller area."),
              backgroundColor: Colors.orange,
            ),
          );
          setState(() {
            _isDownloading = false;
            _selectionStart = null;
            _selectionEnd = null;
            _statusMessage = "Select a smaller area";
          });
        }
        return;
      }

      setState(() {
        _statusMessage = "Downloading tiles...";
      });

      // Start download
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
              _downloadProgress = downloaded / estimatedTiles;
              _statusMessage = "Downloaded $downloaded tiles...";
            });
          }
        },
        onError: (e) {
          debugPrint('Download stream error: $e');
        },
      ).asFuture();

      // Update stats
      try {
        _cachedTiles = await _store!.stats.length;
      } catch (e) {
        // Ignore stats error
      }

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _selectionStart = null;
          _selectionEnd = null;
          _statusMessage = "✅ $_cachedTiles tiles cached";
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ Downloaded $downloaded tiles!"),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Download failed: ${e.toString().substring(0, 50)}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearCache() async {
    if (_store == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Clear Map Cache?",
            style: TextStyle(color: Colors.white)),
        content: Text(
          "This will delete $_cachedTiles cached tiles.",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Clear"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _store!.manage.reset();
        if (mounted) {
          setState(() {
            _cachedTiles = 0;
            _statusMessage = "Cache cleared";
          });
        }
      } catch (e) {
        debugPrint('Clear cache error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("Offline Maps"),
        backgroundColor: const Color(0xFF1A1A1A),
        actions: [
          if (_cachedTiles > 0)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _clearCache,
              tooltip: "Clear cache",
            ),
        ],
      ),
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
                // Tile Layer with caching
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.kreoassist',
                  tileProvider: _fmtcInitialized && _store != null
                      ? _store!.getTileProvider()
                      : NetworkTileProvider(),
                ),

                // Selection rectangle
                if (_selectionStart != null)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: _getSelectionPoints(),
                        color: const Color(0xFF4CAF50).withOpacity(0.2),
                        borderColor: const Color(0xFF4CAF50),
                        borderStrokeWidth: 3,
                      ),
                    ],
                  ),

                // Current location marker
                if (_currentLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentLocation!,
                        width: 60,
                        height: 60,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF2196F3).withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.my_location,
                              color: Color(0xFF2196F3),
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: const Color(0xFF121212),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF4CAF50)),
                    SizedBox(height: 16),
                    Text("Loading map...",
                        style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),

          // Top status bar
          if (!_isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isSelectingArea
                          ? const Color(0xFF2196F3).withOpacity(0.2)
                          : _cachedTiles > 0
                              ? const Color(0xFF4CAF50).withOpacity(0.2)
                              : Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isSelectingArea
                            ? const Color(0xFF2196F3)
                            : _cachedTiles > 0
                                ? const Color(0xFF4CAF50)
                                : Colors.orange,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isSelectingArea
                              ? Icons.touch_app
                              : _cachedTiles > 0
                                  ? Icons.cloud_done
                                  : Icons.cloud_off,
                          size: 16,
                          color: _isSelectingArea
                              ? const Color(0xFF2196F3)
                              : _cachedTiles > 0
                                  ? const Color(0xFF4CAF50)
                                  : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _statusMessage,
                          style: TextStyle(
                            color: _isSelectingArea
                                ? const Color(0xFF2196F3)
                                : _cachedTiles > 0
                                    ? const Color(0xFF4CAF50)
                                    : Colors.orange,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 300.ms),

          // Download progress overlay
          if (_isDownloading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(32),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.download,
                          color: Color(0xFF4CAF50), size: 48),
                      const SizedBox(height: 16),
                      Text(
                        _statusMessage,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: _downloadProgress,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF4CAF50)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${(_downloadProgress * 100).toInt()}%",
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom controls
          if (!_isLoading)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.9),
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      // Area selection button
                      if (!_isDownloading)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed:
                                _isSelectingArea ? null : _startAreaSelection,
                            style: FilledButton.styleFrom(
                              backgroundColor: _isSelectingArea
                                  ? Colors.grey
                                  : const Color(0xFF4CAF50),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: Icon(
                              _isSelectingArea
                                  ? Icons.touch_app
                                  : Icons.crop_free,
                            ),
                            label: Text(
                              _isSelectingArea
                                  ? "Selecting Area..."
                                  : "Select Area to Download",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                      if (_isSelectingArea) ...[
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _isSelectingArea = false;
                              _selectionStart = null;
                              _selectionEnd = null;
                              _statusMessage = _cachedTiles > 0
                                  ? "$_cachedTiles tiles cached"
                                  : "Tap 'Select Area' to download";
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                          ),
                          child: const Text("Cancel Selection"),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
        ],
      ),
      floatingActionButton: !_isLoading && !_isDownloading
          ? FloatingActionButton(
              onPressed: () {
                _getCurrentLocation();
                if (_currentLocation != null) {
                  _mapController.move(_currentLocation!, 14);
                }
              },
              backgroundColor: const Color(0xFF2196F3),
              child: const Icon(Icons.gps_fixed, color: Colors.white),
            )
          : null,
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
    _mapController.dispose();
    super.dispose();
  }
}
