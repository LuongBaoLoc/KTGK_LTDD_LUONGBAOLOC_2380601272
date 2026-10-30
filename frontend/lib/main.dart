import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';
import 'fingerprint.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'api.dart';
import 'location_card.dart';
import 'location_background_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initializeLocationBackgroundService();
  runApp(const ChildGuard());
}

final api = Api();
const ink = Color(0xFFF4F7FB), green = Color(0xFFC6FF4D);
const canvas = Color(0xFF0A0D12), mint = Color(0xFF202936);
const aqua = Color(0xFF77E4C3), muted = Color(0xFF9AA6B5);
const surface = Color(0xFF171E27), border = Color(0xFF29323F);
const warning = Color(0xFFFFBF69), critical = Color(0xFFFF6B76);
const backgroundOptions = <String, Color>{
  'Đen': canvas,
  'Xanh rêu': Color(0xFF10221D),
  'Than chì': Color(0xFF252321),
};
final appTextScale = ValueNotifier<double>(1);
final appBackgroundKey = ValueNotifier<String>('Đen');

Future<void> saveTextScale(double value) async {
  appTextScale.value = value;
  await Api.storage.write(key: 'settings_text_scale', value: value.toString());
}

Future<void> saveBackground(String value) async {
  appBackgroundKey.value = value;
  await Api.storage.write(key: 'settings_background', value: value);
}

String biometricName(BiometricType type) =>
    type == BiometricType.face ? 'khuôn mặt' : 'vân tay';

String biometricTokenKey(BiometricType type) =>
    type == BiometricType.face ? 'face_token' : 'fingerprint_token';

class ChildGuard extends StatefulWidget {
  const ChildGuard({super.key});

  @override
  State<ChildGuard> createState() => _ChildGuardState();
}

class _ChildGuardState extends State<ChildGuard> {
  @override
  void initState() {
    super.initState();
    appTextScale.addListener(refreshPreferences);
    appBackgroundKey.addListener(refreshPreferences);
    loadPreferences();
  }

  @override
  void dispose() {
    appTextScale.removeListener(refreshPreferences);
    appBackgroundKey.removeListener(refreshPreferences);
    super.dispose();
  }

  void refreshPreferences() {
    if (mounted) setState(() {});
  }

  Future<void> loadPreferences() async {
    final values = await Future.wait([
      Api.storage.read(key: 'settings_text_scale'),
      Api.storage.read(key: 'settings_background'),
    ]);
    final scale = double.tryParse(values[0] ?? '');
    if (scale != null && scale >= .85 && scale <= 1.25) {
      appTextScale.value = scale;
    }
    if (backgroundOptions.containsKey(values[1])) {
      appBackgroundKey.value = values[1]!;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ChildGuard',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: green,
            brightness: Brightness.dark,
            surface: surface,
          ).copyWith(
            primary: green,
            onPrimary: canvas,
            secondary: aqua,
            surface: surface,
            onSurface: ink,
            outline: border,
            error: critical,
          ),
      scaffoldBackgroundColor:
          backgroundOptions[appBackgroundKey.value] ?? canvas,
      fontFamily: 'Roboto',
      textTheme: ThemeData.dark().textTheme
          .apply(bodyColor: ink, displayColor: ink)
          .copyWith(
            headlineSmall: const TextStyle(
              color: ink,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
            titleLarge: const TextStyle(
              color: ink,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            titleMedium: const TextStyle(
              color: ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            bodyMedium: const TextStyle(fontSize: 14, height: 1.45),
          ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 54),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          animationDuration: const Duration(milliseconds: 180),
          overlayColor: Colors.white.withValues(alpha: .08),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: .1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 50),
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          animationDuration: const Duration(milliseconds: 180),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: green,
          animationDuration: const Duration(milliseconds: 160),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        iconColor: green,
        minLeadingWidth: 42,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: mint,
        elevation: 0,
        height: 70,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: green,
        foregroundColor: canvas,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundOptions[appBackgroundKey.value] ?? canvas,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        labelStyle: const TextStyle(color: muted),
        hintStyle: const TextStyle(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: green, width: 1.5),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        space: 1,
        thickness: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: green,
        linearTrackColor: mint,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surface,
        contentTextStyle: const TextStyle(color: ink),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: border),
        ),
      ),
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(appTextScale.value)),
      child: child!,
    ),
    home: const Login(),
  );
}

void notify(BuildContext context, Object text) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text.toString().replaceFirst('Exception: ', ''))),
    );
Widget field(
  TextEditingController controller,
  String label, {
  bool secret = false,
  TextInputType? keyboard,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 14),
  child: TextField(
    controller: controller,
    obscureText: secret,
    keyboardType: keyboard,
    decoration: InputDecoration(labelText: label),
  ),
);

Widget sectionHeading(
  String title, {
  String? subtitle,
  Widget? action,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: muted, height: 1.4)),
            ],
          ],
        ),
      ),
      if (action != null) action,
    ],
  ),
);

class AnimatedEntrance extends StatelessWidget {
  const AnimatedEntrance({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 240),
  });

  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reducedMotion ? Duration.zero : duration,
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, progress, child) => Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - progress)),
          child: child,
        ),
      ),
    );
  }
}

class AnimatedPress extends StatefulWidget {
  const AnimatedPress({super.key, required this.child});
  final Widget child;

  @override
  State<AnimatedPress> createState() => _AnimatedPressState();
}

