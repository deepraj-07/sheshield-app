import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../core/constants/app_colors.dart';

// ── Data model ────────────────────────────────────────────────────────────────

class _HelpPlace {
  final String name;
  final String type; // 'police' | 'hospital' | 'fire_station'
  final double lat;
  final double lng;
  final String? phone;
  final String? address;
  final double distanceKm;

  const _HelpPlace({
    required this.name,
    required this.type,
    required this.lat,
    required this.lng,
    this.phone,
    this.address,
    required this.distanceKm,
  });

  String get mapsUrl => 'https://maps.google.com/?q=$lat,$lng';

  IconData get icon {
    switch (type) {
      case 'police':
        return Icons.local_police_rounded;
      case 'hospital':
        return Icons.local_hospital_rounded;
      case 'fire_station':
        return Icons.local_fire_department_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  Color get color {
    switch (type) {
      case 'police':
        return AppColors.primary;
      case 'hospital':
        return AppColors.danger;
      case 'fire_station':
        return const Color(0xFFEA580C);
      default:
        return AppColors.info;
    }
  }

  String get typeLabel {
    switch (type) {
      case 'police':
        return 'Police Station';
      case 'hospital':
        return 'Hospital';
      case 'fire_station':
        return 'Fire Station';
      default:
        return 'Help';
    }
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class NearbyHelpScreen extends StatefulWidget {
  const NearbyHelpScreen({super.key});

  @override
  State<NearbyHelpScreen> createState() => _NearbyHelpScreenState();
}

class _NearbyHelpScreenState extends State<NearbyHelpScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  double? _lat;
  double? _lng;
  bool _locationLoading = true;
  String? _locationError;

  List<_HelpPlace> _allPlaces = [];
  bool _placesLoading = false;
  String? _placesError;

  static const _radiusM = 5000; // 5 km search radius
  static const _ua = {'User-Agent': 'SheShieldApp/1.0 (safety-app)'};

  final List<String> _tabs = ['All', 'Police', 'Hospital', 'Fire'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _fetchLocation();
    if (_lat != null && _lng != null) {
      await _fetchNearbyPlaces();
    }
  }

  // ── GPS ───────────────────────────────────────────────────────────────────

  Future<void> _fetchLocation() async {
    setState(() {
      _locationLoading = true;
      _locationError = null;
    });
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        setState(() {
          _locationError =
              'Location permission denied permanently.\nPlease enable it in Settings.';
          _locationLoading = false;
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 15));
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _locationLoading = false;
      });
    } catch (e) {
      setState(() {
        _locationError = 'Could not get location: $e';
        _locationLoading = false;
      });
    }
  }

  // ── Overpass API ──────────────────────────────────────────────────────────

  Future<void> _fetchNearbyPlaces() async {
    if (_lat == null || _lng == null) return;
    setState(() {
      _placesLoading = true;
      _placesError = null;
    });

    try {
      final places = <_HelpPlace>[];

      // Fetch police, hospitals, fire stations in one query
      final query = '''
[out:json][timeout:25];
(
  node["amenity"="police"](around:$_radiusM,$_lat,$_lng);
  way["amenity"="police"](around:$_radiusM,$_lat,$_lng);
  node["amenity"="hospital"](around:$_radiusM,$_lat,$_lng);
  way["amenity"="hospital"](around:$_radiusM,$_lat,$_lng);
  node["amenity"="fire_station"](around:$_radiusM,$_lat,$_lng);
  way["amenity"="fire_station"](around:$_radiusM,$_lat,$_lng);
);
out center tags;
''';

      final url = Uri.parse('https://overpass-api.de/api/interpreter');
      final response = await http
          .post(url, headers: _ua, body: query)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Overpass API error: ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final elements = json['elements'] as List<dynamic>;

      for (final el in elements) {
        final tags = el['tags'] as Map<String, dynamic>? ?? {};
        final amenity = tags['amenity'] as String? ?? '';

        // Get coordinates (node has lat/lon directly; way has center)
        double? elLat, elLng;
        if (el['type'] == 'node') {
          elLat = (el['lat'] as num?)?.toDouble();
          elLng = (el['lon'] as num?)?.toDouble();
        } else if (el['center'] != null) {
          elLat = (el['center']['lat'] as num?)?.toDouble();
          elLng = (el['center']['lon'] as num?)?.toDouble();
        }
        if (elLat == null || elLng == null) continue;

        final name = tags['name'] as String? ??
            tags['name:en'] as String? ??
            _defaultName(amenity);

        final phone = tags['phone'] as String? ??
            tags['contact:phone'] as String? ??
            _emergencyNumber(amenity);

        final address = _buildAddress(tags);

        final distKm =
            Geolocator.distanceBetween(_lat!, _lng!, elLat, elLng) / 1000;

        places.add(_HelpPlace(
          name: name,
          type: amenity,
          lat: elLat,
          lng: elLng,
          phone: phone,
          address: address,
          distanceKm: distKm,
        ));
      }

      // Sort by distance
      places.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

      setState(() {
        _allPlaces = places;
        _placesLoading = false;
      });
    } catch (e) {
      setState(() {
        _placesError = 'Could not load nearby places: $e';
        _placesLoading = false;
      });
    }
  }

