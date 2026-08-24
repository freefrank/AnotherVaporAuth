import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ru.dart';
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
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('ru'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
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

  /// No description provided for @unlockLoading.
  ///
  /// In en, this message translates to:
  /// **'Decrypting…'**
  String get unlockLoading;

  /// No description provided for @unlockCantUnlock.
  ///
  /// In en, this message translates to:
  /// **'Can\'t unlock?'**
  String get unlockCantUnlock;

  /// No description provided for @resetVaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset encrypted data'**
  String get resetVaultTitle;

  /// No description provided for @resetVaultBody.
  ///
  /// In en, this message translates to:
  /// **'This deletes every account entry and encryption key stored on this device; afterwards you re-import your maFile backups. Your Steam accounts and their authenticators are not affected.\n\nUse this when the correct PIN keeps being rejected — typically after a backup restore or phone migration, since the hardware key never leaves the original device, restored data can never be decrypted.\n\nThis cannot be undone.'**
  String get resetVaultBody;

  /// No description provided for @resetVaultConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete & reset'**
  String get resetVaultConfirm;

  /// No description provided for @storeErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Stored data can\'t be read'**
  String get storeErrorTitle;

  /// No description provided for @storeErrorBody.
  ///
  /// In en, this message translates to:
  /// **'AVA\'s local account database (manifest.json) is missing or corrupt. This can happen after an interrupted write or a partial restore. Retry first; if it keeps failing, reset and re-import your maFile backups.'**
  String get storeErrorBody;

  /// No description provided for @storeRepair.
  ///
  /// In en, this message translates to:
  /// **'Attempt repair'**
  String get storeRepair;

  /// No description provided for @storeActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Action failed: {error}'**
  String storeActionFailed(String error);

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

  /// No description provided for @settingsHoldConfirm.
  ///
  /// In en, this message translates to:
  /// **'Hold to confirm'**
  String get settingsHoldConfirm;

  /// No description provided for @settingsHoldConfirmDesc.
  ///
  /// In en, this message translates to:
  /// **'Irreversible accepts (trades, confirmations) require press-and-hold. When off, a single tap acts immediately; batch actions still ask first.'**
  String get settingsHoldConfirmDesc;

  /// No description provided for @settingsHaptics.
  ///
  /// In en, this message translates to:
  /// **'Haptic feedback'**
  String get settingsHaptics;

  /// No description provided for @settingsHapticsDesc.
  ///
  /// In en, this message translates to:
  /// **'Vibration ticks while holding to confirm and on completion.'**
  String get settingsHapticsDesc;

  /// No description provided for @settingsBlockScreenshots.
  ///
  /// In en, this message translates to:
  /// **'Block screenshots'**
  String get settingsBlockScreenshots;

  /// No description provided for @settingsBlockScreenshotsDesc.
  ///
  /// In en, this message translates to:
  /// **'Hides AVA from screenshots, screen recording and the recent-apps preview. Also blanks the window during screen sharing, and stops you attaching screenshots to feedback.'**
  String get settingsBlockScreenshotsDesc;

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

  /// No description provided for @emptyAddAccount.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get emptyAddAccount;

  /// No description provided for @accountReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get accountReady;

  /// No description provided for @tutCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Live token'**
  String get tutCodeTitle;

  /// No description provided for @tutCodeBody.
  ///
  /// In en, this message translates to:
  /// **'Tap the big code to copy it. Tap the account name to cycle username / nickname / SteamID.'**
  String get tutCodeBody;

  /// No description provided for @tutSwipeRightTitle.
  ///
  /// In en, this message translates to:
  /// **'Swipe right → confirmations'**
  String get tutSwipeRightTitle;

  /// No description provided for @tutSwipeRightBody.
  ///
  /// In en, this message translates to:
  /// **'Swipe an account to the right to open its trade confirmations.'**
  String get tutSwipeRightBody;

  /// No description provided for @tutSwipeLeftTitle.
  ///
  /// In en, this message translates to:
  /// **'Swipe left → more actions'**
  String get tutSwipeLeftTitle;

  /// No description provided for @tutSwipeLeftBody.
  ///
  /// In en, this message translates to:
  /// **'Swipe left to refresh the session, export the maFile, or remove the account.'**
  String get tutSwipeLeftBody;

  /// No description provided for @tutLongPressTitle.
  ///
  /// In en, this message translates to:
  /// **'Long-press → inventory & market'**
  String get tutLongPressTitle;

  /// No description provided for @tutLongPressBody.
  ///
  /// In en, this message translates to:
  /// **'Long-press an account to browse its inventory and list items on the Community Market.'**
  String get tutLongPressBody;

  /// No description provided for @tutPullTitle.
  ///
  /// In en, this message translates to:
  /// **'Pull to refresh'**
  String get tutPullTitle;

  /// No description provided for @tutPullBody.
  ///
  /// In en, this message translates to:
  /// **'Pull the account list down to refresh avatars and check pending sign-ins.'**
  String get tutPullBody;

  /// No description provided for @tutSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get tutSkip;

  /// No description provided for @tutNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get tutNext;

  /// No description provided for @tutDone.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get tutDone;

  /// No description provided for @settingsTutorial.
  ///
  /// In en, this message translates to:
  /// **'Gesture tutorial'**
  String get settingsTutorial;

  /// No description provided for @settingsTutorialDesc.
  ///
  /// In en, this message translates to:
  /// **'Replay the home-screen walkthrough (swipes, long-press, pull-to-refresh).'**
  String get settingsTutorialDesc;

  /// No description provided for @settingsTutorialReplay.
  ///
  /// In en, this message translates to:
  /// **'Replay'**
  String get settingsTutorialReplay;

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

  /// No description provided for @welcomeSyncCta.
  ///
  /// In en, this message translates to:
  /// **'Restore from sync'**
  String get welcomeSyncCta;

  /// No description provided for @welcomeSyncSub.
  ///
  /// In en, this message translates to:
  /// **'Pull your accounts from an existing sync library'**
  String get welcomeSyncSub;

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

  /// No description provided for @pendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pendingTitle;

  /// No description provided for @pendingTabConfirmations.
  ///
  /// In en, this message translates to:
  /// **'Confirmations'**
  String get pendingTabConfirmations;

  /// No description provided for @pendingTabOffers.
  ///
  /// In en, this message translates to:
  /// **'Trade offers'**
  String get pendingTabOffers;

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

  /// No description provided for @confAcceptAllConfirm.
  ///
  /// In en, this message translates to:
  /// **'Accept all {count} confirmations?'**
  String confAcceptAllConfirm(int count);

  /// No description provided for @confRejectAllConfirm.
  ///
  /// In en, this message translates to:
  /// **'Reject all {count} confirmations?'**
  String confRejectAllConfirm(int count);

  /// No description provided for @confAcceptAllWarn.
  ///
  /// In en, this message translates to:
  /// **'This approves every pending trade and market listing at once. Make sure you recognize all of them.'**
  String get confAcceptAllWarn;

  /// No description provided for @confRejectAllWarn.
  ///
  /// In en, this message translates to:
  /// **'This cancels every pending confirmation at once.'**
  String get confRejectAllWarn;

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

  /// No description provided for @confTypeFamilyJoin.
  ///
  /// In en, this message translates to:
  /// **'Family invite'**
  String get confTypeFamilyJoin;

  /// No description provided for @confTypeApiKey.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get confTypeApiKey;

  /// No description provided for @confTypePhoneChange.
  ///
  /// In en, this message translates to:
  /// **'Phone change'**
  String get confTypePhoneChange;

  /// No description provided for @confTypeAccountRecovery.
  ///
  /// In en, this message translates to:
  /// **'Account recovery'**
  String get confTypeAccountRecovery;

  /// No description provided for @confTypeFeatureOptOut.
  ///
  /// In en, this message translates to:
  /// **'Feature opt-out'**
  String get confTypeFeatureOptOut;

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

  /// No description provided for @confRejected.
  ///
  /// In en, this message translates to:
  /// **'Steam rejected the confirmation request. This usually means the maFile does not match the authenticator currently on the account (common with purchased accounts) — remove the authenticator and link it again, or import the right maFile. A large clock drift can also cause this.'**
  String get confRejected;

  /// No description provided for @offersSegReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get offersSegReceived;

  /// No description provided for @offersSegSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get offersSegSent;

  /// No description provided for @offersSegHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get offersSegHistory;

  /// No description provided for @offersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No trade offers.'**
  String get offersEmpty;

  /// No description provided for @offerGift.
  ///
  /// In en, this message translates to:
  /// **'Gift — you give nothing'**
  String get offerGift;

  /// No description provided for @offerOneSided.
  ///
  /// In en, this message translates to:
  /// **'You give items and receive nothing'**
  String get offerOneSided;

  /// No description provided for @offerEscrow.
  ///
  /// In en, this message translates to:
  /// **'Items will be held by Steam before delivery'**
  String get offerEscrow;

  /// No description provided for @offerAcceptHold.
  ///
  /// In en, this message translates to:
  /// **'Hold to accept'**
  String get offerAcceptHold;

  /// No description provided for @offerDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get offerDecline;

  /// No description provided for @offerCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel offer'**
  String get offerCancel;

  /// No description provided for @offerReceiveLabel.
  ///
  /// In en, this message translates to:
  /// **'You receive'**
  String get offerReceiveLabel;

  /// No description provided for @offerGiveLabel.
  ///
  /// In en, this message translates to:
  /// **'You give'**
  String get offerGiveLabel;

  /// No description provided for @offerAccepted.
  ///
  /// In en, this message translates to:
  /// **'Offer accepted — confirm it in the Confirmations tab'**
  String get offerAccepted;

  /// No description provided for @offerAcceptedNoConf.
  ///
  /// In en, this message translates to:
  /// **'Offer accepted.'**
  String get offerAcceptedNoConf;

  /// No description provided for @offerActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Action failed: {msg}'**
  String offerActionFailed(String msg);

  /// No description provided for @offerDeclined.
  ///
  /// In en, this message translates to:
  /// **'Offer declined.'**
  String get offerDeclined;

  /// No description provided for @offerCanceled.
  ///
  /// In en, this message translates to:
  /// **'Offer canceled.'**
  String get offerCanceled;

  /// No description provided for @pendingTabInvites.
  ///
  /// In en, this message translates to:
  /// **'Invites'**
  String get pendingTabInvites;

  /// No description provided for @famInviteTitle.
  ///
  /// In en, this message translates to:
  /// **'「{groupName}」 invited you to join'**
  String famInviteTitle(String groupName);

  /// No description provided for @famInviteTitleGeneric.
  ///
  /// In en, this message translates to:
  /// **'Family group invite'**
  String get famInviteTitleGeneric;

  /// No description provided for @famInviteFrom.
  ///
  /// In en, this message translates to:
  /// **'Invited by {inviter}'**
  String famInviteFrom(String inviter);

  /// No description provided for @famInviteRole.
  ///
  /// In en, this message translates to:
  /// **'Role: {role}'**
  String famInviteRole(String role);

  /// No description provided for @famInviteSlots.
  ///
  /// In en, this message translates to:
  /// **'Members {used}/{total}'**
  String famInviteSlots(int used, int total);

  /// No description provided for @famRoleAdult.
  ///
  /// In en, this message translates to:
  /// **'Adult'**
  String get famRoleAdult;

  /// No description provided for @famRoleChild.
  ///
  /// In en, this message translates to:
  /// **'Child'**
  String get famRoleChild;

  /// No description provided for @famRoleUnknown.
  ///
  /// In en, this message translates to:
  /// **'Role #{n}'**
  String famRoleUnknown(int n);

  /// No description provided for @famPreflightTitle.
  ///
  /// In en, this message translates to:
  /// **'Join checks'**
  String get famPreflightTitle;

  /// No description provided for @famCheckWalletMatch.
  ///
  /// In en, this message translates to:
  /// **'Wallet region matches'**
  String get famCheckWalletMatch;

  /// No description provided for @famCheckWalletMismatch.
  ///
  /// In en, this message translates to:
  /// **'Wallet region doesn\'t match — Steam restricts joining'**
  String get famCheckWalletMismatch;

  /// No description provided for @famCheckIpMatch.
  ///
  /// In en, this message translates to:
  /// **'Usual IP matches'**
  String get famCheckIpMatch;

  /// No description provided for @famCheckIpMismatch.
  ///
  /// In en, this message translates to:
  /// **'IP doesn\'t match your usual location'**
  String get famCheckIpMismatch;

  /// No description provided for @famCheckCooldown.
  ///
  /// In en, this message translates to:
  /// **'Joining locks family-group switching for 1 year (Steam cooldown)'**
  String get famCheckCooldown;

  /// No description provided for @famJoinRestricted.
  ///
  /// In en, this message translates to:
  /// **'Steam blocked this join (restriction {code})'**
  String famJoinRestricted(int code);

  /// No description provided for @famInviteJoinHold.
  ///
  /// In en, this message translates to:
  /// **'Hold to join'**
  String get famInviteJoinHold;

  /// No description provided for @famInviteAwaiting2fa.
  ///
  /// In en, this message translates to:
  /// **'Waiting for confirmation — check the Confirmations tab'**
  String get famInviteAwaiting2fa;

  /// No description provided for @famInviteJoined.
  ///
  /// In en, this message translates to:
  /// **'Joined ✓'**
  String get famInviteJoined;

  /// No description provided for @famInviteViewGroup.
  ///
  /// In en, this message translates to:
  /// **'View family group ›'**
  String get famInviteViewGroup;

  /// No description provided for @famJoinSent.
  ///
  /// In en, this message translates to:
  /// **'Join requested — confirm it in the Confirmations tab'**
  String get famJoinSent;

  /// No description provided for @famJoinDone.
  ///
  /// In en, this message translates to:
  /// **'Joined the family group.'**
  String get famJoinDone;

  /// No description provided for @famJoinFailed.
  ///
  /// In en, this message translates to:
  /// **'Join failed: {msg}'**
  String famJoinFailed(String msg);

  /// No description provided for @famInvitesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No pending family invites.'**
  String get famInvitesEmpty;

  /// No description provided for @famAccountAction.
  ///
  /// In en, this message translates to:
  /// **'Family group'**
  String get famAccountAction;

  /// No description provided for @famNotInGroup.
  ///
  /// In en, this message translates to:
  /// **'This account isn\'t in a family group.'**
  String get famNotInGroup;

  /// No description provided for @famSummaryMembers.
  ///
  /// In en, this message translates to:
  /// **'Members {used}/{total}'**
  String famSummaryMembers(int used, int total);

  /// No description provided for @famSummaryCooldown.
  ///
  /// In en, this message translates to:
  /// **'Cooldown {days}d'**
  String famSummaryCooldown(int days);

  /// No description provided for @famInvitesSection.
  ///
  /// In en, this message translates to:
  /// **'Invites'**
  String get famInvitesSection;

  /// No description provided for @famSectionMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get famSectionMembers;

  /// No description provided for @famMemberYou.
  ///
  /// In en, this message translates to:
  /// **'(you)'**
  String get famMemberYou;

  /// No description provided for @famSectionPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get famSectionPending;

  /// No description provided for @famPendingComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Purchase approval is coming in a future update.'**
  String get famPendingComingSoon;

  /// No description provided for @deviceSessionsAction.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get deviceSessionsAction;

  /// No description provided for @deviceSessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Logged-in devices'**
  String get deviceSessionsTitle;

  /// No description provided for @deviceSessionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No active devices for this account.'**
  String get deviceSessionsEmpty;

  /// No description provided for @deviceRevokeAction.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get deviceRevokeAction;

  /// No description provided for @deviceRevokeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign \"{name}\" out of your Steam account? It will need to log in again.'**
  String deviceRevokeConfirm(String name);

  /// No description provided for @deviceRevokeDone.
  ///
  /// In en, this message translates to:
  /// **'Signed \"{name}\" out.'**
  String deviceRevokeDone(String name);

  /// No description provided for @deviceRevokeFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sign the device out: {error}'**
  String deviceRevokeFailed(String error);

  /// No description provided for @deviceCurrent.
  ///
  /// In en, this message translates to:
  /// **'(this device)'**
  String get deviceCurrent;

  /// No description provided for @deviceSignedOut.
  ///
  /// In en, this message translates to:
  /// **'signed out'**
  String get deviceSignedOut;

  /// No description provided for @deviceUnnamed.
  ///
  /// In en, this message translates to:
  /// **'Unknown device'**
  String get deviceUnnamed;

  /// No description provided for @deviceLastSeen.
  ///
  /// In en, this message translates to:
  /// **'active {age} ago'**
  String deviceLastSeen(String age);

  /// No description provided for @devicePlatformSteam.
  ///
  /// In en, this message translates to:
  /// **'Steam client'**
  String get devicePlatformSteam;

  /// No description provided for @devicePlatformWeb.
  ///
  /// In en, this message translates to:
  /// **'Web browser'**
  String get devicePlatformWeb;

  /// No description provided for @devicePlatformMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile app'**
  String get devicePlatformMobile;

  /// No description provided for @devicePlatformUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get devicePlatformUnknown;

  /// No description provided for @deviceAgeDays.
  ///
  /// In en, this message translates to:
  /// **'{n}d'**
  String deviceAgeDays(int n);

  /// No description provided for @deviceAgeHours.
  ///
  /// In en, this message translates to:
  /// **'{n}h'**
  String deviceAgeHours(int n);

  /// No description provided for @deviceAgeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{n}m'**
  String deviceAgeMinutes(int n);

  /// No description provided for @deviceAgeNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get deviceAgeNow;

  /// No description provided for @keyRedeemAction.
  ///
  /// In en, this message translates to:
  /// **'Redeem key'**
  String get keyRedeemAction;

  /// No description provided for @keyRedeemTitle.
  ///
  /// In en, this message translates to:
  /// **'Redeem a Steam key'**
  String get keyRedeemTitle;

  /// No description provided for @keyRedeemFor.
  ///
  /// In en, this message translates to:
  /// **'Activating on {account}'**
  String keyRedeemFor(String account);

  /// No description provided for @keyRedeemHint.
  ///
  /// In en, this message translates to:
  /// **'XXXXX-XXXXX-XXXXX'**
  String get keyRedeemHint;

  /// No description provided for @keyRedeemPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get keyRedeemPaste;

  /// No description provided for @keyRedeemSubmit.
  ///
  /// In en, this message translates to:
  /// **'Redeem'**
  String get keyRedeemSubmit;

  /// No description provided for @keyRedeemNote.
  ///
  /// In en, this message translates to:
  /// **'Activation is permanent and adds the product to this account. Steam blocks activations for about an hour after a few rejected keys, so check the code before submitting.'**
  String get keyRedeemNote;

  /// No description provided for @keyRedeemConfirm.
  ///
  /// In en, this message translates to:
  /// **'Activate this key on {account}? It can\'t be undone or moved to another account afterwards.'**
  String keyRedeemConfirm(String account);

  /// No description provided for @keyRedeemDone.
  ///
  /// In en, this message translates to:
  /// **'Key activated.'**
  String get keyRedeemDone;

  /// No description provided for @keyRedeemGranted.
  ///
  /// In en, this message translates to:
  /// **'Added to the library:'**
  String get keyRedeemGranted;

  /// No description provided for @keyRedeemNoProducts.
  ///
  /// In en, this message translates to:
  /// **'Steam accepted the key but didn\'t name the product. Check the account\'s library.'**
  String get keyRedeemNoProducts;

  /// No description provided for @keyRedeemNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach Steam. If the request timed out, Steam may still have processed it — check the account\'s library before trying the key again.'**
  String get keyRedeemNetworkError;

  /// No description provided for @keyErrInvalid.
  ///
  /// In en, this message translates to:
  /// **'Steam doesn\'t recognize this code. Check it for typos — letters and digits like 0/O and 1/I are easy to mix up.'**
  String get keyErrInvalid;

  /// No description provided for @keyErrAlreadyOwned.
  ///
  /// In en, this message translates to:
  /// **'This account already owns the product.'**
  String get keyErrAlreadyOwned;

  /// No description provided for @keyErrAlreadyActivated.
  ///
  /// In en, this message translates to:
  /// **'This key has already been used — on this account or another one.'**
  String get keyErrAlreadyActivated;

  /// No description provided for @keyErrRegionLocked.
  ///
  /// In en, this message translates to:
  /// **'This product can\'t be activated in the account\'s country.'**
  String get keyErrRegionLocked;

  /// No description provided for @keyErrNeedsBaseProduct.
  ///
  /// In en, this message translates to:
  /// **'This is DLC or an expansion; the account needs the base game first.'**
  String get keyErrNeedsBaseProduct;

  /// No description provided for @keyErrNeedsPs3Login.
  ///
  /// In en, this message translates to:
  /// **'This product has to be played on a PlayStation®3 system before it can be activated.'**
  String get keyErrNeedsPs3Login;

  /// No description provided for @keyErrRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many rejected keys recently. Steam blocks activations for about an hour — try again later.'**
  String get keyErrRateLimited;

  /// No description provided for @keyErrUnknown.
  ///
  /// In en, this message translates to:
  /// **'Steam rejected the key (code {code}).'**
  String keyErrUnknown(int code);

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

  /// No description provided for @addErrSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the authenticator to this device, so setup was stopped before it took effect. Write down this revocation code and remove the pending authenticator from your account, then try again: {code}'**
  String addErrSaveFailed(String code);

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

  /// No description provided for @feedbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedbackTitle;

  /// No description provided for @feedbackDesc.
  ///
  /// In en, this message translates to:
  /// **'Found a bug or have an idea? Send it straight to the developer, or open a GitHub issue for public discussion.'**
  String get feedbackDesc;

  /// No description provided for @feedbackSend.
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get feedbackSend;

  /// No description provided for @feedbackMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Your feedback'**
  String get feedbackMessageLabel;

  /// No description provided for @feedbackMessageHint.
  ///
  /// In en, this message translates to:
  /// **'What broke / what would you like?'**
  String get feedbackMessageHint;

  /// No description provided for @feedbackContactLabel.
  ///
  /// In en, this message translates to:
  /// **'Contact (optional)'**
  String get feedbackContactLabel;

  /// No description provided for @feedbackContactHint.
  ///
  /// In en, this message translates to:
  /// **'Email or username — only if you want a reply'**
  String get feedbackContactHint;

  /// No description provided for @feedbackAttachNote.
  ///
  /// In en, this message translates to:
  /// **'Sent along with your message: {meta}'**
  String feedbackAttachNote(String meta);

  /// No description provided for @feedbackSent.
  ///
  /// In en, this message translates to:
  /// **'Feedback sent — thank you!'**
  String get feedbackSent;

  /// No description provided for @feedbackFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send. Check your network and try again.'**
  String get feedbackFailed;

  /// No description provided for @feedbackRefused.
  ///
  /// In en, this message translates to:
  /// **'The relay refused this report: {reason}'**
  String feedbackRefused(String reason);

  /// No description provided for @feedbackRelayDown.
  ///
  /// In en, this message translates to:
  /// **'The feedback service is having trouble on its end ({reason}). Your network is fine — please try again later.'**
  String feedbackRelayDown(String reason);

  /// No description provided for @feedbackAttachLog.
  ///
  /// In en, this message translates to:
  /// **'Attach debug log'**
  String get feedbackAttachLog;

  /// No description provided for @feedbackAttachLogHint.
  ///
  /// In en, this message translates to:
  /// **'Recent network trace; may include account names / SteamIDs'**
  String get feedbackAttachLogHint;

  /// No description provided for @feedbackLogConsentBody.
  ///
  /// In en, this message translates to:
  /// **'The debug log contains recent network-trace lines from this session. It may include your account names and SteamIDs — never your secrets, tokens or passwords. It is sent only together with this report, as described in the Privacy Policy.'**
  String get feedbackLogConsentBody;

  /// No description provided for @feedbackLogConsentAgree.
  ///
  /// In en, this message translates to:
  /// **'Agree'**
  String get feedbackLogConsentAgree;

  /// No description provided for @backupReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Back up your secrets'**
  String get backupReminderTitle;

  /// No description provided for @backupReminderBody.
  ///
  /// In en, this message translates to:
  /// **'AVA keeps your authenticator data on this device only. Back up your maFiles somewhere safe. Your revocation code (R-code) is shown only once, when you first add an authenticator — write it down and keep it then; it is your last resort for removing the authenticator if this device is ever lost.'**
  String get backupReminderBody;

  /// No description provided for @backupReminderOk.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get backupReminderOk;

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

  /// No description provided for @loginShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get loginShowPassword;

  /// No description provided for @loginHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get loginHidePassword;

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

  /// No description provided for @loginErrInvalidPassword.
  ///
  /// In en, this message translates to:
  /// **'Wrong account name or password.'**
  String get loginErrInvalidPassword;

  /// No description provided for @loginErrRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts — please wait a while and try again.'**
  String get loginErrRateLimited;

  /// No description provided for @loginErrCodeMismatch.
  ///
  /// In en, this message translates to:
  /// **'That code didn\'t match — check it and try again.'**
  String get loginErrCodeMismatch;

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

  /// No description provided for @approveBadCode.
  ///
  /// In en, this message translates to:
  /// **'That\'s not a Steam sign-in QR code.'**
  String get approveBadCode;

  /// No description provided for @approveLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get approveLocation;

  /// No description provided for @approveDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get approveDevice;

  /// No description provided for @approveWarnStranger.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t start this sign-in yourself? Reject it.'**
  String get approveWarnStranger;

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

  /// No description provided for @importDuplicateTitle.
  ///
  /// In en, this message translates to:
  /// **'Account already exists'**
  String get importDuplicateTitle;

  /// No description provided for @importDuplicateBody.
  ///
  /// In en, this message translates to:
  /// **'This maFile is for {name}, which is already on this device. Overwrite the stored account with the imported file? Its cached avatar, saved password, and existing session are kept when the file doesn\'t include them.'**
  String importDuplicateBody(String name);

  /// No description provided for @importDuplicateBodyUnreadable.
  ///
  /// In en, this message translates to:
  /// **'This maFile is for {name}, which exists on this device but its stored data can no longer be read. Importing will replace it entirely.'**
  String importDuplicateBodyUnreadable(String name);

  /// No description provided for @importDuplicateOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get importDuplicateOverwrite;

  /// No description provided for @importSessionDeadTitle.
  ///
  /// In en, this message translates to:
  /// **'Activate this account?'**
  String get importSessionDeadTitle;

  /// No description provided for @importSessionDeadBody.
  ///
  /// In en, this message translates to:
  /// **'The Steam session in this maFile has expired. Sign in now to enable confirmations and login approvals — the Steam Guard code will be filled in automatically.'**
  String get importSessionDeadBody;

  /// No description provided for @importSessionLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get importSessionLater;

  /// No description provided for @sdaImportAction.
  ///
  /// In en, this message translates to:
  /// **'Import an SDA folder'**
  String get sdaImportAction;

  /// No description provided for @sdaImportHint.
  ///
  /// In en, this message translates to:
  /// **'Select your Steam Desktop Authenticator maFiles folder: pick manifest.json together with the .maFile files. Both are needed — if SDA\'s encryption was on, the decryption parameters live in manifest.json, not in the maFile.'**
  String get sdaImportHint;

  /// No description provided for @sdaImportNoManifest.
  ///
  /// In en, this message translates to:
  /// **'No manifest.json in that selection. Select it together with the .maFile files.'**
  String get sdaImportNoManifest;

  /// No description provided for @sdaImportBadManifest.
  ///
  /// In en, this message translates to:
  /// **'That manifest.json can\'t be read: {error}'**
  String sdaImportBadManifest(String error);

  /// No description provided for @sdaImportPassTitle.
  ///
  /// In en, this message translates to:
  /// **'SDA encryption passphrase'**
  String get sdaImportPassTitle;

  /// No description provided for @sdaImportPassBody.
  ///
  /// In en, this message translates to:
  /// **'These maFiles are encrypted. Enter the passphrase you set in Steam Desktop Authenticator.'**
  String get sdaImportPassBody;

  /// No description provided for @sdaImportWrongPass.
  ///
  /// In en, this message translates to:
  /// **'That passphrase didn\'t decrypt any of the files.'**
  String get sdaImportWrongPass;

  /// No description provided for @sdaImportDone.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 account imported.} other{{count} accounts imported.}}'**
  String sdaImportDone(int count);

  /// No description provided for @sdaImportSkipped.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 account was skipped: {names}} other{{count} accounts were skipped: {names}}}'**
  String sdaImportSkipped(int count, String names);

  /// No description provided for @sdaImportNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing was imported.'**
  String get sdaImportNothing;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available'**
  String updateAvailable(String version);

  /// No description provided for @updateView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get updateView;

  /// No description provided for @updateDismiss.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get updateDismiss;

  /// No description provided for @settingsUpdateCheck.
  ///
  /// In en, this message translates to:
  /// **'Check for updates on launch'**
  String get settingsUpdateCheck;

  /// No description provided for @settingsUpdateCheckDesc.
  ///
  /// In en, this message translates to:
  /// **'One request to the version endpoint per launch. No account data; the endpoint keeps no logs.'**
  String get settingsUpdateCheckDesc;

  /// No description provided for @importSessionLoginNow.
  ///
  /// In en, this message translates to:
  /// **'Sign in now'**
  String get importSessionLoginNow;

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

  /// No description provided for @exportWarnTitle.
  ///
  /// In en, this message translates to:
  /// **'Export unencrypted maFile?'**
  String get exportWarnTitle;

  /// No description provided for @exportWarnBody.
  ///
  /// In en, this message translates to:
  /// **'The exported .maFile is NOT encrypted. It holds this account’s Steam Guard secrets and revocation code — anyone with the file can take over your authenticator. Store it somewhere safe and delete it when done.'**
  String get exportWarnBody;

  /// No description provided for @exportIncludePassword.
  ///
  /// In en, this message translates to:
  /// **'Also include the saved Steam password (not recommended)'**
  String get exportIncludePassword;

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

  /// No description provided for @addPresentFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Can\'t receive the email?'**
  String get addPresentFallbackTitle;

  /// No description provided for @addMoveInButton.
  ///
  /// In en, this message translates to:
  /// **'Move the authenticator to this device'**
  String get addMoveInButton;

  /// No description provided for @addMoveInBlurb.
  ///
  /// In en, this message translates to:
  /// **'Steam will email this account a code. No 15-day trade hold.'**
  String get addMoveInBlurb;

  /// No description provided for @addMoveInSending.
  ///
  /// In en, this message translates to:
  /// **'Sending the code…'**
  String get addMoveInSending;

  /// No description provided for @addMoveInCodePrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter the code Steam emailed you'**
  String get addMoveInCodePrompt;

  /// No description provided for @addMoveInWarn.
  ///
  /// In en, this message translates to:
  /// **'Once you confirm: the authenticator on your old phone stops working immediately, and your old revocation code (Rxxxxx) is replaced by a new one. This cannot be undone.'**
  String get addMoveInWarn;

  /// No description provided for @addMoveInConfirm.
  ///
  /// In en, this message translates to:
  /// **'Move it here'**
  String get addMoveInConfirm;

  /// No description provided for @addMoveInDone.
  ///
  /// In en, this message translates to:
  /// **'Authenticator moved to this device.'**
  String get addMoveInDone;

  /// No description provided for @addMoveInPopBlocked.
  ///
  /// In en, this message translates to:
  /// **'Moving the authenticator — please wait.'**
  String get addMoveInPopBlocked;

  /// No description provided for @addErrBadChallengeCode.
  ///
  /// In en, this message translates to:
  /// **'That code isn\'t right. Check the email and try again.'**
  String get addErrBadChallengeCode;

  /// No description provided for @addMoveInSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'The authenticator moved to this account, but AVA could NOT save it to this device. Your old authenticator is already dead, so these are the only copies — write them down NOW before closing this screen.\n\nRevocation code: {code}\n\nSecret: {secret}'**
  String addMoveInSaveFailed(String code, String secret);

  /// No description provided for @addMoveInCopySecrets.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get addMoveInCopySecrets;

  /// No description provided for @addMoveInCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get addMoveInCopied;

  /// No description provided for @moveInRescueDismiss.
  ///
  /// In en, this message translates to:
  /// **'I saved them — dismiss'**
  String get moveInRescueDismiss;

  /// No description provided for @moveInRescueDismissTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard these secrets?'**
  String get moveInRescueDismissTitle;

  /// No description provided for @moveInRescueDismissBody.
  ///
  /// In en, this message translates to:
  /// **'AVA holds no other copy. If you haven\'t written down the revocation code and secret, you will permanently lose access to this authenticator.'**
  String get moveInRescueDismissBody;

  /// No description provided for @moveInRescueDismissConfirm.
  ///
  /// In en, this message translates to:
  /// **'I saved them'**
  String get moveInRescueDismissConfirm;

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
  /// **'Your local maFiles are encrypted with a random 256-bit key (AES-256-GCM) held in the device Keystore; your 6-digit PIN unlocks it.'**
  String get settingsEncryptionDesc;

  /// No description provided for @settingsThemeDesc.
  ///
  /// In en, this message translates to:
  /// **'Switch the whole UI style.'**
  String get settingsThemeDesc;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsAppearanceDesc.
  ///
  /// In en, this message translates to:
  /// **'Light or dark for the standard look. A skin overrides this while active.'**
  String get settingsAppearanceDesc;

  /// No description provided for @settingsTextSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get settingsTextSize;

  /// No description provided for @settingsTextSizeDesc.
  ///
  /// In en, this message translates to:
  /// **'Applies on top of the system font size.'**
  String get settingsTextSizeDesc;

  /// No description provided for @textSizeSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get textSizeSmall;

  /// No description provided for @textSizeMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get textSizeMedium;

  /// No description provided for @textSizeLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get textSizeLarge;

  /// No description provided for @settingsSkin.
  ///
  /// In en, this message translates to:
  /// **'Skins'**
  String get settingsSkin;

  /// No description provided for @settingsSkinDesc.
  ///
  /// In en, this message translates to:
  /// **'Full-styled looks with their own fonts and effects.'**
  String get settingsSkinDesc;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @skinNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get skinNone;

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

  /// No description provided for @settingsAutoConfirmMarket.
  ///
  /// In en, this message translates to:
  /// **'Auto-confirm market transactions'**
  String get settingsAutoConfirmMarket;

  /// No description provided for @settingsAutoConfirmMarketDesc.
  ///
  /// In en, this message translates to:
  /// **'Pre-ticks the confirm box when you list an item, so a new listing is confirmed right after it\'s created. It never confirms anything in the background.'**
  String get settingsAutoConfirmMarketDesc;

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

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @aboutTagline.
  ///
  /// In en, this message translates to:
  /// **'An open-source Steam Guard authenticator, built with Flutter.'**
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
  /// **'AVA keeps your Steam accounts and secrets on this device — they are never uploaded, unless you set up the optional sync to a server you choose, where everything is encrypted on this device first. There is no account to create. Steam requests go straight to Valve. Two of the developer\'s own services are contacted only when they are needed: Pro entitlement checks, and feedback (only when you press send). The Play version also shows ads on the free tier. There is no tracking or analytics. All of it is spelled out in the Privacy Policy — by continuing, you accept it.'**
  String get privacyConsentBody;

  /// No description provided for @privacyUpdateTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy updated'**
  String get privacyUpdateTitle;

  /// No description provided for @privacyUpdateBody.
  ///
  /// In en, this message translates to:
  /// **'The privacy notice has changed since you accepted it. New: AVA can now sync your account library between your devices, through a server you choose — off by default, everything encrypted on this device before upload, and the developer runs no sync server. Please read the current notice below.'**
  String get privacyUpdateBody;

  /// No description provided for @privacyConsentScrollHint.
  ///
  /// In en, this message translates to:
  /// **'Scroll to the end to continue'**
  String get privacyConsentScrollHint;

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

  /// No description provided for @marketListedPartial.
  ///
  /// In en, this message translates to:
  /// **'Listed {listed} of {total} — the rest failed; confirm any pending in Confirmations.'**
  String marketListedPartial(int listed, int total);

  /// No description provided for @marketListedSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Listed {listed} of {total}, then the session expired — sign in again and confirm them.'**
  String marketListedSessionExpired(int listed, int total);

  /// No description provided for @marketConfirmPartial.
  ///
  /// In en, this message translates to:
  /// **'Listed — {ok} of {total} confirmed; finish the rest in Confirmations.'**
  String marketConfirmPartial(int ok, int total);

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

  /// No description provided for @marketInvalidPrice.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid price.'**
  String get marketInvalidPrice;

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
  /// **'Pending'**
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

  /// No description provided for @settingsPro.
  ///
  /// In en, this message translates to:
  /// **'AVA Pro'**
  String get settingsPro;

  /// No description provided for @proOpen.
  ///
  /// In en, this message translates to:
  /// **'View AVA Pro'**
  String get proOpen;

  /// No description provided for @proStatusFree.
  ///
  /// In en, this message translates to:
  /// **'Free plan'**
  String get proStatusFree;

  /// No description provided for @proStatusPro.
  ///
  /// In en, this message translates to:
  /// **'Pro · until {date}'**
  String proStatusPro(Object date);

  /// No description provided for @proStatusVip.
  ///
  /// In en, this message translates to:
  /// **'VIP · until {date}'**
  String proStatusVip(Object date);

  /// No description provided for @proStatusLifetime.
  ///
  /// In en, this message translates to:
  /// **'Pro · lifetime'**
  String get proStatusLifetime;

  /// No description provided for @proStatusActivations.
  ///
  /// In en, this message translates to:
  /// **'Active on: {classes}'**
  String proStatusActivations(Object classes);

  /// No description provided for @proStatusClassThisDevice.
  ///
  /// In en, this message translates to:
  /// **'{name} (this device)'**
  String proStatusClassThisDevice(Object name);

  /// No description provided for @proDeviceClassAndroid.
  ///
  /// In en, this message translates to:
  /// **'Android'**
  String get proDeviceClassAndroid;

  /// No description provided for @proDeviceClassWindows.
  ///
  /// In en, this message translates to:
  /// **'Windows'**
  String get proDeviceClassWindows;

  /// No description provided for @proDeviceClassLinux.
  ///
  /// In en, this message translates to:
  /// **'Linux'**
  String get proDeviceClassLinux;

  /// No description provided for @proDeviceClassMacos.
  ///
  /// In en, this message translates to:
  /// **'macOS'**
  String get proDeviceClassMacos;

  /// No description provided for @paywallTitle.
  ///
  /// In en, this message translates to:
  /// **'AVA Pro'**
  String get paywallTitle;

  /// No description provided for @paywallPerksTitle.
  ///
  /// In en, this message translates to:
  /// **'Pro perks — core security features stay free forever.'**
  String get paywallPerksTitle;

  /// No description provided for @paywallPerkSkins.
  ///
  /// In en, this message translates to:
  /// **'Theme packs: Neon & Pixel skins'**
  String get paywallPerkSkins;

  /// No description provided for @paywallPerkNoAds.
  ///
  /// In en, this message translates to:
  /// **'No banner ads'**
  String get paywallPerkNoAds;

  /// No description provided for @paywallPerkFuture.
  ///
  /// In en, this message translates to:
  /// **'Coming later: cloud sync, trade notifications'**
  String get paywallPerkFuture;

  /// No description provided for @paywallPlayTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock via Google Play'**
  String get paywallPlayTitle;

  /// No description provided for @paywallSubscribe.
  ///
  /// In en, this message translates to:
  /// **'Subscribe · \$0.99/mo'**
  String get paywallSubscribe;

  /// No description provided for @paywallWatchAd.
  ///
  /// In en, this message translates to:
  /// **'Watch an ad · 3-day VIP'**
  String get paywallWatchAd;

  /// No description provided for @paywallRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore purchase'**
  String get paywallRestore;

  /// No description provided for @paywallCnTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock via Afdian'**
  String get paywallCnTitle;

  /// No description provided for @paywallAfdianIntro.
  ///
  /// In en, this message translates to:
  /// **'Sponsor ¥5/month on Afdian, then enter the order number here to unlock.'**
  String get paywallAfdianIntro;

  /// No description provided for @paywallOpenAfdian.
  ///
  /// In en, this message translates to:
  /// **'Open Afdian'**
  String get paywallOpenAfdian;

  /// No description provided for @paywallOrderHint.
  ///
  /// In en, this message translates to:
  /// **'Afdian order number'**
  String get paywallOrderHint;

  /// No description provided for @paywallRedeem.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get paywallRedeem;

  /// No description provided for @paywallBetaTitle.
  ///
  /// In en, this message translates to:
  /// **'Beta thank-you'**
  String get paywallBetaTitle;

  /// No description provided for @paywallBetaIntro.
  ///
  /// In en, this message translates to:
  /// **'Beta testers get lifetime Pro — enter your code.'**
  String get paywallBetaIntro;

  /// No description provided for @paywallBetaHint.
  ///
  /// In en, this message translates to:
  /// **'Lifetime code'**
  String get paywallBetaHint;

  /// No description provided for @paywallBetaRedeem.
  ///
  /// In en, this message translates to:
  /// **'Redeem'**
  String get paywallBetaRedeem;

  /// No description provided for @proResultSuccess.
  ///
  /// In en, this message translates to:
  /// **'Unlocked — thank you!'**
  String get proResultSuccess;

  /// No description provided for @proErrCanceled.
  ///
  /// In en, this message translates to:
  /// **'Canceled.'**
  String get proErrCanceled;

  /// No description provided for @proErrNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error — try again later.'**
  String get proErrNetwork;

  /// No description provided for @proErrNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not available in this build yet.'**
  String get proErrNotConfigured;

  /// No description provided for @proErrNoSubscription.
  ///
  /// In en, this message translates to:
  /// **'No active subscription on your Play Store\'s current account. Subscribed with a different Google account? Switch to it in the Play Store app (top-right avatar), then retry.'**
  String get proErrNoSubscription;

  /// No description provided for @proErrAlreadyOwned.
  ///
  /// In en, this message translates to:
  /// **'Your Play Store\'s current account already holds this subscription — tap Restore purchase instead.'**
  String get proErrAlreadyOwned;

  /// No description provided for @proErrOrderBound.
  ///
  /// In en, this message translates to:
  /// **'This order is already bound to another user.'**
  String get proErrOrderBound;

  /// No description provided for @proErrOrderNotFound.
  ///
  /// In en, this message translates to:
  /// **'Order not found or plan mismatch.'**
  String get proErrOrderNotFound;

  /// No description provided for @proErrDeviceRevoked.
  ///
  /// In en, this message translates to:
  /// **'This device\'s slot was taken by a newer activation.'**
  String get proErrDeviceRevoked;

  /// No description provided for @proErrNoVip.
  ///
  /// In en, this message translates to:
  /// **'Reward not confirmed yet — try again in a minute.'**
  String get proErrNoVip;

  /// No description provided for @proErrPurchaseBound.
  ///
  /// In en, this message translates to:
  /// **'This subscription is tied to a different Google account. Retry, and in the account chooser pick the one your Play Store uses.'**
  String get proErrPurchaseBound;

  /// No description provided for @proErrPurchaseBoundKnown.
  ///
  /// In en, this message translates to:
  /// **'This subscription is tied to {account}. Retry, and pick that account in the chooser.'**
  String proErrPurchaseBoundKnown(String account);

  /// No description provided for @proErrGeneric.
  ///
  /// In en, this message translates to:
  /// **'Failed: {code}'**
  String proErrGeneric(Object code);

  /// No description provided for @proErrCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Code not recognized — check it for typos.'**
  String get proErrCodeInvalid;

  /// No description provided for @proErrCodeRedeemed.
  ///
  /// In en, this message translates to:
  /// **'This code is already active on another device. To move it here, email hi@dotslash.pro.'**
  String get proErrCodeRedeemed;

  /// No description provided for @proErrCodeActivationLimit.
  ///
  /// In en, this message translates to:
  /// **'This code has switched devices too often recently. Try again later, or email hi@dotslash.pro.'**
  String get proErrCodeActivationLimit;

  /// No description provided for @proErrRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a minute and try again.'**
  String get proErrRateLimited;

  /// No description provided for @proErrSlotOccupied.
  ///
  /// In en, this message translates to:
  /// **'In use: {slots}'**
  String proErrSlotOccupied(Object slots);

  /// No description provided for @proSlotEntry.
  ///
  /// In en, this message translates to:
  /// **'{name} ({time})'**
  String proSlotEntry(Object name, Object time);

  /// No description provided for @proSlotToday.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get proSlotToday;

  /// No description provided for @proSlotDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 day ago} other{{n} days ago}}'**
  String proSlotDaysAgo(int n);

  /// No description provided for @proErrRevoked.
  ///
  /// In en, this message translates to:
  /// **'This entitlement is no longer active. If you think this is a mistake, email hi@dotslash.pro.'**
  String get proErrRevoked;

  /// No description provided for @privacyOptions.
  ///
  /// In en, this message translates to:
  /// **'Privacy options'**
  String get privacyOptions;

  /// No description provided for @skinProNotice.
  ///
  /// In en, this message translates to:
  /// **'Neon & Pixel skins are now Pro perks. Your selection is kept and comes back with Pro.'**
  String get skinProNotice;

  /// No description provided for @skinProNoticeDismiss.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get skinProNoticeDismiss;

  /// No description provided for @syncTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get syncTitle;

  /// No description provided for @syncSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up sync'**
  String get syncSetupTitle;

  /// No description provided for @syncSettingsDesc.
  ///
  /// In en, this message translates to:
  /// **'Keep accounts in sync across devices through a server you control. Everything is encrypted before it leaves this device.'**
  String get syncSettingsDesc;

  /// No description provided for @syncSetUp.
  ///
  /// In en, this message translates to:
  /// **'Set up sync…'**
  String get syncSetUp;

  /// No description provided for @syncStatusOk.
  ///
  /// In en, this message translates to:
  /// **'Up to date'**
  String get syncStatusOk;

  /// No description provided for @syncStatusSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncStatusSyncing;

  /// No description provided for @syncStatusErrorShort.
  ///
  /// In en, this message translates to:
  /// **'Last sync failed — open for details.'**
  String get syncStatusErrorShort;

  /// No description provided for @syncStatusConflicts.
  ///
  /// In en, this message translates to:
  /// **'{count} conflict(s) need your decision'**
  String syncStatusConflicts(int count);

  /// No description provided for @syncLastSync.
  ///
  /// In en, this message translates to:
  /// **'Last sync: {time}'**
  String syncLastSync(String time);

  /// No description provided for @syncNever.
  ///
  /// In en, this message translates to:
  /// **'never'**
  String get syncNever;

  /// No description provided for @syncBackendTitle.
  ///
  /// In en, this message translates to:
  /// **'Where should the data live?'**
  String get syncBackendTitle;

  /// No description provided for @syncBackendWebdav.
  ///
  /// In en, this message translates to:
  /// **'WebDAV'**
  String get syncBackendWebdav;

  /// No description provided for @syncBackendWebdavDesc.
  ///
  /// In en, this message translates to:
  /// **'Nextcloud, Jianguoyun (坚果云), a NAS — any WebDAV folder you control.'**
  String get syncBackendWebdavDesc;

  /// No description provided for @syncBackendGdrive.
  ///
  /// In en, this message translates to:
  /// **'Google Drive'**
  String get syncBackendGdrive;

  /// No description provided for @syncBackendGdriveSoon.
  ///
  /// In en, this message translates to:
  /// **'Pro · coming later'**
  String get syncBackendGdriveSoon;

  /// No description provided for @syncServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get syncServerTitle;

  /// No description provided for @syncServerHint.
  ///
  /// In en, this message translates to:
  /// **'Jianguoyun needs an app password (安全选项 → 添加应用密码), not your login password. A Nextcloud folder URL looks like https://cloud.example.com/remote.php/dav/files/USER/ava/.'**
  String get syncServerHint;

  /// No description provided for @syncServerUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'WebDAV folder URL'**
  String get syncServerUrlLabel;

  /// No description provided for @syncServerFolderLabel.
  ///
  /// In en, this message translates to:
  /// **'Folder (optional)'**
  String get syncServerFolderLabel;

  /// No description provided for @syncServerFolderHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use the URL as-is; a name places the library in that subfolder, created if missing.'**
  String get syncServerFolderHint;

  /// No description provided for @syncServerUserLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get syncServerUserLabel;

  /// No description provided for @syncServerPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password / app password'**
  String get syncServerPasswordLabel;

  /// No description provided for @syncTestConnection.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get syncTestConnection;

  /// No description provided for @syncErrUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid http(s) folder URL.'**
  String get syncErrUrl;

  /// No description provided for @syncErrAuth.
  ///
  /// In en, this message translates to:
  /// **'The server rejected the username or password.'**
  String get syncErrAuth;

  /// No description provided for @syncErrNetwork.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server: {detail}'**
  String syncErrNetwork(String detail);

  /// No description provided for @syncErrServer.
  ///
  /// In en, this message translates to:
  /// **'The server answered with an error: {detail}'**
  String syncErrServer(String detail);

  /// No description provided for @syncErrTls.
  ///
  /// In en, this message translates to:
  /// **'The server\'s certificate is not trusted.'**
  String get syncErrTls;

  /// No description provided for @syncTlsTitle.
  ///
  /// In en, this message translates to:
  /// **'Unknown server certificate'**
  String get syncTlsTitle;

  /// No description provided for @syncTlsBody.
  ///
  /// In en, this message translates to:
  /// **'This server\'s certificate is not trusted by the system. If it is your own server with a self-signed certificate, compare this fingerprint with the one shown on the server, and only trust it if they match exactly.\n\nSHA-256\n{fp}'**
  String syncTlsBody(String fp);

  /// No description provided for @syncTlsTrust.
  ///
  /// In en, this message translates to:
  /// **'Trust this certificate'**
  String get syncTlsTrust;

  /// No description provided for @syncHttpPrivateTitle.
  ///
  /// In en, this message translates to:
  /// **'Unencrypted connection'**
  String get syncHttpPrivateTitle;

  /// No description provided for @syncHttpPrivateBody.
  ///
  /// In en, this message translates to:
  /// **'This is a plain-HTTP address on a private network. Your account data itself is encrypted end-to-end, but the server password travels unencrypted on your network.'**
  String get syncHttpPrivateBody;

  /// No description provided for @syncHttpPublicTitle.
  ///
  /// In en, this message translates to:
  /// **'Plain HTTP across the internet'**
  String get syncHttpPublicTitle;

  /// No description provided for @syncHttpPublicBody.
  ///
  /// In en, this message translates to:
  /// **'This address is public and the connection would be unencrypted: anyone between you and the server can read the server password and sign in to your server. The account data itself stays encrypted. Use HTTPS or a LAN address instead — continue only if you accept this risk.'**
  String get syncHttpPublicBody;

  /// No description provided for @syncHttpPublicHold.
  ///
  /// In en, this message translates to:
  /// **'Hold to allow anyway'**
  String get syncHttpPublicHold;

  /// No description provided for @syncContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get syncContinue;

  /// No description provided for @syncPassphraseNewTitle.
  ///
  /// In en, this message translates to:
  /// **'Set a sync passphrase'**
  String get syncPassphraseNewTitle;

  /// No description provided for @syncPassphraseNewBody.
  ///
  /// In en, this message translates to:
  /// **'Everything is encrypted with this passphrase before upload; the passphrase itself never leaves your devices.\n\nIf you lose it, the synced data cannot be recovered by anyone — there is no reset. At least 8 characters; length matters more than symbols.'**
  String get syncPassphraseNewBody;

  /// No description provided for @syncPassphraseExistingTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the sync passphrase'**
  String get syncPassphraseExistingTitle;

  /// No description provided for @syncPassphraseExistingBody.
  ///
  /// In en, this message translates to:
  /// **'This folder already holds a sync library with {count} account(s). Enter the passphrase it was created with.'**
  String syncPassphraseExistingBody(int count);

  /// No description provided for @syncPassphraseLabel.
  ///
  /// In en, this message translates to:
  /// **'Sync passphrase'**
  String get syncPassphraseLabel;

  /// No description provided for @syncPassphraseConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm passphrase'**
  String get syncPassphraseConfirmLabel;

  /// No description provided for @syncPassphraseTooShort.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters.'**
  String get syncPassphraseTooShort;

  /// No description provided for @syncPassphraseMismatch.
  ///
  /// In en, this message translates to:
  /// **'The passphrases don\'t match.'**
  String get syncPassphraseMismatch;

  /// No description provided for @syncPassphraseWrong.
  ///
  /// In en, this message translates to:
  /// **'That passphrase doesn\'t open this library.'**
  String get syncPassphraseWrong;

  /// No description provided for @syncPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'First sync'**
  String get syncPreviewTitle;

  /// No description provided for @syncPreviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to transfer yet — accounts will sync automatically from now on.'**
  String get syncPreviewEmpty;

  /// No description provided for @syncPreviewPull.
  ///
  /// In en, this message translates to:
  /// **'Download to this device: {count} account(s)'**
  String syncPreviewPull(int count);

  /// No description provided for @syncPreviewPush.
  ///
  /// In en, this message translates to:
  /// **'Upload from this device: {count} account(s)'**
  String syncPreviewPush(int count);

  /// No description provided for @syncPreviewConflict.
  ///
  /// In en, this message translates to:
  /// **'On both sides with different content: {count} — you\'ll choose per account after connecting'**
  String syncPreviewConflict(int count);

  /// No description provided for @syncStart.
  ///
  /// In en, this message translates to:
  /// **'Start syncing'**
  String get syncStart;

  /// No description provided for @syncDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync is on'**
  String get syncDoneTitle;

  /// No description provided for @syncDoneBody.
  ///
  /// In en, this message translates to:
  /// **'Accounts now sync automatically. On a new device each account signs in again the first time you use it — accounts with a saved password do that by themselves; the others ask once.'**
  String get syncDoneBody;

  /// No description provided for @syncDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get syncDone;

  /// No description provided for @syncNeedsPassphrase.
  ///
  /// In en, this message translates to:
  /// **'The stored passphrase no longer matches the remote library — enter it again.'**
  String get syncNeedsPassphrase;

  /// No description provided for @syncEnterPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Enter passphrase'**
  String get syncEnterPassphrase;

  /// No description provided for @syncConditionalWarn.
  ///
  /// In en, this message translates to:
  /// **'This server ignores conditional writes, so two devices syncing at the same moment may overwrite each other. Syncing still works; avoid simultaneous changes on two devices.'**
  String get syncConditionalWarn;

  /// No description provided for @syncConflictsTitle.
  ///
  /// In en, this message translates to:
  /// **'Conflicts'**
  String get syncConflictsTitle;

  /// No description provided for @syncConflictTrashNote.
  ///
  /// In en, this message translates to:
  /// **'Whichever side you discard is kept in the sync trash for 30 days.'**
  String get syncConflictTrashNote;

  /// No description provided for @syncConflictEditEdit.
  ///
  /// In en, this message translates to:
  /// **'Changed on both devices'**
  String get syncConflictEditEdit;

  /// No description provided for @syncConflictEditDelete.
  ///
  /// In en, this message translates to:
  /// **'Changed here, deleted on another device'**
  String get syncConflictEditDelete;

  /// No description provided for @syncConflictDeleteEdit.
  ///
  /// In en, this message translates to:
  /// **'Deleted here, changed on another device'**
  String get syncConflictDeleteEdit;

  /// No description provided for @syncConflictKeepLocal.
  ///
  /// In en, this message translates to:
  /// **'Keep this device\'s'**
  String get syncConflictKeepLocal;

  /// No description provided for @syncConflictKeepRemote.
  ///
  /// In en, this message translates to:
  /// **'Keep the other\'s'**
  String get syncConflictKeepRemote;

  /// No description provided for @syncConflictLocalSide.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get syncConflictLocalSide;

  /// No description provided for @syncConflictRemoteSide.
  ///
  /// In en, this message translates to:
  /// **'Other device'**
  String get syncConflictRemoteSide;

  /// No description provided for @syncDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get syncDeleted;

  /// No description provided for @syncConflictHasPassword.
  ///
  /// In en, this message translates to:
  /// **'Password saved'**
  String get syncConflictHasPassword;

  /// No description provided for @syncConflictNoPassword.
  ///
  /// In en, this message translates to:
  /// **'No saved password'**
  String get syncConflictNoPassword;

  /// No description provided for @syncAutoTitle.
  ///
  /// In en, this message translates to:
  /// **'Automatic sync'**
  String get syncAutoTitle;

  /// No description provided for @syncAutoDesc.
  ///
  /// In en, this message translates to:
  /// **'Sync at launch and after every change. Off means only the button below syncs.'**
  String get syncAutoDesc;

  /// No description provided for @syncPasswordsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync account passwords'**
  String get syncPasswordsTitle;

  /// No description provided for @syncPasswordsDesc.
  ///
  /// In en, this message translates to:
  /// **'Passwords let a new device sign in by itself. Changing this re-uploads every account.'**
  String get syncPasswordsDesc;

  /// No description provided for @syncAppSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync app settings'**
  String get syncAppSettingsTitle;

  /// No description provided for @syncAppSettingsDesc.
  ///
  /// In en, this message translates to:
  /// **'Appearance and behavior preferences (skin, theme, hold-to-confirm…) follow you to every device. Language and text size stay per-device.'**
  String get syncAppSettingsDesc;

  /// No description provided for @syncNowButton.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNowButton;

  /// No description provided for @syncViewRemote.
  ///
  /// In en, this message translates to:
  /// **'View remote library'**
  String get syncViewRemote;

  /// No description provided for @syncRemoteEmpty.
  ///
  /// In en, this message translates to:
  /// **'The remote library is empty.'**
  String get syncRemoteEmpty;

  /// No description provided for @syncRemoteDevices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get syncRemoteDevices;

  /// No description provided for @syncTrashTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync trash'**
  String get syncTrashTitle;

  /// No description provided for @syncTrashEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty. Anything sync removes or replaces is kept here for 30 days.'**
  String get syncTrashEmpty;

  /// No description provided for @syncTrashRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get syncTrashRestore;

  /// No description provided for @syncTrashRestored.
  ///
  /// In en, this message translates to:
  /// **'Account restored.'**
  String get syncTrashRestored;

  /// No description provided for @syncTrashRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'This entry can\'t be decrypted with the current passphrase.'**
  String get syncTrashRestoreFailed;

  /// No description provided for @syncTrashReasonRemoteDelete.
  ///
  /// In en, this message translates to:
  /// **'deleted by another device'**
  String get syncTrashReasonRemoteDelete;

  /// No description provided for @syncTrashReasonConflict.
  ///
  /// In en, this message translates to:
  /// **'replaced in a conflict'**
  String get syncTrashReasonConflict;

  /// No description provided for @syncChangePassphrase.
  ///
  /// In en, this message translates to:
  /// **'Change sync passphrase'**
  String get syncChangePassphrase;

  /// No description provided for @syncPassphraseChanged.
  ///
  /// In en, this message translates to:
  /// **'Passphrase changed; everything re-encrypted. Other devices will ask for the new passphrase.'**
  String get syncPassphraseChanged;

  /// No description provided for @syncPassphraseChangeFailed.
  ///
  /// In en, this message translates to:
  /// **'Passphrase not changed: {reason}'**
  String syncPassphraseChangeFailed(String reason);

  /// No description provided for @syncDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect sync'**
  String get syncDisconnect;

  /// No description provided for @syncDisconnectBody.
  ///
  /// In en, this message translates to:
  /// **'This device stops syncing. The remote library can stay for your other devices — or be deleted from the server entirely.'**
  String get syncDisconnectBody;

  /// No description provided for @syncDisconnectKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep remote data'**
  String get syncDisconnectKeep;

  /// No description provided for @syncDisconnectDeleteHold.
  ///
  /// In en, this message translates to:
  /// **'Hold to delete remote data'**
  String get syncDisconnectDeleteHold;

  /// Shown when the TLS handshake to Steam is cut — the issue-#6 case.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open a secure connection to Steam. The connection was cut during the TLS handshake, which usually means the network is filtering it or is unstable. Try another network — or a proxy — and retry.'**
  String get netErrTls;

  /// Shown when the socket to Steam could not be opened at all.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach Steam. Check your connection and retry.'**
  String get netErrUnreachable;

  /// Shown when Steam did not answer within the client timeout.
  ///
  /// In en, this message translates to:
  /// **'Steam didn\'t answer in time. The network may be slow or filtered.'**
  String get netErrTimeout;

  /// Shown when Steam's TLS certificate failed verification.
  ///
  /// In en, this message translates to:
  /// **'Steam\'s certificate wasn\'t trusted, so AVA closed the connection. Something on this network may be inspecting traffic.'**
  String get netErrCert;

  /// Shown for a non-2xx HTTP status from Steam.
  ///
  /// In en, this message translates to:
  /// **'Steam returned an error ({code}). This is usually temporary — try again shortly.'**
  String netErrServer(int code);

  /// Snackbar after a desktop maFile export, naming the file the user chose.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String exportSaved(String path);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'es',
    'fr',
    'ru',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'ru':
      return AppLocalizationsRu();
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
