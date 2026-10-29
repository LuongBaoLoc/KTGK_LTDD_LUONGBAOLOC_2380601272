import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';
import 'location_background_service.dart';

String formatLocationAccuracy(Object? accuracy) =>
    accuracy is num ? accuracy.toStringAsFixed(1) : accuracy?.toString() ?? '';

class LocationCard extends StatefulWidget {
  const LocationCard({
    super.key,
    required this.api,
    required this.childId,
    required this.canShare,
  });
  final Api api;
  final String childId;
  final bool canShare;
  @override
  State<LocationCard> createState() => _LocationCardState();
}

class _LocationCardState extends State<LocationCard> {
  Map<String, dynamic>? location;
  Timer? _refreshTimer;
  bool busy = false, sharing = false;
  String? error;
  String get path => '/children/${widget.childId}/location';

  @override
  void initState() {
    super.initState();
    load();
    if (widget.canShare) {
      FlutterForegroundTask.addTaskDataCallback(_onTaskData);
      _refreshTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _syncBackgroundService(),
      );
      _syncBackgroundService();
    } else {
      _refreshTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => load(),
      );
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    if (widget.canShare) {
      FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    }
    super.dispose();
  }

  void _onTaskData(Object data) {
    if (!mounted || data is! String) return;
    dynamic decoded;
    try {
      decoded = jsonDecode(data);
    } on FormatException {
      setState(() => error = 'Không đọc được trạng thái chia sẻ vị trí.');
      return;
    }
    if (decoded is! Map) return;
    final event = Map<String, dynamic>.from(decoded);
    switch (event['type']) {
      case 'location':
        final value = event['location'];
        if (value is Map) {
          setState(() {
            location = Map<String, dynamic>.from(value);
            error = null;
          });
        }
        return;
      case 'error':
        final message = event['message'];
        if (message is String) setState(() => error = message);
        return;
      case 'stopped':
        setState(() {
          sharing = false;
          location = null;
        });
        return;
      case 'ready':
        unawaited(_syncBackgroundService());
        return;
    }
  }

  Future<void> _syncBackgroundService() async {
    final running = await FlutterForegroundTask.isRunningService;
    final runningChildId = running
        ? await FlutterForegroundTask.getData<String>(
            key: locationServiceChildKey,
          )
        : null;
    final serviceError = running
        ? await FlutterForegroundTask.getData<String>(
            key: locationServiceErrorKey,
          )
        : null;
    if (!mounted) return;
    final serviceIsSharing =
        running && runningChildId == widget.childId;
    final nextError = serviceIsSharing && serviceError?.isNotEmpty == true
        ? serviceError
        : serviceIsSharing && error == serviceError
        ? null
        : error;
    if (sharing != serviceIsSharing || error != nextError) {
      setState(() {
        sharing = serviceIsSharing;
        error = nextError;
      });
    }
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> load() => run(() async {
    final result = await widget.api.call('GET', path);
    if (!mounted) return;
    setState(() {
      location = result == null ? null : Map<String, dynamic>.from(result);
    });
  });

  Future<void> _ensureBackgroundPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      throw Exception('Chia sẻ vị trí nền hiện chỉ được hỗ trợ trên Android.');
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Hãy bật dịch vụ vị trí trên điện thoại.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      throw Exception(
        'Cần cấp quyền vị trí để chia sẻ. Hãy mở Cài đặt ứng dụng và cho phép truy cập vị trí.',
      );
    }
    if (permission == LocationPermission.whileInUse) {
      if (!mounted) return;
      final openSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cho phép vị trí nền'),
          content: const Text(
            'Để tiếp tục chia sẻ khi ChildGuard chạy nền hoặc màn hình tắt, hãy mở quyền vị trí của ứng dụng và chọn “Cho phép mọi lúc”.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Để sau'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Mở cài đặt'),
            ),
          ],
        ),
      );
      if (openSettings == true) {
        await Geolocator.openAppSettings();
        throw Exception(
          'Chọn “Cho phép mọi lúc” trong Cài đặt, quay lại app rồi bật chia sẻ lại.',
        );
      }
      throw Exception('Chưa cấp quyền vị trí nền.');
    }
    if (permission != LocationPermission.always) {
      throw Exception('Cần quyền “Cho phép mọi lúc” để chia sẻ vị trí nền.');
    }
  }

  Future<void> share() async {
    final agreed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bắt đầu chia sẻ vị trí trực tiếp?'),
        content: const Text(
          'ChildGuard sẽ gửi vị trí điện thoại lên máy chủ khoảng mỗi 30 giây, kể cả khi ứng dụng chạy nền. Phụ huynh liên kết có thể xem vị trí mới nhất. Android sẽ hiện thông báo thường trực khi chia sẻ. Trên OPPO/ColorOS, hãy cho phép ứng dụng chạy nền và đặt pin ở chế độ không hạn chế. Buộc dừng ứng dụng, tắt nguồn hoặc thu hồi quyền có thể làm gián đoạn chia sẻ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đồng ý & tiếp tục'),
          ),
        ],
      ),
    );
    if (agreed != true || !mounted) return;
    await run(() async {
      await _ensureBackgroundPermission();
      if (!widget.api.configured) {
        throw Exception('Địa chỉ máy chủ API chưa được cấu hình hợp lệ.');
      }
      if (await FlutterForegroundTask.checkNotificationPermission() !=
          NotificationPermission.granted) {
        final permission =
            await FlutterForegroundTask.requestNotificationPermission();
        if (permission != NotificationPermission.granted) {
          throw Exception(
            'Cần cho phép thông báo để hiển thị trạng thái chia sẻ vị trí nền.',
          );
        }
      }
      final token = widget.api.token;
      if (token == null) {
        throw Exception('Phiên đăng nhập không hợp lệ. Hãy đăng nhập lại.');
      }
      final result = await startLocationBackgroundService(
        childId: widget.childId,
        apiBase: Api.base,
        token: token,
      );
      if (result is ServiceRequestFailure) {
        throw Exception(result.error);
      }
      setState(() {
        sharing = true;
        error = null;
      });
    });
  }

  Future<void> stopSharing() async {
    await run(() async {
      final runningChildId = await FlutterForegroundTask.getData<String>(
        key: locationServiceChildKey,
      );
      if (await FlutterForegroundTask.isRunningService &&
          runningChildId == widget.childId) {
        final stopped = await stopLocationBackgroundService();
        if (!stopped) {
          throw Exception(
            'Không thể dừng dịch vụ nền. Kiểm tra kết nối mạng rồi thử lại.',
          );
        }
      } else {
        await widget.api.call('DELETE', path);
      }
      if (mounted) {
        setState(() {
          sharing = false;
          location = null;
        });
      }
    });
  }

  String get locationStatus {
    if (location == null) return 'Chưa chia sẻ vị trí.';
    final updatedAt = DateTime.parse(location!['updated_at']).toLocal();
    final age = DateTime.now().difference(updatedAt);
    if (sharing) {
      return 'Đang chia sẻ trực tiếp • cập nhật lúc ${updatedAt.toString().split('.').first}';
    }
    if (age <= const Duration(minutes: 2)) {
      return 'Vị trí mới nhất: ${updatedAt.toString().split('.').first}';
    }
    return 'Vị trí cuối cùng (đã cũ): ${updatedAt.toString().split('.').first}';
  }

  @override
  Widget build(BuildContext context) {
    final accuracyLabel = formatLocationAccuracy(location?['accuracy']);
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.location_on_outlined,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vị trí an tâm',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Chia sẻ minh bạch với gia đình',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    sharing
                        ? Icons.radio_button_checked_rounded
                        : Icons.schedule_rounded,
                    size: 19,
                    color: sharing ? colors.primary : colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      locationStatus,
                      style: TextStyle(
                        color: sharing
                            ? colors.primary
                            : colors.onSurfaceVariant,
                        height: 1.4,
                        fontWeight: sharing ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (location != null) ...[
              const SizedBox(height: 12),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Icon(
                    Icons.gps_fixed_rounded,
                    size: 17,
                    color: colors.onSurfaceVariant,
                  ),
                  Text(
                    'Độ chính xác khoảng $accuracyLabel m',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final l = location!;
                    final uri = Uri.https('www.google.com', '/maps/search/', {
                      'api': '1',
                      'query': '${l['latitude']},${l['longitude']}',
                    });
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Mở vị trí trên bản đồ'),
                ),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  error!,
                  style: TextStyle(color: colors.onErrorContainer, height: 1.4),
                ),
              ),
            ],
            if (busy) ...[
              const SizedBox(height: 12),
              const ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(4)),
                child: LinearProgressIndicator(minHeight: 4),
              ),
            ] else ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: widget.canShare
                    ? FilledButton.icon(
                        onPressed: sharing ? stopSharing : share,
                        icon: Icon(
                          sharing
                              ? Icons.location_off_outlined
                              : Icons.my_location_rounded,
                        ),
                        label: Text(
                          sharing
                              ? 'Ngừng & xóa vị trí'
                              : 'Bắt đầu chia sẻ trực tiếp',
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Làm mới vị trí'),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
