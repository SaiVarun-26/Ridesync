import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/room_providers.dart';

/// Builds a room screen, given a callback that starts the leave flow and
/// whether a leave is in progress.
typedef RoomExitBuilder = Widget Function(
  BuildContext context,
  VoidCallback requestLeave,
  bool isLeaving,
);

/// Wraps a room-flow screen with a confirmed "leave ride" flow.
///
/// Room screens are reached with `go`, so each is the root of the navigation
/// stack and the system back gesture would otherwise close the app while the
/// rider still holds a color. This scope intercepts back, asks for
/// confirmation, leaves the room (releasing the rider's color), and returns
/// home. Screens can also trigger the same flow via the builder's
/// `requestLeave` callback.
class RoomExitScope extends ConsumerStatefulWidget {
  const RoomExitScope({
    super.key,
    required this.roomCode,
    required this.builder,
  });

  final String roomCode;
  final RoomExitBuilder builder;

  @override
  ConsumerState<RoomExitScope> createState() => _RoomExitScopeState();
}

class _RoomExitScopeState extends ConsumerState<RoomExitScope> {
  bool _isLeaving = false;

  Future<void> _requestLeave() async {
    if (_isLeaving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave this ride?'),
        content: const Text('Your color will be released for other riders.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.warning),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false) || !mounted) return;

    setState(() => _isLeaving = true);
    final result = await ref
        .read(roomRepositoryProvider)
        .leaveRoom(code: widget.roomCode);
    if (!mounted) return;
    switch (result) {
      case Success():
        context.go(AppRoutes.home);
      case Failed(:final failure):
        setState(() => _isLeaving = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestLeave();
      },
      child: widget.builder(context, _requestLeave, _isLeaving),
    );
  }
}
