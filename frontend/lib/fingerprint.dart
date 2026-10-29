import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

class BiometricAuth {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> available(BiometricType type) async {
    final types = await _auth.getAvailableBiometrics();
    return types.contains(type) ||
        types.contains(BiometricType.weak) ||
        types.contains(BiometricType.strong);
  }

  Future<bool> authenticate(BuildContext context, BiometricType type) async {
    if (!await available(type)) {
      throw Exception(
        'Thiết bị chưa đăng ký sinh trắc học hoặc không hỗ trợ xác thực này.',
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
