// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'AVA';

  @override
  String get navAccounts => 'Cuentas';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get unlockTitle => 'Desbloquear';

  @override
  String get unlockPrompt => 'Introduce tu clave de cifrado';

  @override
  String get unlockButton => 'Desbloquear';

  @override
  String get unlockInvalid => 'Esa clave no es válida.';

  @override
  String get unlockWithBiometric =>
      'Desbloquear con biometría / PIN del dispositivo';

  @override
  String get unlockLoading => 'Descifrando…';

  @override
  String get unlockCantUnlock => '¿No puedes desbloquear?';

  @override
  String get resetVaultTitle => 'Restablecer los datos cifrados';

  @override
  String get resetVaultBody =>
      'Esto borra todas las cuentas y la clave de cifrado guardadas en este dispositivo; después tendrás que volver a importar tus copias de los maFiles. Tus cuentas de Steam y sus autenticadores no se ven afectados.\n\nÚsalo cuando el PIN correcto se rechaza una y otra vez, algo típico tras restaurar una copia de seguridad o cambiar de teléfono: como la clave del hardware nunca sale del dispositivo original, los datos restaurados no se pueden descifrar nunca.\n\nEsto no se puede deshacer.';

  @override
  String get resetVaultConfirm => 'Borrar y restablecer';

  @override
  String get storeErrorTitle => 'No se pueden leer los datos guardados';

  @override
  String get storeErrorBody =>
      'La base de datos local de cuentas de AVA (manifest.json) falta o está dañada. Puede ocurrir tras una escritura interrumpida o una restauración incompleta. Reintenta primero; si sigue fallando, restablece y vuelve a importar tus copias de los maFiles.';

  @override
  String get storeRepair => 'Intentar reparar';

  @override
  String storeActionFailed(String error) {
    return 'Error en la operación: $error';
  }

  @override
  String get pinSetupTitle => 'Definir PIN de desbloqueo';

  @override
  String get pinSetupPrompt =>
      'Protege AVA con un PIN de 6 dígitos. Lo usarás (o tu huella) para desbloquear.';

  @override
  String get pinLabel => 'PIN de 6 dígitos';

  @override
  String get pinConfirmLabel => 'Confirmar PIN';

  @override
  String get pinSetButton => 'Definir PIN';

  @override
  String get settingsSet => 'Definir';

  @override
  String get pinChangeTitle => 'Cambiar PIN';

  @override
  String get pinCurrentLabel => 'PIN actual';

  @override
  String get pinNewLabel => 'PIN nuevo';

  @override
  String get pinSixDigits => 'Introduce un PIN de 6 dígitos.';

  @override
  String get pinMismatch => 'Los PIN no coinciden.';

  @override
  String get unlockBiometricReason => 'Desbloquear AVA';

  @override
  String get settingsBiometric => 'Desbloqueo biométrico';

  @override
  String get settingsBiometricDesc =>
      'Desbloquea con tu huella o el PIN del dispositivo; la clave se guarda en el Keystore del dispositivo.';

  @override
  String get settingsBiometricNeedPasskey =>
      'Define primero una clave de cifrado.';

  @override
  String get settingsBiometricUnavailable =>
      'Este dispositivo no tiene biometría ni bloqueo de pantalla configurados.';

  @override
  String get settingsBiometricEnabled => 'Desbloqueo biométrico activado.';

  @override
  String get settingsHoldConfirm => 'Mantener para confirmar';

  @override
  String get settingsHoldConfirmDesc =>
      'Las aceptaciones irreversibles (intercambios, confirmaciones) exigen mantener pulsado. Si lo desactivas, un solo toque actúa al instante; las acciones en lote siguen preguntando antes.';

  @override
  String get settingsHaptics => 'Respuesta háptica';

  @override
  String get settingsHapticsDesc =>
      'Vibra mientras mantienes pulsado para confirmar y al terminar.';

  @override
  String get settingsBlockScreenshots => 'Bloquear capturas';

  @override
  String get settingsBlockScreenshotsDesc =>
      'Oculta AVA en las capturas, la grabación de pantalla y la vista de apps recientes. También deja la ventana en negro al compartir pantalla y te impide adjuntar capturas a los comentarios.';

  @override
  String get passkeyLabel => 'Clave de cifrado';

  @override
  String get accountsEmpty =>
      'Aún no hay cuentas. Importa un maFile o inicia sesión para añadir una.';

  @override
  String get emptyAddAccount => 'Añadir cuenta';

  @override
  String get accountReady => 'Lista';

  @override
  String get tutCodeTitle => 'Código en vivo';

  @override
  String get tutCodeBody =>
      'Toca el código grande para copiarlo. Toca el nombre de la cuenta para alternar entre usuario / apodo / SteamID.';

  @override
  String get tutSwipeRightTitle => 'Desliza a la derecha → confirmaciones';

  @override
  String get tutSwipeRightBody =>
      'Desliza una cuenta hacia la derecha para abrir sus confirmaciones de intercambio.';

  @override
  String get tutSwipeLeftTitle => 'Desliza a la izquierda → más acciones';

  @override
  String get tutSwipeLeftBody =>
      'Desliza a la izquierda para actualizar la sesión, exportar el maFile o quitar la cuenta.';

  @override
  String get tutLongPressTitle => 'Mantén pulsado → inventario y mercado';

  @override
  String get tutLongPressBody =>
      'Mantén pulsada una cuenta para ver su inventario y poner objetos a la venta en el Mercado de la Comunidad.';

  @override
  String get tutPullTitle => 'Desliza para actualizar';

  @override
  String get tutPullBody =>
      'Desliza la lista de cuentas hacia abajo para actualizar los avatares y ver si hay inicios de sesión pendientes.';

  @override
  String get tutSkip => 'Saltar';

  @override
  String get tutNext => 'Siguiente';

  @override
  String get tutDone => 'Entendido';

  @override
  String get settingsTutorial => 'Tutorial de gestos';

  @override
  String get settingsTutorialDesc =>
      'Vuelve a ver la guía de la pantalla principal (deslizar, mantener pulsado, deslizar para actualizar).';

  @override
  String get settingsTutorialReplay => 'Repetir';

  @override
  String get welcomeTitle => 'Te damos la bienvenida a AVA';

  @override
  String get welcomeSubtitle =>
      'Tu autenticador se guarda cifrado en este dispositivo. Elige cómo empezar.';

  @override
  String get welcomeLoginCta => 'Iniciar sesión en Steam';

  @override
  String get welcomeLoginSub => 'Configurar un autenticador nuevo';

  @override
  String get welcomeImportCta => 'Importar .maFile';

  @override
  String get welcomeImportSub => 'Migrar una cuenta existente';

  @override
  String get welcomeSyncCta => 'Restaurar desde sincronización';

  @override
  String get welcomeSyncSub =>
      'Recupera tus cuentas desde una biblioteca de sincronización existente';

  @override
  String get copyCode => 'Copiar código';

  @override
  String get codeCopied => 'Código de inicio de sesión copiado al portapapeles';

  @override
  String get copied => 'Copiado al portapapeles';

  @override
  String get copySteamId => 'Copiar SteamID';

  @override
  String get pendingTitle => 'Pendientes';

  @override
  String get pendingTabConfirmations => 'Confirmaciones';

  @override
  String get pendingTabOffers => 'Ofertas';

  @override
  String get confirmationsTitle => 'Confirmaciones';

  @override
  String get confirmationsEmpty => 'No hay confirmaciones pendientes.';

  @override
  String get confirmationsRefresh => 'Actualizar';

  @override
  String get confAccept => 'Aceptar';

  @override
  String get confDecline => 'Rechazar';

  @override
  String get confSelectAll => 'Seleccionar todo';

  @override
  String get confAcceptSelected => 'Aceptar selección';

  @override
  String get confDeclineSelected => 'Rechazar selección';

  @override
  String get confAcceptAll => 'Aceptar todo';

  @override
  String get confRejectAll => 'Rechazar todo';

  @override
  String confAcceptAllConfirm(int count) {
    return '¿Aceptar las $count confirmaciones?';
  }

  @override
  String confRejectAllConfirm(int count) {
    return '¿Rechazar las $count confirmaciones?';
  }

  @override
  String get confAcceptAllWarn =>
      'Esto aprueba de golpe todos los intercambios y anuncios del Mercado pendientes. Asegúrate de reconocerlos todos.';

  @override
  String get confRejectAllWarn =>
      'Esto cancela de golpe todas las confirmaciones pendientes.';

  @override
  String confPending(int count) {
    return 'Pendientes: $count';
  }

  @override
  String get confAllProcessed => 'Todo procesado';

  @override
  String get confTypeTrade => 'Intercambio';

  @override
  String get confTypeMarket => 'Mercado';

  @override
  String get confTypeOther => 'Confirmación';

  @override
  String get confTypeFamilyJoin => 'Grupo familiar';

  @override
  String get confTypeApiKey => 'Clave de API';

  @override
  String get confTypePhoneChange => 'Cambio de teléfono';

  @override
  String get confTypeAccountRecovery => 'Recuperación de cuenta';

  @override
  String get confTypeFeatureOptOut => 'Exclusión de función';

  @override
  String confProcessing(int count) {
    return 'Procesando $count confirmación(es)…';
  }

  @override
  String confResult(int ok, int fail) {
    return '$ok con éxito, $fail con error';
  }

  @override
  String get confNeedsLogin =>
      'La sesión ha caducado: vuelve a iniciar sesión para actualizar esta cuenta.';

  @override
  String get confRejected =>
      'Steam rechazó la solicitud de confirmación. Suele significar que el maFile no coincide con el autenticador que tiene ahora la cuenta (habitual en cuentas compradas): elimina el autenticador y vuelve a vincularlo, o importa el maFile correcto. Un desfase grande del reloj también puede causarlo.';

  @override
  String get offersSegReceived => 'Recibidas';

  @override
  String get offersSegSent => 'Enviadas';

  @override
  String get offersSegHistory => 'Historial';

  @override
  String get offersEmpty => 'No hay ofertas de intercambio.';

  @override
  String get offerGift => 'Regalo: no entregas nada';

  @override
  String get offerOneSided => 'Entregas objetos y no recibes nada';

  @override
  String get offerEscrow => 'Steam retendrá los objetos antes de entregarlos';

  @override
  String get offerAcceptHold => 'Mantén para aceptar';

  @override
  String get offerDecline => 'Rechazar';

  @override
  String get offerCancel => 'Cancelar oferta';

  @override
  String get offerReceiveLabel => 'Recibes';

  @override
  String get offerGiveLabel => 'Entregas';

  @override
  String get offerAccepted =>
      'Oferta aceptada: confírmala en la pestaña Confirmaciones';

  @override
  String get offerAcceptedNoConf => 'Oferta aceptada.';

  @override
  String offerActionFailed(String msg) {
    return 'Error en la operación: $msg';
  }

  @override
  String get offerDeclined => 'Oferta rechazada.';

  @override
  String get offerCanceled => 'Oferta cancelada.';

  @override
  String get pendingTabInvites => 'Invitaciones';

  @override
  String famInviteTitle(String groupName) {
    return '«$groupName» te invita a unirte';
  }

  @override
  String get famInviteTitleGeneric => 'Invitación a un grupo familiar';

  @override
  String famInviteFrom(String inviter) {
    return 'Invitación de $inviter';
  }

  @override
  String famInviteRole(String role) {
    return 'Rol: $role';
  }

  @override
  String famInviteSlots(int used, int total) {
    return 'Miembros $used/$total';
  }

  @override
  String get famRoleAdult => 'Adulto';

  @override
  String get famRoleChild => 'Menor';

  @override
  String famRoleUnknown(int n) {
    return 'Rol n.º $n';
  }

  @override
  String get famPreflightTitle => 'Verificaciones previas';

  @override
  String get famCheckWalletMatch => 'La región del monedero coincide';

  @override
  String get famCheckWalletMismatch =>
      'La región del monedero no coincide: Steam restringe la unión';

  @override
  String get famCheckIpMatch => 'La IP habitual coincide';

  @override
  String get famCheckIpMismatch =>
      'La IP no coincide con tu ubicación habitual';

  @override
  String get famCheckCooldown =>
      'Al unirte no podrás cambiar de grupo familiar durante 1 año (espera de Steam)';

  @override
  String famJoinRestricted(int code) {
    return 'Steam bloqueó esta unión (restricción $code)';
  }

  @override
  String get famInviteJoinHold => 'Mantén para unirte';

  @override
  String get famInviteAwaiting2fa =>
      'Esperando confirmación: revisa la pestaña Confirmaciones';

  @override
  String get famInviteJoined => 'Te has unido ✓';

  @override
  String get famInviteViewGroup => 'Ver grupo familiar ›';

  @override
  String get famJoinSent =>
      'Solicitud de unión enviada: confírmala en la pestaña Confirmaciones';

  @override
  String get famJoinDone => 'Te has unido al grupo familiar.';

  @override
  String famJoinFailed(String msg) {
    return 'Error al unirse: $msg';
  }

  @override
  String get famInvitesEmpty => 'No hay invitaciones familiares pendientes.';

  @override
  String get famAccountAction => 'Grupo familiar';

  @override
  String get famNotInGroup => 'Esta cuenta no está en ningún grupo familiar.';

  @override
  String famSummaryMembers(int used, int total) {
    return 'Miembros $used/$total';
  }

  @override
  String famSummaryCooldown(int days) {
    return 'Espera $days d';
  }

  @override
  String get famInvitesSection => 'Invitaciones';

  @override
  String get famSectionMembers => 'Miembros';

  @override
  String get famMemberYou => '(tú)';

  @override
  String get famSectionPending => 'Pendientes';

  @override
  String get famPendingComingSoon =>
      'La aprobación de compras llegará en una actualización futura.';

  @override
  String get deviceSessionsAction => 'Dispositivos';

  @override
  String get deviceSessionsTitle => 'Dispositivos con sesión iniciada';

  @override
  String get deviceSessionsEmpty =>
      'No hay dispositivos activos en esta cuenta.';

  @override
  String get deviceRevokeAction => 'Cerrar sesión';

  @override
  String deviceRevokeConfirm(String name) {
    return '¿Cerrar la sesión de «$name» en tu cuenta de Steam? Ese dispositivo tendrá que iniciar sesión de nuevo.';
  }

  @override
  String deviceRevokeDone(String name) {
    return 'Sesión de «$name» cerrada.';
  }

  @override
  String deviceRevokeFailed(String error) {
    return 'No se pudo cerrar la sesión del dispositivo: $error';
  }

  @override
  String get deviceCurrent => '(este dispositivo)';

  @override
  String get deviceSignedOut => 'sesión cerrada';

  @override
  String get deviceUnnamed => 'Dispositivo desconocido';

  @override
  String deviceLastSeen(String age) {
    return 'activo hace $age';
  }

  @override
  String get devicePlatformSteam => 'Cliente de Steam';

  @override
  String get devicePlatformWeb => 'Navegador web';

  @override
  String get devicePlatformMobile => 'App móvil';

  @override
  String get devicePlatformUnknown => 'Desconocido';

  @override
  String deviceAgeDays(int n) {
    return '$n d';
  }

  @override
  String deviceAgeHours(int n) {
    return '$n h';
  }

  @override
  String deviceAgeMinutes(int n) {
    return '$n min';
  }

  @override
  String get deviceAgeNow => 'ahora mismo';

  @override
  String get keyRedeemAction => 'Canjear clave';

  @override
  String get keyRedeemTitle => 'Canjear una clave de Steam';

  @override
  String keyRedeemFor(String account) {
    return 'Se activará en $account';
  }

  @override
  String get keyRedeemHint => 'XXXXX-XXXXX-XXXXX';

  @override
  String get keyRedeemPaste => 'Pegar';

  @override
  String get keyRedeemSubmit => 'Canjear';

  @override
  String get keyRedeemNote =>
      'La activación es permanente y añade el producto a esta cuenta. Tras varias claves rechazadas, Steam bloquea las activaciones durante una hora aproximadamente, así que revisa el código antes de enviarlo.';

  @override
  String keyRedeemConfirm(String account) {
    return '¿Activar esta clave en $account? Después no se puede deshacer ni pasar a otra cuenta.';
  }

  @override
  String get keyRedeemDone => 'Clave activada.';

  @override
  String get keyRedeemGranted => 'Añadido a la biblioteca:';

  @override
  String get keyRedeemNoProducts =>
      'Steam aceptó la clave, pero no indicó el producto. Revisa la biblioteca de la cuenta.';

  @override
  String get keyRedeemNetworkError =>
      'No se pudo conectar con Steam. Si la solicitud agotó el tiempo de espera, puede que Steam ya la haya procesado: revisa la biblioteca de la cuenta antes de volver a probar la clave.';

  @override
  String get keyErrInvalid =>
      'Steam no reconoce este código. Revísalo por si hay erratas: letras y números como 0/O o 1/I se confunden con facilidad.';

  @override
  String get keyErrAlreadyOwned => 'Esta cuenta ya tiene el producto.';

  @override
  String get keyErrAlreadyActivated =>
      'Esta clave ya se ha usado, en esta cuenta o en otra.';

  @override
  String get keyErrRegionLocked =>
      'Este producto no se puede activar en el país de la cuenta.';

  @override
  String get keyErrNeedsBaseProduct =>
      'Esto es un DLC o una expansión; la cuenta necesita antes el juego base.';

  @override
  String get keyErrNeedsPs3Login =>
      'Este producto hay que jugarlo en una consola PlayStation®3 antes de poder activarlo.';

  @override
  String get keyErrRateLimited =>
      'Demasiadas claves rechazadas hace poco. Steam bloquea las activaciones durante una hora aproximadamente; inténtalo más tarde.';

  @override
  String keyErrUnknown(int code) {
    return 'Steam rechazó la clave (código $code).';
  }

  @override
  String get loginOrApprove =>
      '…o simplemente toca «Permitir» en la app móvil de Steam.';

  @override
  String get addErrPresent => 'Esta cuenta ya tiene un autenticador.';

  @override
  String get addErrConfirmEmail =>
      'Confirma el correo que te ha enviado Steam y vuelve a intentarlo.';

  @override
  String get addErrLocked =>
      'Steam ha bloqueado o restringido esta cuenta: recupérala en help.steampowered.com antes de añadir un autenticador.';

  @override
  String get addErrRateLimited =>
      'Demasiados intentos. Espera un rato y vuelve a intentarlo.';

  @override
  String get addErrFailed => 'No se pudo añadir el autenticador.';

  @override
  String addErrSaveFailed(String code) {
    return 'No se pudo guardar el autenticador en este dispositivo, así que la configuración se detuvo antes de aplicarse. Apunta este código de revocación y elimina de tu cuenta el autenticador pendiente; después vuelve a intentarlo: $code';
  }

  @override
  String get addErrBadSms =>
      'El código SMS no es correcto, inténtalo de nuevo.';

  @override
  String get debugLog => 'Registro de depuración';

  @override
  String get debugLogDesc =>
      'Traza de red para diagnosticar inicios de sesión / confirmaciones';

  @override
  String get feedbackTitle => 'Comentarios';

  @override
  String get feedbackDesc =>
      '¿Has encontrado un fallo o tienes una idea? Cuéntaselo directamente al desarrollador o abre una incidencia en GitHub para debatirlo en público.';

  @override
  String get feedbackSend => 'Enviar comentarios';

  @override
  String get feedbackMessageLabel => 'Tus comentarios';

  @override
  String get feedbackMessageHint => '¿Qué ha fallado? ¿Qué te gustaría?';

  @override
  String get feedbackContactLabel => 'Contacto (opcional)';

  @override
  String get feedbackContactHint =>
      'Correo o nombre de usuario, solo si quieres respuesta';

  @override
  String feedbackAttachNote(String meta) {
    return 'Se envía junto con tu mensaje: $meta';
  }

  @override
  String get feedbackSent => 'Comentarios enviados. ¡Gracias!';

  @override
  String get feedbackFailed =>
      'No se pudo enviar. Revisa tu conexión y vuelve a intentarlo.';

  @override
  String feedbackRefused(String reason) {
    return 'El servicio de reenvío rechazó este informe: $reason';
  }

  @override
  String feedbackRelayDown(String reason) {
    return 'El servicio de comentarios tiene un problema por su parte ($reason). Tu conexión está bien; inténtalo más tarde.';
  }

  @override
  String get feedbackAttachLog => 'Adjuntar registro de depuración';

  @override
  String get feedbackAttachLogHint =>
      'Traza de red reciente; puede incluir nombres de cuenta / SteamID';

  @override
  String get feedbackLogConsentBody =>
      'El registro de depuración contiene las líneas recientes de la traza de red de esta sesión. Puede incluir tus nombres de cuenta y tus SteamID, nunca tus secretos, tokens ni contraseñas. Solo se envía junto con este informe, tal como describe la Política de Privacidad.';

  @override
  String get feedbackLogConsentAgree => 'Aceptar';

  @override
  String get backupReminderTitle => 'Haz una copia de tus secretos';

  @override
  String get backupReminderBody =>
      'AVA guarda los datos de tu autenticador solo en este dispositivo. Copia tus maFiles en un lugar seguro. El código de revocación (código R) se muestra una sola vez, al añadir el autenticador por primera vez: apúntalo y guárdalo en ese momento; es tu último recurso para eliminar el autenticador si algún día pierdes este dispositivo.';

  @override
  String get backupReminderOk => 'Entendido';

  @override
  String get debugCopyAll => 'Copiar todo';

  @override
  String get debugCopied => 'Registro copiado';

  @override
  String get debugEmpty => 'Aún no hay registro.';

  @override
  String get commonOpen => 'Abrir';

  @override
  String get commonClear => 'Vaciar';

  @override
  String addErrFinalize(String detail) {
    return 'Error al finalizar: $detail';
  }

  @override
  String get loginTitle => 'Iniciar sesión en Steam';

  @override
  String get loginUsername => 'Nombre de usuario';

  @override
  String get loginPassword => 'Contraseña';

  @override
  String get loginShowPassword => 'Mostrar contraseña';

  @override
  String get loginHidePassword => 'Ocultar contraseña';

  @override
  String get loginSavePassword => 'Guardar contraseña';

  @override
  String get loginSavePasswordHint =>
      'Se guarda en el maFile de esta cuenta para renovar la sesión automáticamente; una exportación sin cifrar la incluirá.';

  @override
  String get loginButton => 'Iniciar sesión';

  @override
  String get loginErrInvalidPassword =>
      'Nombre de cuenta o contraseña incorrectos.';

  @override
  String get loginErrRateLimited =>
      'Demasiados intentos: espera un rato y vuelve a intentarlo.';

  @override
  String get loginErrCodeMismatch =>
      'Ese código no coincide; revísalo e inténtalo de nuevo.';

  @override
  String get loginViaQr => 'Iniciar sesión con código QR';

  @override
  String get loginViaCredentials => 'Iniciar sesión con contraseña';

  @override
  String get loginScanWithApp =>
      'Escanea este código con la app móvil de Steam';

  @override
  String get loginNeedGuardCode => 'Introduce el código de Steam Guard';

  @override
  String get loginNeedEmailCode => 'Introduce el código enviado a tu correo';

  @override
  String get loginSubmitCode => 'Enviar';

  @override
  String get loginWaiting => 'Esperando confirmación…';

  @override
  String get loginStepCredentials => 'Credenciales';

  @override
  String get loginStepConfirm => 'Confirmar';

  @override
  String get loginStepDone => 'Listo';

  @override
  String get loginWaitingDesc =>
      'Aprueba este inicio de sesión en la app móvil de Steam. También puedes usar un código por correo o iniciar sesión con QR.';

  @override
  String loginFailed(String error) {
    return 'Error al iniciar sesión: $error';
  }

  @override
  String get approveTitle => 'Aprobar inicio de sesión';

  @override
  String get approveScanPrompt =>
      'Escanea el código QR que aparece en el dispositivo donde quieres iniciar sesión.';

  @override
  String get approvePastePrompt => 'O pega aquí el enlace del código QR';

  @override
  String get approveButton => 'Aprobar';

  @override
  String get approveReject => 'Rechazar';

  @override
  String get approveSuccess => 'Inicio de sesión aprobado.';

  @override
  String get approveRejected => 'Inicio de sesión rechazado.';

  @override
  String get approveBadCode =>
      'Ese no es un código QR de inicio de sesión de Steam.';

  @override
  String get approveLocation => 'Ubicación';

  @override
  String get approveDevice => 'Dispositivo';

  @override
  String get approveWarnStranger =>
      '¿No has iniciado tú este acceso? Recházalo.';

  @override
  String get importTitle => 'Importar cuenta';

  @override
  String get importPickFile => 'Elegir un .maFile';

  @override
  String get importSuccess => 'Cuenta importada.';

  @override
  String importFailed(String error) {
    return 'Error al importar: $error';
  }

  @override
  String get importDuplicateTitle => 'La cuenta ya existe';

  @override
  String importDuplicateBody(String name) {
    return 'Este maFile es de $name, que ya está en este dispositivo. ¿Quieres sobrescribir la cuenta guardada con el archivo importado? Su avatar en caché, la contraseña guardada y la sesión actual se conservan cuando el archivo no los incluye.';
  }

  @override
  String importDuplicateBodyUnreadable(String name) {
    return 'Este maFile es de $name, que existe en este dispositivo pero cuyos datos guardados ya no se pueden leer. Al importar se reemplazará por completo.';
  }

  @override
  String get importDuplicateOverwrite => 'Sobrescribir';

  @override
  String get importSessionDeadTitle => '¿Activar esta cuenta?';

  @override
  String get importSessionDeadBody =>
      'La sesión de Steam de este maFile ha caducado. Inicia sesión ahora para poder usar las confirmaciones y aprobar accesos: el código de Steam Guard se completará automáticamente.';

  @override
  String get importSessionLater => 'Más tarde';

  @override
  String get sdaImportAction => 'Importar una carpeta de SDA';

  @override
  String get sdaImportHint =>
      'Elige tu carpeta maFiles de Steam Desktop Authenticator: selecciona manifest.json junto con los archivos .maFile. Hacen falta los dos: si tenías activado el cifrado de SDA, los parámetros de descifrado están en manifest.json, no dentro del maFile.';

  @override
  String get sdaImportNoManifest =>
      'No hay ningún manifest.json en esa selección. Selecciónalo junto con los archivos .maFile.';

  @override
  String sdaImportBadManifest(String error) {
    return 'Ese manifest.json no se puede leer: $error';
  }

  @override
  String get sdaImportPassTitle => 'Clave de cifrado de SDA';

  @override
  String get sdaImportPassBody =>
      'Estos maFiles están cifrados. Introduce la clave que pusiste en Steam Desktop Authenticator.';

  @override
  String get sdaImportWrongPass =>
      'Esa clave no descifró ninguno de los archivos.';

  @override
  String sdaImportDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cuentas importadas.',
      one: '1 cuenta importada.',
    );
    return '$_temp0';
  }

  @override
  String sdaImportSkipped(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cuentas omitidas: $names',
      one: '1 cuenta omitida: $names',
    );
    return '$_temp0';
  }

  @override
  String get sdaImportNothing => 'No se importó nada.';

  @override
  String get importSessionLoginNow => 'Iniciar sesión';

  @override
  String get actionExport => 'Exportar maFile';

  @override
  String get actionLoginRequests => 'Solicitudes de acceso';

  @override
  String get loginRequestTitle => '¿Aprobar el inicio de sesión?';

  @override
  String loginRequestBody(String device, String location) {
    return '$device está iniciando sesión en tu cuenta de Steam desde $location.';
  }

  @override
  String get loginRequestApprove => 'Permitir';

  @override
  String get loginRequestDeny => 'Denegar';

  @override
  String get loginNoPending => 'No hay solicitudes de acceso pendientes.';

  @override
  String get loginNeedSession =>
      'Inicia sesión primero para renovar la sesión de esta cuenta.';

  @override
  String get loginApproved => 'Acceso permitido.';

  @override
  String get loginDenied => 'Acceso denegado.';

  @override
  String exportFailed(String error) {
    return 'Error al exportar: $error';
  }

  @override
  String get exportWarnTitle => '¿Exportar el maFile sin cifrar?';

  @override
  String get exportWarnBody =>
      'El .maFile exportado NO está cifrado. Contiene los secretos de Steam Guard de esta cuenta y su código de revocación: cualquiera que tenga el archivo puede apoderarse de tu autenticador. Guárdalo en un lugar seguro y bórralo cuando termines.';

  @override
  String get exportIncludePassword =>
      'Incluir también la contraseña de Steam guardada (no recomendado)';

  @override
  String get addAuthTitle => 'Añadir autenticador';

  @override
  String get addAuthPhonePrompt =>
      'Introduce tu número de teléfono (con prefijo del país)';

  @override
  String get addAuthSmsPrompt =>
      'Introduce el código SMS enviado a tu teléfono';

  @override
  String get addAuthEmailPrompt =>
      'Introduce el código de activación que Steam te envió por correo';

  @override
  String addAuthRevocationWarn(String code) {
    return 'Apunta tu código de revocación: $code';
  }

  @override
  String get addAuthConfirmRevocation =>
      'Vuelve a escribir tu código de revocación para confirmar que lo has guardado';

  @override
  String get addAuthLinked => 'Autenticador vinculado correctamente.';

  @override
  String get addAuthStepPhone => 'Teléfono';

  @override
  String get addAuthStepSms => 'Activar';

  @override
  String get addAuthStepRevocation => 'Revocación';

  @override
  String get addPresentTitle => 'Esta cuenta ya tiene un autenticador';

  @override
  String get addPresentIntro =>
      'Steam solo permite un autenticador móvil por cuenta. Elimina el actual y luego toca Reintentar.';

  @override
  String get addPresentStep1 =>
      '¿Aún tienes el teléfono antiguo o la app de Steam? Ábrela → Steam Guard → Eliminar autenticador.';

  @override
  String get addPresentStep2 =>
      '¿Tienes tu código de revocación (Rxxxxx)? Abre la página de abajo y elige «Eliminar autenticador».';

  @override
  String get addPresentStep3 =>
      '¿Has perdido el acceso a ambos? Ve a Soporte de Steam → Ayuda → Autenticador móvil de Steam Guard.';

  @override
  String get addPresentManageUrl => 'store.steampowered.com/twofactor/manage';

  @override
  String get addPresentCopiedUrl => 'Enlace copiado';

  @override
  String get addPresentFallbackTitle => '¿No recibes el correo?';

  @override
  String get addMoveInButton => 'Mover el autenticador a este dispositivo';

  @override
  String get addMoveInBlurb =>
      'Steam enviará un código al correo de esta cuenta. Sin retención de intercambios de 15 días.';

  @override
  String get addMoveInSending => 'Enviando el código…';

  @override
  String get addMoveInCodePrompt =>
      'Introduce el código que Steam te envió por correo';

  @override
  String get addMoveInWarn =>
      'En cuanto confirmes: el autenticador de tu teléfono antiguo dejará de funcionar de inmediato y tu código de revocación anterior (Rxxxxx) se sustituirá por uno nuevo. Esto no se puede deshacer.';

  @override
  String get addMoveInConfirm => 'Moverlo aquí';

  @override
  String get addMoveInDone => 'Autenticador movido a este dispositivo.';

  @override
  String get addMoveInPopBlocked =>
      'Moviendo el autenticador; espera un momento.';

  @override
  String get addErrBadChallengeCode =>
      'Ese código no es correcto. Revisa el correo e inténtalo de nuevo.';

  @override
  String addMoveInSaveFailed(String code, String secret) {
    return 'El autenticador se movió a esta cuenta, pero AVA NO pudo guardarlo en este dispositivo. Tu autenticador anterior ya no funciona, así que estas son las únicas copias: apúntalas AHORA, antes de cerrar esta pantalla.\n\nCódigo de revocación: $code\n\nSecreto: $secret';
  }

  @override
  String get addMoveInCopySecrets => 'Copiar';

  @override
  String get addMoveInCopied => 'Copiado';

  @override
  String get moveInRescueDismiss => 'Ya los he guardado: cerrar';

  @override
  String get moveInRescueDismissTitle => '¿Descartar estos secretos?';

  @override
  String get moveInRescueDismissBody =>
      'AVA no conserva ninguna otra copia. Si no has apuntado el código de revocación y el secreto, perderás para siempre el acceso a este autenticador.';

  @override
  String get moveInRescueDismissConfirm => 'Ya los he guardado';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonCopy => 'Copiar enlace';

  @override
  String get commonRefresh => 'Actualizar';

  @override
  String get commonExport => 'Exportar';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get settingsEncryption => 'Cifrado';

  @override
  String get settingsEncryptionDesc =>
      'Tus maFiles locales se cifran con una clave aleatoria de 256 bits (AES-256-GCM) guardada en el Keystore del dispositivo; tu PIN de 6 dígitos la desbloquea.';

  @override
  String get settingsThemeDesc => 'Cambia el estilo de toda la interfaz.';

  @override
  String get settingsAppearance => 'Apariencia';

  @override
  String get settingsAppearanceDesc =>
      'Claro u oscuro para el aspecto estándar. Una skin lo sustituye mientras esté activa.';

  @override
  String get settingsTextSize => 'Tamaño del texto';

  @override
  String get settingsTextSizeDesc =>
      'Se aplica sobre el tamaño de fuente del sistema.';

  @override
  String get textSizeSmall => 'Pequeño';

  @override
  String get textSizeMedium => 'Mediano';

  @override
  String get textSizeLarge => 'Grande';

  @override
  String get settingsSkin => 'Skins';

  @override
  String get settingsSkinDesc =>
      'Aspectos completos con tipografía y efectos propios.';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get skinNone => 'Ninguna';

  @override
  String get settingsChange => 'Cambiar';

  @override
  String get settingsSetPasskey => 'Definir / cambiar la clave de cifrado';

  @override
  String get settingsAutoConfirmMarket => 'Autoconfirmar ventas del Mercado';

  @override
  String get settingsAutoConfirmMarketDesc =>
      'Marca de antemano la casilla de confirmación al poner un objeto a la venta, para que el anuncio nuevo se confirme justo después de crearlo. Nunca confirma nada en segundo plano.';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsLanguageSystem => 'Predeterminado del sistema';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get themeNeon => 'Neon';

  @override
  String get themePixel => 'Pixel';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get themeLight => 'Claro';

  @override
  String get settingsAbout => 'Acerca de';

  @override
  String get aboutTagline =>
      'Un autenticador de Steam Guard de código abierto, hecho con Flutter.';

  @override
  String get aboutSourceCode => 'Código fuente';

  @override
  String get aboutAuthor => 'Autor';

  @override
  String get aboutLicense => 'Licencia';

  @override
  String get aboutPrivacy => 'Política de Privacidad';

  @override
  String get privacyConsentTitle => 'Tu privacidad';

  @override
  String get privacyConsentBody =>
      'AVA guarda tus cuentas de Steam y sus secretos en este dispositivo: nunca se suben a ningún sitio y no hay que crear ninguna cuenta. Las peticiones de Steam van directas a Valve. Dos servicios propios del desarrollador solo se contactan cuando hacen falta: la comprobación de la licencia Pro y los comentarios (solo cuando pulsas Enviar). La versión de Play además muestra anuncios en el plan gratuito. No hay ningún seguimiento ni analítica. Todo esto está detallado en la Política de Privacidad: al continuar, la aceptas.';

  @override
  String get privacyUpdateTitle => 'Política de Privacidad actualizada';

  @override
  String get privacyUpdateBody =>
      'El aviso que aceptaste antes describía AVA como una app sin servidor propio que solo se conecta con Valve. Eso no era exacto y ya está corregido: el funcionamiento de la app no ha cambiado, solo la descripción. Lee a continuación el aviso vigente.';

  @override
  String get privacyConsentScrollHint =>
      'Desplázate hasta el final para continuar';

  @override
  String get privacyConsentRead => 'Leer la Política de Privacidad completa';

  @override
  String get privacyConsentAgree => 'Aceptar y continuar';

  @override
  String get privacyConsentExit => 'Salir';

  @override
  String get actionMarket => 'Inventario / Mercado';

  @override
  String get marketTabInventory => 'Inventario';

  @override
  String get marketTabListings => 'Mis anuncios';

  @override
  String get marketSelectGame => 'Elige un juego';

  @override
  String get marketNoItems => 'No hay objetos en este inventario.';

  @override
  String get marketNotMarketable => 'No se puede vender';

  @override
  String get marketSellTitle => 'Poner a la venta';

  @override
  String get marketYouReceive => 'Recibes';

  @override
  String get marketBuyerPays => 'Paga el comprador';

  @override
  String get marketLowest => 'Mínimo';

  @override
  String get marketMedian => 'Mediana';

  @override
  String get marketHigh => 'Máx.';

  @override
  String get marketLow => 'Mín.';

  @override
  String get marketPriceUnavailable => 'Precio de mercado no disponible';

  @override
  String get marketListButton => 'Poner a la venta';

  @override
  String get marketListed => 'Puesto a la venta: confírmalo para terminar.';

  @override
  String get marketListedDone => 'Puesto a la venta y confirmado.';

  @override
  String marketListedPartial(int listed, int total) {
    return '$listed de $total puestos a la venta; el resto falló. Confirma los pendientes en Confirmaciones.';
  }

  @override
  String marketListedSessionExpired(int listed, int total) {
    return '$listed de $total puestos a la venta y luego caducó la sesión: vuelve a iniciar sesión y confírmalos.';
  }

  @override
  String marketConfirmPartial(int ok, int total) {
    return 'A la venta: $ok de $total confirmados; termina el resto en Confirmaciones.';
  }

  @override
  String get marketAutoConfirm => 'Confirmar el anuncio automáticamente';

  @override
  String get marketQuantity => 'Cantidad';

  @override
  String get marketMax => 'Máx.';

  @override
  String marketListFailed(String error) {
    return 'Error al poner a la venta: $error';
  }

  @override
  String get marketInvalidPrice => 'Introduce un precio válido.';

  @override
  String get marketCancel => 'Retirar de la venta';

  @override
  String get marketCancelled => 'Anuncio retirado.';

  @override
  String get marketNoListings => 'No hay anuncios activos.';

  @override
  String get marketFeeNote =>
      'Las comisiones de Steam y del juego se suman a lo que recibes tú.';

  @override
  String get aboutLicenses => 'Licencias de código abierto';

  @override
  String get aboutCredits => 'Créditos';

  @override
  String get aboutCreditsBody =>
      'Inspirado en Steam Desktop Authenticator y compatible con su formato maFile. Desarrollado de forma independiente con Flutter, Riverpod, Dio, PointyCastle, mobile_scanner, image y otras bibliotecas de código abierto.';

  @override
  String get actionLogin => 'Iniciar sesión / renovar sesión';

  @override
  String get actionConfirmations => 'Pendientes';

  @override
  String get actionRemove => 'Quitar cuenta';

  @override
  String get actionImport => 'Importar';

  @override
  String get actionAddAuthenticator => 'Añadir autenticador';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonOk => 'Aceptar';

  @override
  String get commonConfirm => 'Confirmar';

  @override
  String get commonClose => 'Cerrar';

  @override
  String get commonError => 'Error';

  @override
  String get sessionExpired =>
      'Tu sesión de Steam ha caducado. Vuelve a iniciar sesión.';

  @override
  String get removeConfirm =>
      '¿Quitar esta cuenta de este dispositivo? Asegúrate de tener una copia de seguridad del maFile.';

  @override
  String get settingsPro => 'AVA Pro';

  @override
  String get proOpen => 'Ver AVA Pro';

  @override
  String get proStatusFree => 'Plan gratuito';

  @override
  String proStatusPro(Object date) {
    return 'Pro · hasta $date';
  }

  @override
  String proStatusVip(Object date) {
    return 'VIP · hasta $date';
  }

  @override
  String get proStatusLifetime => 'Pro · de por vida';

  @override
  String proStatusActivations(Object classes) {
    return 'Activo en: $classes';
  }

  @override
  String proStatusClassThisDevice(Object name) {
    return '$name (este dispositivo)';
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
      'Ventajas Pro: las funciones de seguridad esenciales seguirán siendo gratis para siempre.';

  @override
  String get paywallPerkSkins => 'Packs de temas: skins Neon y Pixel';

  @override
  String get paywallPerkNoAds => 'Sin anuncios de banner';

  @override
  String get paywallPerkFuture =>
      'Próximamente: sincronización en la nube, avisos de intercambios';

  @override
  String get paywallPlayTitle => 'Desbloquear con Google Play';

  @override
  String get paywallSubscribe => 'Suscribirse · 0,99 \$/mes';

  @override
  String get paywallWatchAd => 'Ver un anuncio · VIP 3 días';

  @override
  String get paywallRestore => 'Restaurar compra';

  @override
  String get paywallCnTitle => 'Desbloquear con Afdian';

  @override
  String get paywallAfdianIntro =>
      'Apoya con 5 ¥ al mes en Afdian y luego introduce aquí el número de pedido para desbloquear.';

  @override
  String get paywallOpenAfdian => 'Abrir Afdian';

  @override
  String get paywallOrderHint => 'Número de pedido de Afdian';

  @override
  String get paywallRedeem => 'Desbloquear';

  @override
  String get paywallBetaTitle => 'Gracias por la beta';

  @override
  String get paywallBetaIntro =>
      'Quien probó la beta tiene Pro de por vida: introduce tu código.';

  @override
  String get paywallBetaHint => 'Código de por vida';

  @override
  String get paywallBetaRedeem => 'Canjear';

  @override
  String get proResultSuccess => 'Desbloqueado. ¡Gracias!';

  @override
  String get proErrCanceled => 'Cancelado.';

  @override
  String get proErrNetwork => 'Error de red: inténtalo más tarde.';

  @override
  String get proErrNotConfigured =>
      'Todavía no está disponible en esta versión.';

  @override
  String get proErrNoSubscription =>
      'No se encontró ninguna suscripción activa.';

  @override
  String get proErrOrderBound =>
      'Este pedido ya está vinculado a otro usuario.';

  @override
  String get proErrOrderNotFound =>
      'Pedido no encontrado o el plan no coincide.';

  @override
  String get proErrDeviceRevoked =>
      'Una activación más reciente ocupó el espacio de este dispositivo.';

  @override
  String get proErrNoVip =>
      'La recompensa aún no está confirmada: inténtalo dentro de un minuto.';

  @override
  String proErrGeneric(Object code) {
    return 'Error: $code';
  }

  @override
  String get proErrCodeInvalid =>
      'Código no reconocido: revísalo por si hay erratas.';

  @override
  String get proErrCodeRedeemed =>
      'Este código ya está activo en otro dispositivo. Para moverlo aquí, escribe a hi@dotslash.pro.';

  @override
  String get proErrCodeActivationLimit =>
      'Este código ha cambiado de dispositivo demasiadas veces hace poco. Inténtalo más tarde o escribe a hi@dotslash.pro.';

  @override
  String get proErrRateLimited =>
      'Demasiados intentos. Espera un minuto y vuelve a intentarlo.';

  @override
  String proErrSlotOccupied(Object slots) {
    return 'En uso: $slots';
  }

  @override
  String proSlotEntry(Object name, Object time) {
    return '$name ($time)';
  }

  @override
  String get proSlotToday => 'hoy';

  @override
  String proSlotDaysAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'hace $n días',
      one: 'hace 1 día',
    );
    return '$_temp0';
  }

  @override
  String get proErrRevoked =>
      'Esta licencia ya no está activa. Si crees que es un error, escribe a hi@dotslash.pro.';

  @override
  String get privacyOptions => 'Opciones de privacidad';

  @override
  String get skinProNotice =>
      'Las skins Neon y Pixel ahora son ventajas Pro. Tu selección se conserva y volverá al activar Pro.';

  @override
  String get skinProNoticeDismiss => 'Entendido';

  @override
  String get syncTitle => 'Sincronización';

  @override
  String get syncSetupTitle => 'Configurar la sincronización';

  @override
  String get syncSettingsDesc =>
      'Mantén las cuentas sincronizadas entre dispositivos a través de un servidor que tú controlas. Todo se cifra antes de salir de este dispositivo.';

  @override
  String get syncSetUp => 'Configurar sincronización…';

  @override
  String get syncStatusOk => 'Al día';

  @override
  String get syncStatusSyncing => 'Sincronizando…';

  @override
  String get syncStatusErrorShort =>
      'La última sincronización falló: abre para ver los detalles.';

  @override
  String syncStatusConflicts(int count) {
    return '$count conflicto(s) esperan tu decisión';
  }

  @override
  String syncLastSync(String time) {
    return 'Última sincronización: $time';
  }

  @override
  String get syncNever => 'nunca';

  @override
  String get syncBackendTitle => '¿Dónde deben guardarse los datos?';

  @override
  String get syncBackendWebdav => 'WebDAV';

  @override
  String get syncBackendWebdavDesc =>
      'Nextcloud, Jianguoyun (坚果云), un NAS: cualquier carpeta WebDAV que tú controles.';

  @override
  String get syncBackendGdrive => 'Google Drive';

  @override
  String get syncBackendGdriveSoon => 'Pro · próximamente';

  @override
  String get syncServerTitle => 'Servidor';

  @override
  String get syncServerHint =>
      'Jianguoyun requiere una contraseña de aplicación (安全选项 → 添加应用密码), no tu contraseña de inicio de sesión. Una URL de carpeta de Nextcloud tiene esta forma: https://cloud.example.com/remote.php/dav/files/USER/ava/.';

  @override
  String get syncServerUrlLabel => 'URL de la carpeta WebDAV';

  @override
  String get syncServerFolderLabel => 'Carpeta (opcional)';

  @override
  String get syncServerFolderHint =>
      'Déjalo vacío para usar la URL tal cual; un nombre coloca la biblioteca en esa subcarpeta y la crea si no existe.';

  @override
  String get syncServerUserLabel => 'Usuario';

  @override
  String get syncServerPasswordLabel => 'Contraseña / contraseña de aplicación';

  @override
  String get syncTestConnection => 'Probar conexión';

  @override
  String get syncErrUrl => 'Introduce una URL de carpeta http(s) válida.';

  @override
  String get syncErrAuth => 'El servidor rechazó el usuario o la contraseña.';

  @override
  String syncErrNetwork(String detail) {
    return 'No se pudo conectar con el servidor: $detail';
  }

  @override
  String syncErrServer(String detail) {
    return 'El servidor respondió con un error: $detail';
  }

  @override
  String get syncErrTls => 'El certificado del servidor no es de confianza.';

  @override
  String get syncTlsTitle => 'Certificado de servidor desconocido';

  @override
  String syncTlsBody(String fp) {
    return 'El sistema no confía en el certificado de este servidor. Si es tu propio servidor con un certificado autofirmado, compara esta huella con la que muestra el servidor y confía en él solo si coinciden exactamente.\n\nSHA-256\n$fp';
  }

  @override
  String get syncTlsTrust => 'Confiar en este certificado';

  @override
  String get syncHttpPrivateTitle => 'Conexión sin cifrar';

  @override
  String get syncHttpPrivateBody =>
      'Es una dirección HTTP sin cifrar en una red privada. Los datos de tus cuentas van cifrados de extremo a extremo, pero la contraseña del servidor viaja sin cifrar por tu red.';

  @override
  String get syncHttpPublicTitle => 'HTTP sin cifrar a través de internet';

  @override
  String get syncHttpPublicBody =>
      'Esta dirección es pública y la conexión iría sin cifrar: cualquiera entre tú y el servidor puede leer la contraseña del servidor e iniciar sesión en él. Los datos de las cuentas sí permanecen cifrados. Usa HTTPS o una dirección de red local; continúa solo si aceptas este riesgo.';

  @override
  String get syncHttpPublicHold => 'Mantén para permitir de todos modos';

  @override
  String get syncContinue => 'Continuar';

  @override
  String get syncPassphraseNewTitle =>
      'Define una frase de contraseña de sincronización';

  @override
  String get syncPassphraseNewBody =>
      'Todo se cifra con esta frase antes de subirse; la frase en sí nunca sale de tus dispositivos.\n\nSi la pierdes, nadie podrá recuperar los datos sincronizados: no existe restablecimiento. Al menos 8 caracteres; la longitud importa más que los símbolos.';

  @override
  String get syncPassphraseExistingTitle =>
      'Introduce la frase de contraseña de sincronización';

  @override
  String syncPassphraseExistingBody(int count) {
    return 'Esta carpeta ya contiene una biblioteca de sincronización con $count cuenta(s). Introduce la frase de contraseña con la que se creó.';
  }

  @override
  String get syncPassphraseLabel => 'Frase de contraseña de sincronización';

  @override
  String get syncPassphraseConfirmLabel => 'Confirmar frase de contraseña';

  @override
  String get syncPassphraseTooShort => 'Al menos 8 caracteres.';

  @override
  String get syncPassphraseMismatch => 'Las frases de contraseña no coinciden.';

  @override
  String get syncPassphraseWrong =>
      'Esa frase de contraseña no abre esta biblioteca.';

  @override
  String get syncPreviewTitle => 'Primera sincronización';

  @override
  String get syncPreviewEmpty =>
      'Aún no hay nada que transferir: a partir de ahora las cuentas se sincronizarán automáticamente.';

  @override
  String syncPreviewPull(int count) {
    return 'Descargar a este dispositivo: $count cuenta(s)';
  }

  @override
  String syncPreviewPush(int count) {
    return 'Subir desde este dispositivo: $count cuenta(s)';
  }

  @override
  String syncPreviewConflict(int count) {
    return 'En ambos lados con contenido distinto: $count; elegirás cuenta por cuenta tras conectar';
  }

  @override
  String get syncStart => 'Empezar a sincronizar';

  @override
  String get syncDoneTitle => 'Sincronización activada';

  @override
  String get syncDoneBody =>
      'Las cuentas ya se sincronizan automáticamente. En un dispositivo nuevo, cada cuenta vuelve a iniciar sesión la primera vez que la uses: las que tienen contraseña guardada lo hacen solas; las demás la piden una vez.';

  @override
  String get syncDone => 'Hecho';

  @override
  String get syncNeedsPassphrase =>
      'La frase de contraseña guardada ya no coincide con la biblioteca remota: introdúcela de nuevo.';

  @override
  String get syncEnterPassphrase => 'Introducir frase de contraseña';

  @override
  String get syncConditionalWarn =>
      'Este servidor ignora las escrituras condicionales, así que dos dispositivos que sincronicen en el mismo momento pueden sobrescribirse entre sí. La sincronización funciona igualmente; evita cambios simultáneos en dos dispositivos.';

  @override
  String get syncConflictsTitle => 'Conflictos';

  @override
  String get syncConflictTrashNote =>
      'El lado que descartes se conserva 30 días en la papelera de sincronización.';

  @override
  String get syncConflictEditEdit => 'Modificada en ambos dispositivos';

  @override
  String get syncConflictEditDelete =>
      'Modificada aquí, eliminada en otro dispositivo';

  @override
  String get syncConflictDeleteEdit =>
      'Eliminada aquí, modificada en otro dispositivo';

  @override
  String get syncConflictKeepLocal => 'Conservar la de este dispositivo';

  @override
  String get syncConflictKeepRemote => 'Conservar la del otro';

  @override
  String get syncConflictLocalSide => 'Este dispositivo';

  @override
  String get syncConflictRemoteSide => 'Otro dispositivo';

  @override
  String get syncDeleted => 'Eliminada';

  @override
  String get syncConflictHasPassword => 'Contraseña guardada';

  @override
  String get syncConflictNoPassword => 'Sin contraseña guardada';

  @override
  String get syncAutoTitle => 'Sincronización automática';

  @override
  String get syncAutoDesc =>
      'Sincroniza al iniciar y tras cada cambio. Si se desactiva, solo sincroniza el botón de abajo.';

  @override
  String get syncPasswordsTitle => 'Sincronizar contraseñas de las cuentas';

  @override
  String get syncPasswordsDesc =>
      'Con las contraseñas, un dispositivo nuevo inicia sesión por sí solo. Cambiar esto vuelve a subir todas las cuentas.';

  @override
  String get syncAppSettingsTitle => 'Sincronizar ajustes de la app';

  @override
  String get syncAppSettingsDesc =>
      'Las preferencias de apariencia y comportamiento (aspecto, tema, mantener para confirmar…) te siguen a cada dispositivo. El idioma y el tamaño del texto se mantienen por dispositivo.';

  @override
  String get syncNowButton => 'Sincronizar ahora';

  @override
  String get syncViewRemote => 'Ver biblioteca remota';

  @override
  String get syncRemoteEmpty => 'La biblioteca remota está vacía.';

  @override
  String get syncRemoteDevices => 'Dispositivos';

  @override
  String get syncTrashTitle => 'Papelera de sincronización';

  @override
  String get syncTrashEmpty =>
      'Vacía. Todo lo que la sincronización elimina o reemplaza se conserva aquí 30 días.';

  @override
  String get syncTrashRestore => 'Restaurar';

  @override
  String get syncTrashRestored => 'Cuenta restaurada.';

  @override
  String get syncTrashRestoreFailed =>
      'Esta entrada no se puede descifrar con la frase de contraseña actual.';

  @override
  String get syncTrashReasonRemoteDelete => 'eliminada por otro dispositivo';

  @override
  String get syncTrashReasonConflict => 'reemplazada en un conflicto';

  @override
  String get syncChangePassphrase => 'Cambiar frase de contraseña';

  @override
  String get syncPassphraseChanged =>
      'Frase de contraseña cambiada; todo se ha vuelto a cifrar. Los demás dispositivos pedirán la frase nueva.';

  @override
  String syncPassphraseChangeFailed(String reason) {
    return 'No se cambió la frase de contraseña: $reason';
  }

  @override
  String get syncDisconnect => 'Desconectar sincronización';

  @override
  String get syncDisconnectBody =>
      'Este dispositivo deja de sincronizar. La biblioteca remota puede quedarse para tus otros dispositivos, o eliminarse por completo del servidor.';

  @override
  String get syncDisconnectKeep => 'Conservar datos remotos';

  @override
  String get syncDisconnectDeleteHold => 'Mantén para borrar los datos remotos';
}
