import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';

/// A local wildlife warning event emitted when a visitor approaches or enters
/// a warning area. The coordinates are reference areas, not live animal data.
class WildlifeAlertEvent {
  final String zoneId;
  final String zoneName;
  final String hazardType;
  final bool entered;
  final double distanceMeters;

  const WildlifeAlertEvent({
    required this.zoneId,
    required this.zoneName,
    required this.hazardType,
    required this.entered,
    required this.distanceMeters,
  });
}

class _WildlifeZone {
  final String id;
  final String name;
  final String type;
  final double latitude;
  final double longitude;
  final double warningRadiusMeters;

  const _WildlifeZone({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.warningRadiusMeters,
  });
}

class _WildlifeLine {
  final String id;
  final String name;
  final String type;
  final List<({double latitude, double longitude})> points;
  final double warningRadiusMeters;

  const _WildlifeLine({
    required this.id,
    required this.name,
    required this.type,
    required this.points,
    required this.warningRadiusMeters,
  });
}

/// Offline geofence monitor for the wildlife areas shown on the Sigiriya map.
/// On Android, a visible location service keeps the stream active in background.
class WildlifeAlertService {
  WildlifeAlertService._();

  static final WildlifeAlertService instance = WildlifeAlertService._();

  static const _wildlifeAsset = 'assets/vectors/sigiriya_wildlife_areas.json';
  static const _notificationChannelId = 'wildlife_alerts_v2';
  static const _notificationChannelName = 'Wildlife Alerts';
  static const _mapNotificationPayload = 'open_wildlife_map';
  static const _approachRadiusExtraMeters = 80.0;
  static const _exitHysteresisMeters = 30.0;
  static const _minimumUsefulAccuracyMeters = 100.0;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final Map<String, bool> _insideState = {};
  final Set<String> _approachNotified = {};
  final Map<String, DateTime> _lastEntryAlert = {};
  final StreamController<WildlifeAlertEvent> _events =
      StreamController<WildlifeAlertEvent>.broadcast();
  final StreamController<void> _mapOpenRequests =
      StreamController<void>.broadcast();

  StreamSubscription<Position>? _positionSubscription;
  List<_WildlifeZone> _zones = const [];
  List<_WildlifeLine> _lines = const [];
  bool _initialized = false;
  bool _running = false;
  Future<bool>? _startFuture;

  Stream<WildlifeAlertEvent> get events => _events.stream;
  Stream<void> get mapOpenRequests => _mapOpenRequests.stream;
  bool get isRunning => _running;

