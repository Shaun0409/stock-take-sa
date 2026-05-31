import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Change this to your production URL when deploying
  static const String PRODUCTION_URL = 'https://stock-take-sa.onrender.com/api';
  static const String DEVELOPMENT_URL = 'http://localhost:3000/api';

  // Set to false for production, true for local development
  static const bool IS_DEVELOPMENT = false;

  String get baseUrl => IS_DEVELOPMENT ? DEVELOPMENT_URL : PRODUCTION_URL;

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Content-Type': 'application/json',
    },
  ));

  // Company Login
  Future<Map<String, dynamic>> companyLogin(
      String email, String licenseKey) async {
    try {
      final response = await _dio.post('$baseUrl/company/login', data: {
        'email': email,
        'licenseKey': licenseKey,
      });

      if (response.statusCode == 200 && response.data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('company_id', response.data['company']['id']);
        await prefs.setString('company_name', response.data['company']['name']);
        await prefs.setString(
            'license_key', response.data['company']['license_key']);
        await prefs.setBool('is_logged_in', true);

        return {'success': true, 'data': response.data};
      }
      return {'success': false, 'message': 'Login failed'};
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        return {
          'success': false,
          'message': e.response?.data['message'] ?? 'Account suspended',
          'suspended': true,
          'support_email':
              e.response?.data['support_email'] ?? 'support@stocktake.co.za'
        };
      }
      if (e.response?.statusCode == 401) {
        return {
          'success': false,
          'message':
              e.response?.data['message'] ?? 'Invalid email or license key'
        };
      }
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Network error'
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_logged_in') ?? false;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<String?> getCompanyId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('company_id');
  }

  Future<String?> getLicenseKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('license_key');
  }

  Future<String?> getCompanyName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('company_name');
  }

  // =====================================================
  // STORES API
  // =====================================================

  Future<List<dynamic>> getStores() async {
    final companyId = await getCompanyId();
    if (companyId == null) return [];

    final response = await _dio.get('$baseUrl/companies/$companyId/stores');
    return response.data;
  }

  Future<Map<String, dynamic>> createStore(
      Map<String, dynamic> storeData) async {
    final companyId = await getCompanyId();
    final response = await _dio.post('$baseUrl/stores', data: {
      'company_id': companyId,
      ...storeData,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> updateStore(
      String storeId, Map<String, dynamic> storeData) async {
    final response =
        await _dio.put('$baseUrl/stores/$storeId', data: storeData);
    return response.data;
  }

  Future<bool> deleteStore(String storeId) async {
    final response = await _dio.delete('$baseUrl/stores/$storeId');
    return response.statusCode == 200;
  }

  // =====================================================
  // PRODUCTS API
  // =====================================================

  Future<List<dynamic>> getProducts() async {
    final companyId = await getCompanyId();
    if (companyId == null) return [];

    final response = await _dio.get('$baseUrl/companies/$companyId/products');
    return response.data;
  }

  Future<Map<String, dynamic>> createProduct(
      Map<String, dynamic> productData) async {
    final companyId = await getCompanyId();
    final response = await _dio.post('$baseUrl/products', data: {
      'company_id': companyId,
      ...productData,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> updateProduct(
      String productId, Map<String, dynamic> productData) async {
    final response =
        await _dio.put('$baseUrl/products/$productId', data: productData);
    return response.data;
  }

  Future<bool> deleteProduct(String productId) async {
    final response = await _dio.delete('$baseUrl/products/$productId');
    return response.statusCode == 200;
  }

  Future<List<dynamic>> searchProducts(String query) async {
    final companyId = await getCompanyId();
    if (companyId == null) return [];

    final response =
        await _dio.get('$baseUrl/products/search', queryParameters: {
      'q': query,
      'companyId': companyId,
    });
    return response.data;
  }

  // =====================================================
  // STOCK TAKES API
  // =====================================================

  Future<List<dynamic>> getStockTakes(String storeId) async {
    final response = await _dio.get('$baseUrl/stores/$storeId/stocktakes');
    return response.data;
  }

  Future<Map<String, dynamic>> startStockTake(
      String storeId, DateTime date, String? notes) async {
    final response = await _dio.post('$baseUrl/stocktakes', data: {
      'store_id': storeId,
      'stock_take_date': date.toIso8601String().split('T')[0],
      'notes': notes,
      'is_offline': true,
    });
    return response.data;
  }

  Future<bool> addStockTakeItems(
      String stockTakeId, List<Map<String, dynamic>> items) async {
    final response =
        await _dio.post('$baseUrl/stocktakes/$stockTakeId/items', data: {
      'items': items,
    });
    return response.statusCode == 200;
  }

  Future<Map<String, dynamic>> completeStockTake(
      String stockTakeId, DateTime endTime) async {
    final response =
        await _dio.put('$baseUrl/stocktakes/$stockTakeId/complete', data: {
      'end_time': endTime.toIso8601String(),
    });
    return response.data;
  }

  Future<List<dynamic>> getStockTakeItems(String stockTakeId) async {
    final response = await _dio.get('$baseUrl/stocktakes/$stockTakeId/items');
    return response.data;
  }

  Future<Map<String, dynamic>> calculateShrinkage(
      String storeId, DateTime startDate, DateTime endDate) async {
    final response =
        await _dio.get('$baseUrl/stores/$storeId/shrinkage', queryParameters: {
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate.toIso8601String().split('T')[0],
    });
    return response.data;
  }

  // =====================================================
  // COMPANY PROFILE API
  // =====================================================

  Future<Map<String, dynamic>> getCompanyProfile() async {
    final companyId = await getCompanyId();
    if (companyId == null) return {};

    final response = await _dio.get('$baseUrl/companies/$companyId/profile');
    return response.data;
  }

  Future<Map<String, dynamic>> updateCompanyProfile(
      Map<String, dynamic> profileData) async {
    final companyId = await getCompanyId();
    final response = await _dio.put('$baseUrl/companies/$companyId/profile',
        data: profileData);
    return response.data;
  }

  Future<Map<String, dynamic>> getCompanyStats() async {
    final companyId = await getCompanyId();
    if (companyId == null) return {};

    final response = await _dio.get('$baseUrl/companies/$companyId/stats');
    return response.data;
  }
}
