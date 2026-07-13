import 'package:dio/browser.dart';
import 'package:dio/dio.dart';

void configureDioCredentials(Dio dio) {
  dio.httpClientAdapter = BrowserHttpClientAdapter()..withCredentials = true;
}
