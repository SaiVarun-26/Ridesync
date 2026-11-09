import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/domain/auth_repository.dart';
import '../domain/ride_mode.dart';
import '../domain/room.dart';
import '../domain/room_repository.dart';
import '../domain/room_status.dart';
import 'room_code_generator.dart';
import 'room_dto.dart';

/// Realtime Database implementation of [RoomRepository].
///
/// All room state is live data and lives in RTDB. Color claiming uses database
/// transactions to guarantee uniqueness under concurrency, and presence is
/// maintained with `onDisconnect` handlers so a dropped connection marks the
/// member offline and resets their ready state automatically.
///
/// [FirebaseDatabase] and [AuthRepository] are injected for testability; the
/// code generator is injected so tests can supply a deterministic [Random].
class FirebaseRoomRepository implements RoomRepository {
  FirebaseRoomRepository({
    required FirebaseDatabase database,
    required AuthRepository authRepository,
    RoomCodeGenerator? codeGenerator,
  })  : _database = database,
        _authRepository = authRepository,
        _codeGenerator = codeGenerator ?? RoomCodeGenerator();

  final FirebaseDatabase _database;
  final AuthRepository _authRepository;
  final RoomCodeGenerator _codeGenerator;

  /// Number of attempts to find an unused room code before giving up.
  static const int _maxCodeAttempts = 5;

  DatabaseReference get _roomsRef => _database.ref(RoomPaths.rooms);

  DatabaseReference _roomRef(String code) => _roomsRef.child(code);

