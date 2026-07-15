/// A pending mobile confirmation as returned by `/mobileconf/getlist`.
enum ConfirmationType {
  unknown,
  trade,
  marketListing,
  featureOptOut,
  phoneChange,
  accountRecovery,
  apiKey,
  familyJoin,
  other,
}

class Confirmation {
  final String id;
  final String nonce; // confirmation key (`ck`)
  final ConfirmationType type;
  final String typeName;
  final String creatorId;
  final String headline;
  final List<String> summary;
  final int creationTime;
  final String icon;

  const Confirmation({
    required this.id,
    required this.nonce,
    required this.type,
    required this.typeName,
    required this.creatorId,
    required this.headline,
    required this.summary,
    required this.creationTime,
    required this.icon,
  });

  factory Confirmation.fromJson(Map<String, dynamic> json) {
    return Confirmation(
      id: '${json['id']}',
      nonce: '${json['nonce']}',
      type: _mapType(json['type']),
      typeName: (json['type_name'] ?? '') as String,
      creatorId: '${json['creator_id'] ?? ''}',
      headline: (json['headline'] ?? '') as String,
      summary: (json['summary'] as List?)?.map((e) => '$e').toList() ??
          const <String>[],
      creationTime: _asInt(json['creation_time']),
      icon: (json['icon'] ?? '') as String,
    );
  }

  // Steam confirmation type ids (steamguard-cli ConfirmationType):
  // 1 generic, 2 trade, 3 market listing, 4 feature opt-out,
  // 5 phone number change, 6 account recovery, 9 web API key creation,
  // 11 join Steam family.
  static ConfirmationType _mapType(dynamic raw) {
    switch (_asInt(raw)) {
      case 1:
        return ConfirmationType.other;
      case 2:
        return ConfirmationType.trade;
      case 3:
        return ConfirmationType.marketListing;
      case 4:
        return ConfirmationType.featureOptOut;
      case 5:
        return ConfirmationType.phoneChange;
      case 6:
        return ConfirmationType.accountRecovery;
      case 9:
        return ConfirmationType.apiKey;
      case 11:
        return ConfirmationType.familyJoin;
      default:
        return ConfirmationType.unknown;
    }
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    if (v is double) return v.toInt();
    return 0;
  }
}
