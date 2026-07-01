import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'AVA'**
  String get appTitle;

  /// No description provided for @navAccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get navAccounts;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @unlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlockTitle;

  /// No description provided for @unlockPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter your encryption passkey'**
  String get unlockPrompt;

  /// No description provided for @unlockButton.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlockButton;

  /// No description provided for @unlockInvalid.
  ///
  /// In en, this message translates to:
  /// **'That passkey is invalid.'**
  String get unlockInvalid;

  /// No description provided for @unlockWithBiometric.
  ///
  /// In en, this message translates to:
  /// **'Unlock with biometrics / device PIN'**
  String get unlockWithBiometric;

  /// No description provided for @pinSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set unlock PIN'**
  String get pinSetupTitle;

  /// No description provided for @pinSetupPrompt.
  ///
  /// In en, this message translates to:
  /// **'Protect AVA with a 6-digit PIN. You\'ll enter it (or your fingerprint) to unlock.'**
  String get pinSetupPrompt;

  /// No description provided for @pinLabel.
  ///
  /// In en, this message translates to:
  /// **'6-digit PIN'**
  String get pinLabel;

  /// No description provided for @pinConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm PIN'**
  String get pinConfirmLabel;

  /// No description provided for @pinSetButton.
  ///
  /// In en, this message translates to:
  /// **'Set PIN'**
  String get pinSetButton;

  /// No description provided for @settingsSet.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get settingsSet;

  /// No description provided for @pinChangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get pinChangeTitle;

  /// No description provided for @pinCurrentLabel.
  ///
  /// In en, this message translates to:
  /// **'Current PIN'**
  String get pinCurrentLabel;

  /// No description provided for @pinNewLabel.
  ///
  /// In en, this message translates to:
  /// **'New PIN'**
  String get pinNewLabel;

  /// No description provided for @pinSixDigits.
  ///
  /// In en, this message translates to:
  /// **'Enter a 6-digit PIN.'**
  String get pinSixDigits;

  /// No description provided for @pinMismatch.
  ///
  /// In en, this message translates to:
  /// **'The PINs don\'t match.'**
  String get pinMismatch;

  /// No description provided for @unlockBiometricReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock AVA'**
  String get unlockBiometricReason;

  /// No description provided for @settingsBiometric.
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock'**
  String get settingsBiometric;

  /// No description provided for @settingsBiometricDesc.
  ///
  /// In en, this message translates to:
  /// **'Unlock with your fingerprint or device PIN; the passkey is stored in the device keystore.'**
  String get settingsBiometricDesc;

  /// No description provided for @settingsBiometricNeedPasskey.
  ///
  /// In en, this message translates to:
  /// **'Set an encryption passkey first.'**
  String get settingsBiometricNeedPasskey;

  /// No description provided for @settingsBiometricUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No biometrics or device lock set up on this device.'**
  String get settingsBiometricUnavailable;

  /// No description provided for @settingsBiometricEnabled.
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock enabled.'**
  String get settingsBiometricEnabled;

  /// No description provided for @passkeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Passkey'**
  String get passkeyLabel;

  /// No description provided for @accountsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No accounts yet. Import a maFile or log in to add one.'**
  String get accountsEmpty;

  /// No description provided for @accountReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get accountReady;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to AVA'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your authenticator is stored encrypted on this device. Choose how to begin.'**
  String get welcomeSubtitle;

  /// No description provided for @welcomeLoginCta.
  ///
  /// In en, this message translates to:
  /// **'Log in to Steam'**
  String get welcomeLoginCta;

  /// No description provided for @welcomeLoginSub.
  ///
  /// In en, this message translates to:
  /// **'Set up a new authenticator'**
  String get welcomeLoginSub;

  /// No description provided for @welcomeImportCta.
  ///
  /// In en, this message translates to:
  /// **'Import .maFile'**
  String get welcomeImportCta;

  /// No description provided for @welcomeImportSub.
  ///
  /// In en, this message translates to:
  /// **'Migrate an existing account'**
  String get welcomeImportSub;

  /// No description provided for @copyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get copyCode;

  /// No description provided for @codeCopied.
  ///
  /// In en, this message translates to:
  /// **'Login code copied to clipboard'**
  String get codeCopied;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copied;

  /// No description provided for @copySteamId.
  ///
  /// In en, this message translates to:
  /// **'Copy SteamID'**
  String get copySteamId;

  /// No description provided for @confirmationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirmations'**
  String get confirmationsTitle;

  /// No description provided for @confirmationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No pending confirmations.'**
  String get confirmationsEmpty;

  /// No description provided for @confirmationsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get confirmationsRefresh;

  /// No description provided for @confAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get confAccept;

  /// No description provided for @confDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get confDecline;

  /// No description provided for @confSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get confSelectAll;

  /// No description provided for @confAcceptSelected.
  ///
  /// In en, this message translates to:
  /// **'Accept selected'**
  String get confAcceptSelected;

  /// No description provided for @confDeclineSelected.
  ///
  /// In en, this message translates to:
  /// **'Decline selected'**
  String get confDeclineSelected;

  /// No description provided for @confAcceptAll.
  ///
  /// In en, this message translates to:
  /// **'Accept all'**
  String get confAcceptAll;

  /// No description provided for @confRejectAll.
  ///
  /// In en, this message translates to:
  /// **'Reject all'**
  String get confRejectAll;

  /// No description provided for @confPending.
  ///
  /// In en, this message translates to:
  /// **'{count} pending'**
  String confPending(int count);

  /// No description provided for @confAllProcessed.
  ///
  /// In en, this message translates to:
  /// **'All processed'**
  String get confAllProcessed;

  /// No description provided for @confTypeTrade.
  ///
  /// In en, this message translates to:
  /// **'Trade'**
  String get confTypeTrade;

  /// No description provided for @confTypeMarket.
  ///
  /// In en, this message translates to:
  /// **'Market listing'**
  String get confTypeMarket;

  /// No description provided for @confTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Confirmation'**
  String get confTypeOther;

  /// No description provided for @confProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing {count} confirmation(s)…'**
  String confProcessing(int count);

  /// No description provided for @confResult.
  ///
  /// In en, this message translates to:
  /// **'{ok} succeeded, {fail} failed'**
  String confResult(int ok, int fail);

  /// No description provided for @confNeedsLogin.
  ///
  /// In en, this message translates to:
  /// **'Session expired — sign in again to refresh this account.'**
  String get confNeedsLogin;

  /// No description provided for @loginOrApprove.
  ///
  /// In en, this message translates to:
  /// **'…or just tap “Allow” in your Steam mobile app.'**
  String get loginOrApprove;

  /// No description provided for @addErrPresent.
  ///
  /// In en, this message translates to:
  /// **'This account already has an authenticator.'**
  String get addErrPresent;

  /// No description provided for @addErrConfirmEmail.
  ///
  /// In en, this message translates to:
  /// **'Please confirm the email Steam sent, then retry.'**
  String get addErrConfirmEmail;

  /// No description provided for @addErrLocked.
  ///
  /// In en, this message translates to:
  /// **'This account is locked/restricted by Steam — recover it at help.steampowered.com before adding an authenticator.'**
  String get addErrLocked;

  /// No description provided for @addErrRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a while and try again.'**
  String get addErrRateLimited;

  /// No description provided for @addErrFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add authenticator.'**
  String get addErrFailed;

  /// No description provided for @addErrBadSms.
  ///
  /// In en, this message translates to:
  /// **'Wrong SMS code, please try again.'**
  String get addErrBadSms;

  /// No description provided for @debugLog.
  ///
  /// In en, this message translates to:
  /// **'Debug log'**
  String get debugLog;

  /// No description provided for @debugLogDesc.
  ///
  /// In en, this message translates to:
  /// **'Network trace for diagnosing login / confirmations'**
  String get debugLogDesc;

  /// No description provided for @debugCopyAll.
  ///
  /// In en, this message translates to:
  /// **'Copy all'**
  String get debugCopyAll;

  /// No description provided for @debugCopied.
  ///
  /// In en, this message translates to:
  /// **'Log copied'**
  String get debugCopied;

  /// No description provided for @debugEmpty.
  ///
  /// In en, this message translates to:
  /// **'No log yet.'**
  String get debugEmpty;

  /// No description provided for @commonOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get commonOpen;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @addErrFinalize.
  ///
  /// In en, this message translates to:
  /// **'Finalize failed: {detail}'**
  String addErrFinalize(String detail);

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Log in to Steam'**
  String get loginTitle;

  /// No description provided for @loginUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get loginUsername;

  /// No description provided for @loginPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPassword;

  /// No description provided for @loginSavePassword.
  ///
  /// In en, this message translates to:
  /// **'Save password'**
  String get loginSavePassword;

  /// No description provided for @loginSavePasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Kept in this account\'s maFile for automatic session refresh; an unencrypted export will contain it.'**
  String get loginSavePasswordHint;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get loginButton;

  /// No description provided for @loginViaQr.
  ///
  /// In en, this message translates to:
  /// **'Log in with QR code'**
  String get loginViaQr;

  /// No description provided for @loginViaCredentials.
  ///
  /// In en, this message translates to:
  /// **'Log in with password'**
  String get loginViaCredentials;

  /// No description provided for @loginScanWithApp.
  ///
  /// In en, this message translates to:
  /// **'Scan this code with the Steam mobile app'**
  String get loginScanWithApp;

  /// No description provided for @loginNeedGuardCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the Steam Guard code'**
  String get loginNeedGuardCode;

  /// No description provided for @loginNeedEmailCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the code sent to your email'**
  String get loginNeedEmailCode;

  /// No description provided for @loginSubmitCode.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get loginSubmitCode;

  /// No description provided for @loginWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for confirmation…'**
  String get loginWaiting;

  /// No description provided for @loginStepCredentials.
  ///
  /// In en, this message translates to:
  /// **'Credentials'**
  String get loginStepCredentials;

  /// No description provided for @loginStepConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get loginStepConfirm;

  /// No description provided for @loginStepDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get loginStepDone;

  /// No description provided for @loginWaitingDesc.
  ///
  /// In en, this message translates to:
  /// **'Approve this sign in on the Steam mobile app. You can also use an email code or QR sign-in.'**
  String get loginWaitingDesc;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed: {error}'**
  String loginFailed(String error);

  /// No description provided for @approveTitle.
  ///
  /// In en, this message translates to:
  /// **'Approve sign in'**
  String get approveTitle;

  /// No description provided for @approveScanPrompt.
  ///
  /// In en, this message translates to:
  /// **'Scan the QR code shown on the device you want to sign in.'**
  String get approveScanPrompt;

  /// No description provided for @approvePastePrompt.
  ///
  /// In en, this message translates to:
  /// **'Or paste the QR code link here'**
  String get approvePastePrompt;

  /// No description provided for @approveButton.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approveButton;

  /// No description provided for @approveReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get approveReject;

  /// No description provided for @approveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Sign in approved.'**
  String get approveSuccess;

  /// No description provided for @approveRejected.
  ///
  /// In en, this message translates to:
  /// **'Sign in rejected.'**
  String get approveRejected;

  /// No description provided for @importTitle.
  ///
  /// In en, this message translates to:
  /// **'Import account'**
  String get importTitle;

  /// No description provided for @importPickFile.
  ///
  /// In en, this message translates to:
  /// **'Choose a .maFile'**
  String get importPickFile;

  /// No description provided for @importSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account imported.'**
  String get importSuccess;

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to import: {error}'**
  String importFailed(String error);

  /// No description provided for @actionExport.
  ///
  /// In en, this message translates to:
  /// **'Export maFile'**
  String get actionExport;

  /// No description provided for @actionLoginRequests.
  ///
  /// In en, this message translates to:
  /// **'Sign-in requests'**
  String get actionLoginRequests;

  /// No description provided for @loginRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Approve sign-in?'**
  String get loginRequestTitle;

  /// No description provided for @loginRequestBody.
  ///
  /// In en, this message translates to:
  /// **'{device} is signing in to your Steam account from {location}.'**
  String loginRequestBody(String device, String location);

  /// No description provided for @loginRequestApprove.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get loginRequestApprove;

  /// No description provided for @loginRequestDeny.
  ///
  /// In en, this message translates to:
  /// **'Deny'**
  String get loginRequestDeny;

  /// No description provided for @loginNoPending.
  ///
  /// In en, this message translates to:
  /// **'No pending sign-in requests.'**
  String get loginNoPending;

  /// No description provided for @loginNeedSession.
  ///
  /// In en, this message translates to:
  /// **'Sign in to refresh this account\'s session first.'**
  String get loginNeedSession;

  /// No description provided for @loginApproved.
  ///
  /// In en, this message translates to:
  /// **'Sign-in allowed.'**
  String get loginApproved;

  /// No description provided for @loginDenied.
  ///
  /// In en, this message translates to:
  /// **'Sign-in denied.'**
  String get loginDenied;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to export: {error}'**
  String exportFailed(String error);

  /// No description provided for @addAuthTitle.
  ///
  /// In en, this message translates to:
  /// **'Add authenticator'**
  String get addAuthTitle;

  /// No description provided for @addAuthPhonePrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number (with country code)'**
  String get addAuthPhonePrompt;

  /// No description provided for @addAuthSmsPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter the SMS code sent to your phone'**
  String get addAuthSmsPrompt;

  /// No description provided for @addAuthEmailPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter the activation code Steam emailed you'**
  String get addAuthEmailPrompt;

  /// No description provided for @addAuthRevocationWarn.
  ///
  /// In en, this message translates to:
  /// **'Write down your revocation code: {code}'**
  String addAuthRevocationWarn(String code);

  /// No description provided for @addAuthConfirmRevocation.
  ///
  /// In en, this message translates to:
  /// **'Re-enter your revocation code to confirm you saved it'**
  String get addAuthConfirmRevocation;

  /// No description provided for @addAuthLinked.
  ///
  /// In en, this message translates to:
  /// **'Authenticator linked successfully.'**
  String get addAuthLinked;

  /// No description provided for @addAuthStepPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get addAuthStepPhone;

  /// No description provided for @addAuthStepSms.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get addAuthStepSms;

  /// No description provided for @addAuthStepRevocation.
  ///
  /// In en, this message translates to:
  /// **'Revocation'**
  String get addAuthStepRevocation;

  /// No description provided for @addPresentTitle.
  ///
  /// In en, this message translates to:
  /// **'This account already has an authenticator'**
  String get addPresentTitle;

  /// No description provided for @addPresentIntro.
  ///
  /// In en, this message translates to:
  /// **'Steam allows only one mobile authenticator per account. Remove the existing one, then tap Retry.'**
  String get addPresentIntro;

  /// No description provided for @addPresentStep1.
  ///
  /// In en, this message translates to:
  /// **'Still have the old phone or Steam app? Open it → Steam Guard → Remove Authenticator.'**
  String get addPresentStep1;

  /// No description provided for @addPresentStep2.
  ///
  /// In en, this message translates to:
  /// **'Have your revocation code (Rxxxxx)? Open the page below and choose “Remove Authenticator”.'**
  String get addPresentStep2;

  /// No description provided for @addPresentStep3.
  ///
  /// In en, this message translates to:
  /// **'Lost access to both? Use Steam Support → Help → Steam Guard Mobile Authenticator.'**
  String get addPresentStep3;

  /// No description provided for @addPresentManageUrl.
  ///
  /// In en, this message translates to:
  /// **'store.steampowered.com/twofactor/manage'**
  String get addPresentManageUrl;

  /// No description provided for @addPresentCopiedUrl.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get addPresentCopiedUrl;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get commonCopy;

  /// No description provided for @commonRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// No description provided for @commonExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get commonExport;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @settingsEncryption.
  ///
  /// In en, this message translates to:
  /// **'Encryption'**
  String get settingsEncryption;

  /// No description provided for @settingsEncryptionDesc.
  ///
  /// In en, this message translates to:
  /// **'Your local maFiles are encrypted (AES-256-CBC) with your 6-digit unlock PIN.'**
  String get settingsEncryptionDesc;

  /// No description provided for @settingsThemeDesc.
  ///
  /// In en, this message translates to:
  /// **'Switch the whole UI between Neon and Pixel.'**
  String get settingsThemeDesc;

  /// No description provided for @settingsChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get settingsChange;

  /// No description provided for @settingsSetPasskey.
  ///
  /// In en, this message translates to:
  /// **'Set / change encryption passkey'**
  String get settingsSetPasskey;

  /// No description provided for @settingsPeriodicChecking.
  ///
  /// In en, this message translates to:
  /// **'Periodically check for confirmations'**
  String get settingsPeriodicChecking;

  /// No description provided for @settingsCheckInterval.
  ///
  /// In en, this message translates to:
  /// **'Check interval (seconds)'**
  String get settingsCheckInterval;

  /// No description provided for @settingsCheckAll.
  ///
  /// In en, this message translates to:
  /// **'Check all accounts'**
  String get settingsCheckAll;

  /// No description provided for @settingsAutoConfirmMarket.
  ///
  /// In en, this message translates to:
  /// **'Auto-confirm market transactions'**
  String get settingsAutoConfirmMarket;

  /// No description provided for @settingsAutoConfirmTrades.
  ///
  /// In en, this message translates to:
  /// **'Auto-confirm trades'**
  String get settingsAutoConfirmTrades;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @themeNeon.
  ///
  /// In en, this message translates to:
  /// **'Neon'**
  String get themeNeon;

  /// No description provided for @themePixel.
  ///
  /// In en, this message translates to:
  /// **'Pixel'**
  String get themePixel;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @aboutTagline.
  ///
  /// In en, this message translates to:
  /// **'An open-source Steam Guard authenticator, rewritten in Flutter.'**
  String get aboutTagline;

  /// No description provided for @aboutSourceCode.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get aboutSourceCode;

  /// No description provided for @aboutAuthor.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get aboutAuthor;

  /// No description provided for @aboutLicense.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get aboutLicense;

  /// No description provided for @aboutPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get aboutPrivacy;

  /// No description provided for @privacyConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Your privacy'**
  String get privacyConsentTitle;

  /// No description provided for @privacyConsentBody.
  ///
  /// In en, this message translates to:
  /// **'AVA keeps all of your data on this device. It has no backend of its own, connects only to Valve\'s Steam servers, and does no tracking or analytics. By continuing, you accept the Privacy Policy.'**
  String get privacyConsentBody;

  /// No description provided for @privacyConsentRead.
  ///
  /// In en, this message translates to:
  /// **'Read the full Privacy Policy'**
  String get privacyConsentRead;

  /// No description provided for @privacyConsentAgree.
  ///
  /// In en, this message translates to:
  /// **'Agree & continue'**
  String get privacyConsentAgree;

  /// No description provided for @privacyConsentExit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get privacyConsentExit;

  /// No description provided for @actionMarket.
  ///
  /// In en, this message translates to:
  /// **'Inventory / Market'**
  String get actionMarket;

  /// No description provided for @marketTabInventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get marketTabInventory;

  /// No description provided for @marketTabListings.
  ///
  /// In en, this message translates to:
  /// **'My listings'**
  String get marketTabListings;

  /// No description provided for @marketSelectGame.
  ///
  /// In en, this message translates to:
  /// **'Select a game'**
  String get marketSelectGame;

  /// No description provided for @marketNoItems.
  ///
  /// In en, this message translates to:
  /// **'No items in this inventory.'**
  String get marketNoItems;

  /// No description provided for @marketNotMarketable.
  ///
  /// In en, this message translates to:
  /// **'Not marketable'**
  String get marketNotMarketable;

  /// No description provided for @marketSellTitle.
  ///
  /// In en, this message translates to:
  /// **'List for sale'**
  String get marketSellTitle;

  /// No description provided for @marketYouReceive.
  ///
  /// In en, this message translates to:
  /// **'You receive'**
  String get marketYouReceive;

  /// No description provided for @marketBuyerPays.
  ///
  /// In en, this message translates to:
  /// **'Buyer pays'**
  String get marketBuyerPays;

  /// No description provided for @marketLowest.
  ///
  /// In en, this message translates to:
  /// **'Lowest'**
  String get marketLowest;

  /// No description provided for @marketMedian.
  ///
  /// In en, this message translates to:
  /// **'Median'**
  String get marketMedian;

  /// No description provided for @marketHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get marketHigh;

  /// No description provided for @marketLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get marketLow;

  /// No description provided for @marketPriceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Market price unavailable'**
  String get marketPriceUnavailable;

  /// No description provided for @marketListButton.
  ///
  /// In en, this message translates to:
  /// **'List for sale'**
  String get marketListButton;

  /// No description provided for @marketListed.
  ///
  /// In en, this message translates to:
  /// **'Listed — confirm it to finish.'**
  String get marketListed;

  /// No description provided for @marketListedDone.
  ///
  /// In en, this message translates to:
  /// **'Listed and confirmed.'**
  String get marketListedDone;

  /// No description provided for @marketAutoConfirm.
  ///
  /// In en, this message translates to:
  /// **'Auto-confirm the listing'**
  String get marketAutoConfirm;

  /// No description provided for @marketQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get marketQuantity;

  /// No description provided for @marketMax.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get marketMax;

  /// No description provided for @marketListFailed.
  ///
  /// In en, this message translates to:
  /// **'Listing failed: {error}'**
  String marketListFailed(String error);

  /// No description provided for @marketCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel listing'**
  String get marketCancel;

  /// No description provided for @marketCancelled.
  ///
  /// In en, this message translates to:
  /// **'Listing cancelled.'**
  String get marketCancelled;

  /// No description provided for @marketNoListings.
  ///
  /// In en, this message translates to:
  /// **'No active listings.'**
  String get marketNoListings;

  /// No description provided for @marketFeeNote.
  ///
  /// In en, this message translates to:
  /// **'Steam + game fees are added on top of what you receive.'**
  String get marketFeeNote;

  /// No description provided for @aboutLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get aboutLicenses;

  /// No description provided for @aboutCredits.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get aboutCredits;

  /// No description provided for @aboutCreditsBody.
  ///
  /// In en, this message translates to:
  /// **'Inspired by Steam Desktop Authenticator and compatible with its maFile format. Independently built with Flutter, Riverpod, Dio, PointyCastle, mobile_scanner, image and other open-source libraries.'**
  String get aboutCreditsBody;

  /// No description provided for @actionLogin.
  ///
  /// In en, this message translates to:
  /// **'Log in / refresh session'**
  String get actionLogin;

  /// No description provided for @actionConfirmations.
  ///
  /// In en, this message translates to:
  /// **'Trade confirmations'**
  String get actionConfirmations;

  /// No description provided for @actionRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove account'**
  String get actionRemove;

  /// No description provided for @actionImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get actionImport;

  /// No description provided for @actionAddAuthenticator.
  ///
  /// In en, this message translates to:
  /// **'Add authenticator'**
  String get actionAddAuthenticator;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get commonError;

  /// No description provided for @sessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your Steam session has expired. Please log in again.'**
  String get sessionExpired;

  /// No description provided for @removeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove this account from this device? Make sure you have your maFile backed up.'**
  String get removeConfirm;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
