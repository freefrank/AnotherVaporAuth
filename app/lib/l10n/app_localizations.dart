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
  /// **'Steam Desktop Authenticator'**
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

  /// No description provided for @settingsEncryption.
  ///
  /// In en, this message translates to:
  /// **'Encryption'**
  String get settingsEncryption;

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