  String _defaultName(String amenity) {
    switch (amenity) {
      case 'police':
        return 'Police Station';
      case 'hospital':
        return 'Hospital';
      case 'fire_station':
        return 'Fire Station';
      default:
        return 'Help Center';
    }
  }

  String? _emergencyNumber(String amenity) {
    switch (amenity) {
      case 'police':
        return '100';
      case 'hospital':
        return '108';
      case 'fire_station':
        return '101';
      default:
        return null;
    }
  }

  String? _buildAddress(Map<String, dynamic> tags) {
    final parts = <String>[];
    if (tags['addr:housenumber'] != null) parts.add(tags['addr:housenumber']);
    if (tags['addr:street'] != null) parts.add(tags['addr:street']);
    if (tags['addr:city'] != null) parts.add(tags['addr:city']);
    return parts.isEmpty ? null : parts.join(', ');
  }

  List<_HelpPlace> _filtered(int tabIndex) {
    if (tabIndex == 0) return _allPlaces;
    final type = ['', 'police', 'hospital', 'fire_station'][tabIndex];
    return _allPlaces.where((p) => p.type == type).toList();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _call(String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$digits');
    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot call $phone')),
        );
      }
    }
  }

  Future<void> _openMaps(_HelpPlace place) async {
    final uri = Uri.parse(place.mapsUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot open maps')),
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Nearby Help',
            style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _placesLoading ? null : _init,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_locationLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Getting your location...'),
          ],
        ),
      );
    }

    if (_locationError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off_rounded,
                  size: 56, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              Text(_locationError!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _init,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Location banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppColors.primary.withValues(alpha: 0.08),
          child: Row(children: [
            const Icon(Icons.my_location_rounded,
                size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Searching within ${_radiusM ~/ 1000} km of your location',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            if (_placesLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ]),
        ),

        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: List.generate(
              _tabs.length,
              (i) => _buildTabContent(i),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabContent(int tabIndex) {
    if (_placesLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_placesError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 48, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              Text(_placesError!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              ElevatedButton(
                  onPressed: _fetchNearbyPlaces, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final places = _filtered(tabIndex);

    if (places.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              tabIndex == 1
                  ? Icons.local_police_rounded
                  : tabIndex == 2
                      ? Icons.local_hospital_rounded
                      : Icons.local_fire_department_rounded,
              size: 48,
              color: AppColors.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'No ${_tabs[tabIndex].toLowerCase()} found nearby',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Try expanding the search area',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _init,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: places.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _PlaceCard(
          place: places[i],
          onCall:
              places[i].phone != null ? () => _call(places[i].phone!) : null,
          onMap: () => _openMaps(places[i]),
        ),
      ),
    );
  }
}

// ── Place card ────────────────────────────────────────────────────────────────

class _PlaceCard extends StatelessWidget {
  final _HelpPlace place;
  final VoidCallback? onCall;
  final VoidCallback onMap;

  const _PlaceCard({
    required this.place,
    required this.onCall,
    required this.onMap,
  });

  @override
  Widget build(BuildContext context) {
    final distText = place.distanceKm < 1
        ? '${(place.distanceKm * 1000).toInt()} m away'
        : '${place.distanceKm.toStringAsFixed(1)} km away';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: place.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(place.icon, color: place.color, size: 24),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: place.color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      place.typeLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: place.color,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.near_me_rounded,
                      size: 11, color: AppColors.textSecondary),
                  const SizedBox(width: 3),
                  Text(
                    distText,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ]),
                if (place.phone != null) ...[
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.phone_rounded,
                        size: 11, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      place.phone!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ]),
                ],
                if (place.address != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    place.address!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Action buttons
          Column(
            children: [
              if (onCall != null)
                _ActionBtn(
                  icon: Icons.call_rounded,
                  color: AppColors.safe,
                  onTap: onCall!,
                  tooltip: 'Call',
                ),
              if (onCall != null) const SizedBox(height: 8),
              _ActionBtn(
                icon: Icons.map_rounded,
                color: AppColors.info,
                onTap: onMap,
                tooltip: 'Open in Maps',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
