// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'AVA';

  @override
  String get navAccounts => 'Аккаунты';

  @override
  String get navSettings => 'Настройки';

  @override
  String get unlockTitle => 'Разблокировка';

  @override
  String get unlockPrompt => 'Введите пароль шифрования';

  @override
  String get unlockButton => 'Разблокировать';

  @override
  String get unlockInvalid => 'Неверный пароль.';

  @override
  String get unlockWithBiometric =>
      'Разблокировать биометрией / PIN-кодом устройства';

  @override
  String get unlockLoading => 'Расшифровка…';

  @override
  String get unlockCantUnlock => 'Не удаётся разблокировать?';

  @override
  String get resetVaultTitle => 'Сброс зашифрованных данных';

  @override
  String get resetVaultBody =>
      'Удаляет все записи аккаунтов и ключи шифрования, сохранённые на этом устройстве; после этого нужно заново импортировать резервные копии maFile. На ваши аккаунты Steam и их аутентификаторы это не влияет.\n\nПрименяйте, если правильный PIN-код раз за разом отклоняется — обычно так бывает после восстановления из резервной копии или переноса на другой телефон: аппаратный ключ никогда не покидает исходное устройство, поэтому восстановленные данные расшифровать невозможно.\n\nОтменить это действие нельзя.';

  @override
  String get resetVaultConfirm => 'Удалить и сбросить';

  @override
  String get storeErrorTitle => 'Не удаётся прочитать сохранённые данные';

  @override
  String get storeErrorBody =>
      'Локальная база аккаунтов AVA (manifest.json) отсутствует или повреждена. Так бывает после прерванной записи или неполного восстановления. Сначала попробуйте ещё раз; если ошибка повторяется, сбросьте данные и заново импортируйте резервные копии maFile.';

  @override
  String get storeRepair => 'Попробовать восстановить';

  @override
  String storeActionFailed(String error) {
    return 'Не удалось выполнить действие: $error';
  }

  @override
  String get pinSetupTitle => 'PIN-код для разблокировки';

  @override
  String get pinSetupPrompt =>
      'Защитите AVA 6-значным PIN-кодом. Его (или отпечаток пальца) нужно будет вводить при разблокировке.';

  @override
  String get pinLabel => '6-значный PIN-код';

  @override
  String get pinConfirmLabel => 'Повторите PIN-код';

  @override
  String get pinSetButton => 'Задать PIN-код';

  @override
  String get settingsSet => 'Задать';

  @override
  String get pinChangeTitle => 'Смена PIN-кода';

  @override
  String get pinCurrentLabel => 'Текущий PIN-код';

  @override
  String get pinNewLabel => 'Новый PIN-код';

  @override
  String get pinSixDigits => 'Введите 6-значный PIN-код.';

  @override
  String get pinMismatch => 'PIN-коды не совпадают.';

  @override
  String get unlockBiometricReason => 'Разблокировать AVA';

  @override
  String get settingsBiometric => 'Разблокировка биометрией';

  @override
  String get settingsBiometricDesc =>
      'Разблокировка отпечатком пальца или PIN-кодом устройства; пароль хранится в хранилище ключей устройства.';

  @override
  String get settingsBiometricNeedPasskey =>
      'Сначала задайте пароль шифрования.';

  @override
  String get settingsBiometricUnavailable =>
      'На этом устройстве не настроены биометрия и блокировка экрана.';

  @override
  String get settingsBiometricEnabled => 'Разблокировка биометрией включена.';

  @override
  String get settingsHoldConfirm => 'Подтверждение удержанием';

  @override
  String get settingsHoldConfirmDesc =>
      'Необратимые действия (обмены, подтверждения) требуют нажатия с удержанием. Если выключено, одно нажатие срабатывает сразу; для массовых действий запрос остаётся.';

  @override
  String get settingsDeleteHold => 'Удаление удержанием';

  @override
  String get settingsDeleteHoldDesc =>
      'Кнопку удаления в диалоге подтверждения нужно удерживать, пока она не зарядится — случайное нажатие не удалит аккаунт.';

  @override
  String get accountSessionInvalid =>
      'Вход недействителен — нажмите, чтобы войти заново';

  @override
  String get settingsHaptics => 'Виброотклик';

  @override
  String get settingsHapticsDesc =>
      'Вибрация во время удержания для подтверждения и по его завершении.';

  @override
  String get settingsBlockScreenshots => 'Запрет скриншотов';

  @override
  String get settingsBlockScreenshotsDesc =>
      'Скрывает AVA от скриншотов, записи экрана и превью в списке недавних приложений. Также гасит окно при демонстрации экрана и не даёт прикладывать скриншоты к отзывам.';

  @override
  String get passkeyLabel => 'Пароль';

  @override
  String get accountsEmpty =>
      'Аккаунтов пока нет. Импортируйте maFile или войдите, чтобы добавить.';

  @override
  String get emptyAddAccount => 'Добавить аккаунт';

  @override
  String get accountReady => 'Готов';

  @override
  String get tutCodeTitle => 'Текущий код';

  @override
  String get tutCodeBody =>
      'Нажмите на крупный код, чтобы скопировать его. Нажмите на имя аккаунта, чтобы переключать логин / никнейм / SteamID.';

  @override
  String get tutSwipeRightTitle => 'Свайп вправо → подтверждения';

  @override
  String get tutSwipeRightBody =>
      'Проведите по аккаунту вправо, чтобы открыть его подтверждения обменов.';

  @override
  String get tutSwipeLeftTitle => 'Свайп влево → другие действия';

  @override
  String get tutSwipeLeftBody =>
      'Свайп влево — обновить сессию, экспортировать maFile или удалить аккаунт.';

  @override
  String get tutLongPressTitle => 'Долгое нажатие → инвентарь и площадка';

  @override
  String get tutLongPressBody =>
      'Нажмите и удерживайте аккаунт, чтобы посмотреть инвентарь и выставить предметы на Торговой площадке Сообщества.';

  @override
  String get tutPullTitle => 'Потяните, чтобы обновить';

  @override
  String get tutPullBody =>
      'Потяните список аккаунтов вниз, чтобы обновить аватары и проверить входы, ожидающие подтверждения.';

  @override
  String get tutSkip => 'Пропустить';

  @override
  String get tutNext => 'Далее';

  @override
  String get tutDone => 'Понятно';

  @override
  String get settingsTutorial => 'Обучение жестам';

  @override
  String get settingsTutorialDesc =>
      'Показать обучение по главному экрану заново (свайпы, долгое нажатие, обновление жестом).';

  @override
  String get settingsTutorialReplay => 'Показать';

  @override
  String get welcomeTitle => 'Добро пожаловать в AVA';

  @override
  String get welcomeSubtitle =>
      'Аутентификатор хранится в зашифрованном виде на этом устройстве. Выберите, с чего начать.';

  @override
  String get welcomeLoginCta => 'Войти в Steam';

  @override
  String get welcomeLoginSub => 'Настроить новый аутентификатор';

  @override
  String get welcomeImportCta => 'Импортировать .maFile';

  @override
  String get welcomeImportSub => 'Перенести существующий аккаунт';

  @override
  String get welcomeSyncCta => 'Восстановить из синхронизации';

  @override
  String get welcomeSyncSub =>
      'Загрузите аккаунты из существующей библиотеки синхронизации';

  @override
  String get copyCode => 'Копировать код';

  @override
  String get codeCopied => 'Код входа скопирован в буфер обмена';

  @override
  String get copied => 'Скопировано в буфер обмена';

  @override
  String get copySteamId => 'Копировать SteamID';

  @override
  String get pendingTitle => 'Ожидают';

  @override
  String get pendingTabConfirmations => 'Подтверждения';

  @override
  String get pendingTabOffers => 'Обмены';

  @override
  String get confirmationsTitle => 'Подтверждения';

  @override
  String get confirmationsEmpty => 'Нет подтверждений в ожидании.';

  @override
  String get confirmationsRefresh => 'Обновить';

  @override
  String get confAccept => 'Принять';

  @override
  String get confDecline => 'Отклонить';

  @override
  String get confSelectAll => 'Выбрать все';

  @override
  String get confAcceptSelected => 'Принять выбранные';

  @override
  String get confDeclineSelected => 'Отклонить выбранные';

  @override
  String get confAcceptAll => 'Принять все';

  @override
  String get confRejectAll => 'Отклонить все';

  @override
  String confAcceptAllConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Принять все $count подтверждения?',
      many: 'Принять все $count подтверждений?',
      few: 'Принять все $count подтверждения?',
      one: 'Принять $count подтверждение?',
    );
    return '$_temp0';
  }

  @override
  String confRejectAllConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Отклонить все $count подтверждения?',
      many: 'Отклонить все $count подтверждений?',
      few: 'Отклонить все $count подтверждения?',
      one: 'Отклонить $count подтверждение?',
    );
    return '$_temp0';
  }

  @override
  String get confAcceptAllWarn =>
      'Это одобрит сразу все обмены и лоты, ожидающие подтверждения. Убедитесь, что узнаёте каждый из них.';

  @override
  String get confRejectAllWarn =>
      'Это отменит сразу все подтверждения в ожидании.';

  @override
  String confPending(int count) {
    return 'Ожидают: $count';
  }

  @override
  String get confAllProcessed => 'Все обработаны';

  @override
  String get confTypeTrade => 'Обмен';

  @override
  String get confTypeMarket => 'Лот на площадке';

  @override
  String get confTypeOther => 'Подтверждение';

  @override
  String get confTypeFamilyJoin => 'Приглашение в семью';

  @override
  String get confTypeApiKey => 'Ключ API';

  @override
  String get confTypePhoneChange => 'Смена номера телефона';

  @override
  String get confTypeAccountRecovery => 'Восстановление аккаунта';

  @override
  String get confTypeFeatureOptOut => 'Отказ от функции';

  @override
  String confProcessing(int count) {
    return 'Обработка подтверждений: $count…';
  }

  @override
  String confResult(int ok, int fail) {
    return 'Успешно: $ok, с ошибкой: $fail';
  }

  @override
  String get confNeedsLogin =>
      'Сессия истекла — войдите снова, чтобы обновить этот аккаунт.';

  @override
  String get confRejected =>
      'Steam отклонил запрос на подтверждение. Обычно это значит, что maFile не соответствует аутентификатору, привязанному к аккаунту сейчас (частое дело с купленными аккаунтами) — удалите аутентификатор и привяжите его заново либо импортируйте нужный maFile. Причиной может быть и сильное расхождение часов.';

  @override
  String get offersSegReceived => 'Входящие';

  @override
  String get offersSegSent => 'Исходящие';

  @override
  String get offersSegHistory => 'История';

  @override
  String get offersEmpty => 'Предложений обмена нет.';

  @override
  String get offerGift => 'Подарок — вы ничего не отдаёте';

  @override
  String get offerOneSided => 'Вы отдаёте предметы и не получаете ничего';

  @override
  String get offerEscrow => 'Steam задержит предметы до передачи';

  @override
  String get offerAcceptHold => 'Принять удержанием';

  @override
  String get offerDecline => 'Отклонить';

  @override
  String get offerCancel => 'Отменить обмен';

  @override
  String get offerReceiveLabel => 'Вы получаете';

  @override
  String get offerGiveLabel => 'Вы отдаёте';

  @override
  String get offerAccepted =>
      'Обмен принят — подтвердите его на вкладке «Подтверждения»';

  @override
  String get offerAcceptedNoConf => 'Обмен принят.';

  @override
  String offerActionFailed(String msg) {
    return 'Не удалось выполнить действие: $msg';
  }

  @override
  String get offerDeclined => 'Обмен отклонён.';

  @override
  String get offerCanceled => 'Обмен отменён.';

  @override
  String get pendingTabInvites => 'Приглашения';

  @override
  String famInviteTitle(String groupName) {
    return '«$groupName» приглашает вас вступить';
  }

  @override
  String get famInviteTitleGeneric => 'Приглашение в семейную группу';

  @override
  String famInviteFrom(String inviter) {
    return 'Отправитель: $inviter';
  }

  @override
  String famInviteRole(String role) {
    return 'Роль: $role';
  }

  @override
  String famInviteSlots(int used, int total) {
    return 'Участники $used/$total';
  }

  @override
  String get famRoleAdult => 'Взрослый';

  @override
  String get famRoleChild => 'Ребёнок';

  @override
  String famRoleUnknown(int n) {
    return 'Роль №$n';
  }

  @override
  String get famPreflightTitle => 'Проверки перед вступлением';

  @override
  String get famCheckWalletMatch => 'Регион кошелька совпадает';

  @override
  String get famCheckWalletMismatch =>
      'Регион кошелька не совпадает — Steam ограничивает вступление';

  @override
  String get famCheckIpMatch => 'Обычный IP совпадает';

  @override
  String get famCheckIpMismatch =>
      'IP не совпадает с вашим обычным местоположением';

  @override
  String get famCheckCooldown =>
      'После вступления смена семейной группы блокируется на 1 год (ограничение Steam)';

  @override
  String famJoinRestricted(int code) {
    return 'Steam заблокировал вступление (ограничение $code)';
  }

  @override
  String get famInviteJoinHold => 'Вступить удержанием';

  @override
  String get famInviteAwaiting2fa =>
      'Ожидание подтверждения — откройте вкладку «Подтверждения»';

  @override
  String get famInviteJoined => 'Вы вступили ✓';

  @override
  String get famInviteViewGroup => 'Открыть семейную группу ›';

  @override
  String get famJoinSent =>
      'Запрос отправлен — подтвердите его на вкладке «Подтверждения»';

  @override
  String get famJoinDone => 'Вы вступили в семейную группу.';

  @override
  String famJoinFailed(String msg) {
    return 'Не удалось вступить: $msg';
  }

  @override
  String get famInvitesEmpty => 'Нет приглашений в семейную группу.';

  @override
  String get famAccountAction => 'Семейная группа';

  @override
  String get famNotInGroup => 'Этот аккаунт не состоит в семейной группе.';

  @override
  String famSummaryMembers(int used, int total) {
    return 'Участники $used/$total';
  }

  @override
  String famSummaryCooldown(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Ожидание $days дня',
      many: 'Ожидание $days дней',
      few: 'Ожидание $days дня',
      one: 'Ожидание $days день',
    );
    return '$_temp0';
  }

  @override
  String get famInvitesSection => 'Приглашения';

  @override
  String get famSectionMembers => 'Участники';

  @override
  String get famMemberYou => '(вы)';

  @override
  String get famSectionPending => 'Ожидают';

  @override
  String get famPendingComingSoon =>
      'Одобрение покупок появится в одном из следующих обновлений.';

  @override
  String get deviceSessionsAction => 'Устройства';

  @override
  String get deviceSessionsTitle => 'Активные устройства';

  @override
  String get deviceSessionsEmpty =>
      'Для этого аккаунта нет активных устройств.';

  @override
  String get deviceRevokeAction => 'Выйти';

  @override
  String deviceRevokeConfirm(String name) {
    return 'Выйти из аккаунта Steam на устройстве «$name»? Ему потребуется войти заново.';
  }

  @override
  String deviceRevokeDone(String name) {
    return 'Выход выполнен: «$name».';
  }

  @override
  String deviceRevokeFailed(String error) {
    return 'Не удалось выйти на устройстве: $error';
  }

  @override
  String get deviceCurrent => '(это устройство)';

  @override
  String get deviceSignedOut => 'сессия закрыта';

  @override
  String get deviceUnnamed => 'Неизвестное устройство';

  @override
  String deviceLastSeen(String age) {
    return 'активность $age назад';
  }

  @override
  String get devicePlatformSteam => 'Клиент Steam';

  @override
  String get devicePlatformWeb => 'Браузер';

  @override
  String get devicePlatformMobile => 'Мобильное приложение';

  @override
  String get devicePlatformUnknown => 'Неизвестно';

  @override
  String deviceAgeDays(int n) {
    return '$n д';
  }

  @override
  String deviceAgeHours(int n) {
    return '$n ч';
  }

  @override
  String deviceAgeMinutes(int n) {
    return '$n мин';
  }

  @override
  String get deviceAgeNow => 'только что';

  @override
  String get keyRedeemAction => 'Активировать ключ';

  @override
  String get keyRedeemTitle => 'Активация ключа Steam';

  @override
  String keyRedeemFor(String account) {
    return 'Активация в аккаунте: $account';
  }

  @override
  String get keyRedeemHint => 'XXXXX-XXXXX-XXXXX';

  @override
  String get keyRedeemPaste => 'Вставить';

  @override
  String get keyRedeemSubmit => 'Активировать';

  @override
  String get keyRedeemNote =>
      'Активация необратима: продукт добавляется именно в этот аккаунт. После нескольких отклонённых ключей Steam блокирует активацию примерно на час, поэтому проверьте код перед отправкой.';

  @override
  String keyRedeemConfirm(String account) {
    return 'Активировать этот ключ в аккаунте $account? Отменить активацию или перенести продукт в другой аккаунт потом будет нельзя.';
  }

  @override
  String get keyRedeemDone => 'Ключ активирован.';

  @override
  String get keyRedeemGranted => 'Добавлено в библиотеку:';

  @override
  String get keyRedeemNoProducts =>
      'Steam принял ключ, но не назвал продукт. Проверьте библиотеку аккаунта.';

  @override
  String get keyRedeemNetworkError =>
      'Не удалось связаться со Steam. Если истекло время ожидания, запрос всё же мог быть обработан — проверьте библиотеку аккаунта, прежде чем пробовать ключ снова.';

  @override
  String get keyErrInvalid =>
      'Steam не распознаёт этот код. Проверьте, нет ли опечаток — буквы и цифры вроде 0/O и 1/I легко перепутать.';

  @override
  String get keyErrAlreadyOwned => 'У этого аккаунта продукт уже есть.';

  @override
  String get keyErrAlreadyActivated =>
      'Этот ключ уже использован — на этом аккаунте или на другом.';

  @override
  String get keyErrRegionLocked =>
      'Этот продукт нельзя активировать в стране аккаунта.';

  @override
  String get keyErrNeedsBaseProduct =>
      'Это DLC или дополнение; аккаунту сначала нужна базовая игра.';

  @override
  String get keyErrNeedsPs3Login =>
      'В этот продукт нужно сыграть на системе PlayStation®3, прежде чем его можно будет активировать.';

  @override
  String get keyErrRateLimited =>
      'Слишком много отклонённых ключей за последнее время. Steam блокирует активацию примерно на час — попробуйте позже.';

  @override
  String keyErrUnknown(int code) {
    return 'Steam отклонил ключ (код $code).';
  }

  @override
  String get loginOrApprove =>
      '…или просто нажмите «Разрешить» в мобильном приложении Steam.';

  @override
  String get addErrPresent => 'К этому аккаунту уже привязан аутентификатор.';

  @override
  String get addErrConfirmEmail =>
      'Подтвердите письмо, отправленное Steam, и повторите попытку.';

  @override
  String get addErrLocked =>
      'Аккаунт заблокирован или ограничен Steam — восстановите его на help.steampowered.com, прежде чем добавлять аутентификатор.';

  @override
  String get addErrRateLimited =>
      'Слишком много попыток. Подождите немного и попробуйте снова.';

  @override
  String get addErrFailed => 'Не удалось добавить аутентификатор.';

  @override
  String addErrSaveFailed(String code) {
    return 'Не удалось сохранить аутентификатор на этом устройстве, поэтому настройка остановлена до того, как вступила в силу. Запишите этот код отзыва, удалите незавершённый аутентификатор из аккаунта и попробуйте снова: $code';
  }

  @override
  String get addErrBadSms => 'Неверный код из SMS, попробуйте ещё раз.';

  @override
  String get debugLog => 'Журнал отладки';

  @override
  String get debugLogDesc =>
      'Сетевой трейс для диагностики входа и подтверждений';

  @override
  String get feedbackTitle => 'Обратная связь';

  @override
  String get feedbackDesc =>
      'Нашли ошибку или есть идея? Отправьте разработчику напрямую или создайте issue на GitHub для публичного обсуждения.';

  @override
  String get feedbackSend => 'Отправить';

  @override
  String get feedbackMessageLabel => 'Ваше сообщение';

  @override
  String get feedbackMessageHint => 'Что сломалось / чего вам не хватает?';

  @override
  String get feedbackContactLabel => 'Контакт (необязательно)';

  @override
  String get feedbackContactHint =>
      'Почта или имя пользователя — только если хотите ответ';

  @override
  String feedbackAttachNote(String meta) {
    return 'Отправляется вместе с сообщением: $meta';
  }

  @override
  String get feedbackSent => 'Отправлено — спасибо!';

  @override
  String get feedbackFailed =>
      'Не удалось отправить. Проверьте сеть и попробуйте снова.';

  @override
  String feedbackRefused(String reason) {
    return 'Сервис пересылки отклонил этот отчёт: $reason';
  }

  @override
  String feedbackRelayDown(String reason) {
    return 'У сервиса обратной связи неполадки на его стороне ($reason). С вашей сетью всё в порядке — попробуйте позже.';
  }

  @override
  String get feedbackAttachLog => 'Приложить журнал отладки';

  @override
  String get feedbackAttachLogHint =>
      'Недавний сетевой трейс; может содержать имена аккаунтов и SteamID';

  @override
  String get feedbackLogConsentBody =>
      'Журнал отладки содержит недавние строки сетевого трейса этой сессии. В нём могут быть имена ваших аккаунтов и SteamID — но никогда секреты, токены или пароли. Он отправляется только вместе с этим отчётом, как описано в политике конфиденциальности.';

  @override
  String get feedbackLogConsentAgree => 'Принимаю';

  @override
  String get backupReminderTitle => 'Сделайте резервную копию секретов';

  @override
  String get backupReminderBody =>
      'AVA хранит данные аутентификатора только на этом устройстве. Сохраните резервные копии maFile в надёжном месте. Код отзыва (R-код) показывается лишь один раз — при первом добавлении аутентификатора; запишите его тогда же и сохраните: это ваш последний способ удалить аутентификатор, если устройство когда-нибудь потеряется.';

  @override
  String get backupReminderOk => 'Понятно';

  @override
  String get debugCopyAll => 'Копировать всё';

  @override
  String get debugCopied => 'Журнал скопирован';

  @override
  String get debugEmpty => 'Журнал пуст.';

  @override
  String get commonOpen => 'Открыть';

  @override
  String get commonClear => 'Очистить';

  @override
  String addErrFinalize(String detail) {
    return 'Не удалось завершить: $detail';
  }

  @override
  String get loginTitle => 'Вход в Steam';

  @override
  String get loginUsername => 'Имя пользователя';

  @override
  String get loginPassword => 'Пароль';

  @override
  String get loginShowPassword => 'Показать пароль';

  @override
  String get loginHidePassword => 'Скрыть пароль';

  @override
  String get loginSavePassword => 'Сохранить пароль';

  @override
  String get loginSavePasswordHint =>
      'Хранится в maFile этого аккаунта для автоматического обновления сессии; попадёт в незашифрованный экспорт.';

  @override
  String get loginButton => 'Войти';

  @override
  String get loginErrInvalidPassword => 'Неверное имя аккаунта или пароль.';

  @override
  String get loginErrRateLimited =>
      'Слишком много попыток — подождите немного и попробуйте снова.';

  @override
  String get loginErrCodeMismatch =>
      'Код не подошёл — проверьте его и попробуйте снова.';

  @override
  String get loginViaQr => 'Войти по QR-коду';

  @override
  String get loginViaCredentials => 'Войти по паролю';

  @override
  String get loginScanWithApp =>
      'Отсканируйте этот код мобильным приложением Steam';

  @override
  String get loginNeedGuardCode => 'Введите код Steam Guard';

  @override
  String get loginNeedEmailCode => 'Введите код из письма';

  @override
  String get loginSubmitCode => 'Отправить';

  @override
  String get loginWaiting => 'Ожидание подтверждения…';

  @override
  String get loginStepCredentials => 'Данные';

  @override
  String get loginStepConfirm => 'Проверка';

  @override
  String get loginStepDone => 'Готово';

  @override
  String get loginWaitingDesc =>
      'Одобрите этот вход в мобильном приложении Steam. Можно также использовать код из письма или вход по QR-коду.';

  @override
  String loginFailed(String error) {
    return 'Не удалось войти: $error';
  }

  @override
  String get approveTitle => 'Одобрение входа';

  @override
  String get approveScanPrompt =>
      'Отсканируйте QR-код, показанный на устройстве, где вы хотите войти.';

  @override
  String get approvePastePrompt => 'Или вставьте ссылку QR-кода сюда';

  @override
  String get approveButton => 'Одобрить';

  @override
  String get approveReject => 'Отклонить';

  @override
  String get approveSuccess => 'Вход одобрен.';

  @override
  String get approveRejected => 'Вход отклонён.';

  @override
  String get approveBadCode => 'Это не QR-код входа в Steam.';

  @override
  String get approveLocation => 'Местоположение';

  @override
  String get approveDevice => 'Устройство';

  @override
  String get approveWarnStranger => 'Вход начали не вы? Отклоните его.';

  @override
  String get importTitle => 'Импорт аккаунта';

  @override
  String get importPickFile => 'Выберите файл .maFile';

  @override
  String get importSuccess => 'Аккаунт импортирован.';

  @override
  String importFailed(String error) {
    return 'Не удалось импортировать: $error';
  }

  @override
  String get importDuplicateTitle => 'Аккаунт уже существует';

  @override
  String importDuplicateBody(String name) {
    return 'Этот maFile принадлежит аккаунту $name, который уже есть на устройстве. Перезаписать сохранённый аккаунт импортируемым файлом? Аватар из кэша, сохранённый пароль и текущая сессия сохранятся, если их нет в файле.';
  }

  @override
  String importDuplicateBodyUnreadable(String name) {
    return 'Этот maFile принадлежит аккаунту $name: он есть на устройстве, но его сохранённые данные больше не читаются. Импорт полностью заменит его.';
  }

  @override
  String get importDuplicateOverwrite => 'Перезаписать';

  @override
  String get importSessionDeadTitle => 'Активировать этот аккаунт?';

  @override
  String get importSessionDeadBody =>
      'Сессия Steam в этом maFile истекла. Войдите сейчас, чтобы работали подтверждения и одобрение входов — код Steam Guard подставится автоматически.';

  @override
  String get importSessionLater => 'Позже';

  @override
  String get sdaImportAction => 'Импорт папки SDA';

  @override
  String get sdaImportHint =>
      'Выберите несколько файлов .maFile для импорта. Для незашифрованных файлов manifest.json необязателен. Для зашифрованных файлов SDA выберите также manifest.json: он содержит параметры расшифровки.';

  @override
  String get sdaImportNoManifest =>
      'В выбранном нет manifest.json. Отметьте его вместе с файлами .maFile.';

  @override
  String sdaImportBadManifest(String error) {
    return 'Этот manifest.json не читается: $error';
  }

  @override
  String get sdaImportPassTitle => 'Пароль шифрования SDA';

  @override
  String get sdaImportPassBody =>
      'Эти maFile зашифрованы. Введите пароль, который вы задали в Steam Desktop Authenticator.';

  @override
  String get sdaImportWrongPass =>
      'Этим паролем не удалось расшифровать ни один файл.';

  @override
  String sdaImportDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Импортировано $count аккаунтов.',
      many: 'Импортировано $count аккаунтов.',
      few: 'Импортировано $count аккаунта.',
      one: 'Импортирован $count аккаунт.',
    );
    return '$_temp0';
  }

  @override
  String sdaImportSkipped(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Пропущено $count аккаунтов: $names',
      many: 'Пропущено $count аккаунтов: $names',
      few: 'Пропущено $count аккаунта: $names',
      one: 'Пропущен $count аккаунт: $names',
    );
    return '$_temp0';
  }

  @override
  String get sdaImportNothing => 'Ничего не импортировано.';

  @override
  String updateAvailable(String version) {
    return 'Доступна версия $version';
  }

  @override
  String get updateView => 'Открыть';

  @override
  String get updateDismiss => 'Пропустить';

  @override
  String get settingsUpdateCheck => 'Проверять обновления при запуске';

  @override
  String get settingsUpdateCheckDesc =>
      'Один запрос к эндпоинту версий за запуск. Без данных аккаунта; журналы не ведутся.';

  @override
  String get importSessionLoginNow => 'Войти сейчас';

  @override
  String get actionExport => 'Экспорт maFile';

  @override
  String get actionLoginRequests => 'Запросы на вход';

  @override
  String get loginRequestTitle => 'Одобрить вход?';

  @override
  String loginRequestBody(String device, String location) {
    return 'Выполняется вход в ваш аккаунт Steam. Устройство: $device. Местоположение: $location.';
  }

  @override
  String get loginRequestApprove => 'Разрешить';

  @override
  String get loginRequestDeny => 'Отклонить';

  @override
  String get loginNoPending => 'Нет запросов на вход.';

  @override
  String get loginNeedSession =>
      'Сначала войдите, чтобы обновить сессию этого аккаунта.';

  @override
  String get loginApproved => 'Вход разрешён.';

  @override
  String get loginDenied => 'Вход отклонён.';

  @override
  String exportFailed(String error) {
    return 'Не удалось экспортировать: $error';
  }

  @override
  String get exportWarnTitle => 'Экспортировать незашифрованный maFile?';

  @override
  String get exportWarnBody =>
      'Экспортируемый .maFile НЕ зашифрован. В нём секреты Steam Guard этого аккаунта и код отзыва — любой, у кого окажется файл, сможет забрать ваш аутентификатор. Храните его в надёжном месте и удалите, когда закончите.';

  @override
  String get exportIncludePassword =>
      'Также включить сохранённый пароль Steam (не рекомендуется)';

  @override
  String get addAuthTitle => 'Добавить аутентификатор';

  @override
  String get addAuthPhonePrompt => 'Введите номер телефона (с кодом страны)';

  @override
  String get addAuthSmsPrompt =>
      'Введите код из SMS, отправленного на ваш телефон';

  @override
  String get addAuthEmailPrompt =>
      'Введите код активации, который Steam прислал на почту';

  @override
  String addAuthRevocationWarn(String code) {
    return 'Запишите свой код отзыва: $code';
  }

  @override
  String get addAuthConfirmRevocation =>
      'Введите код отзыва ещё раз, чтобы подтвердить, что вы его сохранили';

  @override
  String get addAuthLinked => 'Аутентификатор успешно привязан.';

  @override
  String get addAuthStepPhone => 'Телефон';

  @override
  String get addAuthStepSms => 'Активация';

  @override
  String get addAuthStepRevocation => 'Код отзыва';

  @override
  String get addPresentTitle => 'К этому аккаунту уже привязан аутентификатор';

  @override
  String get addPresentIntro =>
      'Steam допускает только один мобильный аутентификатор на аккаунт. Удалите существующий, затем нажмите «Повторить».';

  @override
  String get addPresentStep1 =>
      'Остался старый телефон или приложение Steam? Откройте его → Steam Guard → Удалить аутентификатор.';

  @override
  String get addPresentStep2 =>
      'Есть код отзыва (Rxxxxx)? Откройте страницу ниже и выберите «Удалить аутентификатор».';

  @override
  String get addPresentStep3 =>
      'Нет доступа ни к тому, ни к другому? Обратитесь в службу поддержки Steam → Помощь → Мобильный аутентификатор Steam Guard.';

  @override
  String get addPresentManageUrl => 'store.steampowered.com/twofactor/manage';

  @override
  String get addPresentCopiedUrl => 'Ссылка скопирована';

  @override
  String get addPresentFallbackTitle => 'Не приходит письмо?';

  @override
  String get addMoveInButton => 'Перенести аутентификатор на это устройство';

  @override
  String get addMoveInBlurb =>
      'Steam отправит на почту аккаунта код. Без 15-дневной задержки обменов.';

  @override
  String get addMoveInSending => 'Отправка кода…';

  @override
  String get addMoveInCodePrompt =>
      'Введите код, который Steam прислал на почту';

  @override
  String get addMoveInWarn =>
      'После подтверждения аутентификатор на старом телефоне сразу перестанет работать, а прежний код отзыва (Rxxxxx) сменится новым. Отменить это нельзя.';

  @override
  String get addMoveInConfirm => 'Перенести сюда';

  @override
  String get addMoveInDone => 'Аутентификатор перенесён на это устройство.';

  @override
  String get addMoveInPopBlocked => 'Идёт перенос аутентификатора — подождите.';

  @override
  String get addErrBadChallengeCode =>
      'Код неверный. Проверьте письмо и попробуйте снова.';

  @override
  String addMoveInSaveFailed(String code, String secret) {
    return 'Аутентификатор перенесён на этот аккаунт, но AVA НЕ смогла сохранить его на этом устройстве. Старый аутентификатор уже не работает, поэтому это единственные копии — запишите их СЕЙЧАС, до того как закроете экран.\n\nКод отзыва: $code\n\nСекрет: $secret';
  }

  @override
  String get addMoveInCopySecrets => 'Копировать';

  @override
  String get addMoveInCopied => 'Скопировано';

  @override
  String get moveInRescueDismiss => 'Данные записаны — закрыть';

  @override
  String get moveInRescueDismissTitle => 'Отбросить эти секреты?';

  @override
  String get moveInRescueDismissBody =>
      'Другой копии у AVA нет. Если вы не записали код отзыва и секрет, доступ к этому аутентификатору будет потерян навсегда.';

  @override
  String get moveInRescueDismissConfirm => 'Данные записаны';

  @override
  String get commonRetry => 'Повторить';

  @override
  String get commonCopy => 'Копировать ссылку';

  @override
  String get commonRefresh => 'Обновить';

  @override
  String get commonExport => 'Экспорт';

  @override
  String get commonDelete => 'Удалить';

  @override
  String get settingsEncryption => 'Шифрование';

  @override
  String get settingsEncryptionDesc =>
      'Локальные maFile зашифрованы случайным 256-битным ключом (AES-256-GCM) из хранилища ключей устройства; ваш 6-значный PIN-код его разблокирует.';

  @override
  String get settingsThemeDesc => 'Переключает стиль всего интерфейса.';

  @override
  String get settingsAppearance => 'Оформление';

  @override
  String get settingsAppearanceDesc =>
      'Светлый или тёмный для стандартного вида. Активный скин переопределяет эту настройку.';

  @override
  String get settingsTextSize => 'Размер текста';

  @override
  String get settingsTextSizeDesc =>
      'Применяется поверх системного размера шрифта.';

  @override
  String get textSizeSmall => 'Мелкий';

  @override
  String get textSizeMedium => 'Средний';

  @override
  String get textSizeLarge => 'Крупный';

  @override
  String get settingsSkin => 'Скины';

  @override
  String get settingsSkinDesc =>
      'Полностью оформленные стили со своими шрифтами и эффектами.';

  @override
  String get themeSystem => 'Как в системе';

  @override
  String get skinNone => 'Нет';

  @override
  String get settingsChange => 'Изменить';

  @override
  String get settingsSetPasskey => 'Задать / изменить пароль шифрования';

  @override
  String get settingsAutoConfirmMarket => 'Автоподтверждение на площадке';

  @override
  String get settingsAutoConfirmMarketDesc =>
      'Заранее отмечает флажок подтверждения при выставлении предмета, чтобы новый лот подтверждался сразу после создания. В фоне ничего не подтверждается.';

  @override
  String get settingsLanguage => 'Язык';

  @override
  String get settingsLanguageSystem => 'Как в системе';

  @override
  String get settingsTheme => 'Тема';

  @override
  String get themeNeon => 'Неон';

  @override
  String get themePixel => 'Пиксель';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get themeLight => 'Светлая';

  @override
  String get settingsAbout => 'О приложении';

  @override
  String get aboutTagline =>
      'Аутентификатор Steam Guard с открытым кодом, сделан на Flutter.';

  @override
  String get aboutSourceCode => 'Исходный код';

  @override
  String get aboutAuthor => 'Автор';

  @override
  String get aboutLicense => 'Лицензия';

  @override
  String get aboutPrivacy => 'Политика конфиденциальности';

  @override
  String get privacyConsentTitle => 'Ваша конфиденциальность';

  @override
  String get privacyConsentBody =>
      'AVA хранит ваши аккаунты Steam и секреты на этом устройстве — они никогда не выгружаются, если только вы не настроите необязательную синхронизацию с выбранным вами сервером, и даже тогда всё сначала шифруется на этом устройстве. Регистрация не нужна. Запросы к Steam идут напрямую в Valve. Два сервиса разработчика вызываются только по необходимости: проверка Pro и обратная связь (только когда вы нажимаете «отправить»). Play-версия на бесплатном плане также показывает рекламу. Никакой слежки и аналитики. Всё это описано в политике конфиденциальности — продолжая, вы её принимаете.';

  @override
  String get privacyUpdateTitle => 'Политика конфиденциальности обновлена';

  @override
  String get privacyUpdateBody =>
      'Уведомление о конфиденциальности изменилось с тех пор, как вы его приняли. Новое: AVA теперь может синхронизировать библиотеку аккаунтов между вашими устройствами через выбранный вами сервер — по умолчанию выключено, всё шифруется на этом устройстве до отправки, разработчик не держит сервера синхронизации. Прочтите актуальное уведомление ниже.';

  @override
  String get privacyConsentScrollHint =>
      'Прокрутите до конца, чтобы продолжить';

  @override
  String get privacyConsentRead =>
      'Читать политику конфиденциальности полностью';

  @override
  String get privacyConsentAgree => 'Принять и продолжить';

  @override
  String get privacyConsentExit => 'Выйти';

  @override
  String get actionMarket => 'Инвентарь / Площадка';

  @override
  String get marketTabInventory => 'Инвентарь';

  @override
  String get marketTabListings => 'Мои лоты';

  @override
  String get marketSelectGame => 'Выберите игру';

  @override
  String get marketNoItems => 'В этом инвентаре нет предметов.';

  @override
  String get marketNotMarketable => 'Нельзя продать';

  @override
  String get marketSellTitle => 'Выставить на продажу';

  @override
  String get marketYouReceive => 'Вы получите';

  @override
  String get marketBuyerPays => 'Покупатель платит';

  @override
  String get marketLowest => 'Минимум';

  @override
  String get marketMedian => 'Медиана';

  @override
  String get marketHigh => 'Макс.';

  @override
  String get marketLow => 'Мин.';

  @override
  String get marketPriceUnavailable => 'Цена на площадке недоступна';

  @override
  String get marketListButton => 'Выставить на продажу';

  @override
  String get marketListed => 'Выставлено — подтвердите, чтобы завершить.';

  @override
  String get marketListedDone => 'Выставлено и подтверждено.';

  @override
  String marketListedPartial(int listed, int total) {
    return 'Выставлено $listed из $total — остальное не удалось; подтвердите ожидающие на вкладке «Подтверждения».';
  }

  @override
  String marketListedSessionExpired(int listed, int total) {
    return 'Выставлено $listed из $total, затем сессия истекла — войдите снова и подтвердите их.';
  }

  @override
  String marketConfirmPartial(int ok, int total) {
    return 'Выставлено — подтверждено $ok из $total; остальное завершите на вкладке «Подтверждения».';
  }

  @override
  String get marketAutoConfirm => 'Подтвердить лот автоматически';

  @override
  String get marketQuantity => 'Количество';

  @override
  String get marketMax => 'Макс.';

  @override
  String marketListFailed(String error) {
    return 'Не удалось выставить: $error';
  }

  @override
  String get marketInvalidPrice => 'Введите корректную цену.';

  @override
  String get marketCancel => 'Снять лот';

  @override
  String get marketCancelled => 'Лот снят.';

  @override
  String get marketNoListings => 'Активных лотов нет.';

  @override
  String get marketFeeNote =>
      'Комиссии Steam и игры добавляются сверх суммы, которую получите вы.';

  @override
  String get aboutLicenses => 'Лицензии открытого ПО';

  @override
  String get aboutCredits => 'Благодарности';

  @override
  String get aboutCreditsBody =>
      'Вдохновлено Steam Desktop Authenticator и совместимо с его форматом maFile. Разработано независимо на Flutter, Riverpod, Dio, PointyCastle, mobile_scanner, image и других открытых библиотеках.';

  @override
  String get actionLogin => 'Войти / обновить сессию';

  @override
  String get actionConfirmations => 'Ожидают';

  @override
  String get actionRemove => 'Удалить аккаунт';

  @override
  String get actionImport => 'Импорт';

  @override
  String get actionAddAuthenticator => 'Добавить аутентификатор';

  @override
  String get commonCancel => 'Отмена';

  @override
  String get commonOk => 'ОК';

  @override
  String get commonConfirm => 'Подтвердить';

  @override
  String get commonClose => 'Закрыть';

  @override
  String get commonError => 'Ошибка';

  @override
  String get sessionExpired => 'Сессия Steam истекла. Войдите снова.';

  @override
  String get removeConfirm =>
      'Удалить этот аккаунт с устройства? Убедитесь, что резервная копия maFile сохранена.';

  @override
  String get settingsPro => 'AVA Pro';

  @override
  String get proOpen => 'Открыть AVA Pro';

  @override
  String get proStatusFree => 'Бесплатный план';

  @override
  String proStatusPro(Object date) {
    return 'Pro · до $date';
  }

  @override
  String proStatusVip(Object date) {
    return 'VIP · до $date';
  }

  @override
  String get proStatusLifetime => 'Pro · навсегда';

  @override
  String proStatusActivations(Object classes) {
    return 'Активно на: $classes';
  }

  @override
  String proStatusClassThisDevice(Object name) {
    return '$name (это устройство)';
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
      'Возможности Pro — основные функции безопасности навсегда бесплатны.';

  @override
  String get paywallPerkSkins => 'Наборы тем: скины Neon и Pixel';

  @override
  String get paywallPerkNoAds => 'Без баннерной рекламы';

  @override
  String get paywallPerkFuture =>
      'Позже: облачная синхронизация, уведомления об обменах';

  @override
  String get paywallPlayTitle => 'Разблокировать через Google Play';

  @override
  String get paywallSubscribe => 'Подписка · \$0,99/мес';

  @override
  String get paywallWatchAd => 'Реклама · 3 дня VIP';

  @override
  String get paywallRestore => 'Восстановить покупку';

  @override
  String get paywallCnTitle => 'Разблокировать через Afdian';

  @override
  String get paywallAfdianIntro =>
      'Оформите поддержку ¥5/мес на Afdian, затем введите здесь номер заказа для разблокировки.';

  @override
  String get paywallOpenAfdian => 'Открыть Afdian';

  @override
  String get paywallOrderHint => 'Номер заказа Afdian';

  @override
  String get paywallRedeem => 'Разблокировать';

  @override
  String get paywallBetaTitle => 'Спасибо бета-тестерам';

  @override
  String get paywallBetaIntro =>
      'Бета-тестеры получают Pro навсегда — введите свой код.';

  @override
  String get paywallBetaHint => 'Код Pro навсегда';

  @override
  String get paywallBetaRedeem => 'Активировать';

  @override
  String get proResultSuccess => 'Разблокировано — спасибо!';

  @override
  String get proErrCanceled => 'Отменено.';

  @override
  String get proErrNetwork => 'Ошибка сети — попробуйте позже.';

  @override
  String get proErrNotConfigured => 'В этой сборке пока недоступно.';

  @override
  String get proErrNoSubscription =>
      'На текущем аккаунте Play Маркета нет активной подписки. Оформляли её с другого аккаунта Google? Переключитесь на него в Play Маркете (аватар справа вверху) и повторите.';

  @override
  String get proErrAlreadyOwned =>
      'Текущий аккаунт Play Маркета уже владеет этой подпиской — нажмите «Восстановить покупку».';

  @override
  String get proErrOrderBound =>
      'Этот заказ уже привязан к другому пользователю.';

  @override
  String get proErrOrderNotFound => 'Заказ не найден или не совпадает план.';

  @override
  String get proErrDeviceRevoked =>
      'Слот этого устройства занят более новой активацией.';

  @override
  String get proErrNoVip =>
      'Награда ещё не подтверждена — попробуйте через минуту.';

  @override
  String get proErrPurchaseBound =>
      'Эта подписка привязана к другому аккаунту Google. Повторите и выберите в списке тот аккаунт, что использует ваш Play Store.';

  @override
  String proErrPurchaseBoundKnown(String account) {
    return 'Эта подписка привязана к $account. Повторите и выберите этот аккаунт.';
  }

  @override
  String proErrGeneric(Object code) {
    return 'Не удалось: $code';
  }

  @override
  String get proErrCodeInvalid =>
      'Код не распознан — проверьте, нет ли опечаток.';

  @override
  String get proErrCodeRedeemed =>
      'Этот код уже активен на другом устройстве. Чтобы перенести его сюда, напишите на hi@dotslash.pro.';

  @override
  String get proErrCodeActivationLimit =>
      'Этот код в последнее время слишком часто менял устройства. Попробуйте позже или напишите на hi@dotslash.pro.';

  @override
  String get proErrRateLimited =>
      'Слишком много попыток. Подождите минуту и попробуйте снова.';

  @override
  String proErrSlotOccupied(Object slots) {
    return 'Занято: $slots';
  }

  @override
  String proSlotEntry(Object name, Object time) {
    return '$name ($time)';
  }

  @override
  String get proSlotToday => 'сегодня';

  @override
  String proSlotDaysAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n дня назад',
      many: '$n дней назад',
      few: '$n дня назад',
      one: '$n день назад',
    );
    return '$_temp0';
  }

  @override
  String get proErrRevoked =>
      'Эта лицензия больше не активна. Если считаете это ошибкой, напишите на hi@dotslash.pro.';

  @override
  String get privacyOptions => 'Настройки конфиденциальности';

  @override
  String get skinProNotice =>
      'Скины Neon и Pixel теперь входят в Pro. Ваш выбор сохранён и вернётся вместе с Pro.';

  @override
  String get skinProNoticeDismiss => 'Понятно';

  @override
  String get syncTitle => 'Синхронизация';

  @override
  String get syncSetupTitle => 'Настройка синхронизации';

  @override
  String get syncSettingsDesc =>
      'Синхронизация аккаунтов между устройствами через сервер, которым управляете вы. Всё шифруется до того, как покинет это устройство.';

  @override
  String get syncSetUp => 'Настроить синхронизацию…';

  @override
  String get syncStatusOk => 'Всё синхронизировано';

  @override
  String get syncStatusSyncing => 'Синхронизация…';

  @override
  String get syncStatusErrorShort =>
      'Последняя синхронизация не удалась — откройте, чтобы узнать подробности.';

  @override
  String syncStatusConflicts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count конфликта требуют вашего решения',
      many: '$count конфликтов требуют вашего решения',
      few: '$count конфликта требуют вашего решения',
      one: '$count конфликт требует вашего решения',
    );
    return '$_temp0';
  }

  @override
  String syncLastSync(String time) {
    return 'Последняя синхронизация: $time';
  }

  @override
  String get syncNever => 'никогда';

  @override
  String get syncBackendTitle => 'Где хранить данные?';

  @override
  String get syncBackendWebdav => 'WebDAV';

  @override
  String get syncBackendWebdavDesc =>
      'Nextcloud, Jianguoyun (坚果云), NAS — любая папка WebDAV, которой управляете вы.';

  @override
  String get syncBackendGdrive => 'Google Drive';

  @override
  String get syncBackendGdriveSoon => 'Pro · появится позже';

  @override
  String get syncServerTitle => 'Сервер';

  @override
  String get syncServerHint =>
      'Jianguoyun принимает только пароль приложения (安全选项 → 添加应用密码), а не пароль от аккаунта. URL папки Nextcloud выглядит так: https://cloud.example.com/remote.php/dav/files/USER/ava/.';

  @override
  String get syncServerUrlLabel => 'URL папки WebDAV';

  @override
  String get syncServerFolderLabel => 'Папка (необязательно)';

  @override
  String get syncServerFolderHint =>
      'Оставьте пустым, чтобы использовать URL как есть; имя помещает библиотеку в эту подпапку, она создаётся при отсутствии.';

  @override
  String get syncServerUserLabel => 'Имя пользователя';

  @override
  String get syncServerPasswordLabel => 'Пароль / пароль приложения';

  @override
  String get syncTestConnection => 'Проверить подключение';

  @override
  String get syncErrUrl => 'Введите корректный http(s)-адрес папки.';

  @override
  String get syncErrAuth => 'Сервер отклонил имя пользователя или пароль.';

  @override
  String syncErrNetwork(String detail) {
    return 'Не удалось связаться с сервером: $detail';
  }

  @override
  String syncErrServer(String detail) {
    return 'Сервер ответил ошибкой: $detail';
  }

  @override
  String get syncErrTls => 'Сертификат сервера не является доверенным.';

  @override
  String get syncTlsTitle => 'Неизвестный сертификат сервера';

  @override
  String syncTlsBody(String fp) {
    return 'Система не доверяет сертификату этого сервера. Если это ваш собственный сервер с самоподписанным сертификатом, сравните этот отпечаток с показанным на сервере и доверяйте ему только при точном совпадении.\n\nSHA-256\n$fp';
  }

  @override
  String get syncTlsTrust => 'Доверять этому сертификату';

  @override
  String get syncHttpPrivateTitle => 'Незашифрованное соединение';

  @override
  String get syncHttpPrivateBody =>
      'Это адрес с обычным HTTP в частной сети. Сами данные аккаунтов защищены сквозным шифрованием, но пароль сервера передаётся по вашей сети в открытом виде.';

  @override
  String get syncHttpPublicTitle => 'Обычный HTTP через интернет';

  @override
  String get syncHttpPublicBody =>
      'Этот адрес публичный, а соединение будет незашифрованным: любой между вами и сервером сможет прочитать пароль сервера и войти на ваш сервер. Сами данные аккаунтов остаются зашифрованными. Используйте HTTPS или адрес в локальной сети — продолжайте, только если принимаете этот риск.';

  @override
  String get syncHttpPublicHold => 'Всё равно разрешить удержанием';

  @override
  String get syncContinue => 'Продолжить';

  @override
  String get syncPassphraseNewTitle => 'Задайте парольную фразу синхронизации';

  @override
  String get syncPassphraseNewBody =>
      'Всё шифруется этой парольной фразой перед выгрузкой; сама фраза никогда не покидает ваши устройства.\n\nЕсли вы её потеряете, синхронизированные данные не сможет восстановить никто — сброса нет. Не менее 8 символов; длина важнее спецсимволов.';

  @override
  String get syncPassphraseExistingTitle =>
      'Введите парольную фразу синхронизации';

  @override
  String syncPassphraseExistingBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'В этой папке уже есть библиотека синхронизации с $count аккаунтами. Введите парольную фразу, с которой она была создана.',
      many:
          'В этой папке уже есть библиотека синхронизации с $count аккаунтами. Введите парольную фразу, с которой она была создана.',
      few:
          'В этой папке уже есть библиотека синхронизации с $count аккаунтами. Введите парольную фразу, с которой она была создана.',
      one:
          'В этой папке уже есть библиотека синхронизации с $count аккаунтом. Введите парольную фразу, с которой она была создана.',
    );
    return '$_temp0';
  }

  @override
  String get syncPassphraseLabel => 'Парольная фраза синхронизации';

  @override
  String get syncPassphraseConfirmLabel => 'Повторите парольную фразу';

  @override
  String get syncPassphraseTooShort => 'Не менее 8 символов.';

  @override
  String get syncPassphraseMismatch => 'Парольные фразы не совпадают.';

  @override
  String get syncPassphraseWrong =>
      'Эта парольная фраза не подходит к этой библиотеке.';

  @override
  String get syncPreviewTitle => 'Первая синхронизация';

  @override
  String get syncPreviewEmpty =>
      'Переносить пока нечего — дальше аккаунты будут синхронизироваться автоматически.';

  @override
  String syncPreviewPull(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Скачать на это устройство: $count аккаунта',
      many: 'Скачать на это устройство: $count аккаунтов',
      few: 'Скачать на это устройство: $count аккаунта',
      one: 'Скачать на это устройство: $count аккаунт',
    );
    return '$_temp0';
  }

  @override
  String syncPreviewPush(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Выгрузить с этого устройства: $count аккаунта',
      many: 'Выгрузить с этого устройства: $count аккаунтов',
      few: 'Выгрузить с этого устройства: $count аккаунта',
      one: 'Выгрузить с этого устройства: $count аккаунт',
    );
    return '$_temp0';
  }

  @override
  String syncPreviewConflict(int count) {
    return 'С обеих сторон, но с разным содержимым: $count — после подключения вы решите по каждому аккаунту отдельно';
  }

  @override
  String get syncStart => 'Начать синхронизацию';

  @override
  String get syncDoneTitle => 'Синхронизация включена';

  @override
  String get syncDoneBody =>
      'Теперь аккаунты синхронизируются автоматически. На новом устройстве каждый аккаунт при первом использовании входит заново — аккаунты с сохранённым паролем делают это сами, остальные один раз спросят.';

  @override
  String get syncDone => 'Готово';

  @override
  String get syncNeedsPassphrase =>
      'Сохранённая парольная фраза больше не подходит к библиотеке на сервере — введите её заново.';

  @override
  String get syncEnterPassphrase => 'Ввести парольную фразу';

  @override
  String get syncConditionalWarn =>
      'Этот сервер игнорирует условную запись, поэтому два устройства, синхронизирующиеся в один и тот же момент, могут перезаписать друг друга. Синхронизация всё равно работает; просто не меняйте данные одновременно на двух устройствах.';

  @override
  String get syncConflictsTitle => 'Конфликты';

  @override
  String get syncConflictTrashNote =>
      'Сторона, которую вы отбросите, хранится в корзине синхронизации 30 дней.';

  @override
  String get syncConflictEditEdit => 'Изменён на обоих устройствах';

  @override
  String get syncConflictEditDelete =>
      'Изменён здесь, удалён на другом устройстве';

  @override
  String get syncConflictDeleteEdit =>
      'Удалён здесь, изменён на другом устройстве';

  @override
  String get syncConflictKeepLocal => 'Оставить с этого устройства';

  @override
  String get syncConflictKeepRemote => 'Оставить с другого устройства';

  @override
  String get syncConflictLocalSide => 'Это устройство';

  @override
  String get syncConflictRemoteSide => 'Другое устройство';

  @override
  String get syncDeleted => 'Удалён';

  @override
  String get syncConflictHasPassword => 'Пароль сохранён';

  @override
  String get syncConflictNoPassword => 'Пароль не сохранён';

  @override
  String get syncAutoTitle => 'Автоматическая синхронизация';

  @override
  String get syncAutoDesc =>
      'Синхронизация при запуске и после каждого изменения. Если выключено, синхронизирует только кнопка ниже.';

  @override
  String get syncPasswordsTitle => 'Синхронизировать пароли аккаунтов';

  @override
  String get syncPasswordsDesc =>
      'С паролем новое устройство входит в аккаунт само. Изменение этой настройки заново выгружает все аккаунты.';

  @override
  String get syncAppSettingsTitle => 'Синхронизировать настройки приложения';

  @override
  String get syncAppSettingsDesc =>
      'Настройки внешнего вида и поведения (обложка, тема, удержание для подтверждения…) следуют за вами на каждое устройство. Язык и размер текста остаются на каждом устройстве своими.';

  @override
  String get syncNowButton => 'Синхронизировать';

  @override
  String get syncViewRemote => 'Открыть библиотеку на сервере';

  @override
  String get syncRemoteEmpty => 'Библиотека на сервере пуста.';

  @override
  String get syncRemoteDevices => 'Устройства';

  @override
  String get syncTrashTitle => 'Корзина синхронизации';

  @override
  String get syncTrashEmpty =>
      'Пусто. Всё, что синхронизация удаляет или заменяет, хранится здесь 30 дней.';

  @override
  String get syncTrashRestore => 'Восстановить';

  @override
  String get syncTrashRestored => 'Аккаунт восстановлен.';

  @override
  String get syncTrashRestoreFailed =>
      'Эту запись не удаётся расшифровать текущей парольной фразой.';

  @override
  String get syncTrashReasonRemoteDelete => 'удалён другим устройством';

  @override
  String get syncTrashReasonConflict => 'заменён при конфликте';

  @override
  String get syncChangePassphrase => 'Сменить парольную фразу синхронизации';

  @override
  String get syncPassphraseChanged =>
      'Парольная фраза изменена; всё перешифровано. Другие устройства запросят новую фразу.';

  @override
  String syncPassphraseChangeFailed(String reason) {
    return 'Парольная фраза не изменена: $reason';
  }

  @override
  String get syncDisconnect => 'Отключить синхронизацию';

  @override
  String get syncDisconnectBody =>
      'Это устройство перестанет синхронизироваться. Библиотеку на сервере можно оставить для других ваших устройств — или полностью удалить с сервера.';

  @override
  String get syncDisconnectKeep => 'Оставить данные на сервере';

  @override
  String get syncDisconnectDeleteHold => 'Удалить данные с сервера удержанием';

  @override
  String get netErrTls =>
      'Не удалось установить защищённое соединение со Steam. Соединение оборвалось во время TLS-рукопожатия — обычно это значит, что сеть его фильтрует или нестабильна. Попробуйте другую сеть или прокси.';

  @override
  String get netErrUnreachable =>
      'Не удалось связаться со Steam. Проверьте подключение и повторите попытку.';

  @override
  String get netErrTimeout =>
      'Steam не ответил вовремя. Сеть может быть медленной или фильтруемой.';

  @override
  String get netErrCert =>
      'Сертификат Steam не прошёл проверку, поэтому AVA разорвала соединение. Возможно, что-то в этой сети просматривает трафик.';

  @override
  String netErrServer(int code) {
    return 'Steam вернул ошибку ($code). Обычно это временно — повторите попытку чуть позже.';
  }

  @override
  String exportSaved(String path) {
    return 'Сохранено в $path';
  }

  @override
  String get accountSearchHint => 'Поиск аккаунтов';

  @override
  String get accountSearchEmpty => 'Аккаунты не найдены';

  @override
  String get accountSearchClear => 'Очистить поиск';
}
