// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'AVA';

  @override
  String get navAccounts => 'Accounts';

  @override
  String get navSettings => 'Settings';

  @override
  String get unlockTitle => 'Unlock';

  @override
  String get unlockPrompt => 'Enter your encryption passkey';

  @override
  String get unlockButton => 'Unlock';

  @override
  String get unlockInvalid => 'That passkey is invalid.';

  @override
  String get passkeyLabel => 'Passkey';

  @override
  String get accountsEmpty =>
      'No accounts yet. Import a maFile or log in to add one.';

  @override
  String get accountReady => 'Ready';

  @override
  String get welcomeTitle => 'Welcome to AVA';

  @override
  String get welcomeSubtitle =>
      'Your authenticator is stored encrypted on this device. Choose how to begin.';

  @override
  String get welcomeLoginCta => 'Log in to Steam';

  @override
  String get welcomeLoginSub => 'Set up a new authenticator';

  @override
  String get welcomeImportCta => 'Import .maFile';

  @override
  String get welcomeImportSub => 'Migrate an existing account';

  @override
  String get copyCode => 'Copy code';

  @override
  String get codeCopied => 'Login code copied to clipboard';

  @override
  String get copySteamId => 'Copy SteamID';

  @override
  String get confirmationsTitle => 'Confirmations';

  @override
  String get confirmationsEmpty => 'No pending confirmations.';

  @override
  String get confirmationsRefresh => 'Refresh';

  @override
  String get confAccept => 'Accept';

  @override
  String get confDecline => 'Decline';

  @override
  String get confSelectAll => 'Select all';

  @override
  String get confAcceptSelected => 'Accept selected';

  @override
  String get confDeclineSelected => 'Decline selected';

  @override
  String get confAcceptAll => 'Accept all';

  @override
  String get confRejectAll => 'Reject all';

  @override
  String confPending(int count) {
    return '$count pending';
  }

  @override
  String get confAllProcessed => 'All processed';

  @override
  String get confTypeTrade => 'Trade';

  @override
  String get confTypeMarket => 'Market listing';

  @override
  String get confTypeOther => 'Confirmation';

  @override
  String confProcessing(int count) {
    return 'Processing $count confirmation(s)…';
  }

  @override
  String confResult(int ok, int fail) {
    return '$ok succeeded, $fail failed';
  }

  @override
  String get confNeedsLogin =>
      'Session expired — sign in again to refresh this account.';

  @override
  String get loginOrApprove => '…or just tap “Allow” in your Steam mobile app.';

  @override
  String get addErrPresent => 'This account already has an authenticator.';

  @override
  String get addErrConfirmEmail =>
      'Please confirm the email Steam sent, then retry.';

  @override
  String get addErrLocked =>
      'This account is locked/restricted by Steam — recover it at help.steampowered.com before adding an authenticator.';

  @override
  String get addErrRateLimited =>
      'Too many attempts. Please wait a while and try again.';

  @override
  String get addErrFailed => 'Failed to add authenticator.';

  @override
  String get addErrBadSms => 'Wrong SMS code, please try again.';

  @override
  String get debugLog => 'Debug log';

  @override
  String get debugLogDesc =>
      'Network trace for diagnosing login / confirmations';

  @override
  String get debugCopyAll => 'Copy all';

  @override
  String get debugCopied => 'Log copied';

  @override
  String get debugEmpty => 'No log yet.';

  @override
  String get commonOpen => 'Open';

  @override
  String get commonClear => 'Clear';

  @override
  String addErrFinalize(String detail) {
    return 'Finalize failed: $detail';
  }

  @override
  String get loginTitle => 'Log in to Steam';

  @override
  String get loginUsername => 'Username';

  @override
  String get loginPassword => 'Password';

  @override
  String get loginButton => 'Log in';

  @override
  String get loginViaQr => 'Log in with QR code';

  @override
  String get loginViaCredentials => 'Log in with password';

  @override
  String get loginScanWithApp => 'Scan this code with the Steam mobile app';

  @override
  String get loginNeedGuardCode => 'Enter the Steam Guard code';

  @override
  String get loginNeedEmailCode => 'Enter the code sent to your email';

  @override
  String get loginSubmitCode => 'Submit';

  @override
  String get loginWaiting => 'Waiting for confirmation…';

  @override
  String get loginStepCredentials => 'Credentials';

  @override
  String get loginStepConfirm => 'Confirm';

  @override
  String get loginStepDone => 'Done';

  @override
  String get loginWaitingDesc =>
      'Approve this sign in on the Steam mobile app. You can also use an email code or QR sign-in.';

  @override
  String loginFailed(String error) {
    return 'Login failed: $error';
  }

  @override
  String get approveTitle => 'Approve sign in';

  @override
  String get approveScanPrompt =>
      'Scan the QR code shown on the device you want to sign in.';

  @override
  String get approvePastePrompt => 'Or paste the QR code link here';

  @override
  String get approveButton => 'Approve';

  @override
  String get approveReject => 'Reject';

  @override
  String get approveSuccess => 'Sign in approved.';

  @override
  String get approveRejected => 'Sign in rejected.';

  @override
  String get importTitle => 'Import account';

  @override
  String get importPickFile => 'Choose a .maFile';

  @override
  String get importSuccess => 'Account imported.';

  @override
  String importFailed(String error) {
    return 'Failed to import: $error';
  }

  @override
  String get addAuthTitle => 'Add authenticator';

  @override
  String get addAuthPhonePrompt =>
      'Enter your phone number (with country code)';

  @override
  String get addAuthSmsPrompt => 'Enter the SMS code sent to your phone';

  @override
  String get addAuthEmailPrompt =>
      'Enter the activation code Steam emailed you';

  @override
  String addAuthRevocationWarn(String code) {
    return 'Write down your revocation code: $code';
  }

  @override
  String get addAuthConfirmRevocation =>
      'Re-enter your revocation code to confirm you saved it';

  @override
  String get addAuthLinked => 'Authenticator linked successfully.';

  @override
  String get addAuthStepPhone => 'Phone';

  @override
  String get addAuthStepSms => 'Activate';

  @override
  String get addAuthStepRevocation => 'Revocation';

  @override
  String get settingsEncryption => 'Encryption';

  @override
  String get settingsEncryptionDesc =>
      'PBKDF2 50k + AES-256-CBC — protects your local maFiles.';

  @override
  String get settingsThemeDesc => 'Switch the whole UI between Neon and Pixel.';

  @override
  String get settingsChange => 'Change';

  @override
  String get settingsSetPasskey => 'Set / change encryption passkey';

  @override
  String get settingsPeriodicChecking => 'Periodically check for confirmations';

  @override
  String get settingsCheckInterval => 'Check interval (seconds)';

  @override
  String get settingsCheckAll => 'Check all accounts';

  @override
  String get settingsAutoConfirmMarket => 'Auto-confirm market transactions';

  @override
  String get settingsAutoConfirmTrades => 'Auto-confirm trades';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System default';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get themeNeon => 'Neon';

  @override
  String get themePixel => 'Pixel';

  @override
  String get actionLogin => 'Log in / refresh session';

  @override
  String get actionConfirmations => 'Trade confirmations';

  @override
  String get actionRemove => 'Remove account';

  @override
  String get actionImport => 'Import';

  @override
  String get actionAddAuthenticator => 'Add authenticator';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonOk => 'OK';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonClose => 'Close';

  @override
  String get commonError => 'Error';

  @override
  String get sessionExpired =>
      'Your Steam session has expired. Please log in again.';

  @override
  String get removeConfirm =>
      'Remove this account from this device? Make sure you have your maFile backed up.';
}