class _AnimatedPressState extends State<AnimatedPress> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: !reducedMotion && _pressed ? .97 : 1,
        duration: reducedMotion
            ? Duration.zero
            : const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class ScreenTimeOverview extends StatelessWidget {
  const ScreenTimeOverview({
    super.key,
    required this.child,
    required this.profiles,
    required this.selectedChildId,
    required this.onSelectChild,
    required this.onOpenProfile,
  });

  final Map<String, dynamic> child;
  final List<dynamic> profiles;
  final String? selectedChildId;
  final ValueChanged<String> onSelectChild;
  final VoidCallback onOpenProfile;
  @override
  Widget build(BuildContext context) {
    final dailyLimit = int.tryParse('${child['daily_limit']}');
    final profileId = child['id'].toString();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: mint,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.hourglass_bottom_rounded,
                  color: green,
                  size: 19,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Text(
                  'KẾ HOẠCH THỜI GIAN SỐ',
                  style: TextStyle(
                    color: muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              if (profiles.length > 1)
                SizedBox(
                  width: 132,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value:
                          profiles.any(
                            (profile) =>
                                profile['id'].toString() == selectedChildId,
                          )
                          ? selectedChildId
                          : profileId,
                      icon: const Icon(Icons.expand_more_rounded, color: green),
                      dropdownColor: surface,
                      borderRadius: BorderRadius.circular(12),
                      items: profiles
                          .map(
                            (profile) => DropdownMenuItem<String>(
                              value: profile['id'].toString(),
                              child: Text(
                                profile['name'].toString(),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) onSelectChild(value);
                      },
                    ),
                  ),
                ),
            ],
          ),
          if (profiles.length == 1) ...[
            const SizedBox(height: 15),
            Text(
              child['name'].toString(),
              style: const TextStyle(
                color: ink,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${child['age']} tuổi',
              style: const TextStyle(color: muted, fontSize: 13),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'HẠN MỨC HÔM NAY',
                      style: TextStyle(
                        color: muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .7,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      dailyLimit == null ? '—' : '$dailyLimit',
                      style: const TextStyle(
                        color: green,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      'phút mỗi ngày',
                      style: const TextStyle(color: muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 58, color: border),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'THỜI GIAN ĐÃ DÙNG',
                      style: TextStyle(
                        color: muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .5,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      '—',
                      style: TextStyle(
                        color: ink,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      'Chưa được theo dõi',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: aqua, size: 18),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Đây là giới hạn đã thiết lập; ứng dụng chưa thu thập thời gian sử dụng thực tế trên thiết bị.',
                  style: TextStyle(color: muted, height: 1.4, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onOpenProfile,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text('Mở hồ sơ'),
          ),
        ],
      ),
    );
  }
}

class _QuickActionRow extends StatelessWidget {
  const _QuickActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: ListTile(
      minVerticalPadding: 12,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: mint,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: green, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, style: const TextStyle(color: muted)),
      trailing: const Icon(Icons.chevron_right_rounded, color: muted),
      onTap: onTap,
    ),
  );
}

PageRoute<T> softRoute<T>(Widget page) => PageRouteBuilder<T>(
  transitionDuration: const Duration(milliseconds: 240),
  pageBuilder: (context, animation, secondaryAnimation) => page,
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final slide = Tween<Offset>(
      begin: const Offset(.035, .02),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(position: slide, child: child),
    );
  },
);

