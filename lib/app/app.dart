import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/ride/presentation/providers/pending_upload_providers.dart';
import 'router/app_router.dart';

/// The root application widget. Wires the router and the single dark theme.
class RideSyncApp extends ConsumerWidget {
  const RideSyncApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Keeps the offline upload worker alive for the whole session, so rides
    // finished offline upload as soon as the connection returns.
    ref.listen(pendingRideUploadsProvider, (_, _) {});
    // WithForegroundTask lets a tap on the ride notification resume this app
    // task instead of starting a new one.
    return WithForegroundTask(
      child: MaterialApp.router(
        title: 'RideSync',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        routerConfig: router,
      ),
    );
  }
}
