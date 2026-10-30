import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luongbaoloc_2380601272/main.dart';
import 'package:luongbaoloc_2380601272/location_card.dart';

void main() {
  test('Location accuracy is rounded for compact display', () {
    expect(formatLocationAccuracy(14.576000213623047), '14.6');
    expect(formatLocationAccuracy(null), '');
  });

  testWidgets(
    'Login exposes separate biometric buttons; registration can be opened',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(const ChildGuard());
        await tester.pumpAndSettle();
        expect(
          Theme.of(tester.element(find.byType(Scaffold))).brightness,
          Brightness.dark,
        );
        expect(find.text('ChildGuard'), findsOneWidget);
        expect(find.text('Đăng nhập với OTP'), findsOneWidget);
        expect(find.text('Tiếp tục với Google'), findsOneWidget);
        expect(find.text('Mở bằng vân tay'), findsOneWidget);
        expect(find.text('Mở bằng khuôn mặt'), findsOneWidget);
        await tester.ensureVisible(find.text('Chưa có tài khoản? Đăng ký'));
        await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
        await tester.pumpAndSettle();
        expect(find.text('Tạo tổ ấm an toàn'), findsOneWidget);
        expect(find.text('Email'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('Android uses the system-selected biometric option', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(const ChildGuard());
      await tester.pumpAndSettle();

      expect(find.text('Mở bằng sinh trắc học'), findsOneWidget);
      expect(find.text('Mở bằng khuôn mặt'), findsNothing);
      expect(find.text('Mở bằng vân tay'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Theme setting updates the app brightness', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => appDarkMode.value = true);
    addTearDown(() => appTextScale.value = 1);

    await tester.pumpWidget(const ChildGuard());
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.dark,
    );

    appDarkMode.value = false;
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.light,
    );
  });

  testWidgets('Text scale setting updates text throughout the app', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => appTextScale.value = 1);

    await tester.pumpWidget(const ChildGuard());
    await tester.pumpAndSettle();
    final text = tester.element(find.text('Đăng nhập với OTP'));
    expect(MediaQuery.textScalerOf(text).scale(14), 14);

    appTextScale.value = 1.2;
    await tester.pumpAndSettle();
    expect(MediaQuery.textScalerOf(text).scale(14), 16.8);
  });

  testWidgets('Time overview never invents usage values', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ScreenTimeOverview(
              child: const {
                'id': 'child-1',
                'name': 'Linh',
                'age': 10,
                'daily_limit': 120,
                'bonus_minutes_today': 30,
              },
              profiles: const [
                {
                  'id': 'child-1',
                  'name': 'Linh',
                  'age': 10,
                  'daily_limit': 120,
                  'bonus_minutes_today': 30,
                },
              ],
              selectedChildId: 'child-1',
              onSelectChild: (_) {},
              onOpenProfile: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('150'), findsOneWidget);
    expect(find.text('phút mỗi ngày'), findsOneWidget);
    expect(find.text('Gồm +30 phút thưởng NFC'), findsOneWidget);
    expect(find.text('Chưa được theo dõi'), findsOneWidget);
    expect(
      find.text(
        'Đây là giới hạn đã thiết lập; ứng dụng chưa thu thập thời gian sử dụng thực tế trên thiết bị.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
