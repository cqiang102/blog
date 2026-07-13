import 'package:dio/dio.dart';

import 'dio_credentials_stub.dart'
    if (dart.library.js_interop) 'dio_credentials_web.dart'
    as platform;

/// Enables browser cookies for refresh-token rotation on web builds.
void configureDioCredentials(Dio dio) => platform.configureDioCredentials(dio);
