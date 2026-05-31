import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CompanyService {
  static final CompanyService _instance = CompanyService._internal();
  factory CompanyService() => _instance;
  CompanyService._internal();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://localhost:3000/api',
    connectTimeout: const Duration(seconds: 30),
  ));

  Future<Map<String, dynamic>> getCompanyProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final companyId = prefs.getString('company_id');
    final licenseKey = prefs.getString('license_key');

    try {
      final response = await _dio.get('/companies/$companyId/profile',
          options: Options(headers: {'X-License-Key': licenseKey}));
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateCompanyProfile(
      Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    final companyId = prefs.getString('company_id');
    final licenseKey = prefs.getString('license_key');

    try {
      final response = await _dio.put('/companies/$companyId/profile',
          data: jsonEncode(profile),
          options: Options(headers: {
            'X-License-Key': licenseKey,
            'Content-Type': 'application/json'
          }));
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> uploadLogo(String base64Logo) async {
    final prefs = await SharedPreferences.getInstance();
    final companyId = prefs.getString('company_id');
    final licenseKey = prefs.getString('license_key');

    try {
      final response = await _dio.post('/companies/$companyId/logo',
          data: jsonEncode({'logo': base64Logo}),
          options: Options(headers: {
            'X-License-Key': licenseKey,
            'Content-Type': 'application/json'
          }));
      return {'success': true, 'logo_url': response.data['logo_url']};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