class Login extends StatefulWidget {
  const Login({super.key});
  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final username = TextEditingController(),
      password = TextEditingController(),
      email = TextEditingController(),
      name = TextEditingController(),
      code = TextEditingController();
  bool register = false, busy = false;
  String? challenge;
  @override
  void dispose() {
    for (final c in [username, password, email, name, code]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> work(Future<void> Function() fn) async {
    setState(() => busy = true);
    try {
      await fn();
    } catch (e) {
      if (mounted) notify(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> enter(
    Map<String, dynamic> result, {
    bool offerBiometricSetup = false,
  }) async {
    api.token = result['token'];
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      softRoute(
        Home(
          user: Map<String, dynamic>.from(result['user']),
          suggestBiometricSetup: offerBiometricSetup,
        ),
      ),
    );
  }

  Future<void> submit() => work(() async {
    if (challenge != null) {
      await enter(
        Map<String, dynamic>.from(
          await api.call('POST', '/auth/otp', {
            'challengeId': challenge,
            'code': code.text.trim(),
          }),
        ),
        offerBiometricSetup: true,
      );
      return;
    }
    final r = await api
        .call('POST', register ? '/auth/register' : '/auth/login', {
          'username': username.text.trim(),
          'password': password.text,
          if (register) 'email': email.text.trim(),
          if (register) 'name': name.text.trim(),
        });
    setState(() => challenge = r['challengeId']);
    if (mounted) notify(context, r['message']);
  });
  Future<void> biometric(BiometricType type) => work(() async {
    final auth = BiometricAuth();
    if (!mounted) return;
    if (!await auth.authenticate(context, type)) return;
    final key = biometricTokenKey(type);
    final token =
        await Api.storage.read(key: key) ??
        await Api.storage.read(key: 'biometric_token');
    if (token == null) {
      throw Exception(
        'Hãy đăng nhập bằng OTP rồi bật ${biometricName(type)} trong tài khoản trước.',
      );
    }
    await Api.storage.write(key: key, value: token);
    await Api.storage.delete(key: 'biometric_token');
    api.token = token;
    try {
      final u = await api.call('GET', '/me');
      await enter({'token': token, 'user': u});
    } on ApiException catch (e) {
      api.token = null;
      if (e.statusCode == 401) {
        await Api.storage.delete(key: key);
        throw Exception(
          'Phiên đăng nhập đã hết hạn. Hãy đăng nhập lại bằng OTP và bật lại sinh trắc học.',
        );
      }
      rethrow;
    } catch (_) {
      api.token = null;
      rethrow;
    }
  });
  Future<void> google() => work(() async {
    if (!api.configured) throw Exception('Cần cấu hình địa chỉ backend trước.');
    final verifier = base64UrlEncode(
      List<int>.generate(32, (_) => Random.secure().nextInt(256)),
    );
    final digest = sha256.convert(utf8.encode(verifier)).toString();
    final result = await FlutterWebAuth2.authenticate(
      url: '${Api.base}/auth/google/start?verifierHash=$digest',
      callbackUrlScheme: 'childguard',
    );
    final c = Uri.parse(result).queryParameters['code'];
    if (c == null) throw Exception('Google chưa trả mã xác thực');
    final response = Map<String, dynamic>.from(
      await api.call('POST', '/auth/google/exchange', {
        'code': c,
        'verifier': verifier,
      }),
    );
    if (response['requiresOtp'] == true) {
      if (!mounted) return;
      setState(() {
        challenge = response['challengeId'];
        code.clear();
      });
      notify(context, response['message']);
      return;
    }
    await enter(response);
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    body: ColoredBox(
      color: canvas,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedEntrance(
                    child: Row(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: mint,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.shield_rounded,
                            color: green,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ChildGuard',
                                style: TextStyle(
                                  color: ink,
                                  fontSize: 25,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -.5,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Cùng con lớn lên an toàn',
                                style: TextStyle(color: muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  AnimatedEntrance(
                    duration: const Duration(milliseconds: 260),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              challenge != null
                                  ? 'Xác thực email'
                                  : register
                                  ? 'Tạo tổ ấm an toàn'
                                  : 'Chào mừng trở lại',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              challenge != null
                                  ? 'Nhập mã xác thực để tiếp tục.'
                                  : register
                                  ? 'Tạo tài khoản để bắt đầu đồng hành cùng gia đình.'
                                  : 'Đăng nhập để tiếp tục đồng hành cùng gia đình.',
                              style: const TextStyle(
                                color: muted,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 22),
                            if (!api.configured)
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF332819),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Chưa cấu hình máy chủ. Xem hướng dẫn chạy backend để kết nối.',
                                  style: TextStyle(color: warning),
                                ),
                              ),
                            if (challenge != null) ...[
                              const Text(
                                'Mã có hiệu lực 5 phút, tối đa 5 lần thử.',
                              ),
                              const SizedBox(height: 12),
                              field(
                                code,
                                'Mã OTP',
                                keyboard: TextInputType.number,
                              ),
                            ] else ...[
                              if (register) ...[
                                field(name, 'Họ tên'),
                                field(
                                  email,
                                  'Email',
                                  keyboard: TextInputType.emailAddress,
                                ),
                              ],
                              field(
                                username,
                                register
                                    ? 'Tên đăng nhập (3–32 ký tự)'
                                    : 'Tên đăng nhập hoặc email',
                              ),
                              field(
                                password,
                                'Mật khẩu (ít nhất 10 ký tự)',
                                secret: true,
                              ),
                            ],
                            AnimatedPress(
                              child: FilledButton(
                                onPressed: busy ? null : submit,
                                child: Text(
                                  busy
                                      ? 'Đang xử lý…'
                                      : challenge != null
                                      ? 'Xác thực & tiếp tục'
                                      : register
                                      ? 'Đăng ký'
                                      : 'Đăng nhập với OTP',
                                ),
                              ),
                            ),
                            if (challenge == null) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Row(
                                  children: [
                                    Expanded(child: Divider()),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Text(
                                        'HOẶC',
                                        style: TextStyle(
                                          color: muted,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ),
                                    Expanded(child: Divider()),
                                  ],
                                ),
                              ),
                              AnimatedPress(
                                child: OutlinedButton.icon(
                                  onPressed: busy ? null : google,
                                  icon: const Icon(
                                    Icons.account_circle_outlined,
                                  ),
                                  label: const Text('Tiếp tục với Google'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              AnimatedPress(
                                child: OutlinedButton.icon(
                                  onPressed: busy
                                      ? null
                                      : () => biometric(
                                          BiometricType.fingerprint,
                                        ),
                                  icon: const Icon(Icons.fingerprint),
                                  label: const Text('Mở bằng vân tay'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              AnimatedPress(
                                child: OutlinedButton.icon(
                                  onPressed: busy
                                      ? null
                                      : () => biometric(BiometricType.face),
                                  icon: const Icon(
                                    Icons.face_retouching_natural,
                                  ),
                                  label: const Text('Mở bằng khuôn mặt'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Android sẽ chọn phương thức sinh trắc học đã đăng ký.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: muted),
                              ),
                            ],
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => setState(() {
                                      challenge = null;
                                      register = !register;
                                      code.clear();
                                    }),
                              child: Text(
                                challenge != null
                                    ? 'Quay lại / gửi mã mới'
                                    : register
                                    ? 'Đã có tài khoản? Đăng nhập'
                                    : 'Chưa có tài khoản? Đăng ký',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class Home extends StatefulWidget {
  final Map<String, dynamic> user;
  final bool suggestBiometricSetup;
  const Home({
    super.key,
    required this.user,
    this.suggestBiometricSetup = false,
  });
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<dynamic> children = [], users = [];
  Map<String, dynamic> stats = {};
  bool loading = true;
  bool fingerprintEnabled = false, faceEnabled = false;
  String? error;
  String? selectedChildId;
  int page = 0;
  String get role => widget.user['role'];
  bool get isParent => role == 'parent';
  String get userInitial {
    final name = widget.user['name'].toString().trim();
    return name.isEmpty ? 'C' : name.substring(0, 1).toUpperCase();
  }

  Map<String, dynamic>? get selectedChild {
    for (final item in children) {
      if (item is Map && item['id'].toString() == selectedChildId) {
        return Map<String, dynamic>.from(item);
      }
    }
    return children.isEmpty ? null : Map<String, dynamic>.from(children.first);
  }

  @override
  void initState() {
    super.initState();
    load();
    loadBiometricSettings();
    if (widget.suggestBiometricSetup) {
      WidgetsBinding.instance.addPostFrameCallback((_) => suggestBiometrics());
    }
  }

  Future<void> suggestBiometrics() async {
    final values = await Future.wait([
      Api.storage.read(key: biometricTokenKey(BiometricType.fingerprint)),
      Api.storage.read(key: biometricTokenKey(BiometricType.face)),
      Api.storage.read(key: 'biometric_token'),
    ]);
    if (!mounted || values.any((value) => value != null)) return;
    final configure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng nhập nhanh hơn'),
        content: const Text(
          'Bạn có thể bật vân tay hoặc khuôn mặt để dùng cho lần đăng nhập sau.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Thiết lập'),
          ),
        ],
      ),
    );
    if (configure == true && mounted) setState(() => page = 1);
  }

  Future<void> loadBiometricSettings() async {
    final values = await Future.wait([
      Api.storage.read(key: biometricTokenKey(BiometricType.fingerprint)),
      Api.storage.read(key: biometricTokenKey(BiometricType.face)),
      Api.storage.read(key: 'biometric_token'),
    ]);
    if (!mounted) return;
    setState(() {
      fingerprintEnabled = values[0] != null || values[2] != null;
      faceEnabled = values[1] != null;
    });
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (role == 'admin') {
        users = await api.call('GET', '/admin/users');
        stats = Map<String, dynamic>.from(
          await api.call('GET', '/staff/dashboard'),
        );
      } else if (role == 'staff') {
        stats = Map<String, dynamic>.from(
          await api.call('GET', '/staff/dashboard'),
        );
      } else {
        final profiles = await api.call('GET', '/children') as List<dynamic>;
        children = profiles;
        if (!profiles.any((item) => item['id'].toString() == selectedChildId)) {
          selectedChildId = profiles.isEmpty
              ? null
              : profiles.first['id'].toString();
        }
      }
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> manageUser(Map<String, dynamic> user) async {
    const labels = {
      'parent': 'Phụ huynh',
      'child': 'Trẻ em',
      'staff': 'Nhân viên',
      'admin': 'Quản trị viên',
    };
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(user['name']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user['email']),
            Text('Vai trò: ${labels[user['role']] ?? user['role']}'),
            Text(
              user['verified'] == true
                  ? 'Email đã xác minh'
                  : 'Email chưa xác minh',
            ),
            const SizedBox(height: 16),
            if (user['role'] == 'admin')
              const Text(
                'Tài khoản quản trị được bảo vệ, không thể đổi quyền tại đây.',
              )
            else
              ...['parent', 'child', 'staff'].map(
                (role) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(labels[role]!),
                  trailing: user['role'] == role
                      ? const Icon(Icons.check)
                      : const Icon(Icons.chevron_right),
                  onTap: user['role'] == role
                      ? null
                      : () => Navigator.pop(ctx, role),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận đổi quyền'),
        content: Text('Đổi ${user['name']} thành ${labels[selected]}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await execute(() async {
      await api.call('PATCH', '/admin/users/${user['id']}/role', {
        'role': selected,
      });
      if (mounted) {
        notify(context, 'Đã cập nhật quyền thành ${labels[selected]}');
      }
    });
  }

  Future<void> execute(Future<void> Function() fn) async {
    try {
      await fn();
      await load();
    } catch (e) {
      if (mounted) notify(context, e);
    }
  }

  Future<void> editChild([Map<String, dynamic>? c]) async {
    final result = await editDialog(
      context,
      c == null ? 'Thêm hồ sơ trẻ' : 'Sửa hồ sơ trẻ',
      {
        'name': ('Tên trẻ', c?['name'] ?? ''),
        'age': ('Tuổi', '${c?['age'] ?? 8}'),
        'daily_limit': ('Giới hạn phút/ngày', '${c?['daily_limit'] ?? 120}'),
      },
    );
    if (result == null) return;
    await execute(() async {
      await api.call(
        c == null ? 'POST' : 'PUT',
        c == null ? '/children' : '/children/${c['id']}',
        {
          'name': result['name'],
          'age': int.tryParse(result['age'] ?? '') ?? 0,
          'daily_limit': int.tryParse(result['daily_limit'] ?? '') ?? 0,
        },
      );
    });
  }

  Future<void> openChildProfile(Map<String, dynamic> child) async {
    if (mounted) {
      setState(() => selectedChildId = child['id'].toString());
    }
    await Navigator.of(
      context,
    ).push(softRoute(ChildPage(child: child, isParent: isParent)));
    if (mounted) await load();
  }

  Future<void> logout() async {
    try {
      if (await FlutterForegroundTask.isRunningService &&
          !await stopLocationBackgroundService()) {
        throw Exception(
          'Không thể dừng chia sẻ vị trí. Hãy thử lại trước khi đăng xuất.',
        );
      }
      await api.logout();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(softRoute(const Login()));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  Future<void> setBiometricEnabled(BiometricType type, bool enabled) async {
    try {
      if (enabled) {
        final auth = BiometricAuth();
        if (!mounted || !await auth.authenticate(context, type)) return;
        final token = api.token;
        if (token == null) {
          throw Exception('Phiên đăng nhập không hợp lệ. Hãy đăng nhập lại.');
        }
        await Api.storage.write(key: biometricTokenKey(type), value: token);
        await Api.storage.delete(key: 'biometric_token');
      } else {
        await Api.storage.delete(key: biometricTokenKey(type));
        await Api.storage.delete(key: 'biometric_token');
      }
      if (mounted) {
        setState(() {
          if (type == BiometricType.face) {
            faceEnabled = enabled;
          } else {
            fingerprintEnabled = enabled;
          }
        });
        notify(context, 'Đã ${enabled ? 'bật' : 'tắt'} ${biometricName(type)}');
      }
    } catch (e) {
      if (mounted) notify(context, e);
    }
  }

  Future<void> editPersonalProfile() async {
    final values = await editDialog(context, 'Cập nhật hồ sơ', {
      'name': ('Họ tên', widget.user['name'].toString()),
      'email': ('Email', widget.user['email'].toString()),
    });
    if (values == null || !mounted) return;
    try {
      final updated = Map<String, dynamic>.from(
        await api.call('PATCH', '/me', {'name': values['name']}),
      );
      setState(() => widget.user['name'] = updated['name']);
      if (values['email'] != widget.user['email']) {
        final challenge = Map<String, dynamic>.from(
          await api.call('POST', '/me/email', {'email': values['email']}),
        );
        if (challenge['challengeId'] != null) {
          final otp = await editDialog(context, 'Xác minh email mới', {
            'code': ('Mã OTP gửi đến email mới', ''),
          });
          if (otp == null || !mounted) {
            notify(context, 'Tên đã cập nhật; email chưa được thay đổi.');
            return;
          }
          final session = Map<String, dynamic>.from(
            await api.call('POST', '/auth/otp', {
              'challengeId': challenge['challengeId'],
              'code': otp['code'],
            }),
          );
          api.token = session['token'];
          setState(() {
            widget.user['name'] = session['user']['name'];
            widget.user['email'] = session['user']['email'];
          });
        }
      }
      if (mounted) notify(context, 'Đã cập nhật hồ sơ cá nhân.');
    } catch (e) {
      if (mounted) notify(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: mint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.shield_rounded, color: green, size: 19),
          ),
          const SizedBox(width: 11),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ChildGuard'),
              Text(
                'AN TOÀN SỐ • DARK SIGNAL',
                style: TextStyle(
                  color: muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .7,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (page == 0)
          IconButton(
            tooltip: 'Làm mới dữ liệu',
            onPressed: load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        IconButton(
          tooltip: 'Mở tài khoản',
          onPressed: () => setState(() => page = 1),
          icon: CircleAvatar(
            radius: 15,
            backgroundColor: mint,
            child: Text(
              userInitial,
              style: const TextStyle(
                color: green,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: page,
      onDestinationSelected: (i) => setState(() => page = i),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.space_dashboard_outlined),
          selectedIcon: Icon(Icons.space_dashboard_rounded),
          label: 'Tổng quan',
        ),
        NavigationDestination(
          icon: Icon(Icons.manage_accounts_outlined),
          selectedIcon: Icon(Icons.manage_accounts_rounded),
          label: 'Tài khoản',
        ),
      ],
    ),
    body: page == 1
        ? ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              const Text(
                'Tài khoản',
                style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              const Text(
                'Hồ sơ và tùy chọn bảo mật của bạn.',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 18),
              AnimatedEntrance(
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: mint,
                          child: Text(
                            widget.user['name']
                                .toString()
                                .substring(0, 1)
                                .toUpperCase(),
                            style: const TextStyle(
                              color: ink,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.user['name'],
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.user['email'],
                                style: const TextStyle(color: muted),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cập nhật hồ sơ cá nhân',
                          onPressed: editPersonalProfile,
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              sectionHeading('Thông tin tài khoản'),
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: mint,
                    child: Icon(Icons.badge_outlined),
                  ),
                  title: const Text('Vai trò'),
                  subtitle: Text(
                    {
                          'parent': 'Phụ huynh',
                          'child': 'Trẻ em',
                          'staff': 'Nhân viên',
                          'admin': 'Quản trị viên',
                        }[role] ??
                        role,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              sectionHeading('Tùy chỉnh giao diện'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(child: Text('Cỡ chữ')),
                          Text('${(appTextScale.value * 100).round()}%'),
                        ],
                      ),
                      Slider(
                        min: .85,
                        max: 1.25,
                        divisions: 4,
                        value: appTextScale.value,
                        label: '${(appTextScale.value * 100).round()}%',
                        onChanged: (value) => setState(() {
                          appTextScale.value = value;
                        }),
                        onChangeEnd: saveTextScale,
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: appBackgroundKey.value,
                        decoration: const InputDecoration(labelText: 'Màu nền'),
                        items: backgroundOptions.entries
                            .map(
                              (entry) => DropdownMenuItem(
                                value: entry.key,
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 10,
                                      backgroundColor: entry.value,
                                      foregroundColor: ink,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(entry.key),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) saveBackground(value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              sectionHeading(
                'Bảo mật',
                subtitle: 'Chọn cách mở ứng dụng bằng sinh trắc học.',
              ),
              Card(
                child: SwitchListTile(
                  secondary: const CircleAvatar(
                    backgroundColor: mint,
                    child: Icon(Icons.fingerprint),
                  ),
                  title: const Text('Vân tay'),
                  subtitle: const Text(
                    'Dùng sinh trắc học đã đăng ký trên điện thoại.',
                  ),
                  value: fingerprintEnabled,
                  onChanged: (enabled) =>
                      setBiometricEnabled(BiometricType.fingerprint, enabled),
                ),
              ),
              Card(
                child: SwitchListTile(
                  secondary: const CircleAvatar(
                    backgroundColor: mint,
                    child: Icon(Icons.face_retouching_natural),
                  ),
                  title: const Text('Khuôn mặt'),
                  subtitle: const Text(
                    'Dùng sinh trắc học đã đăng ký trên điện thoại.',
                  ),
                  value: faceEnabled,
                  onChanged: (enabled) =>
                      setBiometricEnabled(BiometricType.face, enabled),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: logout,
                icon: const Icon(Icons.logout),
                label: const Text('Đăng xuất khỏi tài khoản'),
              ),
            ],
          )
        : loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error!),
                  FilledButton(onPressed: load, child: const Text('Thử lại')),
                ],
              ),
            ),
          )
        : RefreshIndicator(
            onRefresh: load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                const Text(
                  'TỔNG QUAN • HÔM NAY',
                  style: TextStyle(
                    color: green,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  role == 'admin'
                      ? 'Hệ thống'
                      : role == 'staff'
                      ? 'Tổng quan vận hành'
                      : isParent
                      ? 'Gia đình của bạn'
                      : 'Không gian của con',
                  style: const TextStyle(
                    fontSize: 27,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  role == 'admin'
                      ? 'Trang quản trị'
                      : role == 'staff'
                      ? 'Tổng quan vận hành'
                      : 'Chào ${widget.user['name']}, cùng xây dựng thói quen số lành mạnh.',
                  style: const TextStyle(
                    color: muted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                if (selectedChild != null)
                  AnimatedEntrance(
                    child: ScreenTimeOverview(
                      child: selectedChild!,
                      profiles: children,
                      selectedChildId: selectedChildId,
                      onSelectChild: (id) {
                        setState(() => selectedChildId = id);
                      },
                      onOpenProfile: () => openChildProfile(selectedChild!),
                    ),
                  ),
                if (isParent) ...[
                  const SizedBox(height: 14),
                  _QuickActionRow(
                    icon: Icons.person_add_alt_1_rounded,
                    title: 'Tạo hồ sơ trẻ',
                    subtitle: 'Thêm hồ sơ và thỏa thuận thời gian số.',
                    onTap: () => editChild(),
                  ),
                  const SizedBox(height: 20),
                ] else
                  const SizedBox(height: 20),
                if (role == 'admin' || role == 'staff') ...[
                  sectionHeading(
                    'Tổng quan hoạt động',
                    subtitle: 'Số liệu tổng hợp của hệ thống.',
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) => Wrap(
                      spacing: 12,
                      runSpacing: 0,
                      children: stats.entries.map((e) {
                        final width = (constraints.maxWidth - 12) / 2;
                        return SizedBox(
                          width: width,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.key.replaceAll('_', ' ').toUpperCase(),
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: .5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${e.value}',
                                    style: const TextStyle(
                                      color: ink,
                                      fontSize: 25,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  if (role == 'staff')
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Nhân viên xem số liệu tổng hợp để hỗ trợ vận hành. Không truy cập hồ sơ riêng tư của gia đình.',
                        ),
                      ),
                    ),
                  if (role == 'admin')
                    sectionHeading(
                      'Tài khoản người dùng',
                      subtitle: '${users.length} tài khoản',
                    ),
                  ...users.map(
                    (u) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: mint,
                          child: Text(
                            u['name'].toString().substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              color: ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        title: Text(u['name']),
                        subtitle: Text('${u['email']} • ${u['role']}'),
                        onTap: () => manageUser(Map<String, dynamic>.from(u)),
                        trailing: IconButton(
                          tooltip: 'Quản lý tài khoản',
                          onPressed: () =>
                              manageUser(Map<String, dynamic>.from(u)),
                          icon: const Icon(Icons.manage_accounts_outlined),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  sectionHeading(
                    role == 'child'
                        ? 'Hồ sơ được liên kết'
                        : 'Gia đình của bạn',
                    subtitle: role == 'child'
                        ? 'Các thông tin phụ huynh đã chia sẻ với bạn.'
                        : 'Chọn hồ sơ để xem thông tin và hoạt động của trẻ.',
                  ),
                  if (children.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          children: [
                            const CircleAvatar(
                              radius: 28,
                              backgroundColor: mint,
                              child: Icon(
                                Icons.family_restroom_rounded,
                                color: green,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              isParent
                                  ? 'Chưa có hồ sơ trẻ'
                                  : 'Chưa có hồ sơ được liên kết',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isParent
                                  ? 'Thêm hồ sơ đầu tiên để bắt đầu đồng hành cùng con.'
                                  : 'Nhờ phụ huynh liên kết email tài khoản con trong hồ sơ trẻ.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: muted, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ...children.map(
                    (c) => Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        leading: CircleAvatar(
                          radius: 25,
                          backgroundColor: mint,
                          child: Text(
                            c['name'].toString().substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              color: ink,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        title: Text(
                          c['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${c['age']} tuổi • ${c['daily_limit']} phút/ngày',
                          style: const TextStyle(color: muted),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                        ),
                        onTap: () =>
                            openChildProfile(Map<String, dynamic>.from(c)),
                        onLongPress: isParent
                            ? () => editChild(Map<String, dynamic>.from(c))
                            : null,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
  );
}

Future<Map<String, String>?> editDialog(
  BuildContext context,
  String title,
  Map<String, (String, String)> fields,
) async {
  final controllers = fields.map(
    (key, value) => MapEntry(key, TextEditingController(text: value.$2)),
  );
  final result = await showDialog<Map<String, String>>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: fields.entries
              .map(
                (e) => field(
                  controllers[e.key]!,
                  e.value.$1,
                  keyboard: ['age', 'daily_limit', 'reward'].contains(e.key)
                      ? TextInputType.number
                      : e.key == 'email'
                      ? TextInputType.emailAddress
                      : null,
                ),
              )
              .toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            ctx,
            controllers.map((k, v) => MapEntry(k, v.text.trim())),
          ),
          child: const Text('Lưu'),
        ),
      ],
    ),
  );
  // Controllers stay alive until the dialog route has completed its exit animation.
  Future.delayed(const Duration(seconds: 1), () {
    for (final c in controllers.values) {
      c.dispose();
    }
  });
  return result;
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({
    required this.label,
    required this.value,
    required this.detail,
    this.accent = false,
  });

  final String label;
  final String value;
  final String detail;
  final bool accent;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: muted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: .5,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        value,
        style: TextStyle(
          color: accent ? green : ink,
          fontSize: 25,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
      ),
      Text(detail, style: const TextStyle(color: muted, fontSize: 12)),
    ],
  );
}

class ChildPage extends StatefulWidget {
  final Map<String, dynamic> child;
  final bool isParent;
  const ChildPage({super.key, required this.child, required this.isParent});
  @override
  State<ChildPage> createState() => _ChildPageState();
}

class _ChildPageState extends State<ChildPage> {
  List<dynamic> devices = [], agreements = [], checkins = [];
  bool busy = true;
  String? error;
  String get id => widget.child['id'];
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    NfcManager.instance.stopSession();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final r = await Future.wait([
        api.call('GET', '/children/$id/devices'),
        api.call('GET', '/children/$id/agreements'),
        api.call('GET', '/children/$id/checkins'),
      ]);
      devices = r[0];
      agreements = r[1];
      checkins = r[2];
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> act(Future<void> Function() f) async {
    try {
      await f();
      await load();
    } catch (e) {
      if (mounted) notify(context, e);
    }
  }

  Future<void> device([Map<String, dynamic>? d]) async {
    final b = await editDialog(
      context,
      d == null ? 'Thêm thiết bị' : 'Đổi tên thiết bị',
      {'name': ('Tên điện thoại', d?['name'] ?? '')},
    );
    if (b == null) return;
    await act(() async {
      await api.call(
        d == null ? 'POST' : 'PUT',
        d == null ? '/children/$id/devices' : '/devices/${d['id']}',
        b,
      );
    });
  }

  Future<void> agreement() async {
    final b = await editDialog(context, 'Thỏa thuận thời gian số', {
      'title': ('Mục tiêu (ví dụ đọc sách 30 phút)', ''),
      'reward': ('Phút thưởng', '15'),
    });
    if (b == null) return;
    await act(() async {
      await api.call('POST', '/children/$id/agreements', {
        'title': b['title'],
        'reward': int.tryParse(b['reward'] ?? '') ?? 0,
      });
    });
  }

  Future<void> nfc(bool enroll) async {
    try {
      if (!await NfcManager.instance.isAvailable()) {
        throw Exception('Thiết bị không hỗ trợ NFC hoặc NFC chưa bật.');
      }
      if (!mounted) return;
      bool scanned = false;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(enroll ? 'Gắn thẻ NFC' : 'Check-in NFC'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.nfc, size: 64, color: green),
              SizedBox(height: 16),
              Text('Đưa thẻ đến mặt sau điện thoại.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await NfcManager.instance.stopSession();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Hủy'),
            ),
          ],
        ),
      );
      await NfcManager.instance.startSession(
        onDiscovered: (tag) async {
          if (scanned) return;
          scanned = true;
          try {
            List<int>? uid;
            for (final key in [
              'nfca',
              'nfcb',
              'nfcf',
              'nfcv',
              'mifareclassic',
              'mifareultralight',
              'isodep',
            ]) {
              final d = tag.data[key];
              if (d is Map && d['identifier'] is List) {
                uid = List<int>.from(d['identifier']);
                break;
              }
            }
            if (uid == null || uid.isEmpty) {
              throw Exception('Thẻ không có UID được hỗ trợ');
            }
            final tagHash = sha256.convert(uid).toString();
            await api.call(
              enroll ? 'PUT' : 'POST',
              '/children/$id/${enroll ? 'nfc' : 'checkins'}',
              {'tagHash': tagHash},
            );
            await NfcManager.instance.stopSession();
            if (mounted) {
              Navigator.pop(context);
              notify(context, enroll ? 'Đã gắn thẻ' : 'Check-in thành công');
              await load();
            }
          } catch (e) {
            await NfcManager.instance.stopSession();
            if (mounted) {
              Navigator.pop(context);
              notify(context, e);
            }
          }
        },
      );
    } on PlatformException catch (e) {
      if (mounted) notify(context, e.message ?? 'Lỗi NFC');
    } catch (e) {
      if (mounted) notify(context, e);
    }
  }

  Future<bool> confirm(String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xóa'),
            ),
          ],
        ),
      ) ??
      false;
  @override
  Widget build(BuildContext context) {
    final bonus = agreements
        .where((a) => a['status'] == 'approved')
        .fold<int>(0, (sum, a) => sum + (a['reward'] as int));
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.child['name']),
        actions: [
          IconButton(
            tooltip: 'Làm mới hồ sơ',
            onPressed: load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: busy
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: TextButton(
                onPressed: load,
                child: Text('$error\nThử lại'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
              children: [
                AnimatedEntrance(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: mint,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: const Icon(
                                Icons.person_outline_rounded,
                                color: green,
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.child['name'].toString(),
                                    style: const TextStyle(
                                      color: ink,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${widget.child['age']} tuổi • Hồ sơ trẻ',
                                    style: const TextStyle(color: muted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const Divider(),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _ProfileMetric(
                                label: 'GIỚI HẠN MỖI NGÀY',
                                value: '${widget.child['daily_limit']}',
                                detail: 'phút',
                                accent: true,
                              ),
                            ),
                            Container(width: 1, height: 52, color: border),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _ProfileMetric(
                                label: 'THƯỞNG ĐÃ DUYỆT',
                                value: '$bonus',
                                detail: 'phút',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Đây là kế hoạch đã lưu; ứng dụng chưa theo dõi thời gian sử dụng hoặc chặn ứng dụng trên thiết bị.',
                          style: TextStyle(
                            color: muted,
                            height: 1.45,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.isParent) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final b = await editDialog(context, 'Sửa hồ sơ', {
                            'name': ('Tên', widget.child['name']),
                            'age': ('Tuổi', '${widget.child['age']}'),
                            'daily_limit': (
                              'Phút/ngày',
                              '${widget.child['daily_limit']}',
                            ),
                          });
                          if (b == null) return;
                          await act(() async {
                            final r = await api.call('PUT', '/children/$id', {
                              'name': b['name'],
                              'age': int.tryParse(b['age'] ?? '') ?? 0,
                              'daily_limit':
                                  int.tryParse(b['daily_limit'] ?? '') ?? 0,
                            });
                            widget.child.addAll(Map<String, dynamic>.from(r));
                          });
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Sửa hồ sơ'),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          final b = await editDialog(
                            context,
                            'Liên kết tài khoản trẻ',
                            {
                              'email': (
                                'Email tài khoản trẻ đã được admin cấp quyền',
                                '',
                              ),
                            },
                          );
                          if (b != null) {
                            await act(() async {
                              await api.call('POST', '/children/$id/link', b);
                              if (context.mounted) {
                                notify(context, 'Đã liên kết');
                              }
                            });
                          }
                        },
                        child: const Text('Liên kết trẻ'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                sectionHeading(
                  'Thiết bị của con',
                  subtitle: 'Điện thoại được ghi nhận trong hồ sơ.',
                  action: widget.isParent
                      ? IconButton.filledTonal(
                          tooltip: 'Thêm thiết bị',
                          onPressed: () => device(),
                          icon: const Icon(Icons.add_rounded),
                        )
                      : null,
                ),
                if (devices.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Chưa có thiết bị. Thêm tên điện thoại để quản lý hồ sơ.',
                        style: TextStyle(color: muted),
                      ),
                    ),
                  ),
                ...devices.map(
                  (d) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.phone_android, color: green),
                      title: Text(d['name']),
                      subtitle: const Text('Android • hồ sơ thiết bị'),
                      onTap: widget.isParent
                          ? () => device(Map<String, dynamic>.from(d))
                          : null,
                      trailing: widget.isParent
                          ? IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                if (await confirm('Xóa thiết bị này?')) {
                                  await act(() async {
                                    await api.call(
                                      'DELETE',
                                      '/devices/${d['id']}',
                                    );
                                  });
                                }
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                sectionHeading(
                  'Thỏa thuận tích cực',
                  subtitle: 'Cùng con xây dựng thói quen tốt mỗi ngày.',
                  action: IconButton.filledTonal(
                    tooltip: 'Tạo thỏa thuận',
                    onPressed: agreement,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ),
                ...agreements.map(
                  (a) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const CircleAvatar(
                                radius: 19,
                                backgroundColor: mint,
                                child: Icon(
                                  Icons.flag_outlined,
                                  color: green,
                                  size: 19,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      a['title'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '+${a['reward']} phút • ${{'pending': 'Chờ duyệt', 'approved': 'Đã duyệt', 'rejected': 'Từ chối'}[a['status']]}',
                                      style: const TextStyle(color: muted),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (widget.isParent)
                            Wrap(
                              spacing: 8,
                              alignment: WrapAlignment.end,
                              children: [
                                if (a['status'] == 'pending')
                                  ...['approved', 'rejected'].map(
                                    (s) => TextButton(
                                      onPressed: () => act(() async {
                                        await api.call(
                                          'PATCH',
                                          '/agreements/${a['id']}',
                                          {'status': s},
                                        );
                                      }),
                                      child: Text(
                                        s == 'approved' ? 'Duyệt' : 'Từ chối',
                                      ),
                                    ),
                                  ),
                                TextButton(
                                  onPressed: () async {
                                    if (await confirm('Xóa thỏa thuận này?')) {
                                      await act(() async {
                                        await api.call(
                                          'DELETE',
                                          '/agreements/${a['id']}',
                                        );
                                      });
                                    }
                                  },
                                  child: const Text('Xóa'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                LocationCard(api: api, childId: id, canShare: !widget.isParent),
                const SizedBox(height: 24),
                sectionHeading(
                  'Điểm chạm an tâm',
                  subtitle: 'Check-in nhanh chóng bằng thẻ NFC.',
                ),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Chạm thẻ NFC để ghi nhận check-in. UID thẻ không phải bằng chứng danh tính hay vị trí.',
                      style: TextStyle(color: muted, height: 1.4),
                    ),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => nfc(false),
                      icon: const Icon(Icons.nfc),
                      label: const Text('Check-in NFC'),
                    ),
                    if (widget.isParent)
                      OutlinedButton.icon(
                        onPressed: () => nfc(true),
                        icon: const Icon(Icons.add_link_rounded),
                        label: const Text('Gắn thẻ'),
                      ),
                  ],
                ),
                ...checkins.map(
                  (c) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: mint,
                        child: Icon(Icons.check_rounded),
                      ),
                      title: const Text('Check-in thành công'),
                      subtitle: Text(
                        DateTime.parse(
                          c['created_at'],
                        ).toLocal().toString().split('.').first,
                      ),
                    ),
                  ),
                ),
                if (widget.isParent) ...[
                  const SizedBox(height: 32),
                  TextButton.icon(
                    onPressed: () async {
                      if (!await confirm(
                        'Xóa hồ sơ cùng thiết bị, thỏa thuận và lịch sử check-in?',
                      )) {
                        return;
                      }
                      try {
                        await api.call('DELETE', '/children/$id');
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        if (context.mounted) notify(context, e);
                      }
                    },
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    label: const Text(
                      'Xóa hồ sơ trẻ',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
                const SizedBox(height: 30),
              ],
            ),
    );
  }
}
