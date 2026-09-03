import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import '../errors/app_error.dart';

class NetworkClient {
  final Dio _dio;
  
  NetworkClient({String? baseUrl}) : _dio = Dio(BaseOptions(
    baseUrl: baseUrl ?? '',
    connectTimeout: AppConstants.connectionTimeout,
    receiveTimeout: AppConstants.receiveTimeout,
    sendTimeout: AppConstants.connectionTimeout,
  )) {
    _dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: false,
      error: true,
    ));
  }
  
  Dio get dio => _dio;
  
  Future<Response> get(
    String url, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.get(
        url,
        queryParameters: queryParameters,
        options: Options(headers: headers),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }
  
  Future<Response> post(
    String url, {
    dynamic data,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    try {
      return await _dio.post(
        url,
        data: data,
        options: Options(headers: headers),
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }
  
  Stream<Response> postStream(
    String url, {
    dynamic data,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
  }) async* {
    try {
      final response = await _dio.post(
        url,
        data: data,
        options: Options(
          headers: {
            ...?headers,
            'Accept': 'text/event-stream',
          },
          responseType: ResponseType.stream,
        ),
        cancelToken: cancelToken,
      );
      yield response;
    } on DioException catch (e) {
      yield* Stream.error(_handleDioError(e));
      return;
    }
  }
  
  AppError _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TimeoutError(technicalMessage: error.message);
      case DioExceptionType.connectionError:
        return NetworkError(technicalMessage: error.message);
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode == 401) {
          return AuthenticationError(statusCode: statusCode);
        } else if (statusCode == 429) {
          return RateLimitError(statusCode: statusCode);
        } else if (statusCode == 404) {
          return ModelNotFoundError(statusCode: statusCode);
        }
        return InvalidResponseError(
          message: 'Request failed with status $statusCode',
          statusCode: statusCode,
        );
      case DioExceptionType.cancel:
        return NetworkError(message: 'Request was cancelled.');
      default:
        return NetworkError(technicalMessage: error.message);
    }
  }
  
  void dispose() {
    _dio.close();
  }
}
