import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/user_profile.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Stream of Firebase auth state changes
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Currently loaded user profile
final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, AsyncValue<UserProfile?>>((ref) {
  return UserProfileNotifier(ref);
});

class UserProfileNotifier
    extends StateNotifier<AsyncValue<UserProfile?>> {
  final Ref _ref;

  UserProfileNotifier(this._ref) : super(const AsyncValue.loading()) {
    _ref.listen<AsyncValue<User?>>(authStateProvider, (prev, next) {
      next.when(
        data: (user) async {
          if (user == null) {
            state = const AsyncValue.data(null);
          } else {
            await _load(user.uid);
          }
        },
        loading: () => state = const AsyncValue.loading(),
        error: (e, st) => state = AsyncValue.error(e, st),
      );
    }, fireImmediately: true);
  }

  Future<void> _load(String uid) async {
    state = const AsyncValue.loading();
    try {
      final profile =
          await _ref.read(authServiceProvider).fetchUserProfile(uid);
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> update(UserProfile profile) async {
    await _ref.read(authServiceProvider).updateUserProfile(profile);
    state = AsyncValue.data(profile);
  }

  Future<void> signOut() async {
    await _ref.read(authServiceProvider).signOut();
    state = const AsyncValue.data(null);
  }
}