  Future<bool> wasLaunchedFromWarningNotification() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.macOS)) {
      return false;
    }
    final details = await _notifications.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp == true &&
        details?.notificationResponse?.payload == _mapNotificationPayload;
  }

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      await _notifications.initialize(
        settings,
        onDidReceiveNotificationResponse: (response) {
          if (response.payload == _mapNotificationPayload &&
              !_mapOpenRequests.isClosed) {
            _mapOpenRequests.add(null);
          }
        },
      );
    }
    await _loadWarningAreas();
    _initialized = true;
  }

  /// Starts monitoring and checks the current position immediately.
  /// The app root calls this when the application becomes active; the map is
  /// only a visualization and is not required for safety alerts.
  Future<bool> start({bool notifyIfInside = false}) async {
    final pending = _startFuture;
    if (pending != null) {
      final started = await pending;
      if (started && notifyIfInside) {
        await checkCurrentPosition(notifyIfInside: true);
      }
      return started;
    }
    final operation = _startMonitoring(notifyIfInside: notifyIfInside);
    _startFuture = operation;
    try {
      return await operation;
    } finally {
      _startFuture = null;
    }
  }

  Future<bool> _startMonitoring({required bool notifyIfInside}) async {
    await initialize();
    if (_running) {
      await checkCurrentPosition(notifyIfInside: notifyIfInside);
      return true;
    }

    final locationEnabled = await Geolocator.isLocationServiceEnabled();
    if (!locationEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    await _requestNotificationPermission();

    final locationSettings = !kIsWeb &&
            defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'HeritageAR wildlife alerts active',
              notificationText: 'Checking nearby warning areas using GPS',
              notificationChannelName: 'Location monitoring',
              enableWakeLock: true,
            ),
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          );
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(_handlePosition);
    _running = true;
    await checkCurrentPosition(notifyIfInside: notifyIfInside);
    return true;
  }

  /// Performs a one-shot foreground check for users who are already inside a
  /// warning area when the app opens or returns from the background.
  Future<void> checkCurrentPosition({bool notifyIfInside = false}) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      _handlePosition(position, notifyIfInside: notifyIfInside);
    } catch (_) {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        _handlePosition(lastKnown, notifyIfInside: notifyIfInside);
      }
    }
  }

  Future<void> stop() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _running = false;
    _insideState.clear();
    _approachNotified.clear();
    _lastEntryAlert.clear();
  }

  Future<void> dispose() async {
    await stop();
    await _events.close();
    await _mapOpenRequests.close();
    await _notifications.cancelAll();
  }

  Future<void> _requestNotificationPermission() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    final iOS = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await iOS?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> _loadWarningAreas() async {
    final raw = await rootBundle.loadString(_wildlifeAsset);
    final document = jsonDecode(raw) as Map<String, dynamic>;
    final areas = document['areas'] as List<dynamic>? ?? const [];

    final zones = <_WildlifeZone>[];
    final lines = <_WildlifeLine>[];
    for (final item in areas) {
      final area = item as Map<String, dynamic>;
      final geometry = area['geometry'];
      final type =
          area['subtype']?.toString() ?? area['type']?.toString() ?? '';
      final id = area['id'].toString();
      final name = area['name'].toString();
      final radius = (area['warning_radius_meters'] as num?)?.toDouble() ?? 90;

      if (geometry is Map<String, dynamic> &&
          geometry['type'] == 'LineString') {
        final coordinates =
            geometry['coordinates'] as List<dynamic>? ?? const [];
        final points = <({double latitude, double longitude})>[];
        for (final coordinate in coordinates) {
          final pair = coordinate as List<dynamic>;
          if (pair.length < 2) continue;
          points.add((
            latitude: (pair[1] as num).toDouble(),
            longitude: (pair[0] as num).toDouble(),
          ));
        }
        if (points.length >= 2) {
          lines.add(_WildlifeLine(
            id: id,
            name: name,
            type: type,
            points: points,
            warningRadiusMeters: 35,
          ));
        }
        continue;
      }

      final latitude = (area['latitude'] as num?)?.toDouble();
      final longitude = (area['longitude'] as num?)?.toDouble();
      if (latitude == null || longitude == null) continue;
      zones.add(_WildlifeZone(
        id: id,
        name: name,
        type: type,
        latitude: latitude,
        longitude: longitude,
        warningRadiusMeters: radius,
      ));
    }

    // Temporary GPS test area requested for checking notifications on-device.
    zones.add(const _WildlifeZone(
      id: 'gps_notification_test',
      name: 'GPS notification test area',
      type: 'test',
      latitude: 8.232755,
      longitude: 80.428614,
      warningRadiusMeters: 90,
    ));
    _zones = zones;
    _lines = lines;
  }

  void _handlePosition(Position position, {bool notifyIfInside = false}) {
    if (position.accuracy <= 0 ||
        position.accuracy > _minimumUsefulAccuracyMeters) {
      return;
    }

    for (final zone in _zones) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        zone.latitude,
        zone.longitude,
      );
      _evaluateArea(
        id: zone.id,
        name: zone.name,
        type: zone.type,
        distanceMeters: distance,
        warningRadiusMeters: zone.warningRadiusMeters,
        notifyIfInside: notifyIfInside,
      );
    }

    for (final line in _lines) {
      final distance = _distanceToLineMeters(position, line.points);
      _evaluateArea(
        id: line.id,
        name: line.name,
        type: line.type,
        distanceMeters: distance,
        warningRadiusMeters: line.warningRadiusMeters,
        notifyIfInside: notifyIfInside,
      );
    }
  }

  void _evaluateArea({
    required String id,
    required String name,
    required String type,
    required double distanceMeters,
    required double warningRadiusMeters,
    bool notifyIfInside = false,
  }) {
    final previousInside = _insideState[id] ?? false;
    final approachRadius = warningRadiusMeters + _approachRadiusExtraMeters;
    final exitRadius = warningRadiusMeters + _exitHysteresisMeters;
    final nowInside = previousInside
        ? distanceMeters <= exitRadius
        : distanceMeters <= warningRadiusMeters;

    final lastAlert = _lastEntryAlert[id];
    final shouldRepeat = notifyIfInside &&
        previousInside &&
        nowInside &&
        (lastAlert == null ||
            DateTime.now().difference(lastAlert) >=
                const Duration(seconds: 30));
    if ((!previousInside && nowInside) || shouldRepeat) {
      _lastEntryAlert[id] = DateTime.now();
      _showAlert(
        id: id,
        name: name,
        type: type,
        entered: true,
        distanceMeters: distanceMeters,
      );
    } else if (!previousInside &&
        distanceMeters <= approachRadius &&
        _approachNotified.add(id)) {
      _showAlert(
        id: id,
        name: name,
        type: type,
        entered: false,
        distanceMeters: distanceMeters,
      );
    }

    _insideState[id] = nowInside;
    if (!nowInside && distanceMeters > exitRadius) {
      _approachNotified.remove(id);
    }
  }

  Future<void> _showAlert({
    required String id,
    required String name,
    required String type,
    required bool entered,
    required double distanceMeters,
  }) async {
    final isElephant = type.contains('elephant');
    final isTest = type == 'test';
    final title = isTest
        ? (entered ? 'Test warning area entered' : 'Test warning area nearby')
        : entered
            ? (isElephant ? 'Elephant activity warning' : 'Honeybee warning')
            : (isElephant
                ? 'Approaching elephant warning area'
                : 'Approaching honeybee warning stretch');
    final body = isTest
        ? 'GPS notification test at 8.232755, 80.428614. '
            'You are ${distanceMeters.round()} metres from the test centre. '
            'This is a test, not a wildlife report.'
        : entered
            ? (isElephant
                ? 'Wild elephant activity has been reported here. Stay with your group and follow official instructions.'
                : 'Keep silent, avoid sudden movement, and follow staff instructions in this warning stretch.')
            : (isElephant
                ? 'You are approaching an area where elephant activity has been reported.'
                : 'You are approaching the Asian giant honeybee warning stretch.');
    final preview = isTest
        ? 'GPS test: ${distanceMeters.round()} m from the test point.'
        : entered
            ? (isElephant
                ? 'Elephant warning area. Stay with your group.'
                : 'Honeybee warning stretch. Keep silent.')
            : (isElephant
                ? 'Approaching elephant warning area.'
                : 'Approaching honeybee warning stretch.');

    final androidDetails = AndroidNotificationDetails(
      _notificationChannelId,
      _notificationChannelName,
      channelDescription:
          'Offline wildlife safety alerts for heritage visitors.',
      importance: Importance.max,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'Tap to open Sigiriya map',
      ),
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 250, 500]),
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(presentSound: true),
      macOS: const DarwinNotificationDetails(presentSound: true),
    );

    await _notifications.show(
      _notificationId(id),
      title,
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? preview
          : body,
      details,
      payload: _mapNotificationPayload,
    );

    if (!_events.isClosed) {
      _events.add(WildlifeAlertEvent(
        zoneId: id,
        zoneName: name,
        hazardType: type,
        entered: entered,
        distanceMeters: distanceMeters,
      ));
    }
  }

  int _notificationId(String zoneId) =>
      1000 +
      (zoneId.codeUnits.fold<int>(0, (sum, value) => sum + value) % 9000);

  double _distanceToLineMeters(
    Position position,
    List<({double latitude, double longitude})> points,
  ) {
    var minimum = double.infinity;
    for (var i = 0; i < points.length - 1; i++) {
      final distance = _distanceToSegmentMeters(
        position.latitude,
        position.longitude,
        points[i],
        points[i + 1],
      );
      minimum = math.min(minimum, distance);
    }
    return minimum;
  }

  double _distanceToSegmentMeters(
    double latitude,
    double longitude,
    ({double latitude, double longitude}) start,
    ({double latitude, double longitude}) end,
  ) {
    const latitudeScale = 111320.0;
    final longitudeScale = 111320.0 *
        math.cos(((start.latitude + end.latitude) / 2) * math.pi / 180);
    final x = (longitude - start.longitude) * longitudeScale;
    final y = (latitude - start.latitude) * latitudeScale;
    final dx = (end.longitude - start.longitude) * longitudeScale;
    final dy = (end.latitude - start.latitude) * latitudeScale;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0) return math.sqrt(x * x + y * y);

    final t = ((x * dx) + (y * dy)) / lengthSquared;
    final clamped = t.clamp(0.0, 1.0);
    final nearestX = clamped * dx;
    final nearestY = clamped * dy;
    return math.sqrt(
      math.pow(x - nearestX, 2) + math.pow(y - nearestY, 2),
    );
  }
}
