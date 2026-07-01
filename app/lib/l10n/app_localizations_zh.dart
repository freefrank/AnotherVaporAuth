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
  String get passkeyLabel => '口令';

  @override
  String get accountsEmpty => '暂无账户。导入 maFile 或登录以添加。';

  @override
  String get accountReady => '已就绪';

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
  String get addErrBadSms => '短信验证码错误，请重试。';

  @override
  String get debugLog => '调试日志';

  @override
  String get debugLogDesc => '用于诊断登录 / 确认的网络追踪';

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
  String get loginButton => '登录';

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
  String get pwdSave => '保存密码';

  @override
  String get pwdClear => '清除已存密码';

  @override
  String get pwdCleared => '已清除保存的密码。';

  @override
  String get pwdSaveTitle => '保存 Steam 密码';

  @override
  String get pwdSaveBody => '存于设备 keystore（绝不写入 maFile），用于自动刷新该账户的登录。';

  @override
  String get pwdField => 'Steam 密码';

  @override
  String get pwdVerify => '验证并保存';

  @override
  String get pwdWrong => '密码错误或登录失败。';

  @override
  String get pwdNeedsEmail => '该账户需要邮箱验证码，请改用完整登录。';

  @override
  String get pwdSaved => '密码已保存，登录已刷新。';

  @override
  String get pwdHasSaved => '该账户已保存密码。';

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
      '本机 maFiles 已用你的 6 位解锁 PIN 加密（AES-256-CBC）。';

  @override
  String get settingsThemeDesc => '在霓虹与像素之间切换整体界面。';

  @override
  String get settingsChange => '修改';

  @override
  String get settingsSetPasskey => '设置 / 修改加密口令';

  @override
  String get settingsPeriodicChecking => '周期检查确认';

  @override
  String get settingsCheckInterval => '检查间隔（秒）';

  @override
  String get settingsCheckAll => '检查所有账户';

  @override
  String get settingsAutoConfirmMarket => '自动确认市场交易';

  @override
  String get settingsAutoConfirmTrades => '自动确认交易';

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
  String get aboutLicenses => '开源许可证';

  @override
  String get aboutCredits => '致谢';

  @override
  String get aboutCreditsBody =>
      '灵感来自 Steam Desktop Authenticator，兼容其 maFile 格式。基于 Flutter、Riverpod、Dio、PointyCastle、mobile_scanner、image 等开源库独立构建。';

  @override
  String get actionLogin => '登录 / 刷新会话';

  @override
  String get actionConfirmations => '交易确认';

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