  @override
  Future<Result<Room>> createRoom({required String name}) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return const Failed(
        UnexpectedFailure(message: 'Give your ride a name.'),
      );
    }

    // The durable profile (Firestore) is the source of truth for the display
    // name shown to other riders.
    final AppUser user;
    switch (await _authRepository.loadCurrentProfile()) {
      case Success(:final value):
        user = value;
      case Failed(:final failure):
        return Failed(failure);
    }

    try {
      final code = await _createRoomMeta(hostUid: user.uid, name: trimmedName);
      if (code == null) {
        return const Failed(
          UnexpectedFailure(
            message: 'Could not create a room. Please try again.',
          ),
        );
      }

      final roomRef = _roomRef(code);
      await _writeMembership(
        code: code,
        uid: user.uid,
        displayName: user.displayName,
      );

      final snapshot = await roomRef.get();
      final room = RoomDto.fromSnapshot(code, snapshot.value);
      if (room == null) {
        return const Failed(UnexpectedFailure());
      }
      return Success(room);
    } on FirebaseException catch (e, stack) {
      return Failed(_mapDbException(e, stack));
    } catch (e, stack) {
      return Failed(_unexpected(e, stack));
    }
  }

  @override
  Future<Result<Room>> joinRoom({required String code}) async {
    final normalized = code.trim().toUpperCase();
    if (!RoomCodeGenerator.isValid(normalized)) {
      return const Failed(
        NotFoundFailure(message: 'That code looks invalid. Check and retry.'),
      );
    }

    final AppUser user;
    switch (await _authRepository.loadCurrentProfile()) {
      case Success(:final value):
        user = value;
      case Failed(:final failure):
        return Failed(failure);
    }

    try {
      final metaSnapshot =
          await _roomRef(normalized).child(RoomPaths.meta).get();
      if (!metaSnapshot.exists) {
        return const Failed(
          NotFoundFailure(message: 'No ride found for that code.'),
        );
      }

      await _writeMembership(
        code: normalized,
        uid: user.uid,
        displayName: user.displayName,
      );

      final snapshot = await _roomRef(normalized).get();
      final room = RoomDto.fromSnapshot(normalized, snapshot.value);
      if (room == null) {
        return const Failed(NotFoundFailure(message: 'No ride found.'));
      }
      return Success(room);
    } on FirebaseException catch (e, stack) {
      return Failed(_mapDbException(e, stack));
    } catch (e, stack) {
      return Failed(_unexpected(e, stack));
    }
  }

  @override
  Future<Result<void>> claimColor({
    required String code,
    required String colorId,
  }) async {
    final user = _authRepository.currentUser;
    if (user == null) {
      return const Failed(AuthFailure(message: 'You must be signed in.'));
    }

    final roomRef = _roomRef(code);
    final memberRef = roomRef.child(RoomPaths.members).child(user.uid);

    try {
      final memberMap = _asMap((await memberRef.get()).value);
      if (memberMap[RoomPaths.memberReady] == true) {
        return const Failed(
          ConflictFailure(message: 'Tap Ready again to change your color.'),
        );
      }

      // The uniqueness guarantee lives in this transaction: the claim node is
      // set to our uid only if it is empty or already ours; otherwise the
      // transaction aborts and the caller gets a ConflictFailure. The security
      // rules enforce the same condition server-side.
      final result = await _colorClaimRef(code, colorId).runTransaction(
        (current) {
          if (current == null || current == user.uid) {
            return Transaction.success(user.uid);
          }
          return Transaction.abort();
        },
      );
      if (!result.committed) {
        return const Failed(ConflictFailure());
      }

      // Release the previous color only after the new one is secured, so a
      // lost race never leaves the rider without a color.
      final previous = memberMap[RoomPaths.memberColorId] as String?;
      if (previous != null && previous != colorId) {
        await _colorClaimRef(code, previous).remove();
      }

      await memberRef.update(<String, Object?>{
        RoomPaths.memberColorId: colorId,
      });
      return const Success(null);
    } on FirebaseException catch (e, stack) {
      return Failed(_mapDbException(e, stack));
    } catch (e, stack) {
      return Failed(_unexpected(e, stack));
    }
  }

  @override
  Future<Result<void>> setReady({
    required String code,
    required bool ready,
  }) async {
    final user = _authRepository.currentUser;
    if (user == null) {
      return const Failed(AuthFailure(message: 'You must be signed in.'));
    }

    final roomRef = _roomRef(code);
    try {
      final room = RoomDto.fromSnapshot(code, (await roomRef.get()).value);
      final me = room?.memberByUid(user.uid);
      if (room == null || me == null) {
        return const Failed(NotFoundFailure(message: 'You are not in this ride.'));
      }
      if (me.isHost) {
        return const Failed(
          UnexpectedFailure(message: 'The host does not need to be ready.'),
        );
      }
      if (ready && !me.hasColor) {
        return const Failed(
          UnexpectedFailure(message: 'Pick your color first.'),
        );
      }

      await roomRef
          .child(RoomPaths.members)
          .child(user.uid)
          .update(<String, Object?>{RoomPaths.memberReady: ready});
      return const Success(null);
    } on FirebaseException catch (e, stack) {
      return Failed(_mapDbException(e, stack));
    } catch (e, stack) {
      return Failed(_unexpected(e, stack));
    }
  }

  @override
  Future<Result<void>> continueToRideMode({required String code}) {
    return _updateMetaAsHost(
      code: code,
      buildUpdate: (room) {
        // Re-checked against the latest server state rather than the UI's
        // copy, so a rider who just disconnected cannot be left behind.
        if (!room.canContinue) {
          return const Failed(
            ConflictFailure(message: 'Waiting for every rider to be ready.'),
          );
        }
        return Success(<String, Object?>{
          RoomPaths.metaStatus: RoomStatus.choosingMode.wireValue,
          // A fresh choice every time the room returns to mode selection.
          RoomPaths.metaMode: null,
        });
      },
    );
  }

  @override
  Future<Result<void>> chooseRideMode({
    required String code,
    required RideMode mode,
  }) {
    return _updateMetaAsHost(
      code: code,
      buildUpdate: (room) {
        if (room.status != RoomStatus.choosingMode) {
          return const Failed(
            ConflictFailure(message: 'The ride type has already been chosen.'),
          );
        }
        // Both ride types prepare every device first; a guided ride then
        // moves on to planning (see [completeInitialization]).
        return Success(<String, Object?>{
          RoomPaths.metaMode: mode.wireValue,
          RoomPaths.metaStatus: RoomStatus.initializing.wireValue,
        });
      },
    );
  }

  @override
  Future<Result<void>> setInitialized({
    required String code,
    required bool initialized,
  }) async {
    final user = _authRepository.currentUser;
    if (user == null) {
      return const Failed(AuthFailure(message: 'You must be signed in.'));
    }
    try {
      await _roomRef(code)
          .child(RoomPaths.members)
          .child(user.uid)
          .update(<String, Object?>{RoomPaths.memberInitialized: initialized});
      return const Success(null);
    } on FirebaseException catch (e, stack) {
      return Failed(_mapDbException(e, stack));
    } catch (e, stack) {
      return Failed(_unexpected(e, stack));
    }
  }

  @override
  Future<Result<void>> completeInitialization({required String code}) {
    return _updateMetaAsHost(
      code: code,
      buildUpdate: (room) {
        if (room.status != RoomStatus.initializing) {
          return const Failed(
            ConflictFailure(message: 'The ride is not initializing.'),
          );
        }
        if (!room.everyoneConnectedInitialized) {
          return const Failed(
            ConflictFailure(message: 'Waiting for riders to finish.'),
          );
        }
        final next = room.mode == RideMode.guided
            ? RoomStatus.planning
            : RoomStatus.riding;
        return Success(<String, Object?>{
          RoomPaths.metaStatus: next.wireValue,
        });
      },
    );
  }

  @override
  Future<Result<void>> beginEndingRide({required String code}) {
    return _updateMetaAsHost(
      code: code,
      buildUpdate: (room) {
        // Pressing End Ride again after a failed attempt resumes the ending
        // instead of failing: nothing to write, the room is already ending.
        if (room.status == RoomStatus.ending) {
          return const Success(<String, Object?>{});
        }
        if (room.status != RoomStatus.riding) {
          return const Failed(
            ConflictFailure(message: 'This ride is not in progress.'),
          );
        }
        return Success(<String, Object?>{
          RoomPaths.metaStatus: RoomStatus.ending.wireValue,
        });
      },
    );
  }

  @override
  Future<Result<void>> completeRide({required String code}) {
    return _updateMetaAsHost(
      code: code,
      buildUpdate: (room) {
        if (room.status == RoomStatus.ended) {
          return const Success(<String, Object?>{});
        }
        if (room.status != RoomStatus.ending) {
          return const Failed(
            ConflictFailure(message: 'This ride is not being ended.'),
          );
        }
        return Success(<String, Object?>{
          RoomPaths.metaStatus: RoomStatus.ended.wireValue,
        });
      },
    );
  }

  @override
  Future<Result<void>> startGuidedRide({required String code}) {
    return _updateMetaAsHost(
      code: code,
      buildUpdate: (room) {
        if (room.mode != RideMode.guided ||
            room.status != RoomStatus.planning) {
          return const Failed(
            ConflictFailure(message: 'This ride is not being planned.'),
          );
        }
        if (!room.everyoneConnected) {
          return const Failed(
            ConflictFailure(message: 'Waiting for every rider to reconnect.'),
          );
        }
        // The security rules also refuse this change unless the room has a
        // generated route, so a ride can never start without one.
        return Success(<String, Object?>{
          RoomPaths.metaStatus: RoomStatus.riding.wireValue,
        });
      },
    );
  }

  @override
  Stream<bool> watchConnection() {
    return _database
        .ref(_connectedPath)
        .onValue
        .map((event) => event.snapshot.value == true);
  }

  /// Applies a host-only change to the room's `meta` node.
  ///
  /// Loads the latest room, confirms the caller is the host, then asks
  /// [buildUpdate] for the fields to write (or a [Failure] when the room is
  /// not in a state that allows the change). Mode and status are written in a
  /// single update so riders never observe one without the other. The
  /// security rules independently restrict `meta` writes to the host.
  Future<Result<void>> _updateMetaAsHost({
    required String code,
    required Result<Map<String, Object?>> Function(Room room) buildUpdate,
  }) async {
    final user = _authRepository.currentUser;
    if (user == null) {
      return const Failed(AuthFailure(message: 'You must be signed in.'));
    }

    final roomRef = _roomRef(code);
    try {
      final room = RoomDto.fromSnapshot(code, (await roomRef.get()).value);
      if (room == null) {
        return const Failed(NotFoundFailure(message: 'No ride found.'));
      }
      if (room.hostUid != user.uid) {
        return const Failed(
          AuthFailure(message: 'Only the host can do that.'),
        );
      }

      switch (buildUpdate(room)) {
        case Success(:final value):
          // An empty update means the room is already in the wanted state.
          if (value.isNotEmpty) {
            await roomRef.child(RoomPaths.meta).update(value);
          }
          return const Success(null);
        case Failed(:final failure):
          return Failed(failure);
      }
    } on FirebaseException catch (e, stack) {
      return Failed(_mapDbException(e, stack));
    } catch (e, stack) {
      return Failed(_unexpected(e, stack));
    }
  }

  @override
  Future<Result<void>> leaveRoom({required String code}) async {
    final user = _authRepository.currentUser;
    if (user == null) {
      return const Failed(AuthFailure(message: 'You must be signed in.'));
    }

    final memberRef =
        _roomRef(code).child(RoomPaths.members).child(user.uid);

    try {
      // Release the color first so it frees up for other riders.
      final memberMap = _asMap((await memberRef.get()).value);
      final colorId = memberMap[RoomPaths.memberColorId] as String?;
      if (colorId != null) {
        await _colorClaimRef(code, colorId).remove();
      }

      // Cancel the pending disconnect handler (it covers this node and its
      // children) before removing the membership.
      await memberRef.onDisconnect().cancel();
      await memberRef.remove();
      return const Success(null);
    } on FirebaseException catch (e, stack) {
      return Failed(_mapDbException(e, stack));
    } catch (e, stack) {
      return Failed(_unexpected(e, stack));
    }
  }

  @override
  Stream<bool> trackPresence({required String code}) {
    final uid = _authRepository.currentUser?.uid;
    if (uid == null) return Stream<bool>.value(false);

    final memberRef = _roomRef(code).child(RoomPaths.members).child(uid);

    return watchConnection().asyncMap((connected) async {
      if (connected) {
        try {
          // Arm the disconnect handler before announcing presence, so there is
          // no window where the rider is online without a cleanup registered.
          await _armDisconnectHandler(memberRef);
          await memberRef.update(<String, Object?>{
            RoomPaths.memberOnline: true,
          });
        } on FirebaseException catch (e) {
          // Expected after leaving: the member node is gone, so the rules
          // reject recreating a partial node. Presence is simply not restored.
          debugPrint('Presence not restored (${e.code}): ${e.message}');
        }
      }
      return connected;
    });
  }

  /// Special RTDB path reporting whether this client is connected.
  static const String _connectedPath = '.info/connected';

  @override
  Stream<Room?> watchRoom({required String code}) {
    return _roomRef(code).onValue.map(
          (event) => RoomDto.fromSnapshot(code, event.snapshot.value),
        );
  }

  /// Writes the member node and arms the disconnect handler.
  ///
  /// Every join (including a rejoin) starts the rider as online and not ready,
  /// so late joiners appear as "Waiting" until they press Ready. `joinedAt` is
  /// only stamped on the first join.
  Future<void> _writeMembership({
    required String code,
    required String uid,
    required String? displayName,
  }) async {
    final memberRef = _roomRef(code).child(RoomPaths.members).child(uid);
    final existing = await memberRef.get();
    final isFirstJoin = !existing.exists;

    await memberRef.update(<String, Object?>{
      RoomPaths.memberUid: uid,
      RoomPaths.memberDisplayName: displayName,
      RoomPaths.memberOnline: true,
      RoomPaths.memberReady: false,
      RoomPaths.memberInitialized: false,
      if (isFirstJoin) RoomPaths.memberJoinedAt: ServerValue.timestamp,
    });

    await _armDisconnectHandler(memberRef);
  }

  /// Registers the server-side cleanup that runs if this client drops: the
  /// rider is marked offline and their ready and initialized states are reset,
  /// so a disconnected rider can never hold up or be dragged into a ride.
  Future<void> _armDisconnectHandler(DatabaseReference memberRef) {
    return memberRef.onDisconnect().update(<String, Object?>{
      RoomPaths.memberOnline: false,
      RoomPaths.memberReady: false,
      RoomPaths.memberInitialized: false,
    });
  }

  DatabaseReference _colorClaimRef(String code, String colorId) =>
      _roomRef(code)
          .child(RoomPaths.claims)
          .child(RoomPaths.claimColors)
          .child(colorId);

  static Map<Object?, Object?> _asMap(Object? value) =>
      value is Map ? Map<Object?, Object?>.from(value) : <Object?, Object?>{};

  /// Creates the room's `meta` node under a fresh, unused code and returns the
  /// code, or `null` if no free code was found within [_maxCodeAttempts].
  ///
  /// The complete meta node is written in a single `set`, because the security
  /// rules validate that `meta` always carries every required field. Uniqueness
  /// is enforced server-side: the rules only allow writing `meta` when it does
  /// not exist yet or already belongs to the writer, so if another host takes
  /// the same code between our read and our write, the write is rejected with
  /// `permission-denied` and we try a new code.
  Future<String?> _createRoomMeta({
    required String hostUid,
    required String name,
  }) async {
    for (var attempt = 0; attempt < _maxCodeAttempts; attempt++) {
      final candidate = _codeGenerator.generate();
      final metaRef = _roomRef(candidate).child(RoomPaths.meta);

      // Skip codes that are already in use (including our own older rooms,
      // which the rules would otherwise let us overwrite).
      if ((await metaRef.get()).exists) continue;

      try {
        await metaRef.set(<String, Object?>{
          RoomPaths.metaCode: candidate,
          RoomPaths.metaName: name,
          RoomPaths.metaHostUid: hostUid,
          RoomPaths.metaStatus: RoomStatus.lobby.wireValue,
          RoomPaths.metaCreatedAt: ServerValue.timestamp,
        });
        return candidate;
      } on FirebaseException catch (e) {
        if (e.code == _permissionDenied) {
          debugPrint('Room code $candidate was taken concurrently; retrying.');
          continue;
        }
        rethrow;
      }
    }
    return null;
  }

  /// Error code the SDK reports when a write is rejected by security rules.
  static const String _permissionDenied = 'permission-denied';

  Failure _mapDbException(FirebaseException e, StackTrace stack) {
    debugPrint('RTDB FirebaseException(${e.code}): ${e.message}');
    return switch (e.code) {
      'permission-denied' => const AuthFailure(
          message: 'You do not have access to this room.',
        ),
      'unavailable' || 'network-error' => NetworkFailure(cause: e),
      _ => UnexpectedFailure(cause: e),
    };
  }

  Failure _unexpected(Object error, StackTrace stack) {
    debugPrint('Unexpected room error: $error\n$stack');
    return UnexpectedFailure(cause: error);
  }
}
