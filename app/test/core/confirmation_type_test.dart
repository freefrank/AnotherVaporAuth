import 'package:ava/src/core/models/confirmation.dart';
import 'package:flutter_test/flutter_test.dart';

Confirmation _conf(int type) => Confirmation.fromJson({
      'id': '1', 'nonce': '2', 'type': type, 'creation_time': 0,
    });

void main() {
  test('all known Steam confirmation type ids map to named types', () {
    expect(_conf(1).type, ConfirmationType.other);
    expect(_conf(2).type, ConfirmationType.trade);
    expect(_conf(3).type, ConfirmationType.marketListing);
    expect(_conf(4).type, ConfirmationType.featureOptOut);
    expect(_conf(5).type, ConfirmationType.phoneChange);
    expect(_conf(6).type, ConfirmationType.accountRecovery);
    expect(_conf(9).type, ConfirmationType.apiKey);
    expect(_conf(11).type, ConfirmationType.familyJoin);
    expect(_conf(999).type, ConfirmationType.unknown);
    // 字符串形式的 type 同样解析（getlist 偶发字符串数字）。
    expect(_conf(11).type, Confirmation.fromJson({'id': '1', 'nonce': '2', 'type': '11'}).type);
  });
}
