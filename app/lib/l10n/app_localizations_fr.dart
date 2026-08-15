// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'AVA';

  @override
  String get navAccounts => 'Comptes';

  @override
  String get navSettings => 'Paramètres';

  @override
  String get unlockTitle => 'Déverrouiller';

  @override
  String get unlockPrompt => 'Saisissez votre phrase secrète de chiffrement';

  @override
  String get unlockButton => 'Déverrouiller';

  @override
  String get unlockInvalid => 'Cette phrase secrète est invalide.';

  @override
  String get unlockWithBiometric =>
      'Déverrouiller par biométrie / code de l\'appareil';

  @override
  String get unlockLoading => 'Déchiffrement…';

  @override
  String get unlockCantUnlock => 'Impossible de déverrouiller ?';

  @override
  String get resetVaultTitle => 'Réinitialiser les données chiffrées';

  @override
  String get resetVaultBody =>
      'Supprime toutes les entrées de compte et toutes les clés de chiffrement stockées sur cet appareil ; vous devrez ensuite réimporter vos sauvegardes maFile. Vos comptes Steam et leurs authentificateurs ne sont pas affectés.\n\nÀ utiliser lorsque le bon code PIN est systématiquement refusé — typiquement après une restauration de sauvegarde ou un changement de téléphone : la clé matérielle ne quitte jamais l\'appareil d\'origine, les données restaurées ne pourront donc jamais être déchiffrées.\n\nCette action est irréversible.';

  @override
  String get resetVaultConfirm => 'Supprimer et réinitialiser';

  @override
  String get storeErrorTitle => 'Données locales illisibles';

  @override
  String get storeErrorBody =>
      'La base de comptes locale d\'AVA (manifest.json) est absente ou corrompue. Cela peut arriver après une écriture interrompue ou une restauration partielle. Réessayez d\'abord ; si l\'échec persiste, réinitialisez puis réimportez vos sauvegardes maFile.';

  @override
  String get storeRepair => 'Tenter une réparation';

  @override
  String storeActionFailed(String error) {
    return 'Échec de l\'opération : $error';
  }

  @override
  String get pinSetupTitle => 'Définir le PIN de déverrouillage';

  @override
  String get pinSetupPrompt =>
      'Protégez AVA avec un PIN à 6 chiffres. Vous le saisirez (ou utiliserez votre empreinte) pour déverrouiller.';

  @override
  String get pinLabel => 'PIN à 6 chiffres';

  @override
  String get pinConfirmLabel => 'Confirmer le PIN';

  @override
  String get pinSetButton => 'Définir le PIN';

  @override
  String get settingsSet => 'Définir';

  @override
  String get pinChangeTitle => 'Modifier le PIN';

  @override
  String get pinCurrentLabel => 'PIN actuel';

  @override
  String get pinNewLabel => 'Nouveau PIN';

  @override
  String get pinSixDigits => 'Saisissez un PIN à 6 chiffres.';

  @override
  String get pinMismatch => 'Les deux PIN ne correspondent pas.';

  @override
  String get unlockBiometricReason => 'Déverrouiller AVA';

  @override
  String get settingsBiometric => 'Déverrouillage biométrique';

  @override
  String get settingsBiometricDesc =>
      'Déverrouillez avec votre empreinte ou le code de l\'appareil ; la phrase secrète est conservée dans le keystore de l\'appareil.';

  @override
  String get settingsBiometricNeedPasskey =>
      'Définissez d\'abord une phrase secrète de chiffrement.';

  @override
  String get settingsBiometricUnavailable =>
      'Aucune biométrie ni verrouillage d\'écran configuré sur cet appareil.';

  @override
  String get settingsBiometricEnabled => 'Déverrouillage biométrique activé.';

  @override
  String get settingsHoldConfirm => 'Appui long pour confirmer';

  @override
  String get settingsHoldConfirmDesc =>
      'Les acceptations irréversibles (échanges, confirmations) exigent un appui prolongé. Désactivé, un simple appui agit immédiatement ; les actions groupées demandent toujours confirmation.';

  @override
  String get settingsHaptics => 'Retour haptique';

  @override
  String get settingsHapticsDesc =>
      'Vibrations pendant l\'appui long et une fois l\'action terminée.';

  @override
  String get settingsBlockScreenshots => 'Bloquer les captures d\'écran';

  @override
  String get settingsBlockScreenshotsDesc =>
      'Masque AVA dans les captures d\'écran, l\'enregistrement d\'écran et l\'aperçu des applications récentes. La fenêtre devient aussi noire pendant un partage d\'écran, et vous ne pouvez plus joindre de capture à vos commentaires.';

  @override
  String get passkeyLabel => 'Phrase secrète';

  @override
  String get accountsEmpty =>
      'Aucun compte pour l\'instant. Importez un maFile ou connectez-vous pour en ajouter un.';

  @override
  String get emptyAddAccount => 'Ajouter un compte';

  @override
  String get accountReady => 'Prêt';

  @override
  String get tutCodeTitle => 'Code en direct';

  @override
  String get tutCodeBody =>
      'Touchez le grand code pour le copier. Touchez le nom du compte pour alterner entre nom de compte, pseudo et SteamID.';

  @override
  String get tutSwipeRightTitle => 'Glisser à droite → confirmations';

  @override
  String get tutSwipeRightBody =>
      'Faites glisser un compte vers la droite pour ouvrir ses confirmations d\'échange.';

  @override
  String get tutSwipeLeftTitle => 'Glisser à gauche → plus d\'actions';

  @override
  String get tutSwipeLeftBody =>
      'Glissez vers la gauche pour actualiser la session, exporter le maFile ou supprimer le compte.';

  @override
  String get tutLongPressTitle => 'Appui long → inventaire et marché';

  @override
  String get tutLongPressBody =>
      'Appuyez longuement sur un compte pour parcourir son inventaire et mettre des objets en vente sur le Marché de la communauté.';

  @override
  String get tutPullTitle => 'Tirer pour actualiser';

  @override
  String get tutPullBody =>
      'Tirez la liste des comptes vers le bas pour actualiser les avatars et vérifier les demandes de connexion en attente.';

  @override
  String get tutSkip => 'Passer';

  @override
  String get tutNext => 'Suivant';

  @override
  String get tutDone => 'Compris';

  @override
  String get settingsTutorial => 'Tutoriel des gestes';

  @override
  String get settingsTutorialDesc =>
      'Rejouer la présentation de l\'écran d\'accueil (glissements, appui long, tirer pour actualiser).';

  @override
  String get settingsTutorialReplay => 'Rejouer';

  @override
  String get welcomeTitle => 'Bienvenue dans AVA';

  @override
  String get welcomeSubtitle =>
      'Votre authentificateur est stocké chiffré sur cet appareil. Choisissez par où commencer.';

  @override
  String get welcomeLoginCta => 'Se connecter à Steam';

  @override
  String get welcomeLoginSub => 'Configurer un nouvel authentificateur';

  @override
  String get welcomeImportCta => 'Importer un .maFile';

  @override
  String get welcomeImportSub => 'Migrer un compte existant';

  @override
  String get welcomeSyncCta => 'Restaurer depuis la synchronisation';

  @override
  String get welcomeSyncSub =>
      'Récupérer vos comptes depuis une bibliothèque de synchronisation existante';

  @override
  String get copyCode => 'Copier le code';

  @override
  String get codeCopied => 'Code de connexion copié dans le presse-papiers';

  @override
  String get copied => 'Copié dans le presse-papiers';

  @override
  String get copySteamId => 'Copier le SteamID';

  @override
  String get pendingTitle => 'En attente';

  @override
  String get pendingTabConfirmations => 'Confirmations';

  @override
  String get pendingTabOffers => 'Offres';

  @override
  String get confirmationsTitle => 'Confirmations';

  @override
  String get confirmationsEmpty => 'Aucune confirmation en attente.';

  @override
  String get confirmationsRefresh => 'Actualiser';

  @override
  String get confAccept => 'Accepter';

  @override
  String get confDecline => 'Refuser';

  @override
  String get confSelectAll => 'Tout sélectionner';

  @override
  String get confAcceptSelected => 'Accepter la sélection';

  @override
  String get confDeclineSelected => 'Refuser la sélection';

  @override
  String get confAcceptAll => 'Tout accepter';

  @override
  String get confRejectAll => 'Tout refuser';

  @override
  String confAcceptAllConfirm(int count) {
    return 'Accepter les $count confirmations ?';
  }

  @override
  String confRejectAllConfirm(int count) {
    return 'Refuser les $count confirmations ?';
  }

  @override
  String get confAcceptAllWarn =>
      'Cela approuve d\'un seul coup tous les échanges et toutes les mises en vente en attente. Assurez-vous de les reconnaître tous.';

  @override
  String get confRejectAllWarn =>
      'Cela annule d\'un seul coup toutes les confirmations en attente.';

  @override
  String confPending(int count) {
    return '$count en attente';
  }

  @override
  String get confAllProcessed => 'Tout est traité';

  @override
  String get confTypeTrade => 'Échange';

  @override
  String get confTypeMarket => 'Mise en vente';

  @override
  String get confTypeOther => 'Confirmation';

  @override
  String get confTypeFamilyJoin => 'Invitation famille';

  @override
  String get confTypeApiKey => 'Clé API';

  @override
  String get confTypePhoneChange => 'Changement de numéro';

  @override
  String get confTypeAccountRecovery => 'Récupération de compte';

  @override
  String get confTypeFeatureOptOut => 'Désactivation d\'une fonction';

  @override
  String confProcessing(int count) {
    return 'Traitement de $count confirmation(s)…';
  }

  @override
  String confResult(int ok, int fail) {
    return '$ok réussie(s), $fail échouée(s)';
  }

  @override
  String get confNeedsLogin =>
      'Session expirée — reconnectez-vous pour actualiser ce compte.';

  @override
  String get confRejected =>
      'Steam a refusé la demande de confirmation. Cela signifie généralement que le maFile ne correspond pas à l\'authentificateur actuellement lié au compte (fréquent avec les comptes achetés) — supprimez l\'authentificateur puis liez-le à nouveau, ou importez le bon maFile. Un décalage d\'horloge important peut aussi en être la cause.';

  @override
  String get offersSegReceived => 'Reçues';

  @override
  String get offersSegSent => 'Envoyées';

  @override
  String get offersSegHistory => 'Historique';

  @override
  String get offersEmpty => 'Aucune offre d\'échange.';

  @override
  String get offerGift => 'Cadeau — vous ne donnez rien';

  @override
  String get offerOneSided => 'Vous donnez des objets et ne recevez rien';

  @override
  String get offerEscrow =>
      'Les objets seront retenus par Steam avant leur livraison';

  @override
  String get offerAcceptHold => 'Accepter (maintenir)';

  @override
  String get offerDecline => 'Refuser';

  @override
  String get offerCancel => 'Annuler l\'offre';

  @override
  String get offerReceiveLabel => 'Vous recevez';

  @override
  String get offerGiveLabel => 'Vous donnez';

  @override
  String get offerAccepted =>
      'Offre acceptée — confirmez-la dans l\'onglet Confirmations';

  @override
  String get offerAcceptedNoConf => 'Offre acceptée.';

  @override
  String offerActionFailed(String msg) {
    return 'Échec de l\'opération : $msg';
  }

  @override
  String get offerDeclined => 'Offre refusée.';

  @override
  String get offerCanceled => 'Offre annulée.';

  @override
  String get pendingTabInvites => 'Invitations';

  @override
  String famInviteTitle(String groupName) {
    return '« $groupName » vous invite à le rejoindre';
  }

  @override
  String get famInviteTitleGeneric => 'Invitation à un groupe familial';

  @override
  String famInviteFrom(String inviter) {
    return 'Invitation de $inviter';
  }

  @override
  String famInviteRole(String role) {
    return 'Rôle : $role';
  }

  @override
  String famInviteSlots(int used, int total) {
    return 'Membres $used/$total';
  }

  @override
  String get famRoleAdult => 'Adulte';

  @override
  String get famRoleChild => 'Enfant';

  @override
  String famRoleUnknown(int n) {
    return 'Rôle n° $n';
  }

  @override
  String get famPreflightTitle => 'Vérifications préalables';

  @override
  String get famCheckWalletMatch => 'Région du portefeuille identique';

  @override
  String get famCheckWalletMismatch =>
      'Région du portefeuille différente — Steam limite l\'adhésion';

  @override
  String get famCheckIpMatch => 'IP habituelle concordante';

  @override
  String get famCheckIpMismatch =>
      'L\'IP ne correspond pas à votre localisation habituelle';

  @override
  String get famCheckCooldown =>
      'Rejoindre bloque tout changement de groupe familial pendant 1 an (délai imposé par Steam)';

  @override
  String famJoinRestricted(int code) {
    return 'Steam a bloqué cette adhésion (restriction $code)';
  }

  @override
  String get famInviteJoinHold => 'Rejoindre (maintenir)';

  @override
  String get famInviteAwaiting2fa =>
      'En attente de confirmation — voir l\'onglet Confirmations';

  @override
  String get famInviteJoined => 'Rejoint ✓';

  @override
  String get famInviteViewGroup => 'Voir le groupe familial ›';

  @override
  String get famJoinSent =>
      'Adhésion demandée — confirmez-la dans l\'onglet Confirmations';

  @override
  String get famJoinDone => 'Vous avez rejoint le groupe familial.';

  @override
  String famJoinFailed(String msg) {
    return 'Échec de l\'adhésion : $msg';
  }

  @override
  String get famInvitesEmpty => 'Aucune invitation familiale en attente.';

  @override
  String get famAccountAction => 'Groupe familial';

  @override
  String get famNotInGroup =>
      'Ce compte n\'appartient à aucun groupe familial.';

  @override
  String famSummaryMembers(int used, int total) {
    return 'Membres $used/$total';
  }

  @override
  String famSummaryCooldown(int days) {
    return 'Attente $days j';
  }

  @override
  String get famInvitesSection => 'Invitations';

  @override
  String get famSectionMembers => 'Membres';

  @override
  String get famMemberYou => '(vous)';

  @override
  String get famSectionPending => 'En attente';

  @override
  String get famPendingComingSoon =>
      'L\'approbation des achats arrivera dans une prochaine mise à jour.';

  @override
  String get deviceSessionsAction => 'Appareils';

  @override
  String get deviceSessionsTitle => 'Appareils connectés';

  @override
  String get deviceSessionsEmpty => 'Aucun appareil actif pour ce compte.';

  @override
  String get deviceRevokeAction => 'Déconnecter';

  @override
  String deviceRevokeConfirm(String name) {
    return 'Déconnecter « $name » de votre compte Steam ? Cet appareil devra se reconnecter.';
  }

  @override
  String deviceRevokeDone(String name) {
    return '« $name » déconnecté.';
  }

  @override
  String deviceRevokeFailed(String error) {
    return 'Impossible de déconnecter l\'appareil : $error';
  }

  @override
  String get deviceCurrent => '(cet appareil)';

  @override
  String get deviceSignedOut => 'déconnecté';

  @override
  String get deviceUnnamed => 'Appareil inconnu';

  @override
  String deviceLastSeen(String age) {
    return 'actif il y a $age';
  }

  @override
  String get devicePlatformSteam => 'Client Steam';

  @override
  String get devicePlatformWeb => 'Navigateur web';

  @override
  String get devicePlatformMobile => 'Application mobile';

  @override
  String get devicePlatformUnknown => 'Inconnu';

  @override
  String deviceAgeDays(int n) {
    return '$n j';
  }

  @override
  String deviceAgeHours(int n) {
    return '$n h';
  }

  @override
  String deviceAgeMinutes(int n) {
    return '$n min';
  }

  @override
  String get deviceAgeNow => 'à l\'instant';

  @override
  String get keyRedeemAction => 'Activer une clé';

  @override
  String get keyRedeemTitle => 'Activer une clé Steam';

  @override
  String keyRedeemFor(String account) {
    return 'Activation sur $account';
  }

  @override
  String get keyRedeemHint => 'XXXXX-XXXXX-XXXXX';

  @override
  String get keyRedeemPaste => 'Coller';

  @override
  String get keyRedeemSubmit => 'Activer';

  @override
  String get keyRedeemNote =>
      'L\'activation est définitive et ajoute le produit à ce compte. Après quelques clés refusées, Steam bloque les activations pendant environ une heure : vérifiez le code avant de l\'envoyer.';

  @override
  String keyRedeemConfirm(String account) {
    return 'Activer cette clé sur $account ? C\'est irréversible, et le produit ne pourra pas être transféré vers un autre compte.';
  }

  @override
  String get keyRedeemDone => 'Clé activée.';

  @override
  String get keyRedeemGranted => 'Ajouté à la bibliothèque :';

  @override
  String get keyRedeemNoProducts =>
      'Steam a accepté la clé mais n\'a pas indiqué le produit. Vérifiez la bibliothèque du compte.';

  @override
  String get keyRedeemNetworkError =>
      'Impossible de joindre Steam. Si la requête a expiré, Steam l\'a peut-être quand même traitée — vérifiez la bibliothèque du compte avant de réessayer cette clé.';

  @override
  String get keyErrInvalid =>
      'Steam ne reconnaît pas ce code. Vérifiez les fautes de frappe — les lettres et chiffres comme 0/O et 1/I se confondent facilement.';

  @override
  String get keyErrAlreadyOwned => 'Ce compte possède déjà ce produit.';

  @override
  String get keyErrAlreadyActivated =>
      'Cette clé a déjà été utilisée — sur ce compte ou sur un autre.';

  @override
  String get keyErrRegionLocked =>
      'Ce produit ne peut pas être activé dans le pays du compte.';

  @override
  String get keyErrNeedsBaseProduct =>
      'Il s\'agit d\'un DLC ou d\'une extension ; le compte doit d\'abord posséder le jeu de base.';

  @override
  String get keyErrNeedsPs3Login =>
      'Ce produit doit avoir été lancé sur une console PlayStation®3 avant de pouvoir être activé.';

  @override
  String get keyErrRateLimited =>
      'Trop de clés refusées récemment. Steam bloque les activations pendant environ une heure — réessayez plus tard.';

  @override
  String keyErrUnknown(int code) {
    return 'Steam a refusé la clé (code $code).';
  }

  @override
  String get loginOrApprove =>
      '…ou touchez simplement « Autoriser » dans l\'application mobile Steam.';

  @override
  String get addErrPresent => 'Ce compte possède déjà un authentificateur.';

  @override
  String get addErrConfirmEmail =>
      'Confirmez l\'e-mail envoyé par Steam, puis réessayez.';

  @override
  String get addErrLocked =>
      'Ce compte est verrouillé ou restreint par Steam — récupérez-le sur help.steampowered.com avant d\'ajouter un authentificateur.';

  @override
  String get addErrRateLimited =>
      'Trop de tentatives. Patientez un moment et réessayez.';

  @override
  String get addErrFailed => 'Échec de l\'ajout de l\'authentificateur.';

  @override
  String addErrSaveFailed(String code) {
    return 'Impossible d\'enregistrer l\'authentificateur sur cet appareil ; la configuration a été interrompue avant de prendre effet. Notez ce code de révocation, supprimez de votre compte l\'authentificateur en attente, puis réessayez : $code';
  }

  @override
  String get addErrBadSms => 'Code SMS incorrect, réessayez.';

  @override
  String get debugLog => 'Journal de débogage';

  @override
  String get debugLogDesc =>
      'Trace réseau pour diagnostiquer la connexion et les confirmations';

  @override
  String get feedbackTitle => 'Commentaires';

  @override
  String get feedbackDesc =>
      'Un bug ou une idée ? Écrivez directement au développeur, ou ouvrez un ticket GitHub pour en discuter publiquement.';

  @override
  String get feedbackSend => 'Envoyer';

  @override
  String get feedbackMessageLabel => 'Votre message';

  @override
  String get feedbackMessageHint =>
      'Qu\'est-ce qui ne marche pas / que souhaitez-vous ?';

  @override
  String get feedbackContactLabel => 'Contact (facultatif)';

  @override
  String get feedbackContactHint =>
      'E-mail ou pseudo — seulement si vous voulez une réponse';

  @override
  String feedbackAttachNote(String meta) {
    return 'Envoyé avec votre message : $meta';
  }

  @override
  String get feedbackSent => 'Message envoyé — merci !';

  @override
  String get feedbackFailed =>
      'Envoi impossible. Vérifiez votre connexion et réessayez.';

  @override
  String feedbackRefused(String reason) {
    return 'Le relais a refusé ce rapport : $reason';
  }

  @override
  String feedbackRelayDown(String reason) {
    return 'Le service de commentaires rencontre un problème de son côté ($reason). Votre connexion n\'est pas en cause — réessayez plus tard.';
  }

  @override
  String get feedbackAttachLog => 'Joindre le journal de débogage';

  @override
  String get feedbackAttachLogHint =>
      'Trace réseau récente ; peut contenir des noms de compte / SteamID';

  @override
  String get feedbackLogConsentBody =>
      'Le journal de débogage contient les lignes de trace réseau récentes de cette session. Il peut contenir vos noms de compte et vos SteamID — jamais vos secrets, jetons ou mots de passe. Il n\'est envoyé qu\'avec ce rapport, comme décrit dans la politique de confidentialité.';

  @override
  String get feedbackLogConsentAgree => 'Accepter';

  @override
  String get backupReminderTitle => 'Sauvegardez vos secrets';

  @override
  String get backupReminderBody =>
      'AVA conserve les données de votre authentificateur uniquement sur cet appareil. Sauvegardez vos maFiles en lieu sûr. Votre code de révocation (code R) ne s\'affiche qu\'une seule fois, lors du premier ajout d\'un authentificateur — notez-le et conservez-le à ce moment-là : c\'est votre dernier recours pour supprimer l\'authentificateur si vous perdez un jour cet appareil.';

  @override
  String get backupReminderOk => 'Compris';

  @override
  String get debugCopyAll => 'Tout copier';

  @override
  String get debugCopied => 'Journal copié';

  @override
  String get debugEmpty => 'Aucun journal pour l\'instant.';

  @override
  String get commonOpen => 'Ouvrir';

  @override
  String get commonClear => 'Effacer';

  @override
  String addErrFinalize(String detail) {
    return 'Échec de la finalisation : $detail';
  }

  @override
  String get loginTitle => 'Se connecter à Steam';

  @override
  String get loginUsername => 'Nom de compte';

  @override
  String get loginPassword => 'Mot de passe';

  @override
  String get loginShowPassword => 'Afficher le mot de passe';

  @override
  String get loginHidePassword => 'Masquer le mot de passe';

  @override
  String get loginSavePassword => 'Enregistrer le mot de passe';

  @override
  String get loginSavePasswordHint =>
      'Conservé dans le maFile de ce compte pour actualiser la session automatiquement ; un export non chiffré le contiendra.';

  @override
  String get loginButton => 'Se connecter';

  @override
  String get loginErrInvalidPassword =>
      'Nom de compte ou mot de passe incorrect.';

  @override
  String get loginErrRateLimited =>
      'Trop de tentatives — patientez un moment et réessayez.';

  @override
  String get loginErrCodeMismatch =>
      'Ce code ne correspond pas — vérifiez-le et réessayez.';

  @override
  String get loginViaQr => 'Se connecter par QR code';

  @override
  String get loginViaCredentials => 'Se connecter par mot de passe';

  @override
  String get loginScanWithApp =>
      'Scannez ce code avec l\'application mobile Steam';

  @override
  String get loginNeedGuardCode => 'Saisissez le code Steam Guard';

  @override
  String get loginNeedEmailCode => 'Saisissez le code envoyé par e-mail';

  @override
  String get loginSubmitCode => 'Valider';

  @override
  String get loginWaiting => 'En attente de confirmation…';

  @override
  String get loginStepCredentials => 'Identifiants';

  @override
  String get loginStepConfirm => 'Confirmer';

  @override
  String get loginStepDone => 'Terminé';

  @override
  String get loginWaitingDesc =>
      'Approuvez cette connexion dans l\'application mobile Steam. Vous pouvez aussi utiliser un code envoyé par e-mail ou la connexion par QR code.';

  @override
  String loginFailed(String error) {
    return 'Échec de la connexion : $error';
  }

  @override
  String get approveTitle => 'Approuver la connexion';

  @override
  String get approveScanPrompt =>
      'Scannez le QR code affiché sur l\'appareil que vous voulez connecter.';

  @override
  String get approvePastePrompt => 'Ou collez ici le lien du QR code';

  @override
  String get approveButton => 'Approuver';

  @override
  String get approveReject => 'Refuser';

  @override
  String get approveSuccess => 'Connexion approuvée.';

  @override
  String get approveRejected => 'Connexion refusée.';

  @override
  String get approveBadCode => 'Ce n\'est pas un QR code de connexion Steam.';

  @override
  String get approveLocation => 'Lieu';

  @override
  String get approveDevice => 'Appareil';

  @override
  String get approveWarnStranger =>
      'Ce n\'est pas vous qui avez lancé cette connexion ? Refusez-la.';

  @override
  String get importTitle => 'Importer un compte';

  @override
  String get importPickFile => 'Choisir un .maFile';

  @override
  String get importSuccess => 'Compte importé.';

  @override
  String importFailed(String error) {
    return 'Échec de l\'import : $error';
  }

  @override
  String get importDuplicateTitle => 'Ce compte existe déjà';

  @override
  String importDuplicateBody(String name) {
    return 'Ce maFile correspond à $name, déjà présent sur cet appareil. Remplacer le compte enregistré par le fichier importé ? L\'avatar en cache, le mot de passe enregistré et la session existante sont conservés si le fichier ne les contient pas.';
  }

  @override
  String importDuplicateBodyUnreadable(String name) {
    return 'Ce maFile correspond à $name, présent sur cet appareil mais dont les données locales ne sont plus lisibles. L\'import le remplacera entièrement.';
  }

  @override
  String get importDuplicateOverwrite => 'Remplacer';

  @override
  String get importSessionDeadTitle => 'Activer ce compte ?';

  @override
  String get importSessionDeadBody =>
      'La session Steam contenue dans ce maFile a expiré. Connectez-vous maintenant pour activer les confirmations et les approbations de connexion — le code Steam Guard sera saisi automatiquement.';

  @override
  String get importSessionLater => 'Plus tard';

  @override
  String get sdaImportAction => 'Importer un dossier SDA';

  @override
  String get sdaImportHint =>
      'Sélectionnez votre dossier maFiles de Steam Desktop Authenticator : prenez manifest.json en même temps que les fichiers .maFile. Les deux sont nécessaires — si le chiffrement de SDA était activé, les paramètres de déchiffrement sont dans manifest.json, pas dans le maFile.';

  @override
  String get sdaImportNoManifest =>
      'Pas de manifest.json dans cette sélection. Sélectionnez-le avec les fichiers .maFile.';

  @override
  String sdaImportBadManifest(String error) {
    return 'Ce manifest.json est illisible : $error';
  }

  @override
  String get sdaImportPassTitle => 'Phrase secrète de chiffrement SDA';

  @override
  String get sdaImportPassBody =>
      'Ces maFiles sont chiffrés. Saisissez la phrase secrète que vous aviez définie dans Steam Desktop Authenticator.';

  @override
  String get sdaImportWrongPass =>
      'Cette phrase secrète n\'a déchiffré aucun des fichiers.';

  @override
  String sdaImportDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comptes importés.',
      one: '1 compte importé.',
    );
    return '$_temp0';
  }

  @override
  String sdaImportSkipped(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comptes ignorés : $names',
      one: '1 compte ignoré : $names',
    );
    return '$_temp0';
  }

  @override
  String get sdaImportNothing => 'Rien n\'a été importé.';

  @override
  String updateAvailable(String version) {
    return 'La version $version est disponible';
  }

  @override
  String get updateView => 'Voir';

  @override
  String get updateDismiss => 'Ignorer';

  @override
  String get settingsUpdateCheck => 'Vérifier les mises à jour au lancement';

  @override
  String get settingsUpdateCheckDesc =>
      'À chaque lancement, AVA demande une fois à son point de version s\'il existe une version plus récente — une seule requête, sans aucune donnée de compte, vers un point qui ne garde aucun journal. Désactivé, AVA ne vérifie jamais ; les versions restent sur ava.dotslash.pro.';

  @override
  String get importSessionLoginNow => 'Se connecter';

  @override
  String get actionExport => 'Exporter le maFile';

  @override
  String get actionLoginRequests => 'Demandes de connexion';

  @override
  String get loginRequestTitle => 'Approuver la connexion ?';

  @override
  String loginRequestBody(String device, String location) {
    return '$device se connecte à votre compte Steam depuis $location.';
  }

  @override
  String get loginRequestApprove => 'Autoriser';

  @override
  String get loginRequestDeny => 'Refuser';

  @override
  String get loginNoPending => 'Aucune demande de connexion en attente.';

  @override
  String get loginNeedSession =>
      'Connectez-vous d\'abord pour actualiser la session de ce compte.';

  @override
  String get loginApproved => 'Connexion autorisée.';

  @override
  String get loginDenied => 'Connexion refusée.';

  @override
  String exportFailed(String error) {
    return 'Échec de l\'export : $error';
  }

  @override
  String get exportWarnTitle => 'Exporter un maFile non chiffré ?';

  @override
  String get exportWarnBody =>
      'Le .maFile exporté n\'est PAS chiffré. Il contient les secrets Steam Guard et le code de révocation de ce compte — quiconque obtient ce fichier peut prendre le contrôle de votre authentificateur. Conservez-le en lieu sûr et supprimez-le dès que vous n\'en avez plus besoin.';

  @override
  String get exportIncludePassword =>
      'Inclure aussi le mot de passe Steam enregistré (déconseillé)';

  @override
  String get addAuthTitle => 'Ajouter un authentificateur';

  @override
  String get addAuthPhonePrompt =>
      'Saisissez votre numéro de téléphone (avec l\'indicatif du pays)';

  @override
  String get addAuthSmsPrompt =>
      'Saisissez le code SMS reçu sur votre téléphone';

  @override
  String get addAuthEmailPrompt =>
      'Saisissez le code d\'activation que Steam vous a envoyé par e-mail';

  @override
  String addAuthRevocationWarn(String code) {
    return 'Notez votre code de révocation : $code';
  }

  @override
  String get addAuthConfirmRevocation =>
      'Ressaisissez votre code de révocation pour confirmer que vous l\'avez noté';

  @override
  String get addAuthLinked => 'Authentificateur lié avec succès.';

  @override
  String get addAuthStepPhone => 'Téléphone';

  @override
  String get addAuthStepSms => 'Activer';

  @override
  String get addAuthStepRevocation => 'Révocation';

  @override
  String get addPresentTitle => 'Ce compte possède déjà un authentificateur';

  @override
  String get addPresentIntro =>
      'Steam n\'autorise qu\'un seul authentificateur mobile par compte. Supprimez l\'existant, puis touchez Réessayer.';

  @override
  String get addPresentStep1 =>
      'Vous avez encore l\'ancien téléphone ou l\'application Steam ? Ouvrez-la → Steam Guard → Supprimer l\'authentificateur.';

  @override
  String get addPresentStep2 =>
      'Vous avez votre code de révocation (Rxxxxx) ? Ouvrez la page ci-dessous et choisissez « Supprimer l\'authentificateur ».';

  @override
  String get addPresentStep3 =>
      'Vous n\'avez accès ni à l\'un ni à l\'autre ? Passez par Assistance Steam → Aide → Authentificateur mobile Steam Guard.';

  @override
  String get addPresentManageUrl => 'store.steampowered.com/twofactor/manage';

  @override
  String get addPresentCopiedUrl => 'Lien copié';

  @override
  String get addPresentFallbackTitle => 'Vous ne recevez pas l\'e-mail ?';

  @override
  String get addMoveInButton =>
      'Transférer l\'authentificateur sur cet appareil';

  @override
  String get addMoveInBlurb =>
      'Steam enverra un code par e-mail à ce compte. Aucun blocage des échanges de 15 jours.';

  @override
  String get addMoveInSending => 'Envoi du code…';

  @override
  String get addMoveInCodePrompt =>
      'Saisissez le code que Steam vous a envoyé par e-mail';

  @override
  String get addMoveInWarn =>
      'Dès que vous confirmez : l\'authentificateur de votre ancien téléphone cesse immédiatement de fonctionner, et votre ancien code de révocation (Rxxxxx) est remplacé par un nouveau. Cette action est irréversible.';

  @override
  String get addMoveInConfirm => 'Transférer ici';

  @override
  String get addMoveInDone => 'Authentificateur transféré sur cet appareil.';

  @override
  String get addMoveInPopBlocked =>
      'Transfert de l\'authentificateur en cours — patientez.';

  @override
  String get addErrBadChallengeCode =>
      'Ce code n\'est pas correct. Vérifiez l\'e-mail et réessayez.';

  @override
  String addMoveInSaveFailed(String code, String secret) {
    return 'L\'authentificateur a bien été transféré sur ce compte, mais AVA n\'a PAS pu l\'enregistrer sur cet appareil. Votre ancien authentificateur est déjà hors service : voici les seules copies existantes — notez-les MAINTENANT, avant de fermer cet écran.\n\nCode de révocation : $code\n\nSecret : $secret';
  }

  @override
  String get addMoveInCopySecrets => 'Copier';

  @override
  String get addMoveInCopied => 'Copié';

  @override
  String get moveInRescueDismiss => 'C\'est noté — fermer';

  @override
  String get moveInRescueDismissTitle => 'Abandonner ces secrets ?';

  @override
  String get moveInRescueDismissBody =>
      'AVA n\'en conserve aucune autre copie. Si vous n\'avez pas noté le code de révocation et le secret, vous perdrez définitivement l\'accès à cet authentificateur.';

  @override
  String get moveInRescueDismissConfirm => 'Je les ai notés';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonCopy => 'Copier le lien';

  @override
  String get commonRefresh => 'Actualiser';

  @override
  String get commonExport => 'Exporter';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get settingsEncryption => 'Chiffrement';

  @override
  String get settingsEncryptionDesc =>
      'Vos maFiles locaux sont chiffrés par une clé aléatoire de 256 bits (AES-256-GCM) conservée dans le Keystore de l\'appareil ; votre PIN à 6 chiffres la déverrouille.';

  @override
  String get settingsThemeDesc => 'Change le style de toute l\'interface.';

  @override
  String get settingsAppearance => 'Apparence';

  @override
  String get settingsAppearanceDesc =>
      'Clair ou sombre pour le style standard. Un skin actif a la priorité.';

  @override
  String get settingsTextSize => 'Taille du texte';

  @override
  String get settingsTextSizeDesc =>
      'S\'applique en plus de la taille de police du système.';

  @override
  String get textSizeSmall => 'Petite';

  @override
  String get textSizeMedium => 'Moyenne';

  @override
  String get textSizeLarge => 'Grande';

  @override
  String get settingsSkin => 'Skins';

  @override
  String get settingsSkinDesc =>
      'Des styles complets, avec leurs propres polices et effets.';

  @override
  String get themeSystem => 'Système';

  @override
  String get skinNone => 'Aucun';

  @override
  String get settingsChange => 'Modifier';

  @override
  String get settingsSetPasskey => 'Définir / modifier la phrase secrète';

  @override
  String get settingsAutoConfirmMarket =>
      'Confirmer automatiquement les ventes';

  @override
  String get settingsAutoConfirmMarketDesc =>
      'Coche à l\'avance la case de confirmation quand vous mettez un objet en vente, pour qu\'une nouvelle annonce soit confirmée juste après sa création. Rien n\'est jamais confirmé en arrière-plan.';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get settingsLanguageSystem => 'Langue du système';

  @override
  String get settingsTheme => 'Thème';

  @override
  String get themeNeon => 'Neon';

  @override
  String get themePixel => 'Pixel';

  @override
  String get themeDark => 'Sombre';

  @override
  String get themeLight => 'Clair';

  @override
  String get settingsAbout => 'À propos';

  @override
  String get aboutTagline =>
      'Un authentificateur Steam Guard open source, développé avec Flutter.';

  @override
  String get aboutSourceCode => 'Code source';

  @override
  String get aboutAuthor => 'Auteur';

  @override
  String get aboutLicense => 'Licence';

  @override
  String get aboutPrivacy => 'Politique de confidentialité';

  @override
  String get privacyConsentTitle => 'Votre vie privée';

  @override
  String get privacyConsentBody =>
      'AVA garde vos comptes Steam et vos secrets sur cet appareil — rien n\'est jamais envoyé, sauf si vous configurez la synchronisation optionnelle vers un serveur de votre choix, et même alors tout est d\'abord chiffré sur cet appareil. Aucun compte à créer. Les requêtes Steam vont directement chez Valve. Deux services du développeur ne sont contactés qu\'en cas de besoin : la vérification Pro, et les commentaires (seulement quand vous appuyez sur envoyer). La version Play affiche aussi des publicités en offre gratuite. Aucun pistage ni statistique. Tout est détaillé dans la politique de confidentialité — continuer vaut acceptation.';

  @override
  String get privacyUpdateTitle => 'Politique de confidentialité mise à jour';

  @override
  String get privacyUpdateBody =>
      'L\'avis de confidentialité a changé depuis votre accord. Nouveau : AVA peut désormais synchroniser votre bibliothèque de comptes entre vos appareils, via un serveur de votre choix — désactivé par défaut, tout est chiffré sur cet appareil avant l\'envoi, et le développeur n\'exploite aucun serveur de synchronisation. Merci de lire l\'avis actuel ci-dessous.';

  @override
  String get privacyConsentScrollHint =>
      'Faites défiler jusqu\'en bas pour continuer';

  @override
  String get privacyConsentRead =>
      'Lire la politique de confidentialité complète';

  @override
  String get privacyConsentAgree => 'Accepter et continuer';

  @override
  String get privacyConsentExit => 'Quitter';

  @override
  String get actionMarket => 'Inventaire / Marché';

  @override
  String get marketTabInventory => 'Inventaire';

  @override
  String get marketTabListings => 'Mes ventes';

  @override
  String get marketSelectGame => 'Choisir un jeu';

  @override
  String get marketNoItems => 'Aucun objet dans cet inventaire.';

  @override
  String get marketNotMarketable => 'Non vendable';

  @override
  String get marketSellTitle => 'Mettre en vente';

  @override
  String get marketYouReceive => 'Vous recevez';

  @override
  String get marketBuyerPays => 'L\'acheteur paie';

  @override
  String get marketLowest => 'Plus bas';

  @override
  String get marketMedian => 'Médian';

  @override
  String get marketHigh => 'Haut';

  @override
  String get marketLow => 'Bas';

  @override
  String get marketPriceUnavailable => 'Prix du marché indisponible';

  @override
  String get marketListButton => 'Mettre en vente';

  @override
  String get marketListed => 'Mis en vente — confirmez pour finaliser.';

  @override
  String get marketListedDone => 'Mis en vente et confirmé.';

  @override
  String marketListedPartial(int listed, int total) {
    return '$listed sur $total mis en vente — le reste a échoué ; confirmez ce qui reste en attente dans Confirmations.';
  }

  @override
  String marketListedSessionExpired(int listed, int total) {
    return '$listed sur $total mis en vente, puis la session a expiré — reconnectez-vous et confirmez-les.';
  }

  @override
  String marketConfirmPartial(int ok, int total) {
    return 'Mis en vente — $ok sur $total confirmés ; terminez le reste dans Confirmations.';
  }

  @override
  String get marketAutoConfirm => 'Confirmer automatiquement la mise en vente';

  @override
  String get marketQuantity => 'Quantité';

  @override
  String get marketMax => 'Max';

  @override
  String marketListFailed(String error) {
    return 'Échec de la mise en vente : $error';
  }

  @override
  String get marketInvalidPrice => 'Saisissez un prix valide.';

  @override
  String get marketCancel => 'Retirer la vente';

  @override
  String get marketCancelled => 'Vente retirée.';

  @override
  String get marketNoListings => 'Aucune vente en cours.';

  @override
  String get marketFeeNote =>
      'Les frais Steam + jeu s\'ajoutent au montant que vous recevez.';

  @override
  String get aboutLicenses => 'Licences open source';

  @override
  String get aboutCredits => 'Remerciements';

  @override
  String get aboutCreditsBody =>
      'Inspiré de Steam Desktop Authenticator et compatible avec son format maFile. Développé indépendamment avec Flutter, Riverpod, Dio, PointyCastle, mobile_scanner, image et d\'autres bibliothèques open source.';

  @override
  String get actionLogin => 'Se connecter / actualiser la session';

  @override
  String get actionConfirmations => 'En attente';

  @override
  String get actionRemove => 'Supprimer le compte';

  @override
  String get actionImport => 'Importer';

  @override
  String get actionAddAuthenticator => 'Ajouter un authentificateur';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonOk => 'OK';

  @override
  String get commonConfirm => 'Confirmer';

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonError => 'Erreur';

  @override
  String get sessionExpired =>
      'Votre session Steam a expiré. Reconnectez-vous.';

  @override
  String get removeConfirm =>
      'Supprimer ce compte de cet appareil ? Assurez-vous d\'avoir sauvegardé son maFile.';

  @override
  String get settingsPro => 'AVA Pro';

  @override
  String get proOpen => 'Voir AVA Pro';

  @override
  String get proStatusFree => 'Version gratuite';

  @override
  String proStatusPro(Object date) {
    return 'Pro · jusqu\'au $date';
  }

  @override
  String proStatusVip(Object date) {
    return 'VIP · jusqu\'au $date';
  }

  @override
  String get proStatusLifetime => 'Pro · à vie';

  @override
  String proStatusActivations(Object classes) {
    return 'Actif sur : $classes';
  }

  @override
  String proStatusClassThisDevice(Object name) {
    return '$name (cet appareil)';
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
      'Avantages Pro — les fonctions de sécurité essentielles restent gratuites pour toujours.';

  @override
  String get paywallPerkSkins => 'Packs de thèmes : skins Neon et Pixel';

  @override
  String get paywallPerkNoAds => 'Aucune bannière publicitaire';

  @override
  String get paywallPerkFuture =>
      'Plus tard : synchronisation cloud, notifications d\'échange';

  @override
  String get paywallPlayTitle => 'Débloquer via Google Play';

  @override
  String get paywallSubscribe => 'S\'abonner · 0,99 \$/mois';

  @override
  String get paywallWatchAd => 'Voir une pub · VIP 3 jours';

  @override
  String get paywallRestore => 'Restaurer l\'achat';

  @override
  String get paywallCnTitle => 'Débloquer via Afdian';

  @override
  String get paywallAfdianIntro =>
      'Soutenez à hauteur de 5 ¥/mois sur Afdian, puis saisissez ici le numéro de commande pour débloquer.';

  @override
  String get paywallOpenAfdian => 'Ouvrir Afdian';

  @override
  String get paywallOrderHint => 'Numéro de commande Afdian';

  @override
  String get paywallRedeem => 'Débloquer';

  @override
  String get paywallBetaTitle => 'Merci aux bêta-testeurs';

  @override
  String get paywallBetaIntro =>
      'Les bêta-testeurs reçoivent Pro à vie — saisissez votre code.';

  @override
  String get paywallBetaHint => 'Code à vie';

  @override
  String get paywallBetaRedeem => 'Valider';

  @override
  String get proResultSuccess => 'Débloqué — merci !';

  @override
  String get proErrCanceled => 'Annulé.';

  @override
  String get proErrNetwork => 'Erreur réseau — réessayez plus tard.';

  @override
  String get proErrNotConfigured => 'Pas encore disponible dans cette version.';

  @override
  String get proErrNoSubscription =>
      'Aucun abonnement actif sur le compte actuel du Play Store. Abonné avec un autre compte Google ? Basculez vers ce compte dans le Play Store (avatar en haut à droite), puis réessayez.';

  @override
  String get proErrAlreadyOwned =>
      'Le compte actuel du Play Store possède déjà cet abonnement — utilisez plutôt « Restaurer l\'achat ».';

  @override
  String get proErrOrderBound =>
      'Cette commande est déjà liée à un autre utilisateur.';

  @override
  String get proErrOrderNotFound =>
      'Commande introuvable ou formule incorrecte.';

  @override
  String get proErrDeviceRevoked =>
      'L\'emplacement de cet appareil a été pris par une activation plus récente.';

  @override
  String get proErrNoVip =>
      'Récompense pas encore confirmée — réessayez dans une minute.';

  @override
  String get proErrPurchaseBound =>
      'Cet abonnement est lié à un autre compte Google. Réessayez et choisissez, dans le sélecteur, le compte utilisé par votre Play Store.';

  @override
  String proErrPurchaseBoundKnown(String account) {
    return 'Cet abonnement est lié à $account. Réessayez et choisissez ce compte.';
  }

  @override
  String proErrGeneric(Object code) {
    return 'Échec : $code';
  }

  @override
  String get proErrCodeInvalid =>
      'Code non reconnu — vérifiez les fautes de frappe.';

  @override
  String get proErrCodeRedeemed =>
      'Ce code est déjà actif sur un autre appareil. Pour le transférer ici, écrivez à hi@dotslash.pro.';

  @override
  String get proErrCodeActivationLimit =>
      'Ce code a changé d\'appareil trop souvent ces derniers temps. Réessayez plus tard, ou écrivez à hi@dotslash.pro.';

  @override
  String get proErrRateLimited =>
      'Trop de tentatives. Attendez une minute et réessayez.';

  @override
  String proErrSlotOccupied(Object slots) {
    return 'Utilisé : $slots';
  }

  @override
  String proSlotEntry(Object name, Object time) {
    return '$name ($time)';
  }

  @override
  String get proSlotToday => 'aujourd\'hui';

  @override
  String proSlotDaysAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'il y a $n jours',
      one: 'il y a 1 jour',
    );
    return '$_temp0';
  }

  @override
  String get proErrRevoked =>
      'Ce droit d\'accès n\'est plus actif. Si vous pensez qu\'il s\'agit d\'une erreur, écrivez à hi@dotslash.pro.';

  @override
  String get privacyOptions => 'Options de confidentialité';

  @override
  String get skinProNotice =>
      'Les skins Neon et Pixel font désormais partie des avantages Pro. Votre choix est conservé et revient avec Pro.';

  @override
  String get skinProNoticeDismiss => 'Compris';

  @override
  String get syncTitle => 'Synchronisation';

  @override
  String get syncSetupTitle => 'Configurer la synchronisation';

  @override
  String get syncSettingsDesc =>
      'Gardez vos comptes synchronisés entre vos appareils via un serveur que vous contrôlez. Tout est chiffré avant de quitter cet appareil.';

  @override
  String get syncSetUp => 'Configurer la synchronisation…';

  @override
  String get syncStatusOk => 'À jour';

  @override
  String get syncStatusSyncing => 'Synchronisation…';

  @override
  String get syncStatusErrorShort =>
      'Échec de la dernière synchronisation — ouvrez pour les détails.';

  @override
  String syncStatusConflicts(int count) {
    return '$count conflit(s) attendent votre décision';
  }

  @override
  String syncLastSync(String time) {
    return 'Dernière synchronisation : $time';
  }

  @override
  String get syncNever => 'jamais';

  @override
  String get syncBackendTitle => 'Où stocker les données ?';

  @override
  String get syncBackendWebdav => 'WebDAV';

  @override
  String get syncBackendWebdavDesc =>
      'Nextcloud, Jianguoyun (坚果云), un NAS — n\'importe quel dossier WebDAV que vous contrôlez.';

  @override
  String get syncBackendGdrive => 'Google Drive';

  @override
  String get syncBackendGdriveSoon => 'Pro · à venir';

  @override
  String get syncServerTitle => 'Serveur';

  @override
  String get syncServerHint =>
      'Jianguoyun exige un mot de passe d\'application (安全选项 → 添加应用密码), pas votre mot de passe de connexion. Une URL de dossier Nextcloud ressemble à https://cloud.example.com/remote.php/dav/files/UTILISATEUR/ava/.';

  @override
  String get syncServerUrlLabel => 'URL du dossier WebDAV';

  @override
  String get syncServerFolderLabel => 'Dossier (facultatif)';

  @override
  String get syncServerFolderHint =>
      'Laissez vide pour utiliser l\'URL telle quelle ; un nom place la bibliothèque dans ce sous-dossier, créé s\'il n\'existe pas.';

  @override
  String get syncServerUserLabel => 'Nom d\'utilisateur';

  @override
  String get syncServerPasswordLabel =>
      'Mot de passe / mot de passe d\'application';

  @override
  String get syncTestConnection => 'Tester la connexion';

  @override
  String get syncErrUrl => 'Saisissez une URL de dossier http(s) valide.';

  @override
  String get syncErrAuth =>
      'Le serveur a refusé le nom d\'utilisateur ou le mot de passe.';

  @override
  String syncErrNetwork(String detail) {
    return 'Impossible de joindre le serveur : $detail';
  }

  @override
  String syncErrServer(String detail) {
    return 'Le serveur a répondu par une erreur : $detail';
  }

  @override
  String get syncErrTls => 'Le certificat du serveur n\'est pas approuvé.';

  @override
  String get syncTlsTitle => 'Certificat de serveur inconnu';

  @override
  String syncTlsBody(String fp) {
    return 'Le système n\'approuve pas le certificat de ce serveur. S\'il s\'agit de votre propre serveur avec un certificat auto-signé, comparez cette empreinte avec celle affichée sur le serveur, et ne l\'approuvez que si elles correspondent exactement.\n\nSHA-256\n$fp';
  }

  @override
  String get syncTlsTrust => 'Approuver ce certificat';

  @override
  String get syncHttpPrivateTitle => 'Connexion non chiffrée';

  @override
  String get syncHttpPrivateBody =>
      'Cette adresse est en HTTP simple sur un réseau privé. Vos données de compte restent chiffrées de bout en bout, mais le mot de passe du serveur circule en clair sur votre réseau.';

  @override
  String get syncHttpPublicTitle => 'HTTP en clair sur Internet';

  @override
  String get syncHttpPublicBody =>
      'Cette adresse est publique et la connexion ne serait pas chiffrée : n\'importe qui entre vous et le serveur peut lire le mot de passe du serveur et se connecter à votre serveur. Les données de compte restent chiffrées. Utilisez plutôt HTTPS ou une adresse de réseau local — ne continuez que si vous acceptez ce risque.';

  @override
  String get syncHttpPublicHold => 'Appui long pour autoriser quand même';

  @override
  String get syncContinue => 'Continuer';

  @override
  String get syncPassphraseNewTitle =>
      'Définir une phrase secrète de synchronisation';

  @override
  String get syncPassphraseNewBody =>
      'Tout est chiffré avec cette phrase secrète avant l\'envoi ; la phrase elle-même ne quitte jamais vos appareils.\n\nSi vous la perdez, personne ne pourra récupérer les données synchronisées — il n\'existe aucune réinitialisation. Au moins 8 caractères ; la longueur compte plus que les symboles.';

  @override
  String get syncPassphraseExistingTitle =>
      'Saisissez la phrase secrète de synchronisation';

  @override
  String syncPassphraseExistingBody(int count) {
    return 'Ce dossier contient déjà une bibliothèque de synchronisation avec $count compte(s). Saisissez la phrase secrète utilisée à sa création.';
  }

  @override
  String get syncPassphraseLabel => 'Phrase secrète de synchronisation';

  @override
  String get syncPassphraseConfirmLabel => 'Confirmer la phrase secrète';

  @override
  String get syncPassphraseTooShort => 'Au moins 8 caractères.';

  @override
  String get syncPassphraseMismatch =>
      'Les phrases secrètes ne correspondent pas.';

  @override
  String get syncPassphraseWrong =>
      'Cette phrase secrète n\'ouvre pas cette bibliothèque.';

  @override
  String get syncPreviewTitle => 'Première synchronisation';

  @override
  String get syncPreviewEmpty =>
      'Rien à transférer pour l\'instant — les comptes se synchroniseront désormais automatiquement.';

  @override
  String syncPreviewPull(int count) {
    return 'À télécharger vers cet appareil : $count compte(s)';
  }

  @override
  String syncPreviewPush(int count) {
    return 'À envoyer depuis cet appareil : $count compte(s)';
  }

  @override
  String syncPreviewConflict(int count) {
    return 'Présents des deux côtés avec un contenu différent : $count — vous choisirez compte par compte après la connexion';
  }

  @override
  String get syncStart => 'Démarrer la synchronisation';

  @override
  String get syncDoneTitle => 'Synchronisation activée';

  @override
  String get syncDoneBody =>
      'Les comptes se synchronisent désormais automatiquement. Sur un nouvel appareil, chaque compte se reconnecte à sa première utilisation — ceux dont le mot de passe est enregistré le font seuls ; les autres le demandent une fois.';

  @override
  String get syncDone => 'Terminé';

  @override
  String get syncNeedsPassphrase =>
      'La phrase secrète enregistrée ne correspond plus à la bibliothèque distante — saisissez-la à nouveau.';

  @override
  String get syncEnterPassphrase => 'Saisir la phrase secrète';

  @override
  String get syncConditionalWarn =>
      'Ce serveur ignore les écritures conditionnelles : deux appareils qui synchronisent au même moment peuvent s\'écraser mutuellement. La synchronisation fonctionne quand même ; évitez les modifications simultanées sur deux appareils.';

  @override
  String get syncConflictsTitle => 'Conflits';

  @override
  String get syncConflictTrashNote =>
      'La version que vous écartez est conservée 30 jours dans la corbeille de synchronisation.';

  @override
  String get syncConflictEditEdit => 'Modifié sur les deux appareils';

  @override
  String get syncConflictEditDelete =>
      'Modifié ici, supprimé sur un autre appareil';

  @override
  String get syncConflictDeleteEdit =>
      'Supprimé ici, modifié sur un autre appareil';

  @override
  String get syncConflictKeepLocal => 'Garder la version locale';

  @override
  String get syncConflictKeepRemote => 'Garder la version distante';

  @override
  String get syncConflictLocalSide => 'Cet appareil';

  @override
  String get syncConflictRemoteSide => 'Autre appareil';

  @override
  String get syncDeleted => 'Supprimé';

  @override
  String get syncConflictHasPassword => 'Mot de passe enregistré';

  @override
  String get syncConflictNoPassword => 'Aucun mot de passe enregistré';

  @override
  String get syncAutoTitle => 'Synchronisation automatique';

  @override
  String get syncAutoDesc =>
      'Synchronise au lancement et après chaque modification. Désactivé, seul le bouton ci-dessous synchronise.';

  @override
  String get syncPasswordsTitle => 'Synchroniser les mots de passe des comptes';

  @override
  String get syncPasswordsDesc =>
      'Les mots de passe permettent à un nouvel appareil de se connecter seul. Modifier ce réglage renvoie tous les comptes.';

  @override
  String get syncAppSettingsTitle =>
      'Synchroniser les réglages de l’application';

  @override
  String get syncAppSettingsDesc =>
      'Les préférences d’apparence et de comportement (habillage, thème, appui long…) vous suivent sur chaque appareil. La langue et la taille du texte restent propres à chaque appareil.';

  @override
  String get syncNowButton => 'Synchroniser maintenant';

  @override
  String get syncViewRemote => 'Voir la bibliothèque distante';

  @override
  String get syncRemoteEmpty => 'La bibliothèque distante est vide.';

  @override
  String get syncRemoteDevices => 'Appareils';

  @override
  String get syncTrashTitle => 'Corbeille de synchronisation';

  @override
  String get syncTrashEmpty =>
      'Vide. Tout ce que la synchronisation supprime ou remplace est conservé ici pendant 30 jours.';

  @override
  String get syncTrashRestore => 'Restaurer';

  @override
  String get syncTrashRestored => 'Compte restauré.';

  @override
  String get syncTrashRestoreFailed =>
      'Impossible de déchiffrer cette entrée avec la phrase secrète actuelle.';

  @override
  String get syncTrashReasonRemoteDelete => 'supprimé par un autre appareil';

  @override
  String get syncTrashReasonConflict => 'remplacé lors d\'un conflit';

  @override
  String get syncChangePassphrase =>
      'Modifier la phrase secrète de synchronisation';

  @override
  String get syncPassphraseChanged =>
      'Phrase secrète modifiée ; tout a été rechiffré. Les autres appareils demanderont la nouvelle phrase secrète.';

  @override
  String syncPassphraseChangeFailed(String reason) {
    return 'Phrase secrète non modifiée : $reason';
  }

  @override
  String get syncDisconnect => 'Déconnecter la synchronisation';

  @override
  String get syncDisconnectBody =>
      'Cet appareil cesse de synchroniser. La bibliothèque distante peut rester pour vos autres appareils — ou être entièrement supprimée du serveur.';

  @override
  String get syncDisconnectKeep => 'Conserver les données distantes';

  @override
  String get syncDisconnectDeleteHold =>
      'Appui long pour supprimer les données distantes';

  @override
  String get netErrTls =>
      'Impossible d\'ouvrir une connexion sécurisée vers Steam. La connexion a été coupée pendant la négociation TLS, ce qui indique en général un réseau qui la filtre ou qui est instable. Essayez un autre réseau — ou un proxy.';

  @override
  String get netErrUnreachable =>
      'Steam est injoignable. Vérifiez votre connexion, puis réessayez.';

  @override
  String get netErrTimeout =>
      'Steam n\'a pas répondu à temps. Le réseau est peut-être lent ou filtré.';

  @override
  String get netErrCert =>
      'Le certificat de Steam n\'a pas été reconnu, AVA a donc fermé la connexion. Quelque chose sur ce réseau inspecte peut-être le trafic.';

  @override
  String netErrServer(int code) {
    return 'Steam a renvoyé une erreur ($code). C\'est généralement temporaire — réessayez dans un instant.';
  }
}
