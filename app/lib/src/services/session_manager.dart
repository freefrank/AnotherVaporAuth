import '../core/models/session_data.dart';
import '../core/proto/protobuf_wire.dart';
import 'steam_api_client.dart';

/// Manages refreshing the short-lived access token from the refresh token.
class SessionManager {
  final SteamApiClient api;
  SessionManager(this.api);

  /// Returns true if the access token looks present (a JWT is opaque to us;
  /// real expiry is enforced server-side, so we refresh on 401-style failures).
  bool hasUsableToken(SessionData session) => session.hasTokens;

  /// Exchanges the refresh token for a fresh access token, updating [session]
  /// in place. Returns false if there is no refresh token or the call fails.
  Future<bool> refresh(SessionData session) async {
    final refreshToken = session.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final req = ProtoWriter()
        ..writeString(1, refreshToken)
        ..writeUint64(2, session.steamId);
      final fields = (await api.callProtobuf(
        'IAuthenticationService',
        'GenerateAccessTokenForApp',
        request: req,
      ))
          .parse();
      final newAccess = fields[1]?.asString;
      if (newAccess != null && newAccess.isNotEmpty) {
        session.accessToken = newAccess;
        final newRefresh = fields[2]?.asString;
        if (newRefresh != null && newRefresh.isNotEmpty) {
          session.refreshToken = newRefresh;
        }
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
