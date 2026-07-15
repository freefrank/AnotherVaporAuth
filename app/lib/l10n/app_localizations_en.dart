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
  String get unlockWithBiometric => 'Unlock with biometrics / device PIN';

  @override
  String get unlockLoading => 'Decrypting…';

  @override
  String get unlockCantUnlock => 'Can\'t unlock?';

  @override
  String get resetVaultTitle => 'Reset encrypted data';

  @override
  String get resetVaultBody =>
      'This deletes every account entry and encryption key stored on this device; afterwards you re-import your maFile backups. Your Steam accounts and their authenticators are not affected.\n\nUse this when the correct PIN keeps being rejected — typically after a backup restore or phone migration, since the hardware key never leaves the original device, restored data can never be decrypted.\n\nThis cannot be undone.';

  @override
  String get resetVaultConfirm => 'Delete & reset';

  @override
  String get pinSetupTitle => 'Set unlock PIN';

  @override
  String get pinSetupPrompt =>
      'Protect AVA with a 6-digit PIN. You\'ll enter it (or your fingerprint) to unlock.';

  @override
  String get pinLabel => '6-digit PIN';

  @override
  String get pinConfirmLabel => 'Confirm PIN';

  @override
  String get pinSetButton => 'Set PIN';

  @override
  String get settingsSet => 'Set';

  @override
  String get pinChangeTitle => 'Change PIN';

  @override
  String get pinCurrentLabel => 'Current PIN';

  @override
  String get pinNewLabel => 'New PIN';

  @override
  String get pinSixDigits => 'Enter a 6-digit PIN.';

  @override
  String get pinMismatch => 'The PINs don\'t match.';

  @override
  String get unlockBiometricReason => 'Unlock AVA';

  @override
  String get settingsBiometric => 'Biometric unlock';

  @override
  String get settingsBiometricDesc =>
      'Unlock with your fingerprint or device PIN; the passkey is stored in the device keystore.';

  @override
  String get settingsBiometricNeedPasskey => 'Set an encryption passkey first.';

  @override
  String get settingsBiometricUnavailable =>
      'No biometrics or device lock set up on this device.';

  @override
  String get settingsBiometricEnabled => 'Biometric unlock enabled.';

  @override
  String get settingsHoldConfirm => 'Hold to confirm';

  @override
  String get settingsHoldConfirmDesc =>
      'Irreversible accepts (trades, confirmations) require press-and-hold. When off, a single tap acts immediately; batch actions still ask first.';

  @override
  String get settingsHaptics => 'Haptic feedback';

  @override
  String get settingsHapticsDesc =>
      'Vibration ticks while holding to confirm and on completion.';

  @override
  String get passkeyLabel => 'Passkey';

  @override
  String get accountsEmpty =>
      'No accounts yet. Import a maFile or log in to add one.';

  @override
  String get emptyAddAccount => 'Add account';

  @override
  String get accountReady => 'Ready';

  @override
  String get tutCodeTitle => 'Live token';

  @override
  String get tutCodeBody =>
      'Tap the big code to copy it. Tap the account name to cycle username / nickname / SteamID.';

  @override
  String get tutSwipeRightTitle => 'Swipe right → confirmations';

  @override
  String get tutSwipeRightBody =>
      'Swipe an account to the right to open its trade confirmations.';

  @override
  String get tutSwipeLeftTitle => 'Swipe left → more actions';

  @override
  String get tutSwipeLeftBody =>
      'Swipe left to refresh the session, export the maFile, or remove the account.';

  @override
  String get tutLongPressTitle => 'Long-press → inventory & market';

  @override
  String get tutLongPressBody =>
      'Long-press an account to browse its inventory and list items on the Community Market.';

  @override
  String get tutPullTitle => 'Pull to refresh';

  @override
  String get tutPullBody =>
      'Pull the account list down to refresh avatars and check pending sign-ins.';

  @override
  String get tutSkip => 'Skip';

  @override
  String get tutNext => 'Next';

  @override
  String get tutDone => 'Got it';

  @override
  String get settingsTutorial => 'Gesture tutorial';

  @override
  String get settingsTutorialDesc =>
      'Replay the home-screen walkthrough (swipes, long-press, pull-to-refresh).';

  @override
  String get settingsTutorialReplay => 'Replay';

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
  String get copied => 'Copied to clipboard';

  @override
  String get copySteamId => 'Copy SteamID';

  @override
  String get pendingTitle => 'Pending';

  @override
  String get pendingTabConfirmations => 'Confirmations';

  @override
  String get pendingTabOffers => 'Trade offers';

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
  String confAcceptAllConfirm(int count) {
    return 'Accept all $count confirmations?';
  }

  @override
  String confRejectAllConfirm(int count) {
    return 'Reject all $count confirmations?';
  }

  @override
  String get confAcceptAllWarn =>
      'This approves every pending trade and market listing at once. Make sure you recognize all of them.';

  @override
  String get confRejectAllWarn =>
      'This cancels every pending confirmation at once.';

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
  String get confTypeFamilyJoin => 'Family invite';

  @override
  String get confTypeApiKey => 'API key';

  @override
  String get confTypePhoneChange => 'Phone change';

  @override
  String get confTypeAccountRecovery => 'Account recovery';

  @override
  String get confTypeFeatureOptOut => 'Feature opt-out';

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
  String get confRejected =>
      'Steam rejected the confirmation request. This usually means the maFile does not match the authenticator currently on the account (common with purchased accounts) — remove the authenticator and link it again, or import the right maFile. A large clock drift can also cause this.';

  @override
  String get offersSegReceived => 'Received';

  @override
  String get offersSegSent => 'Sent';

  @override
  String get offersSegHistory => 'History';

  @override
  String get offersEmpty => 'No trade offers.';

  @override
  String get offerGift => 'Gift — you give nothing';

  @override
  String get offerOneSided => 'You give items and receive nothing';

  @override
  String get offerEscrow => 'Items will be held by Steam before delivery';

  @override
  String get offerAcceptHold => 'Hold to accept';

  @override
  String get offerDecline => 'Decline';

  @override
  String get offerCancel => 'Cancel offer';

  @override
  String get offerReceiveLabel => 'You receive';

  @override
  String get offerGiveLabel => 'You give';

  @override
  String get offerAccepted =>
      'Offer accepted — confirm it in the Confirmations tab';

  @override
  String get offerAcceptedNoConf => 'Offer accepted.';

  @override
  String offerActionFailed(String msg) {
    return 'Action failed: $msg';
  }

  @override
  String get offerDeclined => 'Offer declined.';

  @override
  String get offerCanceled => 'Offer canceled.';

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
  String addErrSaveFailed(String code) {
    return 'Couldn\'t save the authenticator to this device, so setup was stopped before it took effect. Write down this revocation code and remove the pending authenticator from your account, then try again: $code';
  }

  @override
  String get addErrBadSms => 'Wrong SMS code, please try again.';

  @override
  String get debugLog => 'Debug log';

  @override
  String get debugLogDesc =>
      'Network trace for diagnosing login / confirmations';

  @override
  String get feedbackTitle => 'Feedback';

  @override
  String get feedbackDesc =>
      'Found a bug or have an idea? Send it straight to the developer, or open a GitHub issue for public discussion.';

  @override
  String get feedbackSend => 'Send feedback';

  @override
  String get feedbackMessageLabel => 'Your feedback';

  @override
  String get feedbackMessageHint => 'What broke / what would you like?';

  @override
  String get feedbackContactLabel => 'Contact (optional)';

  @override
  String get feedbackContactHint =>
      'Email or username — only if you want a reply';

  @override
  String feedbackAttachNote(String meta) {
    return 'Sent along with your message: $meta';
  }

  @override
  String get feedbackSent => 'Feedback sent — thank you!';

  @override
  String get feedbackFailed =>
      'Couldn\'t send. Check your network and try again.';

  @override
  String get feedbackAttachLog => 'Attach debug log';

  @override
  String get feedbackAttachLogHint =>
      'Recent network trace; may include account names / SteamIDs';

  @override
  String get feedbackLogConsentBody =>
      'The debug log contains recent network-trace lines from this session. It may include your account names and SteamIDs — never your secrets, tokens or passwords. It is sent only together with this report, as described in the Privacy Policy.';

  @override
  String get feedbackLogConsentAgree => 'Agree';

  @override
  String get backupReminderTitle => 'Back up your secrets';

  @override
  String get backupReminderBody =>
      'AVA keeps your authenticator data on this device only. Back up your maFiles somewhere safe. Your revocation code (R-code) is shown only once, when you first add an authenticator — write it down and keep it then; it is your last resort for removing the authenticator if this device is ever lost.';

  @override
  String get backupReminderOk => 'Got it';

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
  String get loginShowPassword => 'Show password';

  @override
  String get loginHidePassword => 'Hide password';

  @override
  String get loginSavePassword => 'Save password';

  @override
  String get loginSavePasswordHint =>
      'Kept in this account\'s maFile for automatic session refresh; an unencrypted export will contain it.';

  @override
  String get loginButton => 'Log in';

  @override
  String get loginErrInvalidPassword => 'Wrong account name or password.';

  @override
  String get loginErrRateLimited =>
      'Too many attempts — please wait a while and try again.';

  @override
  String get loginErrCodeMismatch =>
      'That code didn\'t match — check it and try again.';

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
  String get approveBadCode => 'That\'s not a Steam sign-in QR code.';

  @override
  String get approveLocation => 'Location';

  @override
  String get approveDevice => 'Device';

  @override
  String get approveWarnStranger =>
      'Didn\'t start this sign-in yourself? Reject it.';

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
  String get importSessionDeadTitle => 'Activate this account?';

  @override
  String get importSessionDeadBody =>
      'The Steam session in this maFile has expired. Sign in now to enable confirmations and login approvals — the Steam Guard code will be filled in automatically.';

  @override
  String get importSessionLater => 'Later';

  @override
  String get importSessionLoginNow => 'Sign in now';

  @override
  String get actionExport => 'Export maFile';

  @override
  String get actionLoginRequests => 'Sign-in requests';

  @override
  String get loginRequestTitle => 'Approve sign-in?';

  @override
  String loginRequestBody(String device, String location) {
    return '$device is signing in to your Steam account from $location.';
  }

  @override
  String get loginRequestApprove => 'Allow';

  @override
  String get loginRequestDeny => 'Deny';

  @override
  String get loginNoPending => 'No pending sign-in requests.';

  @override
  String get loginNeedSession =>
      'Sign in to refresh this account\'s session first.';

  @override
  String get loginApproved => 'Sign-in allowed.';

  @override
  String get loginDenied => 'Sign-in denied.';

  @override
  String exportFailed(String error) {
    return 'Failed to export: $error';
  }

  @override
  String get exportWarnTitle => 'Export unencrypted maFile?';

  @override
  String get exportWarnBody =>
      'The exported .maFile is NOT encrypted. It holds this account’s Steam Guard secrets and revocation code — anyone with the file can take over your authenticator. Store it somewhere safe and delete it when done.';

  @override
  String get exportIncludePassword =>
      'Also include the saved Steam password (not recommended)';

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
  String get addPresentTitle => 'This account already has an authenticator';

  @override
  String get addPresentIntro =>
      'Steam allows only one mobile authenticator per account. Remove the existing one, then tap Retry.';

  @override
  String get addPresentStep1 =>
      'Still have the old phone or Steam app? Open it → Steam Guard → Remove Authenticator.';

  @override
  String get addPresentStep2 =>
      'Have your revocation code (Rxxxxx)? Open the page below and choose “Remove Authenticator”.';

  @override
  String get addPresentStep3 =>
      'Lost access to both? Use Steam Support → Help → Steam Guard Mobile Authenticator.';

  @override
  String get addPresentManageUrl => 'store.steampowered.com/twofactor/manage';

  @override
  String get addPresentCopiedUrl => 'Link copied';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonCopy => 'Copy link';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonExport => 'Export';

  @override
  String get commonDelete => 'Delete';

  @override
  String get settingsEncryption => 'Encryption';

  @override
  String get settingsEncryptionDesc =>
      'Your local maFiles are encrypted with a random 256-bit key (AES-256-GCM) held in the device Keystore; your 6-digit PIN unlocks it.';

  @override
  String get settingsThemeDesc => 'Switch the whole UI style.';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsAppearanceDesc =>
      'Light or dark for the standard look. A skin overrides this while active.';

  @override
  String get settingsSkin => 'Skins';

  @override
  String get settingsSkinDesc =>
      'Full-styled looks with their own fonts and effects.';

  @override
  String get themeSystem => 'System';

  @override
  String get skinNone => 'None';

  @override
  String get settingsChange => 'Change';

  @override
  String get settingsSetPasskey => 'Set / change encryption passkey';

  @override
  String get settingsAutoConfirmMarket => 'Auto-confirm market transactions';

  @override
  String get settingsAutoConfirmMarketDesc =>
      'Pre-ticks the confirm box when you list an item, so a new listing is confirmed right after it\'s created. It never confirms anything in the background.';

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
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get settingsAbout => 'About';

  @override
  String get aboutTagline =>
      'An open-source Steam Guard authenticator, rewritten in Flutter.';

  @override
  String get aboutSourceCode => 'Source code';

  @override
  String get aboutAuthor => 'Author';

  @override
  String get aboutLicense => 'License';

  @override
  String get aboutPrivacy => 'Privacy policy';

  @override
  String get privacyConsentTitle => 'Your privacy';

  @override
  String get privacyConsentBody =>
      'AVA keeps all of your data on this device. It has no backend of its own, connects only to Valve\'s Steam servers, and does no tracking or analytics. By continuing, you accept the Privacy Policy.';

  @override
  String get privacyConsentRead => 'Read the full Privacy Policy';

  @override
  String get privacyConsentAgree => 'Agree & continue';

  @override
  String get privacyConsentExit => 'Exit';

  @override
  String get actionMarket => 'Inventory / Market';

  @override
  String get marketTabInventory => 'Inventory';

  @override
  String get marketTabListings => 'My listings';

  @override
  String get marketSelectGame => 'Select a game';

  @override
  String get marketNoItems => 'No items in this inventory.';

  @override
  String get marketNotMarketable => 'Not marketable';

  @override
  String get marketSellTitle => 'List for sale';

  @override
  String get marketYouReceive => 'You receive';

  @override
  String get marketBuyerPays => 'Buyer pays';

  @override
  String get marketLowest => 'Lowest';

  @override
  String get marketMedian => 'Median';

  @override
  String get marketHigh => 'High';

  @override
  String get marketLow => 'Low';

  @override
  String get marketPriceUnavailable => 'Market price unavailable';

  @override
  String get marketListButton => 'List for sale';

  @override
  String get marketListed => 'Listed — confirm it to finish.';

  @override
  String get marketListedDone => 'Listed and confirmed.';

  @override
  String get marketAutoConfirm => 'Auto-confirm the listing';

  @override
  String get marketQuantity => 'Quantity';

  @override
  String get marketMax => 'Max';

  @override
  String marketListFailed(String error) {
    return 'Listing failed: $error';
  }

  @override
  String get marketCancel => 'Cancel listing';

  @override
  String get marketCancelled => 'Listing cancelled.';

  @override
  String get marketNoListings => 'No active listings.';

  @override
  String get marketFeeNote =>
      'Steam + game fees are added on top of what you receive.';

  @override
  String get aboutLicenses => 'Open-source licenses';

  @override
  String get aboutCredits => 'Credits';

  @override
  String get aboutCreditsBody =>
      'Inspired by Steam Desktop Authenticator and compatible with its maFile format. Independently built with Flutter, Riverpod, Dio, PointyCastle, mobile_scanner, image and other open-source libraries.';

  @override
  String get actionLogin => 'Log in / refresh session';

  @override
  String get actionConfirmations => 'Pending';

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
