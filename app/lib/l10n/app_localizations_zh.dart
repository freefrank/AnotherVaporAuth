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
    return '空位 $used/$total';
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
  String get famSectionMembers => '成员';

  @override
  String get famMemberYou => '（你）';

  @override
  String get famSectionPending => '待处理';

  @override
  String get famPendingComingSoon => '购买审批将在后续版本推出。';

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
  String get importSessionDeadTitle => '激活该账户的会话？';

  @override
  String get importSessionDeadBody =>
      '该 maFile 中的 Steam 会话已失效。现在登录即可使用交易确认与登录批准——令牌验证码会自动填写。';

  @override
  String get importSessionLater => '稍后';

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
  String get aboutTagline => '开源的 Steam 令牌验证器，用 Flutter 重写。';

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
      'AVA 把你的全部数据都保存在本机。它没有自己的后端，只连接 Valve 的 Steam 服务器，不做任何追踪或分析。继续即表示你接受隐私政策。';

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
}
