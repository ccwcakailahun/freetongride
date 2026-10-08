import 'package:flutter/foundation.dart';

import 'api.dart';
import 'models.dart';
import 'realtime.dart';

/// Signed-in state shared by every screen. Each app creates one with its required role.
class Session extends ChangeNotifier {
  Session({required this.role, ApiClient? client}) : client = client ?? ApiClient() {
    api = FtrApi(this.client);
    realtime = Realtime(this.client);
    this.client.onUnauthorized = () => signOut();
  }

  final UserRole role;
  final ApiClient client;
  late final FtrApi api;
  late final Realtime realtime;

  AppUser? _user;
  bool _ready = false;

  AppUser? get user => _user;
  bool get ready => _ready;
  bool get signedIn => _user != null;

  /// Restores a saved session on launch. Never throws.
  Future<void> restore() async {
    try {
      if (await client.loadToken() != null) {
        final me = await api.me();
        if (me.role == role) {
          _user = me;
          realtime.connect();
        } else {
          await client.saveToken(null);
        }
      }
    } on ApiException catch (e) {
      if (e.unauthorized) await client.saveToken(null);
    } catch (_) {
      // Offline at launch: stay signed out of memory, keep the token for next time.
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> signIn(AuthResult r) async {
    await client.saveToken(r.token);
    _user = r.user;
    realtime.connect();
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      _user = await api.me();
      notifyListeners();
    } catch (_) {}
  }

  void setUser(AppUser u) {
    _user = u;
    notifyListeners();
  }

  Future<void> signOut() async {
    await realtime.disconnect();
    await client.saveToken(null);
    _user = null;
    notifyListeners();
  }
}
