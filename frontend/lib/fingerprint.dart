import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

class BiometricAuth {
  final LocalAuthentication _auth = LocalAuthentication();

  bool get canChooseBiometricType =>
      defaultTargetPlatform != TargetPlatform.android;

  Future<bool> available(BiometricType type) async {
    final types = await _auth.getAvailableBiometrics();
    if (canChooseBiometricType) return types.contains(type);
    return types.contains(BiometricType.weak) ||
        types.contains(BiometricType.strong);
  }

  Future<bool> authenticate(BuildContext context, BiometricType type) async {
    if (!await available(type)) {
      throw Exception(
        canChooseBiometricType
            ? 'Thiết bị chưa đăng ký ${type == BiometricType.face ? 'khuôn mặt' : 'vân tay'}.'
            : 'Thiết bị chưa đăng ký sinh trắc học.',
      );
    }
    return _auth.authenticate(
      localizedReason: 'Xác thực sinh trắc học để mở ChildGuard',
      options: const AuthenticationOptions(
        biometricOnly: true,
        stickyAuth: true,
      ),
    );
  }
}
