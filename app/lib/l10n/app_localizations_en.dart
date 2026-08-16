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
  String get storeErrorTitle => 'Stored data can\'t be read';

  @override
  String get storeErrorBody =>
      'AVA\'s local account database (manifest.json) is missing or corrupt. This can happen after an interrupted write or a partial restore. Retry first; if it keeps failing, reset and re-import your maFile backups.';

  @override
  String get storeRepair => 'Attempt repair';

  @override
  String storeActionFailed(String error) {
    return 'Action failed: $error';
  }

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
  String get settingsBlockScreenshots => 'Block screenshots';

  @override
  String get settingsBlockScreenshotsDesc =>
      'Hides AVA from screenshots, screen recording and the recent-apps preview. Also blanks the window during screen sharing, and stops you attaching screenshots to feedback.';

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
  String get welcomeSyncCta => 'Restore from sync';

  @override
  String get welcomeSyncSub =>
      'Pull your accounts from an existing sync library';

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
  String get pendingTabInvites => 'Invites';

  @override
  String famInviteTitle(String groupName) {
    return '「$groupName」 invited you to join';
  }

  @override
  String get famInviteTitleGeneric => 'Family group invite';

  @override
  String famInviteFrom(String inviter) {
    return 'Invited by $inviter';
  }

  @override
  String famInviteRole(String role) {
    return 'Role: $role';
  }

  @override
  String famInviteSlots(int used, int total) {
    return 'Members $used/$total';
  }

  @override
  String get famRoleAdult => 'Adult';

  @override
  String get famRoleChild => 'Child';

  @override
  String famRoleUnknown(int n) {
    return 'Role #$n';
  }

  @override
  String get famPreflightTitle => 'Join checks';

  @override
  String get famCheckWalletMatch => 'Wallet region matches';

  @override
  String get famCheckWalletMismatch =>
      'Wallet region doesn\'t match — Steam restricts joining';

  @override
  String get famCheckIpMatch => 'Usual IP matches';

  @override
  String get famCheckIpMismatch => 'IP doesn\'t match your usual location';

  @override
  String get famCheckCooldown =>
      'Joining locks family-group switching for 1 year (Steam cooldown)';

  @override
  String famJoinRestricted(int code) {
    return 'Steam blocked this join (restriction $code)';
  }

  @override
  String get famInviteJoinHold => 'Hold to join';

  @override
  String get famInviteAwaiting2fa =>
      'Waiting for confirmation — check the Confirmations tab';

  @override
  String get famInviteJoined => 'Joined ✓';

  @override
  String get famInviteViewGroup => 'View family group ›';

  @override
  String get famJoinSent =>
      'Join requested — confirm it in the Confirmations tab';

  @override
  String get famJoinDone => 'Joined the family group.';

  @override
  String famJoinFailed(String msg) {
    return 'Join failed: $msg';
  }

  @override
  String get famInvitesEmpty => 'No pending family invites.';

  @override
  String get famAccountAction => 'Family group';

  @override
  String get famNotInGroup => 'This account isn\'t in a family group.';

  @override
  String famSummaryMembers(int used, int total) {
    return 'Members $used/$total';
  }

  @override
  String famSummaryCooldown(int days) {
    return 'Cooldown ${days}d';
  }

  @override
  String get famInvitesSection => 'Invites';

  @override
  String get famSectionMembers => 'Members';

  @override
  String get famMemberYou => '(you)';

  @override
  String get famSectionPending => 'Pending';

  @override
  String get famPendingComingSoon =>
      'Purchase approval is coming in a future update.';

  @override
  String get deviceSessionsAction => 'Devices';

  @override
  String get deviceSessionsTitle => 'Logged-in devices';

  @override
  String get deviceSessionsEmpty => 'No active devices for this account.';

  @override
  String get deviceRevokeAction => 'Sign out';

  @override
  String deviceRevokeConfirm(String name) {
    return 'Sign \"$name\" out of your Steam account? It will need to log in again.';
  }

  @override
  String deviceRevokeDone(String name) {
    return 'Signed \"$name\" out.';
  }

  @override
  String deviceRevokeFailed(String error) {
    return 'Couldn\'t sign the device out: $error';
  }

  @override
  String get deviceCurrent => '(this device)';

  @override
  String get deviceSignedOut => 'signed out';

  @override
  String get deviceUnnamed => 'Unknown device';

  @override
  String deviceLastSeen(String age) {
    return 'active $age ago';
  }

  @override
  String get devicePlatformSteam => 'Steam client';

  @override
  String get devicePlatformWeb => 'Web browser';

  @override
  String get devicePlatformMobile => 'Mobile app';

  @override
  String get devicePlatformUnknown => 'Unknown';

  @override
  String deviceAgeDays(int n) {
    return '${n}d';
  }

  @override
  String deviceAgeHours(int n) {
    return '${n}h';
  }

  @override
  String deviceAgeMinutes(int n) {
    return '${n}m';
  }

  @override
  String get deviceAgeNow => 'just now';

  @override
  String get keyRedeemAction => 'Redeem key';

  @override
  String get keyRedeemTitle => 'Redeem a Steam key';

  @override
  String keyRedeemFor(String account) {
    return 'Activating on $account';
  }

  @override
  String get keyRedeemHint => 'XXXXX-XXXXX-XXXXX';

  @override
  String get keyRedeemPaste => 'Paste';

  @override
  String get keyRedeemSubmit => 'Redeem';

  @override
  String get keyRedeemNote =>
      'Activation is permanent and adds the product to this account. Steam blocks activations for about an hour after a few rejected keys, so check the code before submitting.';

  @override
  String keyRedeemConfirm(String account) {
    return 'Activate this key on $account? It can\'t be undone or moved to another account afterwards.';
  }

  @override
  String get keyRedeemDone => 'Key activated.';

  @override
  String get keyRedeemGranted => 'Added to the library:';

  @override
  String get keyRedeemNoProducts =>
      'Steam accepted the key but didn\'t name the product. Check the account\'s library.';

  @override
  String get keyRedeemNetworkError =>
      'Couldn\'t reach Steam. If the request timed out, Steam may still have processed it — check the account\'s library before trying the key again.';

  @override
  String get keyErrInvalid =>
      'Steam doesn\'t recognize this code. Check it for typos — letters and digits like 0/O and 1/I are easy to mix up.';

  @override
  String get keyErrAlreadyOwned => 'This account already owns the product.';

  @override
  String get keyErrAlreadyActivated =>
      'This key has already been used — on this account or another one.';

  @override
  String get keyErrRegionLocked =>
      'This product can\'t be activated in the account\'s country.';

  @override
  String get keyErrNeedsBaseProduct =>
      'This is DLC or an expansion; the account needs the base game first.';

  @override
  String get keyErrNeedsPs3Login =>
      'This product has to be played on a PlayStation®3 system before it can be activated.';

  @override
  String get keyErrRateLimited =>
      'Too many rejected keys recently. Steam blocks activations for about an hour — try again later.';

  @override
  String keyErrUnknown(int code) {
    return 'Steam rejected the key (code $code).';
  }

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
  String feedbackRefused(String reason) {
    return 'The relay refused this report: $reason';
  }

  @override
  String feedbackRelayDown(String reason) {
    return 'The feedback service is having trouble on its end ($reason). Your network is fine — please try again later.';
  }

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
  String get importDuplicateTitle => 'Account already exists';

  @override
  String importDuplicateBody(String name) {
    return 'This maFile is for $name, which is already on this device. Overwrite the stored account with the imported file? Its cached avatar, saved password, and existing session are kept when the file doesn\'t include them.';
  }

  @override
  String importDuplicateBodyUnreadable(String name) {
    return 'This maFile is for $name, which exists on this device but its stored data can no longer be read. Importing will replace it entirely.';
  }

  @override
  String get importDuplicateOverwrite => 'Overwrite';

  @override
  String get importSessionDeadTitle => 'Activate this account?';

  @override
  String get importSessionDeadBody =>
      'The Steam session in this maFile has expired. Sign in now to enable confirmations and login approvals — the Steam Guard code will be filled in automatically.';

  @override
  String get importSessionLater => 'Later';

  @override
  String get sdaImportAction => 'Import an SDA folder';

  @override
  String get sdaImportHint =>
      'Select your Steam Desktop Authenticator maFiles folder: pick manifest.json together with the .maFile files. Both are needed — if SDA\'s encryption was on, the decryption parameters live in manifest.json, not in the maFile.';

  @override
  String get sdaImportNoManifest =>
      'No manifest.json in that selection. Select it together with the .maFile files.';

  @override
  String sdaImportBadManifest(String error) {
    return 'That manifest.json can\'t be read: $error';
  }

  @override
  String get sdaImportPassTitle => 'SDA encryption passphrase';

  @override
  String get sdaImportPassBody =>
      'These maFiles are encrypted. Enter the passphrase you set in Steam Desktop Authenticator.';

  @override
  String get sdaImportWrongPass =>
      'That passphrase didn\'t decrypt any of the files.';

  @override
  String sdaImportDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count accounts imported.',
      one: '1 account imported.',
    );
    return '$_temp0';
  }

  @override
  String sdaImportSkipped(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count accounts were skipped: $names',
      one: '1 account was skipped: $names',
    );
    return '$_temp0';
  }

  @override
  String get sdaImportNothing => 'Nothing was imported.';

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
  String get addPresentFallbackTitle => 'Can\'t receive the email?';

  @override
  String get addMoveInButton => 'Move the authenticator to this device';

  @override
  String get addMoveInBlurb =>
      'Steam will email this account a code. No 15-day trade hold.';

  @override
  String get addMoveInSending => 'Sending the code…';

  @override
  String get addMoveInCodePrompt => 'Enter the code Steam emailed you';

  @override
  String get addMoveInWarn =>
      'Once you confirm: the authenticator on your old phone stops working immediately, and your old revocation code (Rxxxxx) is replaced by a new one. This cannot be undone.';

  @override
  String get addMoveInConfirm => 'Move it here';

  @override
  String get addMoveInDone => 'Authenticator moved to this device.';

  @override
  String get addMoveInPopBlocked => 'Moving the authenticator — please wait.';

  @override
  String get addErrBadChallengeCode =>
      'That code isn\'t right. Check the email and try again.';

  @override
  String addMoveInSaveFailed(String code, String secret) {
    return 'The authenticator moved to this account, but AVA could NOT save it to this device. Your old authenticator is already dead, so these are the only copies — write them down NOW before closing this screen.\n\nRevocation code: $code\n\nSecret: $secret';
  }

  @override
  String get addMoveInCopySecrets => 'Copy';

  @override
  String get addMoveInCopied => 'Copied';

  @override
  String get moveInRescueDismiss => 'I saved them — dismiss';

  @override
  String get moveInRescueDismissTitle => 'Discard these secrets?';

  @override
  String get moveInRescueDismissBody =>
      'AVA holds no other copy. If you haven\'t written down the revocation code and secret, you will permanently lose access to this authenticator.';

  @override
  String get moveInRescueDismissConfirm => 'I saved them';

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
  String get settingsTextSize => 'Text size';

  @override
  String get settingsTextSizeDesc => 'Applies on top of the system font size.';

  @override
  String get textSizeSmall => 'Small';

  @override
  String get textSizeMedium => 'Medium';

  @override
  String get textSizeLarge => 'Large';

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
      'An open-source Steam Guard authenticator, built with Flutter.';

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
      'AVA keeps your Steam accounts and secrets on this device — they are never uploaded, unless you set up the optional sync to a server you choose, where everything is encrypted on this device first. There is no account to create. Steam requests go straight to Valve. Two of the developer\'s own services are contacted only when they are needed: Pro entitlement checks, and feedback (only when you press send). The Play version also shows ads on the free tier. There is no tracking or analytics. All of it is spelled out in the Privacy Policy — by continuing, you accept it.';

  @override
  String get privacyUpdateTitle => 'Privacy Policy updated';

  @override
  String get privacyUpdateBody =>
      'The privacy notice has changed since you accepted it. New: AVA can now sync your account library between your devices, through a server you choose — off by default, everything encrypted on this device before upload, and the developer runs no sync server. Please read the current notice below.';

  @override
  String get privacyConsentScrollHint => 'Scroll to the end to continue';

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
  String marketListedPartial(int listed, int total) {
    return 'Listed $listed of $total — the rest failed; confirm any pending in Confirmations.';
  }

  @override
  String marketListedSessionExpired(int listed, int total) {
    return 'Listed $listed of $total, then the session expired — sign in again and confirm them.';
  }

  @override
  String marketConfirmPartial(int ok, int total) {
    return 'Listed — $ok of $total confirmed; finish the rest in Confirmations.';
  }

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
  String get marketInvalidPrice => 'Enter a valid price.';

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

  @override
  String get settingsPro => 'AVA Pro';

  @override
  String get proOpen => 'View AVA Pro';

  @override
  String get proStatusFree => 'Free plan';

  @override
  String proStatusPro(Object date) {
    return 'Pro · until $date';
  }

  @override
  String proStatusVip(Object date) {
    return 'VIP · until $date';
  }

  @override
  String get proStatusLifetime => 'Pro · lifetime';

  @override
  String proStatusActivations(Object classes) {
    return 'Active on: $classes';
  }

  @override
  String proStatusClassThisDevice(Object name) {
    return '$name (this device)';
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
  String get paywallPerksTitle =>
      'Pro perks — core security features stay free forever.';

  @override
  String get paywallPerkSkins => 'Theme packs: Neon & Pixel skins';

  @override
  String get paywallPerkNoAds => 'No banner ads';

  @override
  String get paywallPerkFuture =>
      'Coming later: cloud sync, trade notifications';

  @override
  String get paywallPlayTitle => 'Unlock via Google Play';

  @override
  String get paywallSubscribe => 'Subscribe · \$0.99/mo';

  @override
  String get paywallWatchAd => 'Watch an ad · 3-day VIP';

  @override
  String get paywallRestore => 'Restore purchase';

  @override
  String get paywallCnTitle => 'Unlock via Afdian';

  @override
  String get paywallAfdianIntro =>
      'Sponsor ¥5/month on Afdian, then enter the order number here to unlock.';

  @override
  String get paywallOpenAfdian => 'Open Afdian';

  @override
  String get paywallOrderHint => 'Afdian order number';

  @override
  String get paywallRedeem => 'Unlock';

  @override
  String get paywallBetaTitle => 'Beta thank-you';

  @override
  String get paywallBetaIntro =>
      'Beta testers get lifetime Pro — enter your code.';

  @override
  String get paywallBetaHint => 'Lifetime code';

  @override
  String get paywallBetaRedeem => 'Redeem';

  @override
  String get proResultSuccess => 'Unlocked — thank you!';

  @override
  String get proErrCanceled => 'Canceled.';

  @override
  String get proErrNetwork => 'Network error — try again later.';

  @override
  String get proErrNotConfigured => 'Not available in this build yet.';

  @override
  String get proErrNoSubscription =>
      'No active subscription on your Play Store\'s current account. Subscribed with a different Google account? Switch to it in the Play Store app (top-right avatar), then retry.';

  @override
  String get proErrAlreadyOwned =>
      'Your Play Store\'s current account already holds this subscription — tap Restore purchase instead.';

  @override
  String get proErrOrderBound => 'This order is already bound to another user.';

  @override
  String get proErrOrderNotFound => 'Order not found or plan mismatch.';

  @override
  String get proErrDeviceRevoked =>
      'This device\'s slot was taken by a newer activation.';

  @override
  String get proErrNoVip => 'Reward not confirmed yet — try again in a minute.';

  @override
  String get proErrPurchaseBound =>
      'This subscription is tied to a different Google account. Retry, and in the account chooser pick the one your Play Store uses.';

  @override
  String proErrPurchaseBoundKnown(String account) {
    return 'This subscription is tied to $account. Retry, and pick that account in the chooser.';
  }

  @override
  String proErrGeneric(Object code) {
    return 'Failed: $code';
  }

  @override
  String get proErrCodeInvalid => 'Code not recognized — check it for typos.';

  @override
  String get proErrCodeRedeemed =>
      'This code is already active on another device. To move it here, email hi@dotslash.pro.';

  @override
  String get proErrCodeActivationLimit =>
      'This code has switched devices too often recently. Try again later, or email hi@dotslash.pro.';

  @override
  String get proErrRateLimited =>
      'Too many attempts. Wait a minute and try again.';

  @override
  String proErrSlotOccupied(Object slots) {
    return 'In use: $slots';
  }

  @override
  String proSlotEntry(Object name, Object time) {
    return '$name ($time)';
  }

  @override
  String get proSlotToday => 'today';

  @override
  String proSlotDaysAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get proErrRevoked =>
      'This entitlement is no longer active. If you think this is a mistake, email hi@dotslash.pro.';

  @override
  String get privacyOptions => 'Privacy options';

  @override
  String get skinProNotice =>
      'Neon & Pixel skins are now Pro perks. Your selection is kept and comes back with Pro.';

  @override
  String get skinProNoticeDismiss => 'Got it';

  @override
  String get syncTitle => 'Sync';

  @override
  String get syncSetupTitle => 'Set up sync';

  @override
  String get syncSettingsDesc =>
      'Keep accounts in sync across devices through a server you control. Everything is encrypted before it leaves this device.';

  @override
  String get syncSetUp => 'Set up sync…';

  @override
  String get syncStatusOk => 'Up to date';

  @override
  String get syncStatusSyncing => 'Syncing…';

  @override
  String get syncStatusErrorShort => 'Last sync failed — open for details.';

  @override
  String syncStatusConflicts(int count) {
    return '$count conflict(s) need your decision';
  }

  @override
  String syncLastSync(String time) {
    return 'Last sync: $time';
  }

  @override
  String get syncNever => 'never';

  @override
  String get syncBackendTitle => 'Where should the data live?';

  @override
  String get syncBackendWebdav => 'WebDAV';

  @override
  String get syncBackendWebdavDesc =>
      'Nextcloud, Jianguoyun (坚果云), a NAS — any WebDAV folder you control.';

  @override
  String get syncBackendGdrive => 'Google Drive';

  @override
  String get syncBackendGdriveSoon => 'Pro · coming later';

  @override
  String get syncServerTitle => 'Server';

  @override
  String get syncServerHint =>
      'Jianguoyun needs an app password (安全选项 → 添加应用密码), not your login password. A Nextcloud folder URL looks like https://cloud.example.com/remote.php/dav/files/USER/ava/.';

  @override
  String get syncServerUrlLabel => 'WebDAV folder URL';

  @override
  String get syncServerFolderLabel => 'Folder (optional)';

  @override
  String get syncServerFolderHint =>
      'Leave empty to use the URL as-is; a name places the library in that subfolder, created if missing.';

  @override
  String get syncServerUserLabel => 'Username';

  @override
  String get syncServerPasswordLabel => 'Password / app password';

  @override
  String get syncTestConnection => 'Test connection';

  @override
  String get syncErrUrl => 'Enter a valid http(s) folder URL.';

  @override
  String get syncErrAuth => 'The server rejected the username or password.';

  @override
  String syncErrNetwork(String detail) {
    return 'Could not reach the server: $detail';
  }

  @override
  String syncErrServer(String detail) {
    return 'The server answered with an error: $detail';
  }

  @override
  String get syncErrTls => 'The server\'s certificate is not trusted.';

  @override
  String get syncTlsTitle => 'Unknown server certificate';

  @override
  String syncTlsBody(String fp) {
    return 'This server\'s certificate is not trusted by the system. If it is your own server with a self-signed certificate, compare this fingerprint with the one shown on the server, and only trust it if they match exactly.\n\nSHA-256\n$fp';
  }

  @override
  String get syncTlsTrust => 'Trust this certificate';

  @override
  String get syncHttpPrivateTitle => 'Unencrypted connection';

  @override
  String get syncHttpPrivateBody =>
      'This is a plain-HTTP address on a private network. Your account data itself is encrypted end-to-end, but the server password travels unencrypted on your network.';

  @override
  String get syncHttpPublicTitle => 'Plain HTTP across the internet';

  @override
  String get syncHttpPublicBody =>
      'This address is public and the connection would be unencrypted: anyone between you and the server can read the server password and sign in to your server. The account data itself stays encrypted. Use HTTPS or a LAN address instead — continue only if you accept this risk.';

  @override
  String get syncHttpPublicHold => 'Hold to allow anyway';

  @override
  String get syncContinue => 'Continue';

  @override
  String get syncPassphraseNewTitle => 'Set a sync passphrase';

  @override
  String get syncPassphraseNewBody =>
      'Everything is encrypted with this passphrase before upload; the passphrase itself never leaves your devices.\n\nIf you lose it, the synced data cannot be recovered by anyone — there is no reset. At least 8 characters; length matters more than symbols.';

  @override
  String get syncPassphraseExistingTitle => 'Enter the sync passphrase';

  @override
  String syncPassphraseExistingBody(int count) {
    return 'This folder already holds a sync library with $count account(s). Enter the passphrase it was created with.';
  }

  @override
  String get syncPassphraseLabel => 'Sync passphrase';

  @override
  String get syncPassphraseConfirmLabel => 'Confirm passphrase';

  @override
  String get syncPassphraseTooShort => 'At least 8 characters.';

  @override
  String get syncPassphraseMismatch => 'The passphrases don\'t match.';

  @override
  String get syncPassphraseWrong =>
      'That passphrase doesn\'t open this library.';

  @override
  String get syncPreviewTitle => 'First sync';

  @override
  String get syncPreviewEmpty =>
      'Nothing to transfer yet — accounts will sync automatically from now on.';

  @override
  String syncPreviewPull(int count) {
    return 'Download to this device: $count account(s)';
  }

  @override
  String syncPreviewPush(int count) {
    return 'Upload from this device: $count account(s)';
  }

  @override
  String syncPreviewConflict(int count) {
    return 'On both sides with different content: $count — you\'ll choose per account after connecting';
  }

  @override
  String get syncStart => 'Start syncing';

  @override
  String get syncDoneTitle => 'Sync is on';

  @override
  String get syncDoneBody =>
      'Accounts now sync automatically. On a new device each account signs in again the first time you use it — accounts with a saved password do that by themselves; the others ask once.';

  @override
  String get syncDone => 'Done';

  @override
  String get syncNeedsPassphrase =>
      'The stored passphrase no longer matches the remote library — enter it again.';

  @override
  String get syncEnterPassphrase => 'Enter passphrase';

  @override
  String get syncConditionalWarn =>
      'This server ignores conditional writes, so two devices syncing at the same moment may overwrite each other. Syncing still works; avoid simultaneous changes on two devices.';

  @override
  String get syncConflictsTitle => 'Conflicts';

  @override
  String get syncConflictTrashNote =>
      'Whichever side you discard is kept in the sync trash for 30 days.';

  @override
  String get syncConflictEditEdit => 'Changed on both devices';

  @override
  String get syncConflictEditDelete =>
      'Changed here, deleted on another device';

  @override
  String get syncConflictDeleteEdit =>
      'Deleted here, changed on another device';

  @override
  String get syncConflictKeepLocal => 'Keep this device\'s';

  @override
  String get syncConflictKeepRemote => 'Keep the other\'s';

  @override
  String get syncConflictLocalSide => 'This device';

  @override
  String get syncConflictRemoteSide => 'Other device';

  @override
  String get syncDeleted => 'Deleted';

  @override
  String get syncConflictHasPassword => 'Password saved';

  @override
  String get syncConflictNoPassword => 'No saved password';

  @override
  String get syncAutoTitle => 'Automatic sync';

  @override
  String get syncAutoDesc =>
      'Sync at launch and after every change. Off means only the button below syncs.';

  @override
  String get syncPasswordsTitle => 'Sync account passwords';

  @override
  String get syncPasswordsDesc =>
      'Passwords let a new device sign in by itself. Changing this re-uploads every account.';

  @override
  String get syncAppSettingsTitle => 'Sync app settings';

  @override
  String get syncAppSettingsDesc =>
      'Appearance and behavior preferences (skin, theme, hold-to-confirm…) follow you to every device. Language and text size stay per-device.';

  @override
  String get syncNowButton => 'Sync now';

  @override
  String get syncViewRemote => 'View remote library';

  @override
  String get syncRemoteEmpty => 'The remote library is empty.';

  @override
  String get syncRemoteDevices => 'Devices';

  @override
  String get syncTrashTitle => 'Sync trash';

  @override
  String get syncTrashEmpty =>
      'Empty. Anything sync removes or replaces is kept here for 30 days.';

  @override
  String get syncTrashRestore => 'Restore';

  @override
  String get syncTrashRestored => 'Account restored.';

  @override
  String get syncTrashRestoreFailed =>
      'This entry can\'t be decrypted with the current passphrase.';

  @override
  String get syncTrashReasonRemoteDelete => 'deleted by another device';

  @override
  String get syncTrashReasonConflict => 'replaced in a conflict';

  @override
  String get syncChangePassphrase => 'Change sync passphrase';

  @override
  String get syncPassphraseChanged =>
      'Passphrase changed; everything re-encrypted. Other devices will ask for the new passphrase.';

  @override
  String syncPassphraseChangeFailed(String reason) {
    return 'Passphrase not changed: $reason';
  }

  @override
  String get syncDisconnect => 'Disconnect sync';

  @override
  String get syncDisconnectBody =>
      'This device stops syncing. The remote library can stay for your other devices — or be deleted from the server entirely.';

  @override
  String get syncDisconnectKeep => 'Keep remote data';

  @override
  String get syncDisconnectDeleteHold => 'Hold to delete remote data';
}
