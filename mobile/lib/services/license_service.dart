import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'dart:io';

class LicenseService {
  static const String API_URL = 'http://localhost:3000/api/validate-license';
  static const String LICENSE_KEY_PREF = 'license_key';

  final Dio _dio = Dio();

  Future<bool> checkLicense() async {
    final prefs = await SharedPreferences.getInstance();
    String? licenseKey = prefs.getString(LICENSE_KEY_PREF);

    // If no license key stored, prompt user to enter one
    if (licenseKey == null || licenseKey.isEmpty) {
      licenseKey = await _promptForLicenseKey();
      if (licenseKey == null) return false;
      await prefs.setString(LICENSE_KEY_PREF, licenseKey);
    }

    try {
      final response = await _dio.get(
        '$API_URL/$licenseKey',
        options: Options(
          headers: {
            'X-Device-ID': Platform.isAndroid
                ? 'android_${licenseKey}'
                : 'web_${licenseKey}',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['valid'] == true) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      // If offline, assume valid but check again later
      return true;
    }
  }

  Future<String?> _promptForLicenseKey() async {
    // In production, show a dialog
    // For now, return a default for testing
    return 'LIC-TEST-123-XYZ';
  }
}
