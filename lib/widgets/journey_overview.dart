import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/constants/app_colors.dart';

class JourneyOverview extends StatefulWidget {
  const JourneyOverview({super.key});

  @override
  State<JourneyOverview> createState() => _JourneyOverviewState();
}

class _JourneyOverviewState extends State<JourneyOverview> {
  String _currentAddress = 'Fetching location...';
  LatLng? _currentLatLng;
  bool _locationLoading = true;
  final TextEditingController _destCtrl = TextEditingController();
  LatLng? _destLatLng;
  String _destAddress = '';
  bool _geocoding = false;
  List<LatLng> _routePoints = [];
  bool _routeLoading = false;
  String? _routeDistance;
  String? _routeDuration;
  final MapController _mapController = MapController();
  int _selectedRoute = 0;

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  @override
  void dispose() {
    _destCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() => _locationLoading = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        setState(() {
          _currentAddress = 'Location permission denied';
          _locationLoading = false;
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final latlng = LatLng(pos.latitude, pos.longitude);
      final address = await _reverseGeocode(latlng);
      if (!mounted) return;
      setState(() {
        _currentLatLng = latlng;
        _currentAddress = address;
        _locationLoading = false;
      });
      _mapController.move(latlng, 14);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _currentAddress = 'Unable to fetch location';
        _locationLoading = false;
      });
    }
  }

  static const _ua = {'User-Agent': 'SheShieldApp/1.0 (safety-app)'};

  Future<String> _reverseGeocode(LatLng p) async {
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse'
          '?lat=${p.latitude}&lon=${p.longitude}&format=json');
      final res = await http.get(url, headers: _ua).timeout(const Duration(seconds: 8));
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      return j['display_name'] as String? ??
          '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';
    } catch (_) {
      return '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';
    }
  }

  Future<LatLng?> _geocodeAddress(String address) async {
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search'
          '?q=${Uri.encodeComponent(address)}&format=json&limit=1');
      final res = await http.get(url, headers: _ua).timeout(const Duration(seconds: 8));
      final list = jsonDecode(res.body) as List<dynamic>;
      if (list.isEmpty) return null;
      final f = list[0] as Map<String, dynamic>;
      return LatLng(double.parse(f['lat'] as String), double.parse(f['lon'] as String));
    } catch (_) {
      return null;
    }
  }

  Future<void> _fetchRoute(LatLng origin, LatLng dest) async {
    setState(() => _routeLoading = true);
    try {
      final url = Uri.parse('https://router.project-osrm.org/route/v1/driving/'
          '${origin.longitude},${origin.latitude};'
          '${dest.longitude},${dest.latitude}'
          '?overview=full&geometries=geojson');
      final res = await http.get(url, headers: _ua).timeout(const Duration(seconds: 12));
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      if (j['code'] == 'Ok') {
        final route = (j['routes'] as List<dynamic>)[0] as Map<String, dynamic>;
        final coords = (route['geometry']['coordinates'] as List<dynamic>).map((c) {
          final arr = c as List<dynamic>;
          return LatLng((arr[1] as num).toDouble(), (arr[0] as num).toDouble());
        }).toList();
        final distM = (route['distance'] as num).toDouble();
        final durS = (route['duration'] as num).toDouble();
        final dist = distM >= 1000
            ? '${(distM / 1000).toStringAsFixed(1)} km'
            : '${distM.toInt()} m';
        final dur = durS >= 3600
            ? '${(durS / 3600).toStringAsFixed(1)} hr'
            : '${(durS / 60).toInt()} min';
        if (!mounted) return;
        setState(() {
          _routePoints = coords;
          _routeDistance = dist;
          _routeDuration = dur;
          _routeLoading = false;
        });
        if (coords.isNotEmpty) {
          final lats = coords.map((p) => p.latitude);
          final lngs = coords.map((p) => p.longitude);
          _mapController.fitCamera(CameraFit.bounds(
            bounds: LatLngBounds(
              LatLng(lats.reduce((a, b) => a < b ? a : b), lngs.reduce((a, b) => a < b ? a : b)),
              LatLng(lats.reduce((a, b) => a > b ? a : b), lngs.reduce((a, b) => a > b ? a : b)),
            ),
            padding: const EdgeInsets.all(60),
          ));
        }
      } else {
        if (!mounted) return;
        setState(() => _routeLoading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _routeLoading = false);
    }
  }

  Future<void> _setDestination() async {
    final text = _destCtrl.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _geocoding = true);
    final latlng = await _geocodeAddress(text);
    if (!mounted) return;
    if (latlng == null) {
      setState(() => _geocoding = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Location not found. Try a more specific address.')));
      return;
    }
    setState(() {
      _destLatLng = latlng;
      _destAddress = text;
      _geocoding = false;
      _routePoints = [];
      _routeDistance = null;
      _routeDuration = null;
    });
    if (_currentLatLng != null) {
      await _fetchRoute(_currentLatLng!, latlng);
    } else {
      _mapController.move(latlng, 14);
    }
  }

  void _clearDestination() {
    _destCtrl.clear();
    setState(() {
      _destLatLng = null;
      _destAddress = '';
      _routePoints = [];
      _routeDistance = null;
      _routeDuration = null;
    });
    if (_currentLatLng != null) _mapController.move(_currentLatLng!, 14);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Journey Mode',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    )),
            const SizedBox(height: 18),
            _Panel(child: _buildPlanPanel()),
            const SizedBox(height: 16),
            _Panel(child: _buildMap()),
            const SizedBox(height: 16),
            _Panel(child: _buildRouteOptions()),
            const SizedBox(height: 16),
            _Panel(child: _buildSafetyScore()),
            const SizedBox(height: 16),
            _Panel(child: _buildGeofence()),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_currentLatLng != null && _destLatLng != null) ? () {} : null,
                icon: const Icon(Icons.navigation_rounded),
                label: Text(_destAddress.isEmpty ? 'Set destination first' : 'Start Journey'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Plan Your Journey',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 18),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _dot(const Color(0xFF7C3AED)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('From',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              _locationLoading
                  ? const Row(children: [
                      SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 8),
                      Text('Fetching GPS...'),
                    ])
                  : Row(children: [
                      Expanded(
                        child: Text(_currentAddress,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        color: AppColors.primary,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: _fetchCurrentLocation,
                      ),
                    ]),
            ]),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 6, bottom: 6),
          child: Container(width: 2, height: 20, color: AppColors.border),
        ),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          _dot(const Color(0xFFE94B4B)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('To',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _destCtrl,
                    decoration: InputDecoration(
                      hintText: 'Enter destination...',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      suffixIcon: _destCtrl.text.isNotEmpty
                          ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: _clearDestination)
                          : null,
                    ),
                    onSubmitted: (_) => _setDestination(),
                    textInputAction: TextInputAction.search,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: _geocoding ? null : _setDestination,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _geocoding
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.search_rounded, size: 18),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
        if (_routeDistance != null && _routeDuration != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _InfoChip(icon: Icons.route_rounded, label: _routeDistance!),
                Container(width: 1, height: 24, color: AppColors.border),
                _InfoChip(icon: Icons.access_time_rounded, label: _routeDuration!),
                Container(width: 1, height: 24, color: AppColors.border),
                const _InfoChip(icon: Icons.shield_rounded, label: 'Safe route'),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMap() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 280,
        child: Stack(children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLatLng ?? const LatLng(28.6139, 77.2090),
              initialZoom: 13,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.sheshield.app',
                maxZoom: 19,
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(polylines: [
                  Polyline(points: _routePoints, color: AppColors.primary, strokeWidth: 4.5),
                ]),
              MarkerLayer(markers: [
                if (_currentLatLng != null)
                  Marker(
                    point: _currentLatLng!,
                    width: 40,
                    height: 40,
                    child: _MapMarker(color: const Color(0xFF7C3AED), icon: Icons.my_location_rounded),
                  ),
                if (_destLatLng != null)
                  Marker(
                    point: _destLatLng!,
                    width: 40,
                    height: 40,
                    child: _MapMarker(color: AppColors.danger, icon: Icons.location_on_rounded),
                  ),
              ]),
            ],
          ),
          if (_routeLoading)
            Positioned(
              top: 10, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('Finding route...', style: TextStyle(fontSize: 12)),
                  ]),
                ),
              ),
            ),
          Positioned(
            bottom: 12, right: 12,
            child: FloatingActionButton.small(
              heroTag: 'locate_btn',
              backgroundColor: Colors.white,
              onPressed: () {
                if (_currentLatLng != null) {
                  _mapController.move(_currentLatLng!, 15);
                } else {
                  _fetchCurrentLocation();
                }
              },
              child: const Icon(Icons.my_location_rounded, color: AppColors.primary, size: 20),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildRouteOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Route Options',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        _RouteOption(
          color: const Color(0xFF22C55E),
          title: 'Safest',
          subtitle: _routeDuration != null ? '~$_routeDuration' : '-- min',
          badge: 'Recommended',
          badgeColor: const Color(0xFFDCFCE7),
          badgeTextColor: const Color(0xFF16A34A),
          selected: _selectedRoute == 0,
          onTap: () => setState(() => _selectedRoute = 0),
        ),
        const SizedBox(height: 10),
        _RouteOption(
          color: const Color(0xFFEAB308),
          title: 'Balanced',
          subtitle: _routeDuration != null ? '~$_routeDuration' : '-- min',
          badge: 'Moderate',
          badgeColor: const Color(0xFFFEF3C7),
          badgeTextColor: const Color(0xFFB45309),
          selected: _selectedRoute == 1,
          onTap: () => setState(() => _selectedRoute = 1),
        ),
        const SizedBox(height: 10),
        _RouteOption(
          color: const Color(0xFFEF4444),
          title: 'Fastest',
          subtitle: _routeDuration != null ? '~$_routeDuration' : '-- min',
          badge: 'Risky',
          badgeColor: const Color(0xFFFEE2E2),
          badgeTextColor: const Color(0xFFDC2626),
          selected: _selectedRoute == 2,
          onTap: () => setState(() => _selectedRoute = 2),
        ),
      ],
    );
  }

  Widget _buildSafetyScore() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Route Safety Score',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('7.5',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  )),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('/10',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    )),
          ),
        ]),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: const LinearProgressIndicator(
            value: 0.75,
            minHeight: 8,
            backgroundColor: Color(0xFFE5E7EB),
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
        const SizedBox(height: 18),
        const _SafetyLine(label: 'Lighting', value: 'Good', stars: 4),
        const SizedBox(height: 8),
        const _SafetyLine(label: 'Crowd', value: 'Moderate', stars: 3),
        const SizedBox(height: 8),
        const _SafetyLine(label: 'Crime History', value: 'Low', stars: 5),
      ],
    );
  }

  Widget _buildGeofence() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Geofence Alerts',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        _GeofenceRow(
          title: 'Alert if I deviate route',
          subtitle: '200m deviation triggers SMS',
          enabled: true,
          onChanged: (_) {},
        ),
        const SizedBox(height: 14),
        _GeofenceRow(
          title: 'Alert if I stop >5 min',
          subtitle: 'Auto notify contacts',
          enabled: true,
          onChanged: (_) {},
        ),
      ],
    );
  }

  Widget _dot(Color color) => Container(
        width: 10,
        height: 10,
        margin: const EdgeInsets.only(top: 5),
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}

