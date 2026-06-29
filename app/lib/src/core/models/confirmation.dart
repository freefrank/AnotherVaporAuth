/// A pending mobile confirmation as returned by `/mobileconf/getlist`.
enum ConfirmationType { unknown, trade, marketListing, other }

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

  // Steam confirmation type ids: 1 = generic, 2 = trade, 3 = market listing.
  static ConfirmationType _mapType(dynamic raw) {
    final t = _asInt(raw);
    switch (t) {
      case 2:
        return ConfirmationType.trade;
      case 3:
        return ConfirmationType.marketListing;
      case 1:
        return ConfirmationType.other;
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
