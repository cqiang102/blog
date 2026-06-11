import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'src/core/app.dart';
import 'src/core/provider_retry.dart';

void main() {
  usePathUrlStrategy();
  runApp(const ProviderScope(retry: appProviderRetry, child: BlogApp()));
}
