import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DioClient {
  static final DioClient _instance = DioClient._internal();
  late Dio dio;
  final storage = const FlutterSecureStorage();

  factory DioClient() {
    return _instance;
  }

  DioClient._internal() {
    dio = Dio(BaseOptions(
      // Localhost + `adb reverse tcp:8080 tcp:8080` (USB): el teléfono ve el
      // backend de tu PC como si fuera local, sin depender de la IP de WiFi.
      // Si pruebas sin cable, cambia esto por la IP LAN de tu PC.
      baseUrl: 'http://localhost:8080/api/v1',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await storage.read(key: 'jwt_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          // Token expired or invalid, handle logout
          await storage.delete(key: 'jwt_token');
        }
        return handler.next(e);
      },
    ));
  }
}

final dioClient = DioClient();
