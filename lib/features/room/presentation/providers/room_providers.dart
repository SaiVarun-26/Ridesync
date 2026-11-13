import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/result.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/firebase_room_repository.dart';
import '../../domain/room.dart';
import '../../domain/room_preview.dart';
import '../../domain/room_repository.dart';

/// Exposes the [FirebaseDatabase] singleton as an overridable dependency so
/// tests can inject a fake instance without reaching for the global.
final firebaseDatabaseProvider = Provider<FirebaseDatabase>((ref) {
  return FirebaseDatabase.instance;
});

/// The app's [RoomRepository], wired to the Realtime Database implementation.
///
/// Presentation code depends only on the [RoomRepository] interface. Tests
/// override this provider with a mock.
final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  return FirebaseRoomRepository(
    database: ref.watch(firebaseDatabaseProvider),
    authRepository: ref.watch(authRepositoryProvider),
  );
});

/// A live stream of the room identified by the given code.
///
/// Keyed by room code and auto-disposed, so the database listener is detached
/// as soon as the lobby stops watching it. Emits `null` when the room no
/// longer exists.
final roomStreamProvider = StreamProvider.autoDispose.family<Room?, String>((
  ref,
  code,
) {
  return ref.watch(roomRepositoryProvider).watchRoom(code: code);
});

/// A look at the room with `code` before joining: its name, how many riders
/// are in it and whether it still takes new ones. Read once per code (no live
/// listener); a failure surfaces as an error holding the [Failure].
final roomPreviewProvider = FutureProvider.autoDispose
    .family<RoomPreview, String>((ref, code) async {
      final result = await ref
          .watch(roomRepositoryProvider)
          .previewRoom(code: code);
      return switch (result) {
        Success(:final value) => value,
        Failed(:final failure) => throw failure,
      };
    });

/// Maintains the current rider's presence in the given room while watched.
///
/// Auto-disposed so presence tracking stops when the rider leaves the lobby.
/// Emits whether the client is currently connected to the database.
final roomPresenceProvider = StreamProvider.autoDispose.family<bool, String>((
  ref,
  code,
) {
  return ref.watch(roomRepositoryProvider).trackPresence(code: code);
});
