// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'AVA';

  @override
  String get navAccounts => '账户';

  @override
  String get navSettings => '设置';

  @override
  String get unlockTitle => '解锁';

  @override
  String get unlockPrompt => '请输入加密口令';

  @override
  String get unlockButton => '解锁';

  @override
  String get unlockInvalid => '口令无效。';

  @override
  String get unlockWithBiometric => '用指纹 / 设备密码解锁';

  @override
  String get unlockLoading => '正在解锁…';

  @override
  String get unlockCantUnlock => '无法解锁？';

  @override
  String get resetVaultTitle => '重置加密数据';

  @override
  String get resetVaultBody =>
      '将删除本机存储的全部账户条目与加密密钥，之后需要重新导入你的 maFile 备份。你的 Steam 账户和已绑定的验证器不受影响。\n\n适用于正确 PIN 一直被拒的情况——通常发生在备份恢复或换机迁移之后：硬件密钥不会离开原设备，恢复出来的数据永远无法解密。\n\n此操作无法撤销。';

  @override
  String get resetVaultConfirm => '全部删除并重置';

  @override
  String get storeErrorTitle => '本地数据无法读取';

  @override
  String get storeErrorBody =>
      'AVA 的本地账户数据库（manifest.json）缺失或损坏。写入被中断或恢复不完整都可能导致此问题。请先重试；若持续失败，可重置后重新导入你的 maFile 备份。';

  @override
  String get storeRepair => '尝试修复';

  @override
  String storeActionFailed(String error) {
    return '操作失败：$error';
  }

  @override
  String get pinSetupTitle => '设置解锁 PIN';

  @override
  String get pinSetupPrompt => '用 6 位 PIN 保护 AVA。解锁时输入它（或用指纹）。';

  @override
  String get pinLabel => '6 位 PIN';

  @override
  String get pinConfirmLabel => '确认 PIN';

  @override
  String get pinSetButton => '设置 PIN';

  @override
  String get settingsSet => '设置';

  @override
  String get pinChangeTitle => '修改 PIN';

  @override
  String get pinCurrentLabel => '当前 PIN';

  @override
  String get pinNewLabel => '新 PIN';

  @override
  String get pinSixDigits => '请输入 6 位 PIN。';

  @override
  String get pinMismatch => '两次 PIN 不一致。';

  @override
  String get unlockBiometricReason => '解锁 AVA';

  @override
  String get settingsBiometric => '指纹解锁';

  @override
  String get settingsBiometricDesc => '用指纹或设备密码解锁；口令保存在设备 Keystore 中。';

  @override
  String get settingsBiometricNeedPasskey => '请先设置加密口令。';

  @override
  String get settingsBiometricUnavailable => '此设备未设置生物识别或屏幕锁。';

  @override
  String get settingsBiometricEnabled => '已启用指纹解锁。';

  @override
  String get settingsHoldConfirm => '长按确认';

  @override
  String get settingsHoldConfirmDesc =>
      '不可逆的接受类操作（交易、确认）需长按生效；关闭后单击立即生效，批量操作仍会弹窗确认。';

  @override
  String get settingsHaptics => '震动反馈';

  @override
  String get settingsHapticsDesc => '长按确认过程中与完成时的触觉反馈。';

  @override
  String get settingsBlockScreenshots => '禁止截屏';

  @override
  String get settingsBlockScreenshotsDesc =>
      '让 AVA 不出现在截屏、录屏和最近任务预览里。代价是投屏时窗口会变黑，也没法再截图附到反馈里。';

  @override
  String get passkeyLabel => '口令';

  @override
  String get accountsEmpty => '暂无账户。导入 maFile 或登录以添加。';

  @override
  String get emptyAddAccount => '添加账户';

  @override
  String get accountReady => '已就绪';

  @override
  String get tutCodeTitle => '实时令牌';

  @override
  String get tutCodeBody => '点击大号令牌即可复制;点击账户名可在用户名 / 昵称 / SteamID 间切换。';

  @override
  String get tutSwipeRightTitle => '右滑 → 交易确认';

  @override
  String get tutSwipeRightBody => '在账户条目上向右滑动,直接打开它的交易确认列表。';

  @override
  String get tutSwipeLeftTitle => '左滑 → 更多操作';

  @override
  String get tutSwipeLeftBody => '向左滑动可刷新会话、导出 maFile 或删除账户。';

  @override
  String get tutLongPressTitle => '长按 → 库存与市场';

  @override
  String get tutLongPressBody => '长按账户可浏览库存,并把物品上架到社区市场。';

  @override
  String get tutPullTitle => '下拉刷新';

  @override
  String get tutPullBody => '下拉账户列表可刷新头像并检查待处理的登录请求。';

  @override
  String get tutSkip => '跳过';

  @override
  String get tutNext => '下一步';

  @override
  String get tutDone => '知道了';

  @override
  String get settingsTutorial => '手势教程';

  @override
  String get settingsTutorialDesc => '重新播放主屏手势引导(滑动、长按、下拉刷新)。';

  @override
  String get settingsTutorialReplay => '重新播放';

  @override
  String get welcomeTitle => '欢迎使用 AVA';

  @override
  String get welcomeSubtitle => '本机加密保存你的验证器。开始前请选择一种方式。';

  @override
  String get welcomeLoginCta => '登录 Steam 账户';

  @override
  String get welcomeLoginSub => '新建一个验证器';

  @override
  String get welcomeImportCta => '导入 .maFile';

  @override
  String get welcomeImportSub => '迁移已有账户';

  @override
  String get welcomeSyncCta => '从同步恢复';

  @override
  String get welcomeSyncSub => '从已有的同步库拉取你的账户';

  @override
  String get copyCode => '复制验证码';

  @override
  String get codeCopied => '验证码已复制到剪贴板';

  @override
  String get copied => '已复制到剪贴板';

  @override
  String get copySteamId => '复制 SteamID';

  @override
  String get pendingTitle => '待办';

  @override
  String get pendingTabConfirmations => '确认';

  @override
  String get pendingTabOffers => '报价';

  @override
  String get confirmationsTitle => '确认';

  @override
  String get confirmationsEmpty => '没有待处理的确认。';

  @override
  String get confirmationsRefresh => '刷新';

  @override
  String get confAccept => '接受';

  @override
  String get confDecline => '拒绝';

  @override
  String get confSelectAll => '全选';

  @override
  String get confAcceptSelected => '批量接受';

  @override
  String get confDeclineSelected => '批量拒绝';

  @override
  String get confAcceptAll => '全部接受';

  @override
  String get confRejectAll => '全部拒绝';

  @override
  String confAcceptAllConfirm(int count) {
    return '接受全部 $count 项确认?';
  }

  @override
  String confRejectAllConfirm(int count) {
    return '拒绝全部 $count 项确认?';
  }

  @override
  String get confAcceptAllWarn => '将一次性批准所有待处理的交易与市场上架,请确认你认识其中每一项。';

  @override
  String get confRejectAllWarn => '将一次性取消所有待处理的确认。';

  @override
  String confPending(int count) {
    return '$count 项待确认';
  }

  @override
  String get confAllProcessed => '已全部处理';

  @override
  String get confTypeTrade => '交易';

  @override
  String get confTypeMarket => '市场上架';

  @override
  String get confTypeOther => '确认';

  @override
  String get confTypeFamilyJoin => '家庭组邀请';

  @override
  String get confTypeApiKey => 'API 密钥';

  @override
  String get confTypePhoneChange => '更换手机号';

  @override
  String get confTypeAccountRecovery => '账户恢复';

  @override
  String get confTypeFeatureOptOut => '功能退出';

  @override
  String confProcessing(int count) {
    return '正在处理 $count 条确认…';
  }

  @override
  String confResult(int ok, int fail) {
    return '成功 $ok 条，失败 $fail 条';
  }

  @override
  String get confNeedsLogin => '会话已失效 —— 请重新登录该账户以刷新。';

  @override
  String get confRejected =>
      'Steam 拒绝了确认请求。这通常说明 maFile 与账户当前的验证器不匹配（购入账户较常见）——请移除验证器后重新绑定，或导入正确的 maFile；设备时间偏差过大也会导致此问题。';

  @override
  String get offersSegReceived => '收到';

  @override
  String get offersSegSent => '发出';

  @override
  String get offersSegHistory => '历史';

  @override
  String get offersEmpty => '没有交易报价。';

  @override
  String get offerGift => '赠送 — 你无需给出物品';

  @override
  String get offerOneSided => '你给出物品但一无所获';

  @override
  String get offerEscrow => '物品将被 Steam 暂挂后交付';

  @override
  String get offerAcceptHold => '长按接受';

  @override
  String get offerDecline => '拒绝';

  @override
  String get offerCancel => '取消报价';

  @override
  String get offerReceiveLabel => '你收到';

  @override
  String get offerGiveLabel => '你给出';

  @override
  String get offerAccepted => '已接受报价 — 请到「确认」页签完成确认';

  @override
  String get offerAcceptedNoConf => '已接受报价。';

  @override
  String offerActionFailed(String msg) {
    return '操作失败：$msg';
  }

  @override
  String get offerDeclined => '已拒绝报价。';

  @override
  String get offerCanceled => '已取消报价。';

  @override
  String get pendingTabInvites => '邀请';

  @override
  String famInviteTitle(String groupName) {
    return '「$groupName」邀请你加入家庭组';
  }

  @override
  String get famInviteTitleGeneric => '家庭组邀请';

  @override
  String famInviteFrom(String inviter) {
    return '邀请人：$inviter';
  }

  @override
  String famInviteRole(String role) {
    return '角色：$role';
  }

  @override
  String famInviteSlots(int used, int total) {
    return '成员 $used/$total';
  }

  @override
  String get famRoleAdult => '成人';

  @override
  String get famRoleChild => '儿童';

  @override
  String famRoleUnknown(int n) {
    return '角色 #$n';
  }

  @override
  String get famPreflightTitle => '加入前预检';

  @override
  String get famCheckWalletMatch => '钱包地区一致';

  @override
  String get famCheckWalletMismatch => '钱包地区不一致 —— Steam 限制加入';

  @override
  String get famCheckIpMatch => '常用 IP 匹配';

  @override
  String get famCheckIpMismatch => 'IP 与常用地点不符';

  @override
  String get famCheckCooldown => '加入后 1 年内不能更换家庭组（官方冷却）';

  @override
  String famJoinRestricted(int code) {
    return 'Steam 阻止了此次加入（限制码 $code）';
  }

  @override
  String get famInviteJoinHold => '加入（长按）';

  @override
  String get famInviteAwaiting2fa => '等待确认 —— 请到「确认」页签处理';

  @override
  String get famInviteJoined => '已加入 ✓';

  @override
  String get famInviteViewGroup => '查看家庭组 ›';

  @override
  String get famJoinSent => '已发起加入 —— 请到「确认」页签完成确认';

  @override
  String get famJoinDone => '已加入家庭组。';

  @override
  String famJoinFailed(String msg) {
    return '加入失败：$msg';
  }

  @override
  String get famInvitesEmpty => '没有待处理的家庭组邀请。';

  @override
  String get famAccountAction => '家庭组';

  @override
  String get famNotInGroup => '该账户不在任何家庭组中。';

  @override
  String famSummaryMembers(int used, int total) {
    return '成员 $used/$total';
  }

  @override
  String famSummaryCooldown(int days) {
    return '冷却 $days 天';
  }

  @override
  String get famInvitesSection => '邀请';

  @override
  String get famSectionMembers => '成员';

  @override
  String get famMemberYou => '（你）';

  @override
  String get famSectionPending => '待处理';

  @override
  String get famPendingComingSoon => '购买审批将在后续版本推出。';

  @override
  String get deviceSessionsAction => '登录设备';

  @override
  String get deviceSessionsTitle => '已登录的设备';

  @override
  String get deviceSessionsEmpty => '该账户没有已登录的设备。';

  @override
  String get deviceRevokeAction => '注销';

  @override
  String deviceRevokeConfirm(String name) {
    return '将「$name」从你的 Steam 账户注销?该设备需要重新登录。';
  }

  @override
  String deviceRevokeDone(String name) {
    return '已注销「$name」。';
  }

  @override
  String deviceRevokeFailed(String error) {
    return '注销设备失败:$error';
  }

  @override
  String get deviceCurrent => '(本机)';

  @override
  String get deviceSignedOut => '已登出';

  @override
  String get deviceUnnamed => '未知设备';

  @override
  String deviceLastSeen(String age) {
    return '$age前活跃';
  }

  @override
  String get devicePlatformSteam => 'Steam 客户端';

  @override
  String get devicePlatformWeb => '网页浏览器';

  @override
  String get devicePlatformMobile => '手机 App';

  @override
  String get devicePlatformUnknown => '未知';

  @override
  String deviceAgeDays(int n) {
    return '$n 天';
  }

  @override
  String deviceAgeHours(int n) {
    return '$n 小时';
  }

  @override
  String deviceAgeMinutes(int n) {
    return '$n 分钟';
  }

  @override
  String get deviceAgeNow => '刚刚';

  @override
  String get keyRedeemAction => '兑换密钥';

  @override
  String get keyRedeemTitle => '兑换 Steam 密钥';

  @override
  String keyRedeemFor(String account) {
    return '激活到 $account';
  }

  @override
  String get keyRedeemHint => 'XXXXX-XXXXX-XXXXX';

  @override
  String get keyRedeemPaste => '粘贴';

  @override
  String get keyRedeemSubmit => '兑换';

  @override
  String get keyRedeemNote =>
      '激活不可撤销，产品会直接加进这个账户。连续几个密钥被拒后 Steam 会封锁激活约一小时，提交前请先核对。';

  @override
  String keyRedeemConfirm(String account) {
    return '把这个密钥激活到 $account？之后无法撤销，也无法转到别的账户。';
  }

  @override
  String get keyRedeemDone => '密钥已激活。';

  @override
  String get keyRedeemGranted => '已加入库：';

  @override
  String get keyRedeemNoProducts => 'Steam 接受了密钥但没有返回产品名，请到该账户的库里确认。';

  @override
  String get keyRedeemNetworkError =>
      '连不上 Steam。如果是请求超时，Steam 可能已经处理过了——再试这枚密钥前，请先到该账户的库里确认。';

  @override
  String get keyErrInvalid => 'Steam 不认识这个密钥。请检查是否输错——0 与 O、1 与 I 很容易看混。';

  @override
  String get keyErrAlreadyOwned => '该账户已拥有这个产品。';

  @override
  String get keyErrAlreadyActivated => '这个密钥已被使用过——可能是本账户，也可能是别的账户。';

  @override
  String get keyErrRegionLocked => '该产品无法在此账户所在的国家/地区激活。';

  @override
  String get keyErrNeedsBaseProduct => '这是 DLC 或资料片，需要该账户先拥有本体游戏。';

  @override
  String get keyErrNeedsPs3Login => '该产品需要先在 PlayStation®3 主机上游玩过才能激活。';

  @override
  String get keyErrRateLimited => '最近被拒的密钥太多，Steam 会封锁激活约一小时，请稍后再试。';

  @override
  String keyErrUnknown(int code) {
    return 'Steam 拒绝了这个密钥（代码 $code）。';
  }

  @override
  String get loginOrApprove => '…或直接在 Steam 手机 App 点「允许」。';

  @override
  String get addErrPresent => '该账户已有验证器。';

  @override
  String get addErrConfirmEmail => '请先确认 Steam 发送的邮件，然后重试。';

  @override
  String get addErrLocked =>
      '该账户已被 Steam 锁定/限制 —— 请先到 help.steampowered.com 恢复后再添加验证器。';

  @override
  String get addErrRateLimited => '尝试次数过多，请稍后再试。';

  @override
  String get addErrFailed => '添加验证器失败。';

  @override
  String addErrSaveFailed(String code) {
    return '无法把验证器保存到本机，已在生效前停止设置。请记下这个撤销码,并从你的账户移除这个待处理的验证器,然后重试:$code';
  }

  @override
  String get addErrBadSms => '短信验证码错误，请重试。';

  @override
  String get debugLog => '调试日志';

  @override
  String get debugLogDesc => '用于诊断登录 / 确认的网络追踪';

  @override
  String get feedbackTitle => '反馈';

  @override
  String get feedbackDesc => '发现 bug 或有想法？直接发给开发者；想公开讨论也可以去 GitHub 提 issue。';

  @override
  String get feedbackSend => '发送反馈';

  @override
  String get feedbackMessageLabel => '反馈内容';

  @override
  String get feedbackMessageHint => '遇到了什么问题 / 想要什么功能？';

  @override
  String get feedbackContactLabel => '联系方式（选填）';

  @override
  String get feedbackContactHint => '邮箱或用户名，需要回复才填';

  @override
  String feedbackAttachNote(String meta) {
    return '将随反馈一并发送：$meta';
  }

  @override
  String get feedbackSent => '已发送，感谢反馈！';

  @override
  String get feedbackFailed => '发送失败，请检查网络后重试。';

  @override
  String feedbackRefused(String reason) {
    return '中转服务拒绝了这条反馈:$reason';
  }

  @override
  String feedbackRelayDown(String reason) {
    return '反馈服务自身出了故障($reason)。你的网络没问题,请稍后再试。';
  }

  @override
  String get feedbackAttachLog => '附加调试日志';

  @override
  String get feedbackAttachLogHint => '最近的网络跟踪记录，可能包含账户名 / SteamID';

  @override
  String get feedbackLogConsentBody =>
      '调试日志是本次会话中最近的网络跟踪记录，可能包含你的账户名与 SteamID——绝不含密钥、令牌或密码。它只会随本条反馈一并发送，详见隐私政策。';

  @override
  String get feedbackLogConsentAgree => '同意';

  @override
  String get backupReminderTitle => '记得备份';

  @override
  String get backupReminderBody =>
      'AVA 的令牌数据只保存在本机。请将 maFile 备份到安全的地方。撤销码（R 码）仅在你首次添加令牌时显示一次——请当场抄下并妥善保管；设备丢失时，它是移除令牌的最后手段。';

  @override
  String get backupReminderOk => '知道了';

  @override
  String get debugCopyAll => '全部复制';

  @override
  String get debugCopied => '日志已复制';

  @override
  String get debugEmpty => '暂无日志。';

  @override
  String get commonOpen => '打开';

  @override
  String get commonClear => '清空';

  @override
  String addErrFinalize(String detail) {
    return '完成失败：$detail';
  }

  @override
  String get loginTitle => '登录 Steam';

  @override
  String get loginUsername => '用户名';

  @override
  String get loginPassword => '密码';

  @override
  String get loginShowPassword => '显示密码';

  @override
  String get loginHidePassword => '隐藏密码';

  @override
  String get loginSavePassword => '保存密码';

  @override
  String get loginSavePasswordHint =>
      '存在该账户的 maFile 中用于自动刷新登录；导出的未加密 maFile 会包含它。';

  @override
  String get loginButton => '登录';

  @override
  String get loginErrInvalidPassword => '账户名或密码错误。';

  @override
  String get loginErrRateLimited => '尝试太频繁，请稍候片刻再试。';

  @override
  String get loginErrCodeMismatch => '验证码不正确，请检查后重试。';

  @override
  String get loginViaQr => '扫码登录';

  @override
  String get loginViaCredentials => '密码登录';

  @override
  String get loginScanWithApp => '用 Steam 手机 App 扫描此二维码';

  @override
  String get loginNeedGuardCode => '请输入 Steam 令牌验证码';

  @override
  String get loginNeedEmailCode => '请输入邮箱收到的验证码';

  @override
  String get loginSubmitCode => '提交';

  @override
  String get loginWaiting => '等待确认…';

  @override
  String get loginStepCredentials => '凭据';

  @override
  String get loginStepConfirm => '确认';

  @override
  String get loginStepDone => '完成';

  @override
  String get loginWaitingDesc => '请在 Steam 手机 App 上批准这次登录。也可改用邮箱验证码或扫码登录。';

  @override
  String loginFailed(String error) {
    return '登录失败：$error';
  }

  @override
  String get approveTitle => '批准登录';

  @override
  String get approveScanPrompt => '扫描你想登录的设备上显示的二维码。';

  @override
  String get approvePastePrompt => '或在此粘贴二维码链接';

  @override
  String get approveButton => '批准';

  @override
  String get approveReject => '拒绝';

  @override
  String get approveSuccess => '登录已批准。';

  @override
  String get approveRejected => '登录已拒绝。';

  @override
  String get approveBadCode => '这不是 Steam 登录二维码。';

  @override
  String get approveLocation => '位置';

  @override
  String get approveDevice => '设备';

  @override
  String get approveWarnStranger => '不是你本人发起的登录？请拒绝。';

  @override
  String get importTitle => '导入账户';

  @override
  String get importPickFile => '选择 .maFile 文件';

  @override
  String get importSuccess => '账户已导入。';

  @override
  String importFailed(String error) {
    return '导入失败：$error';
  }

  @override
  String get importDuplicateTitle => '账户已存在';

  @override
  String importDuplicateBody(String name) {
    return '该 maFile 对应的账户 $name 已在本设备上。要用导入的文件覆盖现有账户吗？文件中未包含的缓存头像、已存密码与现有会话会被保留。';
  }

  @override
  String importDuplicateBodyUnreadable(String name) {
    return '该 maFile 对应的账户 $name 已在本设备上，但其本地数据已无法读取。导入将完全替换它。';
  }

  @override
  String get importDuplicateOverwrite => '覆盖';

  @override
  String get importSessionDeadTitle => '激活该账户的会话？';

  @override
  String get importSessionDeadBody =>
      '该 maFile 中的 Steam 会话已失效。现在登录即可使用交易确认与登录批准——令牌验证码会自动填写。';

  @override
  String get importSessionLater => '稍后';

  @override
  String get sdaImportAction => '导入 SDA 文件夹';

  @override
  String get sdaImportHint =>
      '选择你的 Steam Desktop Authenticator maFiles 文件夹：把 manifest.json 和那些 .maFile 一起选中。两者缺一不可——如果当初在 SDA 里开了加密，解密参数存在 manifest.json 里，不在 maFile 内部。';

  @override
  String get sdaImportNoManifest => '所选文件里没有 manifest.json。请把它和 .maFile 一起选中。';

  @override
  String sdaImportBadManifest(String error) {
    return '这个 manifest.json 读不了：$error';
  }

  @override
  String get sdaImportPassTitle => 'SDA 加密口令';

  @override
  String get sdaImportPassBody =>
      '这些 maFile 是加密的。请输入你当初在 Steam Desktop Authenticator 里设置的口令。';

  @override
  String get sdaImportWrongPass => '这个口令解不开任何一个文件。';

  @override
  String sdaImportDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已导入 $count 个账户。',
    );
    return '$_temp0';
  }

  @override
  String sdaImportSkipped(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '跳过了 $count 个账户：$names',
    );
    return '$_temp0';
  }

  @override
  String get sdaImportNothing => '没有导入任何账户。';

  @override
  String get importSessionLoginNow => '立即登录';

  @override
  String get actionExport => '导出 maFile';

  @override
  String get actionLoginRequests => '登录请求';

  @override
  String get loginRequestTitle => '批准登录？';

  @override
  String loginRequestBody(String device, String location) {
    return '$device 正在从 $location 登录你的 Steam 账户。';
  }

  @override
  String get loginRequestApprove => '允许';

  @override
  String get loginRequestDeny => '拒绝';

  @override
  String get loginNoPending => '没有待批准的登录请求。';

  @override
  String get loginNeedSession => '请先登录刷新该账户的会话。';

  @override
  String get loginApproved => '已允许登录。';

  @override
  String get loginDenied => '已拒绝登录。';

  @override
  String exportFailed(String error) {
    return '导出失败：$error';
  }

  @override
  String get exportWarnTitle => '导出未加密的 maFile？';

  @override
  String get exportWarnBody =>
      '导出的 .maFile 是未加密的。它包含该账户的 Steam 令牌密钥与撤销码——任何拿到文件的人都能接管你的验证器。请妥善保存，用完及时删除。';

  @override
  String get exportIncludePassword => '同时导出已保存的 Steam 密码（不建议）';

  @override
  String get addAuthTitle => '添加验证器';

  @override
  String get addAuthPhonePrompt => '请输入手机号（含国家区号）';

  @override
  String get addAuthSmsPrompt => '请输入手机收到的短信验证码';

  @override
  String get addAuthEmailPrompt => '请输入 Steam 发到邮箱的激活码';

  @override
  String addAuthRevocationWarn(String code) {
    return '请记下你的撤销码：$code';
  }

  @override
  String get addAuthConfirmRevocation => '请再次输入撤销码以确认你已保存';

  @override
  String get addAuthLinked => '验证器绑定成功。';

  @override
  String get addAuthStepPhone => '手机';

  @override
  String get addAuthStepSms => '激活';

  @override
  String get addAuthStepRevocation => '撤销码';

  @override
  String get addPresentTitle => '该账户已有验证器';

  @override
  String get addPresentIntro => 'Steam 同一账户只允许一个手机验证器。请先移除现有验证器，再点「重试」。';

  @override
  String get addPresentStep1 => '仍有旧手机或 Steam App？打开它 → Steam 令牌 → 移除验证器。';

  @override
  String get addPresentStep2 => '有撤销代码（Rxxxxx）？打开下方页面，选择「移除验证器」。';

  @override
  String get addPresentStep3 => '两者都无法访问？通过 Steam 客服 → 帮助 → Steam 令牌手机验证器。';

  @override
  String get addPresentManageUrl => 'store.steampowered.com/twofactor/manage';

  @override
  String get addPresentCopiedUrl => '链接已复制';

  @override
  String get addPresentFallbackTitle => '收不到邮件？';

  @override
  String get addMoveInButton => '把验证器移到本设备';

  @override
  String get addMoveInBlurb => 'Steam 会向该账户邮箱发送验证码，无需 15 天交易冷却。';

  @override
  String get addMoveInSending => '正在发送验证码…';

  @override
  String get addMoveInCodePrompt => '请输入 Steam 发到你邮箱的验证码';

  @override
  String get addMoveInWarn =>
      '确认后：旧手机上的验证器会立即失效，旧的撤销代码（Rxxxxx）作废并换发新的。此操作不可撤销。';

  @override
  String get addMoveInConfirm => '移到本设备';

  @override
  String get addMoveInDone => '验证器已移到本设备。';

  @override
  String get addMoveInPopBlocked => '正在迁移令牌，请稍候。';

  @override
  String get addErrBadChallengeCode => '验证码不正确，请核对邮件后重试。';

  @override
  String addMoveInSaveFailed(String code, String secret) {
    return '验证器已迁移成功，但 AVA 未能把它保存到本设备。旧验证器已失效，以下是仅有的副本——关闭本页前请立即抄写。\n\n撤销代码：$code\n\n密钥：$secret';
  }

  @override
  String get addMoveInCopySecrets => '复制';

  @override
  String get addMoveInCopied => '已复制';

  @override
  String get moveInRescueDismiss => '我已保存——关闭';

  @override
  String get moveInRescueDismissTitle => '丢弃这些密钥？';

  @override
  String get moveInRescueDismissBody => 'AVA 没有其他副本。若尚未抄下撤销代码与密钥，你将永久失去这个验证器。';

  @override
  String get moveInRescueDismissConfirm => '我已保存';

  @override
  String get commonRetry => '重试';

  @override
  String get commonCopy => '复制链接';

  @override
  String get commonRefresh => '刷新';

  @override
  String get commonExport => '导出';

  @override
  String get commonDelete => '删除';

  @override
  String get settingsEncryption => '加密';

  @override
  String get settingsEncryptionDesc =>
      '本机 maFiles 由存于设备 Keystore 的随机 256 位密钥加密（AES-256-GCM），6 位 PIN 用于解锁。';

  @override
  String get settingsThemeDesc => '切换整体界面风格。';

  @override
  String get settingsAppearance => '明暗';

  @override
  String get settingsAppearanceDesc => '标准外观的亮暗模式；启用皮肤时以皮肤为准。';

  @override
  String get settingsTextSize => '字号';

  @override
  String get settingsTextSizeDesc => '在系统字体大小基础上叠加。';

  @override
  String get textSizeSmall => '小';

  @override
  String get textSizeMedium => '中';

  @override
  String get textSizeLarge => '大';

  @override
  String get settingsSkin => '皮肤';

  @override
  String get settingsSkinDesc => '带专属字体与特效的完整风格外观。';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get skinNone => '无';

  @override
  String get settingsChange => '修改';

  @override
  String get settingsSetPasskey => '设置 / 修改加密口令';

  @override
  String get settingsAutoConfirmMarket => '自动确认市场交易';

  @override
  String get settingsAutoConfirmMarketDesc =>
      '上架物品时预先勾选确认框,让新上架在创建后立即被确认。它不会在后台确认任何东西。';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsLanguageSystem => '跟随系统';

  @override
  String get settingsTheme => '主题';

  @override
  String get themeNeon => '霓虹';

  @override
  String get themePixel => '像素';

  @override
  String get themeDark => '暗色';

  @override
  String get themeLight => '亮色';

  @override
  String get settingsAbout => '关于';

  @override
  String get aboutTagline => '开源的 Steam 令牌验证器，用 Flutter 打造。';

  @override
  String get aboutSourceCode => '源代码';

  @override
  String get aboutAuthor => '作者';

  @override
  String get aboutLicense => '许可证';

  @override
  String get aboutPrivacy => '隐私政策';

  @override
  String get privacyConsentTitle => '你的隐私';

  @override
  String get privacyConsentBody =>
      'AVA 把你的 Steam 账户与密钥保存在本设备上——绝不上传;除非你启用可选的同步功能并指定自己的服务器,而那也是先在本机加密后才离开设备。无需注册任何账户。Steam 请求直连 Valve。开发者自己的两个服务只在需要时才被连接:Pro 权益校验,以及反馈(仅当你按下发送)。Play 版免费档还会显示广告。没有任何跟踪或统计。这一切都写在隐私政策里——继续即表示你接受它。';

  @override
  String get privacyUpdateTitle => '隐私政策已更新';

  @override
  String get privacyUpdateBody =>
      '隐私说明在你同意之后有了变更。新增:AVA 现在可以通过你自己指定的服务器,在多台设备间同步账户库——默认关闭,所有数据先在本机加密再上传,开发者不运营任何同步服务器。请阅读下方最新的说明。';

  @override
  String get privacyConsentScrollHint => '请滑到底部后继续';

  @override
  String get privacyConsentRead => '阅读完整隐私政策';

  @override
  String get privacyConsentAgree => '同意并继续';

  @override
  String get privacyConsentExit => '退出';

  @override
  String get actionMarket => '库存 / 市场';

  @override
  String get marketTabInventory => '库存';

  @override
  String get marketTabListings => '我的在售';

  @override
  String get marketSelectGame => '选择游戏';

  @override
  String get marketNoItems => '该库存没有物品。';

  @override
  String get marketNotMarketable => '不可上架';

  @override
  String get marketSellTitle => '上架出售';

  @override
  String get marketYouReceive => '你到手';

  @override
  String get marketBuyerPays => '买家支付';

  @override
  String get marketLowest => '最低在售';

  @override
  String get marketMedian => '中位成交';

  @override
  String get marketHigh => '最高';

  @override
  String get marketLow => '最低';

  @override
  String get marketPriceUnavailable => '市场价暂不可用';

  @override
  String get marketListButton => '确认上架';

  @override
  String get marketListed => '已上架，去确认完成。';

  @override
  String get marketListedDone => '已上架并确认。';

  @override
  String marketListedPartial(int listed, int total) {
    return '已上架 $listed/$total 件（其余失败）——如有待确认项请在确认页完成。';
  }

  @override
  String marketListedSessionExpired(int listed, int total) {
    return '已上架 $listed/$total 件后会话过期——请重新登录并完成确认。';
  }

  @override
  String marketConfirmPartial(int ok, int total) {
    return '已上架——已确认 $ok/$total，其余请在确认页完成。';
  }

  @override
  String get marketAutoConfirm => '上架后自动确认';

  @override
  String get marketQuantity => '数量';

  @override
  String get marketMax => '最大';

  @override
  String marketListFailed(String error) {
    return '上架失败：$error';
  }

  @override
  String get marketInvalidPrice => '请输入有效价格。';

  @override
  String get marketCancel => '撤销在售';

  @override
  String get marketCancelled => '已撤销在售。';

  @override
  String get marketNoListings => '暂无在售。';

  @override
  String get marketFeeNote => 'Steam + 游戏手续费会在你到手价基础上叠加给买家。';

  @override
  String get aboutLicenses => '开源许可证';

  @override
  String get aboutCredits => '致谢';

  @override
  String get aboutCreditsBody =>
      '灵感来自 Steam Desktop Authenticator，兼容其 maFile 格式。基于 Flutter、Riverpod、Dio、PointyCastle、mobile_scanner、image 等开源库独立构建。';

  @override
  String get actionLogin => '登录 / 刷新会话';

  @override
  String get actionConfirmations => '待办';

  @override
  String get actionRemove => '移除账户';

  @override
  String get actionImport => '导入';

  @override
  String get actionAddAuthenticator => '添加验证器';

  @override
  String get commonCancel => '取消';

  @override
  String get commonOk => '确定';

  @override
  String get commonConfirm => '确认';

  @override
  String get commonClose => '关闭';

  @override
  String get commonError => '错误';

  @override
  String get sessionExpired => '你的 Steam 会话已过期，请重新登录。';

  @override
  String get removeConfirm => '从本设备移除该账户？请确保已备份 maFile。';

  @override
  String get settingsPro => 'AVA Pro';

  @override
  String get proOpen => '查看 AVA Pro';

  @override
  String get proStatusFree => '免费版';

  @override
  String proStatusPro(Object date) {
    return 'Pro · 有效至 $date';
  }

  @override
  String proStatusVip(Object date) {
    return 'VIP · 有效至 $date';
  }

  @override
  String get proStatusLifetime => 'Pro · 终身';

  @override
  String proStatusActivations(Object classes) {
    return '已激活：$classes';
  }

  @override
  String proStatusClassThisDevice(Object name) {
    return '$name（本机）';
  }

  @override
  String get proDeviceClassAndroid => 'Android';

  @override
  String get proDeviceClassWindows => 'Windows';

  @override
  String get proDeviceClassLinux => 'Linux';

  @override
  String get proDeviceClassMacos => 'macOS';

  @override
  String get paywallTitle => 'AVA Pro';

  @override
  String get paywallPerksTitle => 'Pro 权益——核心安全功能永久免费。';

  @override
  String get paywallPerkSkins => '主题包：Neon 与 Pixel 皮肤';

  @override
  String get paywallPerkNoAds => '去横幅广告';

  @override
  String get paywallPerkFuture => '后续：云同步、交易通知';

  @override
  String get paywallPlayTitle => '通过 Google Play 解锁';

  @override
  String get paywallSubscribe => '订阅 · \$0.99/月';

  @override
  String get paywallWatchAd => '看广告 · 得 3 天 VIP';

  @override
  String get paywallRestore => '恢复购买';

  @override
  String get paywallCnTitle => '通过爱发电解锁';

  @override
  String get paywallAfdianIntro => '在爱发电以 ¥5/月赞助，然后在此输入订单号解锁。';

  @override
  String get paywallOpenAfdian => '打开爱发电';

  @override
  String get paywallOrderHint => '爱发电订单号';

  @override
  String get paywallRedeem => '解锁';

  @override
  String get paywallBetaTitle => '内测回礼';

  @override
  String get paywallBetaIntro => '内测用户享终身 Pro——输入你的兑换码。';

  @override
  String get paywallBetaHint => '终身兑换码';

  @override
  String get paywallBetaRedeem => '兑换';

  @override
  String get proResultSuccess => '已解锁，感谢支持！';

  @override
  String get proErrCanceled => '已取消。';

  @override
  String get proErrNetwork => '网络错误，稍后再试。';

  @override
  String get proErrNotConfigured => '当前构建尚未开通此功能。';

  @override
  String get proErrNoSubscription =>
      'Play 商店当前账户名下没有有效订阅。如果是用另一个 Google 账户订的：在 Play 商店里（右上角头像）切换到那个账户，再回来重试。';

  @override
  String get proErrAlreadyOwned => 'Play 商店当前账户已持有该订阅——点「恢复购买」即可。';

  @override
  String get proErrOrderBound => '该订单已被其他用户绑定。';

  @override
  String get proErrOrderNotFound => '订单不存在或方案不符。';

  @override
  String get proErrDeviceRevoked => '本设备名额已被新设备占用。';

  @override
  String get proErrNoVip => '奖励尚未到账，请稍后重试。';

  @override
  String get proErrPurchaseBound =>
      '该订阅绑定在另一个 Google 账户上。请重试，并在账户选择器里选 Play 商店正在用的那个账户。';

  @override
  String proErrPurchaseBoundKnown(String account) {
    return '该订阅绑定在 $account。请重试，并在选择器里选这个账户。';
  }

  @override
  String proErrGeneric(Object code) {
    return '失败：$code';
  }

  @override
  String get proErrCodeInvalid => '激活码无效，请检查是否输错。';

  @override
  String get proErrCodeRedeemed =>
      '该激活码已在另一台设备上激活。如需换机使用，请发邮件至 hi@dotslash.pro。';

  @override
  String get proErrCodeActivationLimit =>
      '该激活码近期更换设备过于频繁，请稍后再试，或联系 hi@dotslash.pro。';

  @override
  String get proErrRateLimited => '尝试次数过多，请稍等一分钟再试。';

  @override
  String proErrSlotOccupied(Object slots) {
    return '占用中：$slots';
  }

  @override
  String proSlotEntry(Object name, Object time) {
    return '$name（$time）';
  }

  @override
  String get proSlotToday => '今天';

  @override
  String proSlotDaysAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 天前',
    );
    return '$_temp0';
  }

  @override
  String get proErrRevoked => '该权益已不再有效。如有疑问，请联系 hi@dotslash.pro。';

  @override
  String get privacyOptions => '隐私选项';

  @override
  String get skinProNotice => 'Neon 与 Pixel 皮肤现为 Pro 权益；你的选择已保留，解锁 Pro 即恢复。';

  @override
  String get skinProNoticeDismiss => '知道了';

  @override
  String get syncTitle => '同步';

  @override
  String get syncSetupTitle => '设置同步';

  @override
  String get syncSettingsDesc => '通过你自己掌控的服务器在多台设备间同步账户。所有数据离开本机前都已加密。';

  @override
  String get syncSetUp => '设置同步…';

  @override
  String get syncStatusOk => '已是最新';

  @override
  String get syncStatusSyncing => '正在同步…';

  @override
  String get syncStatusErrorShort => '上次同步失败——打开查看详情。';

  @override
  String syncStatusConflicts(int count) {
    return '$count 个冲突等待你决定';
  }

  @override
  String syncLastSync(String time) {
    return '上次同步：$time';
  }

  @override
  String get syncNever => '从未';

  @override
  String get syncBackendTitle => '数据放在哪里？';

  @override
  String get syncBackendWebdav => 'WebDAV';

  @override
  String get syncBackendWebdavDesc => 'Nextcloud、坚果云、NAS——任何一个你掌控的 WebDAV 文件夹。';

  @override
  String get syncBackendGdrive => 'Google Drive';

  @override
  String get syncBackendGdriveSoon => 'Pro · 稍后推出';

  @override
  String get syncServerTitle => '服务器';

  @override
  String get syncServerHint =>
      '坚果云需要「应用密码」（安全选项 → 添加应用密码），不是登录密码。Nextcloud 的文件夹 URL 形如 https://cloud.example.com/remote.php/dav/files/用户名/ava/。';

  @override
  String get syncServerUrlLabel => 'WebDAV 文件夹 URL';

  @override
  String get syncServerFolderLabel => '文件夹（可选）';

  @override
  String get syncServerFolderHint => '留空则直接使用上面的 URL；填写则放入该子文件夹，不存在会自动创建。';

  @override
  String get syncServerUserLabel => '用户名';

  @override
  String get syncServerPasswordLabel => '密码 / 应用密码';

  @override
  String get syncTestConnection => '测试连接';

  @override
  String get syncErrUrl => '请输入有效的 http(s) 文件夹 URL。';

  @override
  String get syncErrAuth => '服务器拒绝了用户名或密码。';

  @override
  String syncErrNetwork(String detail) {
    return '无法连接服务器：$detail';
  }

  @override
  String syncErrServer(String detail) {
    return '服务器返回错误：$detail';
  }

  @override
  String get syncErrTls => '服务器证书不受信任。';

  @override
  String get syncTlsTitle => '未知的服务器证书';

  @override
  String syncTlsBody(String fp) {
    return '系统不信任该服务器的证书。如果这是你自己的服务器（自签名证书），请把下面的指纹与服务器上显示的逐字比对，完全一致才信任。\n\nSHA-256\n$fp';
  }

  @override
  String get syncTlsTrust => '信任该证书';

  @override
  String get syncHttpPrivateTitle => '未加密连接';

  @override
  String get syncHttpPrivateBody =>
      '这是内网的明文 HTTP 地址。账户数据本身是端到端加密的，但服务器密码会在你的局域网内明文传输。';

  @override
  String get syncHttpPublicTitle => '公网明文 HTTP';

  @override
  String get syncHttpPublicBody =>
      '该地址位于公网且连接不加密：你与服务器之间的任何中间节点都能读到服务器密码并登录你的服务器。账户数据本身仍是加密的。强烈建议改用 HTTPS 或内网地址——确认风险自担才继续。';

  @override
  String get syncHttpPublicHold => '长按仍然允许';

  @override
  String get syncContinue => '继续';

  @override
  String get syncPassphraseNewTitle => '设置同步口令';

  @override
  String get syncPassphraseNewBody =>
      '所有数据上传前都会用这个口令加密；口令本身绝不离开你的设备。\n\n口令一旦丢失，同步数据任何人都无法找回——没有重置这回事。至少 8 个字符；长度比符号更重要。';

  @override
  String get syncPassphraseExistingTitle => '输入同步口令';

  @override
  String syncPassphraseExistingBody(int count) {
    return '这个文件夹里已有一个包含 $count 个账户的同步库。请输入创建它时设置的口令。';
  }

  @override
  String get syncPassphraseLabel => '同步口令';

  @override
  String get syncPassphraseConfirmLabel => '确认口令';

  @override
  String get syncPassphraseTooShort => '至少 8 个字符。';

  @override
  String get syncPassphraseMismatch => '两次输入的口令不一致。';

  @override
  String get syncPassphraseWrong => '这个口令打不开该同步库。';

  @override
  String get syncPreviewTitle => '首次同步';

  @override
  String get syncPreviewEmpty => '暂时没有要传输的内容——之后的账户变动会自动同步。';

  @override
  String syncPreviewPull(int count) {
    return '下载到本机：$count 个账户';
  }

  @override
  String syncPreviewPush(int count) {
    return '从本机上传：$count 个账户';
  }

  @override
  String syncPreviewConflict(int count) {
    return '两侧内容不同：$count 个——连接后逐个选择';
  }

  @override
  String get syncStart => '开始同步';

  @override
  String get syncDoneTitle => '同步已开启';

  @override
  String get syncDoneBody =>
      '账户现在会自动同步。新设备上每个账户首次使用时会重新登录——存过密码的自动完成，其余的会提示输一次。';

  @override
  String get syncDone => '完成';

  @override
  String get syncNeedsPassphrase => '存储的口令与远端同步库不再匹配——请重新输入。';

  @override
  String get syncEnterPassphrase => '输入口令';

  @override
  String get syncConditionalWarn =>
      '该服务器忽略条件写入，两台设备同时同步可能互相覆盖。同步仍可用；避免在两台设备上同时改动。';

  @override
  String get syncConflictsTitle => '冲突';

  @override
  String get syncConflictTrashNote => '被舍弃的一侧会在同步回收站保留 30 天。';

  @override
  String get syncConflictEditEdit => '两台设备都改过';

  @override
  String get syncConflictEditDelete => '本机改过，另一台设备已删除';

  @override
  String get syncConflictDeleteEdit => '本机已删除，另一台设备改过';

  @override
  String get syncConflictKeepLocal => '保留本机版本';

  @override
  String get syncConflictKeepRemote => '保留对方版本';

  @override
  String get syncConflictLocalSide => '本机';

  @override
  String get syncConflictRemoteSide => '另一台设备';

  @override
  String get syncDeleted => '已删除';

  @override
  String get syncConflictHasPassword => '已存密码';

  @override
  String get syncConflictNoPassword => '未存密码';

  @override
  String get syncAutoTitle => '自动同步';

  @override
  String get syncAutoDesc => '启动时和每次改动后同步。关闭后只有下面的按钮会同步。';

  @override
  String get syncPasswordsTitle => '同步账户密码';

  @override
  String get syncPasswordsDesc => '有密码，新设备才能自行登录。改动此项会重新上传全部账户。';

  @override
  String get syncAppSettingsTitle => '同步应用设置';

  @override
  String get syncAppSettingsDesc =>
      '外观与行为偏好（皮肤、明暗、长按确认等）跟随你到每台设备；语言与字号保持各设备独立。';

  @override
  String get syncNowButton => '立即同步';

  @override
  String get syncViewRemote => '查看远端同步库';

  @override
  String get syncRemoteEmpty => '远端同步库是空的。';

  @override
  String get syncRemoteDevices => '设备';

  @override
  String get syncTrashTitle => '同步回收站';

  @override
  String get syncTrashEmpty => '空的。被同步删除或替换的账户会在这里保留 30 天。';

  @override
  String get syncTrashRestore => '恢复';

  @override
  String get syncTrashRestored => '账户已恢复。';

  @override
  String get syncTrashRestoreFailed => '当前口令解不开这条记录。';

  @override
  String get syncTrashReasonRemoteDelete => '被另一台设备删除';

  @override
  String get syncTrashReasonConflict => '在冲突中被替换';

  @override
  String get syncChangePassphrase => '更改同步口令';

  @override
  String get syncPassphraseChanged => '口令已更改，数据已全部重新加密。其他设备会要求输入新口令。';

  @override
  String syncPassphraseChangeFailed(String reason) {
    return '口令未更改：$reason';
  }

  @override
  String get syncDisconnect => '断开同步';

  @override
  String get syncDisconnectBody => '本机停止同步。远端同步库可以留给其他设备继续用——也可以从服务器上彻底删除。';

  @override
  String get syncDisconnectKeep => '保留远端数据';

  @override
  String get syncDisconnectDeleteHold => '长按删除远端数据';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get appTitle => 'AVA';

  @override
  String get navAccounts => '帳號';

  @override
  String get navSettings => '設定';

  @override
  String get unlockTitle => '解鎖';

  @override
  String get unlockPrompt => '請輸入你的加密通行碼';

  @override
  String get unlockButton => '解鎖';

  @override
  String get unlockInvalid => '通行碼不正確。';

  @override
  String get unlockWithBiometric => '用生物辨識 / 裝置密碼解鎖';

  @override
  String get unlockLoading => '解密中…';

  @override
  String get unlockCantUnlock => '無法解鎖？';

  @override
  String get resetVaultTitle => '重設加密資料';

  @override
  String get resetVaultBody =>
      '這會刪除這台裝置上儲存的每一筆帳號項目與加密金鑰，之後你必須重新匯入 maFile 備份。你的 Steam 帳號與其驗證器不受影響。\n\n適用於正確的 PIN 一直被拒絕的情況——通常發生在備份還原或換機之後：硬體金鑰永遠不會離開原本那台裝置，還原回來的資料再也無法解密。\n\n此操作無法復原。';

  @override
  String get resetVaultConfirm => '刪除並重設';

  @override
  String get storeErrorTitle => '無法讀取已儲存的資料';

  @override
  String get storeErrorBody =>
      'AVA 的本機帳號資料庫（manifest.json）遺失或損毀。寫入被中斷或還原不完整都可能造成這個情況。請先重試；若一直失敗，就重設後重新匯入你的 maFile 備份。';

  @override
  String get storeRepair => '嘗試修復';

  @override
  String storeActionFailed(String error) {
    return '操作失敗：$error';
  }

  @override
  String get pinSetupTitle => '設定解鎖 PIN';

  @override
  String get pinSetupPrompt => '用 6 位數 PIN 保護 AVA。解鎖時要輸入它（或用指紋）。';

  @override
  String get pinLabel => '6 位數 PIN';

  @override
  String get pinConfirmLabel => '確認 PIN';

  @override
  String get pinSetButton => '設定 PIN';

  @override
  String get settingsSet => '設定';

  @override
  String get pinChangeTitle => '變更 PIN';

  @override
  String get pinCurrentLabel => '目前的 PIN';

  @override
  String get pinNewLabel => '新的 PIN';

  @override
  String get pinSixDigits => '請輸入 6 位數 PIN。';

  @override
  String get pinMismatch => '兩次輸入的 PIN 不一致。';

  @override
  String get unlockBiometricReason => '解鎖 AVA';

  @override
  String get settingsBiometric => '生物辨識解鎖';

  @override
  String get settingsBiometricDesc => '用指紋或裝置密碼解鎖；通行碼存放在裝置的 Keystore 裡。';

  @override
  String get settingsBiometricNeedPasskey => '請先設定加密通行碼。';

  @override
  String get settingsBiometricUnavailable => '這台裝置沒有設定生物辨識或螢幕鎖。';

  @override
  String get settingsBiometricEnabled => '已啟用生物辨識解鎖。';

  @override
  String get settingsHoldConfirm => '長按確認';

  @override
  String get settingsHoldConfirmDesc =>
      '不可逆的接受動作（交易、確認）需要長按才會生效。關閉後單擊就立即生效；批次動作仍會先詢問。';

  @override
  String get settingsHaptics => '觸覺回饋';

  @override
  String get settingsHapticsDesc => '長按確認的過程中與完成時的震動回饋。';

  @override
  String get settingsBlockScreenshots => '禁止截圖';

  @override
  String get settingsBlockScreenshotsDesc =>
      '讓 AVA 不出現在截圖、螢幕錄影和最近使用畫面的預覽裡。代價是螢幕分享時視窗會變黑，也沒辦法再把截圖附到意見回饋裡。';

  @override
  String get passkeyLabel => '通行碼';

  @override
  String get accountsEmpty => '還沒有帳號。匯入 maFile 或登入來新增一個。';

  @override
  String get emptyAddAccount => '新增帳號';

  @override
  String get accountReady => '就緒';

  @override
  String get tutCodeTitle => '即時驗證碼';

  @override
  String get tutCodeBody => '點大字驗證碼就能複製。點帳號那一行可在帳號名稱 / 暱稱 / SteamID 之間切換。';

  @override
  String get tutSwipeRightTitle => '向右滑 → 交易確認';

  @override
  String get tutSwipeRightBody => '把帳號向右滑，直接打開它的交易確認。';

  @override
  String get tutSwipeLeftTitle => '向左滑 → 更多動作';

  @override
  String get tutSwipeLeftBody => '向左滑可更新登入狀態、匯出 maFile 或移除帳號。';

  @override
  String get tutLongPressTitle => '長按 → 庫存與市集';

  @override
  String get tutLongPressBody => '長按帳號可瀏覽它的庫存，並把物品上架到社群市集。';

  @override
  String get tutPullTitle => '下拉重新整理';

  @override
  String get tutPullBody => '下拉帳號清單可更新頭像，並檢查待處理的登入請求。';

  @override
  String get tutSkip => '略過';

  @override
  String get tutNext => '下一步';

  @override
  String get tutDone => '知道了';

  @override
  String get settingsTutorial => '手勢教學';

  @override
  String get settingsTutorialDesc => '重播主畫面的操作導覽（滑動、長按、下拉重新整理）。';

  @override
  String get settingsTutorialReplay => '重播';

  @override
  String get welcomeTitle => '歡迎使用 AVA';

  @override
  String get welcomeSubtitle => '你的驗證器會加密儲存在這台裝置上。請選擇開始的方式。';

  @override
  String get welcomeLoginCta => '登入 Steam';

  @override
  String get welcomeLoginSub => '設定一個新的驗證器';

  @override
  String get welcomeImportCta => '匯入 .maFile';

  @override
  String get welcomeImportSub => '把既有帳號搬過來';

  @override
  String get welcomeSyncCta => '從同步還原';

  @override
  String get welcomeSyncSub => '從既有的同步庫拉取你的帳號';

  @override
  String get copyCode => '複製驗證碼';

  @override
  String get codeCopied => '登入驗證碼已複製到剪貼簿';

  @override
  String get copied => '已複製到剪貼簿';

  @override
  String get copySteamId => '複製 SteamID';

  @override
  String get pendingTitle => '待處理';

  @override
  String get pendingTabConfirmations => '確認';

  @override
  String get pendingTabOffers => '交易報價';

  @override
  String get confirmationsTitle => '確認';

  @override
  String get confirmationsEmpty => '沒有待處理的確認。';

  @override
  String get confirmationsRefresh => '重新整理';

  @override
  String get confAccept => '接受';

  @override
  String get confDecline => '拒絕';

  @override
  String get confSelectAll => '全選';

  @override
  String get confAcceptSelected => '接受所選';

  @override
  String get confDeclineSelected => '拒絕所選';

  @override
  String get confAcceptAll => '全部接受';

  @override
  String get confRejectAll => '全部拒絕';

  @override
  String confAcceptAllConfirm(int count) {
    return '要接受全部 $count 項確認嗎？';
  }

  @override
  String confRejectAllConfirm(int count) {
    return '要拒絕全部 $count 項確認嗎？';
  }

  @override
  String get confAcceptAllWarn => '這會一次批准所有待處理的交易與市集上架。請確認你認得其中每一項。';

  @override
  String get confRejectAllWarn => '這會一次取消所有待處理的確認。';

  @override
  String confPending(int count) {
    return '$count 項待確認';
  }

  @override
  String get confAllProcessed => '已全部處理';

  @override
  String get confTypeTrade => '交易';

  @override
  String get confTypeMarket => '市集上架';

  @override
  String get confTypeOther => '確認';

  @override
  String get confTypeFamilyJoin => '家庭群組邀請';

  @override
  String get confTypeApiKey => 'API 金鑰';

  @override
  String get confTypePhoneChange => '更換手機號碼';

  @override
  String get confTypeAccountRecovery => '帳號救援';

  @override
  String get confTypeFeatureOptOut => '功能退出';

  @override
  String confProcessing(int count) {
    return '正在處理 $count 項確認…';
  }

  @override
  String confResult(int ok, int fail) {
    return '成功 $ok 項，失敗 $fail 項';
  }

  @override
  String get confNeedsLogin => '登入狀態已過期——請重新登入以更新這個帳號。';

  @override
  String get confRejected =>
      'Steam 拒絕了這次確認請求。這通常代表 maFile 與帳號上目前的驗證器不符（買來的帳號很常見）——請先移除驗證器再重新綁定，或匯入正確的 maFile。裝置時間偏差過大也會造成這個問題。';

  @override
  String get offersSegReceived => '收到';

  @override
  String get offersSegSent => '送出';

  @override
  String get offersSegHistory => '紀錄';

  @override
  String get offersEmpty => '沒有交易報價。';

  @override
  String get offerGift => '贈送——你不用給出任何東西';

  @override
  String get offerOneSided => '你給出物品，卻收不到任何東西';

  @override
  String get offerEscrow => '物品會先由 Steam 保管一段時間才送達';

  @override
  String get offerAcceptHold => '長按接受';

  @override
  String get offerDecline => '拒絕';

  @override
  String get offerCancel => '取消報價';

  @override
  String get offerReceiveLabel => '你收到';

  @override
  String get offerGiveLabel => '你給出';

  @override
  String get offerAccepted => '已接受報價——請到「確認」頁完成確認';

  @override
  String get offerAcceptedNoConf => '已接受報價。';

  @override
  String offerActionFailed(String msg) {
    return '操作失敗：$msg';
  }

  @override
  String get offerDeclined => '已拒絕報價。';

  @override
  String get offerCanceled => '已取消報價。';

  @override
  String get pendingTabInvites => '邀請';

  @override
  String famInviteTitle(String groupName) {
    return '「$groupName」邀請你加入';
  }

  @override
  String get famInviteTitleGeneric => '家庭群組邀請';

  @override
  String famInviteFrom(String inviter) {
    return '邀請人：$inviter';
  }

  @override
  String famInviteRole(String role) {
    return '角色：$role';
  }

  @override
  String famInviteSlots(int used, int total) {
    return '成員 $used/$total';
  }

  @override
  String get famRoleAdult => '成人';

  @override
  String get famRoleChild => '兒童';

  @override
  String famRoleUnknown(int n) {
    return '角色 #$n';
  }

  @override
  String get famPreflightTitle => '加入前檢查';

  @override
  String get famCheckWalletMatch => '錢包地區相符';

  @override
  String get famCheckWalletMismatch => '錢包地區不符——Steam 會限制加入';

  @override
  String get famCheckIpMatch => '常用 IP 相符';

  @override
  String get famCheckIpMismatch => 'IP 與你的常用地點不符';

  @override
  String get famCheckCooldown => '加入後 1 年內無法更換家庭群組（Steam 冷卻期）';

  @override
  String famJoinRestricted(int code) {
    return 'Steam 阻擋了這次加入（限制碼 $code）';
  }

  @override
  String get famInviteJoinHold => '長按加入';

  @override
  String get famInviteAwaiting2fa => '等待確認中——請到「確認」頁處理';

  @override
  String get famInviteJoined => '已加入 ✓';

  @override
  String get famInviteViewGroup => '查看家庭群組 ›';

  @override
  String get famJoinSent => '已送出加入請求——請到「確認」頁完成確認';

  @override
  String get famJoinDone => '已加入家庭群組。';

  @override
  String famJoinFailed(String msg) {
    return '加入失敗：$msg';
  }

  @override
  String get famInvitesEmpty => '沒有待處理的家庭群組邀請。';

  @override
  String get famAccountAction => '家庭群組';

  @override
  String get famNotInGroup => '這個帳號不在任何家庭群組裡。';

  @override
  String famSummaryMembers(int used, int total) {
    return '成員 $used/$total';
  }

  @override
  String famSummaryCooldown(int days) {
    return '冷卻 $days 天';
  }

  @override
  String get famInvitesSection => '邀請';

  @override
  String get famSectionMembers => '成員';

  @override
  String get famMemberYou => '（你）';

  @override
  String get famSectionPending => '待處理';

  @override
  String get famPendingComingSoon => '購買審核會在後續版本推出。';

  @override
  String get deviceSessionsAction => '裝置';

  @override
  String get deviceSessionsTitle => '已登入的裝置';

  @override
  String get deviceSessionsEmpty => '這個帳號沒有使用中的裝置。';

  @override
  String get deviceRevokeAction => '登出';

  @override
  String deviceRevokeConfirm(String name) {
    return '要把「$name」從你的 Steam 帳號登出嗎？它必須重新登入。';
  }

  @override
  String deviceRevokeDone(String name) {
    return '已將「$name」登出。';
  }

  @override
  String deviceRevokeFailed(String error) {
    return '無法將這台裝置登出：$error';
  }

  @override
  String get deviceCurrent => '（本機）';

  @override
  String get deviceSignedOut => '已登出';

  @override
  String get deviceUnnamed => '未知裝置';

  @override
  String deviceLastSeen(String age) {
    return '$age前活躍';
  }

  @override
  String get devicePlatformSteam => 'Steam 用戶端';

  @override
  String get devicePlatformWeb => '網頁瀏覽器';

  @override
  String get devicePlatformMobile => '手機 App';

  @override
  String get devicePlatformUnknown => '未知';

  @override
  String deviceAgeDays(int n) {
    return '$n 天';
  }

  @override
  String deviceAgeHours(int n) {
    return '$n 小時';
  }

  @override
  String deviceAgeMinutes(int n) {
    return '$n 分鐘';
  }

  @override
  String get deviceAgeNow => '剛剛';

  @override
  String get keyRedeemAction => '兌換產品代碼';

  @override
  String get keyRedeemTitle => '兌換 Steam 產品代碼';

  @override
  String keyRedeemFor(String account) {
    return '啟動到 $account';
  }

  @override
  String get keyRedeemHint => 'XXXXX-XXXXX-XXXXX';

  @override
  String get keyRedeemPaste => '貼上';

  @override
  String get keyRedeemSubmit => '兌換';

  @override
  String get keyRedeemNote =>
      '啟動無法復原，產品會直接加進這個帳號。連續幾組產品代碼被拒絕後，Steam 會封鎖啟動約一小時，送出前請先核對。';

  @override
  String keyRedeemConfirm(String account) {
    return '要把這組產品代碼啟動到 $account 嗎？之後無法復原，也無法轉到其他帳號。';
  }

  @override
  String get keyRedeemDone => '產品代碼已啟動。';

  @override
  String get keyRedeemGranted => '已加入媒體庫：';

  @override
  String get keyRedeemNoProducts => 'Steam 接受了這組產品代碼，但沒有回報產品名稱。請到這個帳號的媒體庫確認。';

  @override
  String get keyRedeemNetworkError =>
      '連不上 Steam。如果是請求逾時，Steam 可能其實已經處理過了——再試這組產品代碼之前，請先到這個帳號的媒體庫確認。';

  @override
  String get keyErrInvalid =>
      'Steam 不認得這組產品代碼。請檢查是否打錯——0 與 O、1 與 I 之類的字元很容易看混。';

  @override
  String get keyErrAlreadyOwned => '這個帳號已經擁有這項產品。';

  @override
  String get keyErrAlreadyActivated => '這組產品代碼已經被用過了——可能是這個帳號，也可能是別的帳號。';

  @override
  String get keyErrRegionLocked => '這項產品無法在這個帳號所在的國家／地區啟動。';

  @override
  String get keyErrNeedsBaseProduct => '這是 DLC 或資料片，這個帳號必須先擁有本體遊戲。';

  @override
  String get keyErrNeedsPs3Login => '這項產品必須先在 PlayStation®3 主機上遊玩過才能啟動。';

  @override
  String get keyErrRateLimited => '最近被拒絕的產品代碼太多。Steam 會封鎖啟動約一小時——請稍後再試。';

  @override
  String keyErrUnknown(int code) {
    return 'Steam 拒絕了這組產品代碼（代碼 $code）。';
  }

  @override
  String get loginOrApprove => '…或者直接在 Steam 手機 App 裡點「允許」。';

  @override
  String get addErrPresent => '這個帳號已經有驗證器了。';

  @override
  String get addErrConfirmEmail => '請先確認 Steam 寄來的 Email，然後重試。';

  @override
  String get addErrLocked =>
      '這個帳號已被 Steam 鎖定／限制——請先到 help.steampowered.com 救回帳號，再新增驗證器。';

  @override
  String get addErrRateLimited => '嘗試次數太多。請稍等一陣子再試。';

  @override
  String get addErrFailed => '新增驗證器失敗。';

  @override
  String addErrSaveFailed(String code) {
    return '無法把驗證器存到這台裝置，所以在它生效之前就停止了設定。請記下這組撤銷碼，並從你的帳號移除這個待處理的驗證器，然後再試一次：$code';
  }

  @override
  String get addErrBadSms => '簡訊驗證碼錯誤，請再試一次。';

  @override
  String get debugLog => '除錯記錄';

  @override
  String get debugLogDesc => '用來診斷登入 / 確認的網路追蹤記錄';

  @override
  String get feedbackTitle => '意見回饋';

  @override
  String get feedbackDesc => '發現 bug 或有想法嗎？直接寄給開發者；想公開討論也可以到 GitHub 開 issue。';

  @override
  String get feedbackSend => '送出回饋';

  @override
  String get feedbackMessageLabel => '你的意見';

  @override
  String get feedbackMessageHint => '哪裡壞了 / 你想要什麼？';

  @override
  String get feedbackContactLabel => '聯絡方式（選填）';

  @override
  String get feedbackContactHint => 'Email 或使用者名稱——想要回覆才需要填';

  @override
  String feedbackAttachNote(String meta) {
    return '會隨你的訊息一起送出：$meta';
  }

  @override
  String get feedbackSent => '已送出，謝謝你的回饋！';

  @override
  String get feedbackFailed => '送不出去。請檢查網路後再試一次。';

  @override
  String feedbackRefused(String reason) {
    return '中繼服務拒絕了這份回報：$reason';
  }

  @override
  String feedbackRelayDown(String reason) {
    return '意見回饋服務自己那端出了問題（$reason）。你的網路沒問題——請稍後再試。';
  }

  @override
  String get feedbackAttachLog => '附上除錯記錄';

  @override
  String get feedbackAttachLogHint => '最近的網路追蹤記錄，可能包含帳號名稱 / SteamID';

  @override
  String get feedbackLogConsentBody =>
      '除錯記錄是這次執行期間最近的網路追蹤內容，可能包含你的帳號名稱與 SteamID——絕不含你的金鑰、權杖或密碼。它只會隨這份回報一起送出，詳見隱私權政策。';

  @override
  String get feedbackLogConsentAgree => '同意';

  @override
  String get backupReminderTitle => '請備份你的金鑰';

  @override
  String get backupReminderBody =>
      'AVA 只把你的驗證器資料留在這台裝置上。請把 maFile 備份到安全的地方。撤銷碼（R 碼）只在你第一次新增驗證器時顯示一次——請當場抄下並保管好；萬一這台裝置遺失，它是你移除驗證器的最後手段。';

  @override
  String get backupReminderOk => '知道了';

  @override
  String get debugCopyAll => '全部複製';

  @override
  String get debugCopied => '記錄已複製';

  @override
  String get debugEmpty => '還沒有記錄。';

  @override
  String get commonOpen => '開啟';

  @override
  String get commonClear => '清除';

  @override
  String addErrFinalize(String detail) {
    return '完成綁定失敗：$detail';
  }

  @override
  String get loginTitle => '登入 Steam';

  @override
  String get loginUsername => '帳號名稱';

  @override
  String get loginPassword => '密碼';

  @override
  String get loginShowPassword => '顯示密碼';

  @override
  String get loginHidePassword => '隱藏密碼';

  @override
  String get loginSavePassword => '儲存密碼';

  @override
  String get loginSavePasswordHint =>
      '存在這個帳號的 maFile 裡，用來自動更新登入狀態；未加密的匯出檔會包含它。';

  @override
  String get loginButton => '登入';

  @override
  String get loginErrInvalidPassword => '帳號名稱或密碼錯誤。';

  @override
  String get loginErrRateLimited => '嘗試次數太多——請稍等一陣子再試。';

  @override
  String get loginErrCodeMismatch => '驗證碼不符——請核對後再試一次。';

  @override
  String get loginViaQr => '用 QR Code 登入';

  @override
  String get loginViaCredentials => '用密碼登入';

  @override
  String get loginScanWithApp => '用 Steam 手機 App 掃描這個 QR Code';

  @override
  String get loginNeedGuardCode => '請輸入 Steam 令牌驗證碼';

  @override
  String get loginNeedEmailCode => '請輸入寄到你信箱的驗證碼';

  @override
  String get loginSubmitCode => '送出';

  @override
  String get loginWaiting => '等待確認中…';

  @override
  String get loginStepCredentials => '帳密';

  @override
  String get loginStepConfirm => '確認';

  @override
  String get loginStepDone => '完成';

  @override
  String get loginWaitingDesc =>
      '請在 Steam 手機 App 上批准這次登入。你也可以改用 Email 驗證碼或 QR Code 登入。';

  @override
  String loginFailed(String error) {
    return '登入失敗：$error';
  }

  @override
  String get approveTitle => '批准登入';

  @override
  String get approveScanPrompt => '掃描你要登入的那台裝置上顯示的 QR Code。';

  @override
  String get approvePastePrompt => '或在這裡貼上 QR Code 連結';

  @override
  String get approveButton => '批准';

  @override
  String get approveReject => '拒絕';

  @override
  String get approveSuccess => '已批准登入。';

  @override
  String get approveRejected => '已拒絕登入。';

  @override
  String get approveBadCode => '這不是 Steam 登入用的 QR Code。';

  @override
  String get approveLocation => '地點';

  @override
  String get approveDevice => '裝置';

  @override
  String get approveWarnStranger => '不是你自己發起的登入嗎？請拒絕。';

  @override
  String get importTitle => '匯入帳號';

  @override
  String get importPickFile => '選擇 .maFile 檔案';

  @override
  String get importSuccess => '已匯入帳號。';

  @override
  String importFailed(String error) {
    return '匯入失敗：$error';
  }

  @override
  String get importDuplicateTitle => '帳號已存在';

  @override
  String importDuplicateBody(String name) {
    return '這個 maFile 對應的帳號 $name 已經在這台裝置上。要用匯入的檔案覆寫已儲存的帳號嗎？檔案裡沒有的快取頭像、已存密碼與現有登入狀態會保留下來。';
  }

  @override
  String importDuplicateBodyUnreadable(String name) {
    return '這個 maFile 對應的帳號 $name 已經在這台裝置上，但它的資料已經無法讀取。匯入會把它完全取代掉。';
  }

  @override
  String get importDuplicateOverwrite => '覆寫';

  @override
  String get importSessionDeadTitle => '要啟用這個帳號嗎？';

  @override
  String get importSessionDeadBody =>
      '這個 maFile 裡的 Steam 登入狀態已經過期。現在登入就能使用交易確認與登入批准——Steam 令牌驗證碼會自動填入。';

  @override
  String get importSessionLater => '稍後';

  @override
  String get sdaImportAction => '匯入 SDA 資料夾';

  @override
  String get sdaImportHint =>
      '選擇你的 Steam Desktop Authenticator maFiles 資料夾：把 manifest.json 和那些 .maFile 一起選取。兩者缺一不可——如果當初在 SDA 裡開了加密，解密參數存在 manifest.json 裡，不在 maFile 內部。';

  @override
  String get sdaImportNoManifest => '所選檔案裡沒有 manifest.json。請把它和 .maFile 一起選取。';

  @override
  String sdaImportBadManifest(String error) {
    return '這個 manifest.json 讀不了：$error';
  }

  @override
  String get sdaImportPassTitle => 'SDA 加密通行碼';

  @override
  String get sdaImportPassBody =>
      '這些 maFile 是加密的。請輸入你當初在 Steam Desktop Authenticator 裡設定的通行碼。';

  @override
  String get sdaImportWrongPass => '這個通行碼解不開任何一個檔案。';

  @override
  String sdaImportDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已匯入 $count 個帳號。',
    );
    return '$_temp0';
  }

  @override
  String sdaImportSkipped(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '略過了 $count 個帳號：$names',
    );
    return '$_temp0';
  }

  @override
  String get sdaImportNothing => '沒有匯入任何帳號。';

  @override
  String get importSessionLoginNow => '立即登入';

  @override
  String get actionExport => '匯出 maFile';

  @override
  String get actionLoginRequests => '登入請求';

  @override
  String get loginRequestTitle => '要批准登入嗎？';

  @override
  String loginRequestBody(String device, String location) {
    return '$device 正從 $location 登入你的 Steam 帳號。';
  }

  @override
  String get loginRequestApprove => '允許';

  @override
  String get loginRequestDeny => '拒絕';

  @override
  String get loginNoPending => '沒有待處理的登入請求。';

  @override
  String get loginNeedSession => '請先登入以更新這個帳號的登入狀態。';

  @override
  String get loginApproved => '已允許登入。';

  @override
  String get loginDenied => '已拒絕登入。';

  @override
  String exportFailed(String error) {
    return '匯出失敗：$error';
  }

  @override
  String get exportWarnTitle => '要匯出未加密的 maFile 嗎？';

  @override
  String get exportWarnBody =>
      '匯出的 .maFile 沒有加密。它含有這個帳號的 Steam 令牌金鑰與撤銷碼——任何拿到這個檔案的人都能接管你的驗證器。請存放在安全的地方，用完立刻刪除。';

  @override
  String get exportIncludePassword => '一併包含已儲存的 Steam 密碼（不建議）';

  @override
  String get addAuthTitle => '新增驗證器';

  @override
  String get addAuthPhonePrompt => '請輸入你的手機號碼（含國碼）';

  @override
  String get addAuthSmsPrompt => '請輸入手機收到的簡訊驗證碼';

  @override
  String get addAuthEmailPrompt => '請輸入 Steam 寄到你信箱的啟用碼';

  @override
  String addAuthRevocationWarn(String code) {
    return '請記下你的撤銷碼：$code';
  }

  @override
  String get addAuthConfirmRevocation => '請再輸入一次撤銷碼，確認你已經存好了';

  @override
  String get addAuthLinked => '驗證器已成功綁定。';

  @override
  String get addAuthStepPhone => '手機';

  @override
  String get addAuthStepSms => '啟用';

  @override
  String get addAuthStepRevocation => '撤銷碼';

  @override
  String get addPresentTitle => '這個帳號已經有驗證器';

  @override
  String get addPresentIntro => 'Steam 每個帳號只允許一個手機驗證器。請先移除現有的那個，再點「重試」。';

  @override
  String get addPresentStep1 => '還有舊手機或 Steam App 嗎？打開它 → Steam 令牌 → 移除驗證器。';

  @override
  String get addPresentStep2 => '有撤銷碼（Rxxxxx）嗎？開啟下面的頁面，選擇「移除驗證器」。';

  @override
  String get addPresentStep3 => '兩個都用不了嗎？請走 Steam 客服 → 說明 → Steam 令牌手機驗證器。';

  @override
  String get addPresentManageUrl => 'store.steampowered.com/twofactor/manage';

  @override
  String get addPresentCopiedUrl => '已複製連結';

  @override
  String get addPresentFallbackTitle => '收不到 Email 嗎？';

  @override
  String get addMoveInButton => '把驗證器移到這台裝置';

  @override
  String get addMoveInBlurb => 'Steam 會寄一組驗證碼到這個帳號的信箱。不會有 15 天交易保留期。';

  @override
  String get addMoveInSending => '正在寄送驗證碼…';

  @override
  String get addMoveInCodePrompt => '請輸入 Steam 寄到你信箱的驗證碼';

  @override
  String get addMoveInWarn =>
      '一旦確認：舊手機上的驗證器會立刻失效，舊的撤銷碼（Rxxxxx）也會作廢並換成新的。此操作無法復原。';

  @override
  String get addMoveInConfirm => '移到這裡';

  @override
  String get addMoveInDone => '驗證器已移到這台裝置。';

  @override
  String get addMoveInPopBlocked => '正在搬移驗證器，請稍候。';

  @override
  String get addErrBadChallengeCode => '驗證碼不正確。請核對 Email 後再試一次。';

  @override
  String addMoveInSaveFailed(String code, String secret) {
    return '驗證器已經移到這個帳號，但 AVA 沒能把它存到這台裝置。你的舊驗證器已經失效，所以以下是僅有的副本——關閉這個畫面之前請立刻抄下來。\n\n撤銷碼：$code\n\n金鑰：$secret';
  }

  @override
  String get addMoveInCopySecrets => '複製';

  @override
  String get addMoveInCopied => '已複製';

  @override
  String get moveInRescueDismiss => '我存好了——關閉';

  @override
  String get moveInRescueDismissTitle => '要捨棄這些金鑰嗎？';

  @override
  String get moveInRescueDismissBody =>
      'AVA 沒有留下任何其他副本。如果你還沒抄下撤銷碼與金鑰，你將永久失去這個驗證器。';

  @override
  String get moveInRescueDismissConfirm => '我存好了';

  @override
  String get commonRetry => '重試';

  @override
  String get commonCopy => '複製連結';

  @override
  String get commonRefresh => '重新整理';

  @override
  String get commonExport => '匯出';

  @override
  String get commonDelete => '刪除';

  @override
  String get settingsEncryption => '加密';

  @override
  String get settingsEncryptionDesc =>
      '本機的 maFile 以存放在裝置 Keystore 的隨機 256 位元金鑰加密（AES-256-GCM）；你的 6 位數 PIN 用來解開它。';

  @override
  String get settingsThemeDesc => '切換整體介面風格。';

  @override
  String get settingsAppearance => '外觀';

  @override
  String get settingsAppearanceDesc => '標準外觀要淺色還是深色。啟用皮膚時以皮膚為準。';

  @override
  String get settingsTextSize => '文字大小';

  @override
  String get settingsTextSizeDesc => '在系統字型大小之上再套用。';

  @override
  String get textSizeSmall => '小';

  @override
  String get textSizeMedium => '中';

  @override
  String get textSizeLarge => '大';

  @override
  String get settingsSkin => '皮膚';

  @override
  String get settingsSkinDesc => '有專屬字型與特效的完整風格外觀。';

  @override
  String get themeSystem => '跟隨系統';

  @override
  String get skinNone => '無';

  @override
  String get settingsChange => '變更';

  @override
  String get settingsSetPasskey => '設定 / 變更加密通行碼';

  @override
  String get settingsAutoConfirmMarket => '自動確認市集交易';

  @override
  String get settingsAutoConfirmMarketDesc =>
      '上架物品時預先勾選確認框，讓新的上架建立後立刻被確認。它絕不會在背景確認任何東西。';

  @override
  String get settingsLanguage => '語言';

  @override
  String get settingsLanguageSystem => '系統預設';

  @override
  String get settingsTheme => '主題';

  @override
  String get themeNeon => '霓虹';

  @override
  String get themePixel => '像素';

  @override
  String get themeDark => '深色';

  @override
  String get themeLight => '淺色';

  @override
  String get settingsAbout => '關於';

  @override
  String get aboutTagline => '開源的 Steam 令牌驗證器，以 Flutter 打造。';

  @override
  String get aboutSourceCode => '原始碼';

  @override
  String get aboutAuthor => '作者';

  @override
  String get aboutLicense => '授權條款';

  @override
  String get aboutPrivacy => '隱私權政策';

  @override
  String get privacyConsentTitle => '你的隱私';

  @override
  String get privacyConsentBody =>
      'AVA 把你的 Steam 帳號與金鑰保存在本裝置上——絕不上傳;除非你啟用可選的同步功能並指定自己的伺服器,而那也是先在本機加密後才離開裝置。無需註冊任何帳號。Steam 請求直連 Valve。開發者自己的兩個服務只在需要時才會被連線:Pro 權益查驗,以及意見回饋(僅當你按下傳送)。Play 版免費方案還會顯示廣告。沒有任何追蹤或統計。這一切都寫在隱私權政策裡——繼續即表示你接受它。';

  @override
  String get privacyUpdateTitle => '隱私權政策已更新';

  @override
  String get privacyUpdateBody =>
      '隱私權說明在你同意之後有了變更。新增:AVA 現在可以透過你自己指定的伺服器,在多台裝置間同步帳號庫——預設關閉,所有資料先在本機加密再上傳,開發者不營運任何同步伺服器。請閱讀下方最新的說明。';

  @override
  String get privacyConsentScrollHint => '請捲動到底才能繼續';

  @override
  String get privacyConsentRead => '閱讀完整的隱私權政策';

  @override
  String get privacyConsentAgree => '同意並繼續';

  @override
  String get privacyConsentExit => '結束';

  @override
  String get actionMarket => '庫存 / 市集';

  @override
  String get marketTabInventory => '庫存';

  @override
  String get marketTabListings => '我的上架';

  @override
  String get marketSelectGame => '選擇遊戲';

  @override
  String get marketNoItems => '這個庫存裡沒有物品。';

  @override
  String get marketNotMarketable => '無法上架';

  @override
  String get marketSellTitle => '上架出售';

  @override
  String get marketYouReceive => '你實得';

  @override
  String get marketBuyerPays => '買家支付';

  @override
  String get marketLowest => '最低價';

  @override
  String get marketMedian => '中位價';

  @override
  String get marketHigh => '最高';

  @override
  String get marketLow => '最低';

  @override
  String get marketPriceUnavailable => '無法取得市價';

  @override
  String get marketListButton => '確認上架';

  @override
  String get marketListed => '已上架——去確認以完成。';

  @override
  String get marketListedDone => '已上架並確認。';

  @override
  String marketListedPartial(int listed, int total) {
    return '已上架 $listed/$total 件——其餘失敗；待確認的請到「確認」頁完成。';
  }

  @override
  String marketListedSessionExpired(int listed, int total) {
    return '已上架 $listed/$total 件後登入狀態過期——請重新登入並完成確認。';
  }

  @override
  String marketConfirmPartial(int ok, int total) {
    return '已上架——已確認 $ok/$total，其餘請到「確認」頁完成。';
  }

  @override
  String get marketAutoConfirm => '上架後自動確認';

  @override
  String get marketQuantity => '數量';

  @override
  String get marketMax => '最大';

  @override
  String marketListFailed(String error) {
    return '上架失敗：$error';
  }

  @override
  String get marketInvalidPrice => '請輸入有效的價格。';

  @override
  String get marketCancel => '取消上架';

  @override
  String get marketCancelled => '已取消上架。';

  @override
  String get marketNoListings => '沒有上架中的商品。';

  @override
  String get marketFeeNote => 'Steam 與遊戲的手續費會加在你實得的金額之上。';

  @override
  String get aboutLicenses => '開源授權';

  @override
  String get aboutCredits => '致謝';

  @override
  String get aboutCreditsBody =>
      '靈感來自 Steam Desktop Authenticator，並相容其 maFile 格式。以 Flutter、Riverpod、Dio、PointyCastle、mobile_scanner、image 等開源函式庫獨立打造。';

  @override
  String get actionLogin => '登入 / 更新登入狀態';

  @override
  String get actionConfirmations => '待處理';

  @override
  String get actionRemove => '移除帳號';

  @override
  String get actionImport => '匯入';

  @override
  String get actionAddAuthenticator => '新增驗證器';

  @override
  String get commonCancel => '取消';

  @override
  String get commonOk => '確定';

  @override
  String get commonConfirm => '確認';

  @override
  String get commonClose => '關閉';

  @override
  String get commonError => '錯誤';

  @override
  String get sessionExpired => '你的 Steam 登入狀態已過期，請重新登入。';

  @override
  String get removeConfirm => '要把這個帳號從這台裝置移除嗎？請先確認你已經備份好 maFile。';

  @override
  String get settingsPro => 'AVA Pro';

  @override
  String get proOpen => '查看 AVA Pro';

  @override
  String get proStatusFree => '免費方案';

  @override
  String proStatusPro(Object date) {
    return 'Pro · 有效至 $date';
  }

  @override
  String proStatusVip(Object date) {
    return 'VIP · 有效至 $date';
  }

  @override
  String get proStatusLifetime => 'Pro · 終身';

  @override
  String proStatusActivations(Object classes) {
    return '已啟用於：$classes';
  }

  @override
  String proStatusClassThisDevice(Object name) {
    return '$name（本機）';
  }

  @override
  String get proDeviceClassAndroid => 'Android';

  @override
  String get proDeviceClassWindows => 'Windows';

  @override
  String get proDeviceClassLinux => 'Linux';

  @override
  String get proDeviceClassMacos => 'macOS';

  @override
  String get paywallTitle => 'AVA Pro';

  @override
  String get paywallPerksTitle => 'Pro 權益——核心安全功能永遠免費。';

  @override
  String get paywallPerkSkins => '主題包：Neon 與 Pixel 皮膚';

  @override
  String get paywallPerkNoAds => '沒有橫幅廣告';

  @override
  String get paywallPerkFuture => '之後推出：雲端同步、交易通知';

  @override
  String get paywallPlayTitle => '透過 Google Play 解鎖';

  @override
  String get paywallSubscribe => '訂閱 · \$0.99/月';

  @override
  String get paywallWatchAd => '看廣告 · 3 天 VIP';

  @override
  String get paywallRestore => '還原購買';

  @override
  String get paywallCnTitle => '透過愛發電解鎖';

  @override
  String get paywallAfdianIntro => '在愛發電以每月 ¥5 贊助，然後在這裡輸入訂單編號解鎖。';

  @override
  String get paywallOpenAfdian => '開啟愛發電';

  @override
  String get paywallOrderHint => '愛發電訂單編號';

  @override
  String get paywallRedeem => '解鎖';

  @override
  String get paywallBetaTitle => 'Beta 回禮';

  @override
  String get paywallBetaIntro => 'Beta 測試者可獲得終身 Pro——請輸入你的兌換碼。';

  @override
  String get paywallBetaHint => '終身兌換碼';

  @override
  String get paywallBetaRedeem => '兌換';

  @override
  String get proResultSuccess => '已解鎖，謝謝你！';

  @override
  String get proErrCanceled => '已取消。';

  @override
  String get proErrNetwork => '網路錯誤——請稍後再試。';

  @override
  String get proErrNotConfigured => '這個版本還不支援。';

  @override
  String get proErrNoSubscription =>
      'Play 商店目前帳號名下沒有有效訂閱。如果是用另一個 Google 帳號訂的：在 Play 商店裡（右上角頭像）切換到那個帳號，再回來重試。';

  @override
  String get proErrAlreadyOwned => 'Play 商店目前帳號已持有該訂閱——點「還原購買」即可。';

  @override
  String get proErrOrderBound => '這筆訂單已經綁定到其他使用者。';

  @override
  String get proErrOrderNotFound => '找不到訂單，或方案不符。';

  @override
  String get proErrDeviceRevoked => '這台裝置的名額已被較新的啟用取代。';

  @override
  String get proErrNoVip => '獎勵還沒確認到帳——請一分鐘後再試。';

  @override
  String get proErrPurchaseBound =>
      '該訂閱綁定在另一個 Google 帳號上。請重試，並在帳號選擇器裡選 Play 商店正在使用的那個帳號。';

  @override
  String proErrPurchaseBoundKnown(String account) {
    return '該訂閱綁定在 $account。請重試，並在選擇器裡選這個帳號。';
  }

  @override
  String proErrGeneric(Object code) {
    return '失敗：$code';
  }

  @override
  String get proErrCodeInvalid => '無法辨識這組兌換碼——請檢查是否打錯。';

  @override
  String get proErrCodeRedeemed =>
      '這組兌換碼已經在另一台裝置上啟用。要移到這裡，請來信 hi@dotslash.pro。';

  @override
  String get proErrCodeActivationLimit =>
      '這組兌換碼最近換裝置太頻繁。請稍後再試，或來信 hi@dotslash.pro。';

  @override
  String get proErrRateLimited => '嘗試次數太多。請等一分鐘再試。';

  @override
  String proErrSlotOccupied(Object slots) {
    return '使用中：$slots';
  }

  @override
  String proSlotEntry(Object name, Object time) {
    return '$name（$time）';
  }

  @override
  String get proSlotToday => '今天';

  @override
  String proSlotDaysAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 天前',
    );
    return '$_temp0';
  }

  @override
  String get proErrRevoked => '這項權益已經失效。如果你覺得這是錯誤，請來信 hi@dotslash.pro。';

  @override
  String get privacyOptions => '隱私選項';

  @override
  String get skinProNotice => 'Neon 與 Pixel 皮膚現在是 Pro 權益。你的選擇已保留，解鎖 Pro 後就會回來。';

  @override
  String get skinProNoticeDismiss => '知道了';

  @override
  String get syncTitle => '同步';

  @override
  String get syncSetupTitle => '設定同步';

  @override
  String get syncSettingsDesc => '透過你自己掌控的伺服器在多台裝置間同步帳號。所有資料離開這台裝置前都已加密。';

  @override
  String get syncSetUp => '設定同步…';

  @override
  String get syncStatusOk => '已是最新';

  @override
  String get syncStatusSyncing => '同步中…';

  @override
  String get syncStatusErrorShort => '上次同步失敗——點開查看詳情。';

  @override
  String syncStatusConflicts(int count) {
    return '$count 個衝突等你決定';
  }

  @override
  String syncLastSync(String time) {
    return '上次同步：$time';
  }

  @override
  String get syncNever => '從未';

  @override
  String get syncBackendTitle => '資料要放在哪裡？';

  @override
  String get syncBackendWebdav => 'WebDAV';

  @override
  String get syncBackendWebdavDesc =>
      'Nextcloud、坚果云（Jianguoyun）、NAS——任何一個你掌控的 WebDAV 資料夾。';

  @override
  String get syncBackendGdrive => 'Google 雲端硬碟';

  @override
  String get syncBackendGdriveSoon => 'Pro · 之後推出';

  @override
  String get syncServerTitle => '伺服器';

  @override
  String get syncServerHint =>
      '坚果云需要「應用程式密碼」（安全选项 → 添加应用密码），不是登入密碼。Nextcloud 的資料夾 URL 格式類似 https://cloud.example.com/remote.php/dav/files/使用者名稱/ava/。';

  @override
  String get syncServerUrlLabel => 'WebDAV 資料夾 URL';

  @override
  String get syncServerFolderLabel => '資料夾（選填）';

  @override
  String get syncServerFolderHint => '留空則直接使用上面的 URL；填寫則放入該子資料夾，不存在會自動建立。';

  @override
  String get syncServerUserLabel => '使用者名稱';

  @override
  String get syncServerPasswordLabel => '密碼 / 應用程式密碼';

  @override
  String get syncTestConnection => '測試連線';

  @override
  String get syncErrUrl => '請輸入有效的 http(s) 資料夾 URL。';

  @override
  String get syncErrAuth => '伺服器拒絕了使用者名稱或密碼。';

  @override
  String syncErrNetwork(String detail) {
    return '無法連上伺服器：$detail';
  }

  @override
  String syncErrServer(String detail) {
    return '伺服器回應了錯誤：$detail';
  }

  @override
  String get syncErrTls => '伺服器憑證不受信任。';

  @override
  String get syncTlsTitle => '未知的伺服器憑證';

  @override
  String syncTlsBody(String fp) {
    return '系統不信任這個伺服器的憑證。如果這是你自己的伺服器（自簽憑證），請把下面的指紋和伺服器上顯示的逐字比對，完全一致才信任。\n\nSHA-256\n$fp';
  }

  @override
  String get syncTlsTrust => '信任這個憑證';

  @override
  String get syncHttpPrivateTitle => '未加密連線';

  @override
  String get syncHttpPrivateBody =>
      '這是內部網路上的明文 HTTP 位址。帳號資料本身是端對端加密的，但伺服器密碼會在你的網路上明文傳輸。';

  @override
  String get syncHttpPublicTitle => '跨網際網路的明文 HTTP';

  @override
  String get syncHttpPublicBody =>
      '這個位址在公開網路上，連線不會加密：你和伺服器之間的任何人都能讀到伺服器密碼並登入你的伺服器。帳號資料本身仍是加密的。請改用 HTTPS 或區域網路位址——確定接受這個風險才繼續。';

  @override
  String get syncHttpPublicHold => '長按仍要允許';

  @override
  String get syncContinue => '繼續';

  @override
  String get syncPassphraseNewTitle => '設定同步密語';

  @override
  String get syncPassphraseNewBody =>
      '所有資料上傳前都會用這組密語加密；密語本身絕不會離開你的裝置。\n\n密語一旦遺失，同步的資料任何人都救不回來——沒有重設這回事。至少 8 個字元；長度比符號更重要。';

  @override
  String get syncPassphraseExistingTitle => '輸入同步密語';

  @override
  String syncPassphraseExistingBody(int count) {
    return '這個資料夾已經有一個包含 $count 個帳號的同步庫。請輸入建立它時設定的密語。';
  }

  @override
  String get syncPassphraseLabel => '同步密語';

  @override
  String get syncPassphraseConfirmLabel => '確認密語';

  @override
  String get syncPassphraseTooShort => '至少 8 個字元。';

  @override
  String get syncPassphraseMismatch => '兩次輸入的密語不一致。';

  @override
  String get syncPassphraseWrong => '這組密語打不開這個同步庫。';

  @override
  String get syncPreviewTitle => '首次同步';

  @override
  String get syncPreviewEmpty => '目前沒有要傳輸的內容——之後帳號有變動就會自動同步。';

  @override
  String syncPreviewPull(int count) {
    return '下載到這台裝置：$count 個帳號';
  }

  @override
  String syncPreviewPush(int count) {
    return '從這台裝置上傳：$count 個帳號';
  }

  @override
  String syncPreviewConflict(int count) {
    return '兩邊內容不同：$count 個——連線後逐一選擇';
  }

  @override
  String get syncStart => '開始同步';

  @override
  String get syncDoneTitle => '同步已開啟';

  @override
  String get syncDoneBody =>
      '帳號現在會自動同步。新裝置上每個帳號第一次使用時要重新登入——存過密碼的會自己完成，其餘的會問一次。';

  @override
  String get syncDone => '完成';

  @override
  String get syncNeedsPassphrase => '儲存的密語和遠端同步庫已對不上——請重新輸入。';

  @override
  String get syncEnterPassphrase => '輸入密語';

  @override
  String get syncConditionalWarn =>
      '這台伺服器會忽略條件寫入，兩台裝置同時同步可能互相覆寫。同步仍可使用；請避免在兩台裝置上同時改動。';

  @override
  String get syncConflictsTitle => '衝突';

  @override
  String get syncConflictTrashNote => '被捨棄的那一邊會在同步垃圾桶保留 30 天。';

  @override
  String get syncConflictEditEdit => '兩台裝置都改過';

  @override
  String get syncConflictEditDelete => '這裡改過，另一台裝置已刪除';

  @override
  String get syncConflictDeleteEdit => '這裡已刪除，另一台裝置改過';

  @override
  String get syncConflictKeepLocal => '保留這台的版本';

  @override
  String get syncConflictKeepRemote => '保留對方的版本';

  @override
  String get syncConflictLocalSide => '這台裝置';

  @override
  String get syncConflictRemoteSide => '另一台裝置';

  @override
  String get syncDeleted => '已刪除';

  @override
  String get syncConflictHasPassword => '已存密碼';

  @override
  String get syncConflictNoPassword => '未存密碼';

  @override
  String get syncAutoTitle => '自動同步';

  @override
  String get syncAutoDesc => '啟動時和每次改動後同步。關閉後只有下面的按鈕會同步。';

  @override
  String get syncPasswordsTitle => '同步帳號密碼';

  @override
  String get syncPasswordsDesc => '有密碼，新裝置才能自行登入。變更這一項會重新上傳所有帳號。';

  @override
  String get syncAppSettingsTitle => '同步應用程式設定';

  @override
  String get syncAppSettingsDesc =>
      '外觀與行為偏好（面板、明暗、長按確認等）跟著你到每台裝置；語言與文字大小維持各裝置獨立。';

  @override
  String get syncNowButton => '立即同步';

  @override
  String get syncViewRemote => '檢視遠端同步庫';

  @override
  String get syncRemoteEmpty => '遠端同步庫是空的。';

  @override
  String get syncRemoteDevices => '裝置';

  @override
  String get syncTrashTitle => '同步垃圾桶';

  @override
  String get syncTrashEmpty => '空的。被同步刪除或取代的帳號會在這裡保留 30 天。';

  @override
  String get syncTrashRestore => '還原';

  @override
  String get syncTrashRestored => '帳號已還原。';

  @override
  String get syncTrashRestoreFailed => '目前的密語解不開這筆資料。';

  @override
  String get syncTrashReasonRemoteDelete => '被另一台裝置刪除';

  @override
  String get syncTrashReasonConflict => '在衝突中被取代';

  @override
  String get syncChangePassphrase => '變更同步密語';

  @override
  String get syncPassphraseChanged => '密語已變更，資料已全部重新加密。其他裝置會要求輸入新密語。';

  @override
  String syncPassphraseChangeFailed(String reason) {
    return '密語未變更：$reason';
  }

  @override
  String get syncDisconnect => '中斷同步';

  @override
  String get syncDisconnectBody =>
      '這台裝置會停止同步。遠端同步庫可以留給你的其他裝置繼續用——也可以從伺服器上整個刪除。';

  @override
  String get syncDisconnectKeep => '保留遠端資料';

  @override
  String get syncDisconnectDeleteHold => '長按刪除遠端資料';
}
