// app/lib/src/ui/family_group_screen.dart
import 'package:flutter/material.dart';

import '../core/models/steam_guard_account.dart';

/// 占位版本（Task 5 前向引用）：构造签名与 Task 7 实装版完全一致，
/// Task 7 会替换为只读家庭组信息页。
class FamilyGroupScreen extends StatelessWidget {
  final SteamGuardAccount account;
  final int? familyGroupId;
  const FamilyGroupScreen(
      {super.key, required this.account, this.familyGroupId});

  @override
  Widget build(BuildContext context) => const Scaffold();
}