// =============================================================================
// Helper widgets
// =============================================================================

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }
}

class _MapMarker extends StatelessWidget {
  final Color color;
  final IconData icon;
  const _MapMarker({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 1)],
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: AppColors.primary),
      const SizedBox(width: 5),
      Text(label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              )),
    ]);
  }
}

class _RouteOption extends StatelessWidget {
  final Color color;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final Color badgeTextColor;
  final bool selected;
  final VoidCallback? onTap;

  const _RouteOption({
    required this.color,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.badgeTextColor,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF5EEFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.primary.withValues(alpha: 0.35) : AppColors.border,
          ),
        ),
        child: Row(children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            Text(subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          ]),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(999)),
            child: Text(badge,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: badgeTextColor,
                      fontWeight: FontWeight.w700,
                    )),
          ),
          if (selected) ...[
            const SizedBox(width: 10),
            const Icon(Icons.check_circle_rounded, color: AppColors.primary),
          ],
        ]),
      ),
    );
  }
}

class _SafetyLine extends StatelessWidget {
  final String label;
  final String value;
  final int stars;
  const _SafetyLine({required this.label, required this.value, required this.stars});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(
          width: 92,
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
      Expanded(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
              5,
              (i) => Icon(
                    i < stars ? Icons.star_rounded : Icons.star_border_rounded,
                    color: const Color(0xFFF4B63F),
                    size: 18,
                  )),
        ),
      ),
      SizedBox(
        width: 82,
        child: Text(value,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                )),
      ),
    ]);
  }
}

class _GeofenceRow extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _GeofenceRow({
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onChanged,
  });

  @override
  State<_GeofenceRow> createState() => _GeofenceRowState();
}

class _GeofenceRowState extends State<_GeofenceRow> {
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _enabled = widget.enabled;
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(widget.subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
        ]),
      ),
      Switch.adaptive(
          value: _enabled,
          onChanged: (v) {
            setState(() => _enabled = v);
            widget.onChanged(v);
          }),
    ]);
  }
}

