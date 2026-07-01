/// In-memory model of `maFiles/manifest.json`.
///
/// Field names match the legacy C# `Manifest` JsonProperty names exactly so the
/// file is fully interoperable with the .NET version.
class Manifest {
  bool encrypted;
  bool firstRun;
  List<ManifestEntry> entries;
  bool periodicChecking;
  int periodicCheckingInterval;
  bool checkAllAccounts;
  bool autoConfirmMarketTransactions;
  bool autoConfirmTrades;

  /// `salt|iv|ciphertext` of a known plaintext, used to verify the passkey even
  /// when there are no accounts (lets a PIN be set on an empty store).
  String? passkeyCheck;

  /// PBKDF2 rounds used for this store's own encryption. Imported maFiles use
  /// the 50000-round maFile default; AVA's own PIN encryption can use fewer
  /// (a 6-digit PIN's small keyspace dominates, so high rounds add little).
  /// Legacy — unused once [vault] is true.
  int kdfIterations;

  /// True once the store has migrated to the vault scheme (random DEK +
  /// AES-256-GCM, DEK held in Android Keystore-backed storage). When true the
  /// PIN no longer derives the file key and [kdfIterations]/[passkeyCheck] are
  /// unused. AVA-internal only; never written into an exported maFile.
  bool vault;

  /// Internal manifest schema version. 1 = legacy PIN/CBC, 2 = vault/GCM.
  int schemaVersion;

  Manifest({
    this.encrypted = false,
    this.firstRun = true,
    List<ManifestEntry>? entries,
    this.periodicChecking = false,
    this.periodicCheckingInterval = 5,
    this.checkAllAccounts = false,
    this.autoConfirmMarketTransactions = false,
    this.autoConfirmTrades = false,
    this.passkeyCheck,
    this.kdfIterations = 50000,
    this.vault = false,
    this.schemaVersion = 1,
  }) : entries = entries ?? <ManifestEntry>[];

  factory Manifest.fromJson(Map<String, dynamic> json) => Manifest(
        encrypted: json['encrypted'] == true,
        firstRun: json['first_run'] ?? true,
        passkeyCheck: json['passkey_check'] as String?,
        kdfIterations: _asInt(json['kdf_iterations'], 50000),
        vault: json['vault'] == true,
        schemaVersion: _asInt(json['schema_version'], 1),
        entries: (json['entries'] as List?)
                ?.map((e) =>
                    ManifestEntry.fromJson(e as Map<String, dynamic>))
                .toList() ??
            <ManifestEntry>[],
        periodicChecking: json['periodic_checking'] == true,
        periodicCheckingInterval: _asInt(json['periodic_checking_interval'], 5),
        checkAllAccounts: json['periodic_checking_checkall'] == true,
        autoConfirmMarketTransactions:
            json['auto_confirm_market_transactions'] == true,
        autoConfirmTrades: json['auto_confirm_trades'] == true,
      );

  Map<String, dynamic> toJson() => {
        'encrypted': encrypted,
        'first_run': firstRun,
        'entries': entries.map((e) => e.toJson()).toList(),
        'periodic_checking': periodicChecking,
        'periodic_checking_interval': periodicCheckingInterval,
        'periodic_checking_checkall': checkAllAccounts,
        'auto_confirm_market_transactions': autoConfirmMarketTransactions,
        'auto_confirm_trades': autoConfirmTrades,
        if (passkeyCheck != null) 'passkey_check': passkeyCheck,
        'kdf_iterations': kdfIterations,
        'vault': vault,
        'schema_version': schemaVersion,
      };

  static int _asInt(dynamic v, int fallback) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? fallback;
    if (v is double) return v.toInt();
    return fallback;
  }
}

class ManifestEntry {
  String? iv; // encryption_iv
  String? salt; // encryption_salt
  String filename; // filename
  int steamId; // steamid

  ManifestEntry({
    this.iv,
    this.salt,
    required this.filename,
    this.steamId = 0,
  });

  factory ManifestEntry.fromJson(Map<String, dynamic> json) => ManifestEntry(
        iv: json['encryption_iv'] as String?,
        salt: json['encryption_salt'] as String?,
        filename: (json['filename'] ?? '') as String,
        steamId: _asInt(json['steamid']),
      );

  Map<String, dynamic> toJson() => {
        'encryption_iv': iv,
        'encryption_salt': salt,
        'filename': filename,
        'steamid': steamId,
      };

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    if (v is double) return v.toInt();
    return 0;
  }
}
