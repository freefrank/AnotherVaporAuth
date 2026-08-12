/// The transport a sync round talks through. One implementation per backend
/// (WebDAV now, Google Drive later) — the engine above this interface never
/// changes when a backend is added.
///
/// Concurrency contract: the engine treats `ava.sync.json` (the sidecar) as
/// the commit point. Every push sequence ends with a conditional PUT of the
/// sidecar; [SyncPreconditionFailed] from that PUT means another device
/// committed first and the whole round re-pulls and re-merges. Account
/// payload files are written under revision-suffixed names, so they are never
/// overwritten in place and a lost race can't corrupt anything — at worst it
/// leaves an orphan file the next committer garbage-collects.
library;

import 'dart:typed_data';

/// A fetched remote file. [etag] is null when the server sent none.
class RemoteFile {
  final Uint8List bytes;
  final String? etag;
  const RemoteFile(this.bytes, this.etag);
}

abstract class SyncTransport {
  /// Creates the remote root when missing; succeeds silently when it exists.
  Future<void> ensureRoot();

  /// Fetches [name], or null when the file does not exist.
  Future<RemoteFile?> getFile(String name);

  /// Writes [name]. Exactly one of the guards may be set:
  /// - [ifMatch]: only overwrite the version with this ETag;
  /// - [ifAbsent]: only create, never overwrite.
  /// Throws [SyncPreconditionFailed] when the guard fails.
  /// Returns the new ETag when the server reports one.
  Future<String?> putFile(String name, Uint8List bytes,
      {String? ifMatch, bool ifAbsent = false});

  /// Deletes [name]; missing files are not an error (delete is how the
  /// engine garbage-collects, and a double-delete must stay idempotent).
  Future<void> deleteFile(String name);

  /// Cheap reachability + credential check for the setup wizard. Throws the
  /// typed errors below; returns normally when the server answers.
  Future<void> probe();

  /// Whether the server actually enforces conditional PUTs ([ifMatch] /
  /// [ifAbsent]). Some WebDAV implementations accept-and-ignore the
  /// precondition headers, which silently downgrades the optimistic lock —
  /// the setup wizard runs this once and the engine warns when unsupported.
  /// Implementations may write and delete a throwaway probe file.
  Future<bool> checkConditionalSupport();

  /// Releases any sockets/resources. Safe to call more than once.
  void close();
}

/// Base class so callers can catch every transport failure in one arm.
sealed class SyncTransportException implements Exception {
  final String message;
  const SyncTransportException(this.message);
  @override
  String toString() => message;
}

/// Credentials rejected (401/403).
class SyncAuthError extends SyncTransportException {
  const SyncAuthError(super.message);
}

/// A conditional PUT lost the race (412) — re-pull, re-merge, retry.
class SyncPreconditionFailed extends SyncTransportException {
  const SyncPreconditionFailed(super.message);
}

/// TLS certificate not in the system trust store and not pinned. Carries the
/// certificate's SHA-256 fingerprint so the UI can show it for pinning.
class SyncTlsUntrusted extends SyncTransportException {
  final String host;

  /// Hex SHA-256 of the certificate DER, colon-separated pairs.
  final String fingerprint;
  const SyncTlsUntrusted(this.host, this.fingerprint)
      : super('untrusted certificate for $host');
}

/// The URL violates the HTTP policy (plain HTTP to a public host without the
/// per-server override).
class SyncHttpPolicyError extends SyncTransportException {
  const SyncHttpPolicyError(super.message);
}

/// Network-level failure: DNS, refused, timeout, connection reset.
class SyncNetworkError extends SyncTransportException {
  const SyncNetworkError(super.message);
}

/// Any other HTTP status the engine has no specific handling for.
class SyncServerError extends SyncTransportException {
  final int status;
  const SyncServerError(this.status, super.message);
}
