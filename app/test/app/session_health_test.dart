import 'package:ava/src/app/providers.dart';
import 'package:ava/src/services/auto_login.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// issue #8:账号失效提醒的判定核心。只有 Steam 明确回 InvalidPassword
/// (invalidCredentials)才标失效;网络故障、缺密码、需要交互都不能标,
/// 否则断网一次首页就全线飘红。
void main() {
  ProviderContainer container() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  test('invalidCredentials marks the account; ok clears it', () {
    final c = container();
    final health = c.read(sessionHealthProvider.notifier);

    health.record(1, AutoLoginOutcome.invalidCredentials);
    expect(c.read(sessionHealthProvider), {1});

    health.record(1, AutoLoginOutcome.ok);
    expect(c.read(sessionHealthProvider), isEmpty);
  });

  test('inconclusive outcomes neither mark nor clear', () {
    final c = container();
    final health = c.read(sessionHealthProvider.notifier);

    // None of these may mark a healthy account…
    health.record(1, AutoLoginOutcome.failed);
    health.record(1, AutoLoginOutcome.needsPassword);
    health.record(1, AutoLoginOutcome.needsInteractive);
    expect(c.read(sessionHealthProvider), isEmpty);

    // …and none of these may absolve a marked one: a network error after a
    // definitive InvalidPassword is not evidence the password works again.
    health.record(2, AutoLoginOutcome.invalidCredentials);
    health.record(2, AutoLoginOutcome.failed);
    health.record(2, AutoLoginOutcome.needsInteractive);
    expect(c.read(sessionHealthProvider), {2});
  });

  test('clear removes exactly the given account', () {
    final c = container();
    final health = c.read(sessionHealthProvider.notifier);

    health.record(1, AutoLoginOutcome.invalidCredentials);
    health.record(2, AutoLoginOutcome.invalidCredentials);
    health.clear(1);
    expect(c.read(sessionHealthProvider), {2});
    // Clearing an unmarked account is a no-op, not an error.
    health.clear(99);
    expect(c.read(sessionHealthProvider), {2});
  });

  test('verdicts are independent per account', () {
    final c = container();
    final health = c.read(sessionHealthProvider.notifier);

    health.record(1, AutoLoginOutcome.invalidCredentials);
    health.record(2, AutoLoginOutcome.ok);
    health.record(3, AutoLoginOutcome.invalidCredentials);
    expect(c.read(sessionHealthProvider), {1, 3});

    health.record(3, AutoLoginOutcome.ok);
    expect(c.read(sessionHealthProvider), {1});
  });
}
