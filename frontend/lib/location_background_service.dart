import 'dart:async';
import 'dart:convert';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

const locationServiceChildKey = 'location_service_child_id';
const locationServiceApiKey = 'location_service_api_base';
const locationServiceTokenKey = 'location_service_auth_token';
const locationServiceReadyKey = 'location_service_ready';
const locationServiceErrorKey = 'location_service_error';
const _stopButtonId = 'stop_location_sharing';
const _locationServiceId = 238061458;
const _locationUpdateInterval = Duration(seconds: 30);

void initializeLocationBackgroundService() {
  FlutterForegroundTask.initCommunicationPort();
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'childguard_location_sharing',
      channelName: 'Chia sẻ vị trí',
      channelDescription:
          'Thông báo thường trực khi thiết bị đang chia sẻ vị trí.',
      onlyAlertOnce: true,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(
        _locationUpdateInterval.inMilliseconds,
      ),
      allowWakeLock: true,
      allowAutoRestart: true,
      stopWithTask: false,
    ),
  );
}

Future<ServiceRequestResult> startLocationBackgroundService({
  required String childId,
  required String apiBase,
  required String token,
}) async {
  if (await FlutterForegroundTask.isRunningService) {
    final runningChildId = await FlutterForegroundTask.getData<String>(
      key: locationServiceChildKey,
    );
    if (runningChildId == childId) {
      return const ServiceRequestSuccess();
    }
    return const ServiceRequestFailure(
      error: 'Đang có phiên chia sẻ vị trí khác. Hãy dừng phiên đó trước.',
    );
  }

  await FlutterForegroundTask.saveData(
    key: locationServiceReadyKey,
    value: false,
  );
  await FlutterForegroundTask.saveData(
    key: locationServiceChildKey,
    value: childId,
  );
  await FlutterForegroundTask.saveData(
    key: locationServiceApiKey,
    value: apiBase,
  );
  await FlutterForegroundTask.saveData(key: locationServiceErrorKey, value: '');
  await const FlutterSecureStorage().write(
    key: locationServiceTokenKey,
    value: token,
  );

  final result = await FlutterForegroundTask.startService(
    serviceId: _locationServiceId,
    serviceTypes: const [ForegroundServiceTypes.location],
    notificationTitle: 'ChildGuard đang chia sẻ vị trí',
    notificationText: 'Đang kết nối dịch vụ vị trí nền…',
    notificationButtons: const [
      NotificationButton(id: _stopButtonId, text: 'Dừng chia sẻ'),
    ],
    callback: startLocationTask,
  );

  if (result is! ServiceRequestSuccess) {
    await _clearLocationServiceConfiguration();
    return result;
  }

  for (var attempt = 0; attempt < 50; attempt++) {
    if (await FlutterForegroundTask.getData<bool>(
          key: locationServiceReadyKey,
        ) ==
        true) {
      return result;
    }
    if (!await FlutterForegroundTask.isRunningService) break;
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  final serviceError = await FlutterForegroundTask.getData<String>(
    key: locationServiceErrorKey,
  );
  await FlutterForegroundTask.stopService();
  await _clearLocationServiceConfiguration();
  return ServiceRequestFailure(
    error: serviceError?.isNotEmpty == true
        ? serviceError!
        : 'Không khởi động được dịch vụ chia sẻ vị trí nền.',
  );
}

Future<void> _clearLocationServiceConfiguration() async {
  await FlutterForegroundTask.removeData(key: locationServiceReadyKey);
  await FlutterForegroundTask.removeData(key: locationServiceChildKey);
  await FlutterForegroundTask.removeData(key: locationServiceApiKey);
  await FlutterForegroundTask.removeData(key: locationServiceErrorKey);
  await const FlutterSecureStorage().delete(key: locationServiceTokenKey);
}

Future<bool> stopLocationBackgroundService() async {
  if (!await FlutterForegroundTask.isRunningService) return false;

  FlutterForegroundTask.sendDataToTask(const {'action': 'stop'});
  for (var attempt = 0; attempt < 60; attempt++) {
    if (!await FlutterForegroundTask.isRunningService) return true;
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  return false;
}

@pragma('vm:entry-point')
void startLocationTask() {
  FlutterForegroundTask.setTaskHandler(LocationBackgroundTaskHandler());
}

class LocationBackgroundTaskHandler extends TaskHandler {
  String? _childId;
  String? _apiBase;
  String? _token;
  bool _uploading = false;
  bool _stopping = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _childId = await FlutterForegroundTask.getData<String>(
      key: locationServiceChildKey,
    );
    _apiBase = await FlutterForegroundTask.getData<String>(
      key: locationServiceApiKey,
    );
    _token = await const FlutterSecureStorage().read(
      key: locationServiceTokenKey,
    );

    if (_childId == null || _apiBase == null || _token == null) {
      await _reportError('Thiếu thông tin đăng nhập để chia sẻ vị trí.');
      await FlutterForegroundTask.saveData(
        key: locationServiceReadyKey,
        value: true,
      );
      return;
    }

    await FlutterForegroundTask.saveData(
      key: locationServiceReadyKey,
      value: true,
    );
    _sendTaskEvent(const {'type': 'ready'});
    unawaited(_uploadCurrentPosition());
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    unawaited(_uploadCurrentPosition());
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onReceiveData(Object data) {
    if (data is Map && data['action'] == 'stop') {
      unawaited(_stopAndDeleteLocation());
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == _stopButtonId) unawaited(_stopAndDeleteLocation());
  }

  Future<void> _uploadCurrentPosition() async {
    if (_uploading || _stopping) return;
    final childId = _childId;
    final apiBase = _apiBase;
    final token = _token;
    if (childId == null || apiBase == null || token == null) return;

    _uploading = true;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Dịch vụ vị trí trên điện thoại đang tắt.');
      }
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always) {
        throw Exception('Cần quyền vị trí “Cho phép mọi lúc”.');
      }

      final point = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 25),
        ),
      );
      final response = await http
          .put(
            Uri.parse('$apiBase/children/$childId/location'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'latitude': point.latitude,
              'longitude': point.longitude,
              'accuracy': point.accuracy,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = response.body.isEmpty ? null : jsonDecode(response.body);
        final message = body is Map ? body['message'] : null;
        throw Exception(
          message is String ? message : 'Máy chủ từ chối cập nhật vị trí.',
        );
      }

      final location = jsonDecode(response.body);
      if (location is! Map<String, dynamic>) {
        throw Exception('Máy chủ trả về dữ liệu vị trí không hợp lệ.');
      }

      await FlutterForegroundTask.saveData(
        key: locationServiceErrorKey,
        value: '',
      );
      await FlutterForegroundTask.updateService(
        notificationText: 'Đang chia sẻ vị trí cho phụ huynh liên kết.',
      );
      _sendTaskEvent({'type': 'location', 'location': location});
    } catch (error) {
      await _reportError(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      _uploading = false;
    }
  }

  Future<void> _stopAndDeleteLocation() async {
    if (_stopping) return;
    _stopping = true;

    final childId = _childId;
    final apiBase = _apiBase;
    final token = _token;
    if (childId == null || apiBase == null || token == null) {
      await _reportError(
        'Không thể dừng an toàn: thiếu thông tin phiên chia sẻ.',
      );
      _stopping = false;
      return;
    }

    try {
      while (_uploading) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      final response = await http
          .delete(
            Uri.parse('$apiBase/children/$childId/location'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Không xóa được vị trí trên máy chủ.');
      }

      _sendTaskEvent(const {'type': 'stopped'});
      await _clearLocationServiceConfiguration();
      await FlutterForegroundTask.stopService();
    } catch (error) {
      await _reportError(error.toString().replaceFirst('Exception: ', ''));
      _stopping = false;
    }
  }

  Future<void> _reportError(String message) async {
    await FlutterForegroundTask.saveData(
      key: locationServiceErrorKey,
      value: message,
    );
    _sendTaskEvent({'type': 'error', 'message': message});
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(
        notificationText: 'Đang chờ khôi phục vị trí hoặc kết nối mạng.',
      );
    }
  }

  void _sendTaskEvent(Map<String, dynamic> event) {
    FlutterForegroundTask.sendDataToMain(jsonEncode(event));
  }
}
