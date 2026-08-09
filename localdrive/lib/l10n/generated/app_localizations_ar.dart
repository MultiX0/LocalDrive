// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class L10nAr extends L10n {
  L10nAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'لوكال درايف';

  @override
  String get actionContinue => 'متابعة';

  @override
  String get actionCancel => 'إلغاء';

  @override
  String get actionSave => 'حفظ';

  @override
  String get actionDone => 'تم';

  @override
  String get actionRetry => 'إعادة المحاولة';

  @override
  String get actionDelete => 'حذف';

  @override
  String get actionRemove => 'إزالة';

  @override
  String get actionCopy => 'نسخ';

  @override
  String get actionCopyLink => 'نسخ الرابط';

  @override
  String get actionCopyCode => 'نسخ الرمز';

  @override
  String get actionCopied => 'تم النسخ';

  @override
  String get actionPlay => 'تشغيل';

  @override
  String get actionPause => 'إيقاف مؤقت';

  @override
  String get actionFullscreen => 'ملء الشاشة';

  @override
  String get actionExitFullscreen => 'إنهاء ملء الشاشة';

  @override
  String get actionMute => 'كتم الصوت';

  @override
  String get actionUnmute => 'إلغاء الكتم';

  @override
  String get actionOpen => 'فتح';

  @override
  String get actionRename => 'إعادة تسمية';

  @override
  String get actionMove => 'نقل';

  @override
  String get actionShare => 'مشاركة';

  @override
  String get actionBack => 'رجوع';

  @override
  String get actionRefresh => 'تحديث';

  @override
  String get actionDeselect => 'إلغاء التحديد';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navSearch => 'بحث';

  @override
  String get navCreate => 'إنشاء';

  @override
  String get navShared => 'المشتركة';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get myFiles => 'ملفاتي';

  @override
  String get newFolder => 'مجلد جديد';

  @override
  String get upload => 'رفع';

  @override
  String get uploadFile => 'رفع ملف';

  @override
  String get download => 'تنزيل';

  @override
  String get gallery => 'المعرض';

  @override
  String get galleryEmptyTitle => 'لا توجد صور بعد';

  @override
  String get galleryEmptyBody =>
      'كل ما ترفعه من صور ومقاطع يظهر هنا، الأحدث أولًا.';

  @override
  String get shareOneAtATime =>
      'شارك صورة واحدة في كل مرة، ليحصل كل شخص على الوصول الذي قصدته';

  @override
  String get gallerySortTitle => 'الترتيب والتجميع';

  @override
  String get gallerySortTaken => 'تاريخ الالتقاط';

  @override
  String get gallerySortAdded => 'تاريخ الإضافة';

  @override
  String get gallerySortModified => 'تاريخ التعديل';

  @override
  String get gallerySortName => 'الاسم';

  @override
  String get gallerySortSize => 'حجم الملف';

  @override
  String get galleryGroupTitle => 'التجميع حسب';

  @override
  String get galleryGroupDay => 'اليوم';

  @override
  String get galleryGroupMonth => 'الشهر';

  @override
  String get galleryGroupYear => 'السنة';

  @override
  String get galleryGroupNone => 'بدون تجميع';

  @override
  String get galleryGroupUnavailable =>
      'التجميع يعمل فقط عند ترتيب الصور حسب التاريخ.';

  @override
  String galleryPositionOf(String position, String total) {
    return '$position من $total';
  }

  @override
  String gallerySummary(int photos, int videos) {
    return '$photos صورة، $videos مقطع';
  }

  @override
  String gallerySelected(int count) {
    return '$count محدد';
  }

  @override
  String get galleryColumns => 'حجم المربعات';

  @override
  String get galleryToday => 'اليوم';

  @override
  String get galleryYesterday => 'أمس';

  @override
  String get share => 'مشاركة';

  @override
  String get sharedWithMe => '‏المشتركة معي';

  @override
  String get recent => 'حديثًا';

  @override
  String get starred => 'المميزة بنجمة';

  @override
  String get trash => 'سلة المهملات';

  @override
  String get restore => 'استعادة';

  @override
  String get storage => 'مساحة التخزين';

  @override
  String get settings => 'الإعدادات';

  @override
  String get search => 'بحث';

  @override
  String get activity => 'النشاط';

  @override
  String get devices => 'الأجهزة';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get createAccount => 'إنشاء حساب';

  @override
  String get permanentlyDelete => 'حذف نهائيًا';

  @override
  String get pendingApproval => 'بانتظار الموافقة';

  @override
  String get approve => 'الموافقة';

  @override
  String get deny => 'رفض';

  @override
  String get scanForServers => 'البحث عن الأجهزة على الشبكة';

  @override
  String get linkExpiration => 'تاريخ انتهاء الصلاحية';

  @override
  String get neverExpires => 'لا تنتهي صلاحيته';

  @override
  String get setUpThisServer => 'إعداد الخادم';

  @override
  String get invite => 'دعوة';

  @override
  String get roleAdmin => 'المشرف';

  @override
  String get roleMember => 'عضو';

  @override
  String get resetPassword => 'إعادة تعيين كلمة المرور';

  @override
  String get sharedWithPerson => 'مشاركة مع شخص';

  @override
  String get nearby => 'بالقرب منك';

  @override
  String get availableOffline => 'متاح دون اتصال';

  @override
  String get welcomeTitle => 'ملفاتك على جهازك';

  @override
  String get welcomeBody =>
      'يحفظ لوكال درايف كل شيء على خادم تديره أنت، في مكان تعرفه.';

  @override
  String get welcomeStart => 'لنبدأ';

  @override
  String get welcomePointHardware =>
      'ملفاتك تبقى على جهاز تملكه. لا شيء يُنسخ إلى جهاز شخص آخر.';

  @override
  String get welcomePointKeys =>
      'بلا حساب ولا اشتراك ولا تتبّع. لا شيء يُرسل إلى أي جهة.';

  @override
  String get welcomePointDevices =>
      'الهاتف واللوحي والحاسوب والمتصفح تصل جميعها إلى المكتبة نفسها.';

  @override
  String get connectTitle => 'الاتصال بخادم';

  @override
  String get connectBody => 'اختر خادمًا على شبكتك، أو اكتب عنوانه.';

  @override
  String get scanningNetwork => 'جارٍ البحث في شبكتك';

  @override
  String get scanAgain => 'إعادة البحث';

  @override
  String get enterAddressManually => 'إدخال العنوان يدويًا';

  @override
  String get addressHint => '‎192.168.1.10 أو drive.example.com';

  @override
  String get nothingFound => 'لم يُعثر على شيء على هذه الشبكة';

  @override
  String get nothingFoundBody =>
      'هذا طبيعي إذا كان الخادم على شبكة فرعية أخرى أو كان الإعلان عن الشبكة معطلًا. اكتب العنوان بدلًا من ذلك.';

  @override
  String get serverReady => 'جاهز';

  @override
  String get serverNeedsSetup => 'يحتاج إلى إعداد';

  @override
  String get connectAction => 'اتصال';

  @override
  String get couldNotReachServer => 'تعذّر الوصول إلى هذا العنوان';

  @override
  String get languageTitle => 'اختر اللغة';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageArabic => 'العربية';

  @override
  String get setupTitle => 'إعداد الخادم';

  @override
  String get setupBody =>
      'هذا خادم جديد تمامًا. الحساب الذي تنشئه الآن هو حساب المشرف.';

  @override
  String get setupAdminSection => 'حساب المدير';

  @override
  String get setupOnceNotice =>
      'تظهر هذه الشاشة مرة واحدة. بمجرد إنشاء هذا الحساب يتوقف الخادم عن قبول الإعداد، وينضم الجميع بعد ذلك عبر دعوة.';

  @override
  String get serverNameLabel => 'اسم الخادم';

  @override
  String get serverNameHint => 'ما يراه الناس عند الاتصال';

  @override
  String get usernameLabel => 'اسم المستخدم';

  @override
  String get usernameHint => 'الاسم الذي تسجّل الدخول به';

  @override
  String get passwordLabel => 'كلمة المرور';

  @override
  String get passwordHintNew => '10 أحرف على الأقل';

  @override
  String get passwordHintExisting => 'كلمة مرور هذا الحساب';

  @override
  String get confirmPasswordLabel => 'تأكيد كلمة المرور';

  @override
  String get confirmPasswordHint => 'اكتب كلمة المرور نفسها مرة أخرى';

  @override
  String get inviteCodeLabel => 'رمز الدعوة';

  @override
  String get inviteCodeHint => 'مثل ABCD-1234';

  @override
  String get passwordsDoNotMatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get passwordTooShort => 'استخدم 10 أحرف على الأقل';

  @override
  String get signInTitle => 'أهلًا بعودتك';

  @override
  String signInBody(String serverName) {
    return 'سجّل الدخول إلى $serverName.';
  }

  @override
  String get createAccountTitle => 'أنشئ حسابك';

  @override
  String get createAccountBody => 'أدخل رمز الدعوة الذي وصلك.';

  @override
  String get noAccountYet => 'ليس لديك حساب؟';

  @override
  String get alreadyHaveAccount => 'لديك حساب بالفعل؟';

  @override
  String get twoFactorCode => 'رمز التحقق بخطوتين';

  @override
  String get twoFactorHint => 'من تطبيق المصادقة لديك';

  @override
  String get waitingForApprovalTitle => 'بانتظار الموافقة';

  @override
  String get waitingForApprovalBody =>
      'هذا جهاز جديد. وافق عليه من الإعدادات على جهاز سجّلت الدخول منه من قبل.';

  @override
  String get deviceApproved => 'تمت الموافقة على هذا الجهاز';

  @override
  String get deviceDeniedTitle => 'لم تتم الموافقة على هذا الجهاز';

  @override
  String get deviceDeniedBody =>
      'اسأل من يدير هذا الخادم، أو حاول تسجيل الدخول مرة أخرى.';

  @override
  String get mustChangePasswordTitle => 'اختر كلمة مرور جديدة';

  @override
  String get mustChangePasswordBody =>
      'هذا الحساب يستخدم كلمة مرور مؤقتة. لن يعمل أي شيء آخر قبل تغييرها.';

  @override
  String get currentPassword => 'كلمة المرور الحالية';

  @override
  String get newPassword => 'كلمة المرور الجديدة';

  @override
  String get passwordChanged => 'تم تغيير كلمة المرور';

  @override
  String get emptyFolderTitle => 'لا شيء هنا بعد';

  @override
  String get emptyFolderBody => 'ارفع ملفًا أو أنشئ مجلدًا للبدء.';

  @override
  String get emptySharedTitle => 'لم يشاركك أحد شيئًا';

  @override
  String get emptySharedBody => 'كل ما يشاركه معك أحد سيظهر هنا.';

  @override
  String get emptyStarredTitle => 'لا توجد عناصر مميزة بنجمة';

  @override
  String get emptyStarredBody => 'ميّز بنجمة ما تريد الوصول إليه بسرعة.';

  @override
  String get emptyRecentTitle => 'لا يوجد نشاط حديث';

  @override
  String get emptyRecentBody => 'الملفات التي تغيّرها ستظهر هنا.';

  @override
  String get emptyTrashTitle => 'سلة المهملات فارغة';

  @override
  String get emptyTrashBody => 'ما تحذفه ينتظر هنا قبل أن يُحذف نهائيًا.';

  @override
  String get emptySearchTitle => 'لا توجد نتائج';

  @override
  String get emptySearchBody => 'جرّب كلمة أخرى.';

  @override
  String get emptyActivityTitle => 'لم يحدث شيء بعد';

  @override
  String get emptyDevicesTitle => 'لا توجد أجهزة أخرى';

  @override
  String get emptyUsersTitle => 'أنت وحدك حتى الآن';

  @override
  String get emptyUsersBody => 'ادعُ شخصًا ليحصل على مساحته الخاصة.';

  @override
  String get emptyTransfersTitle => 'لا توجد عمليات نقل';

  @override
  String get emptyTransfersBody => 'تظهر هنا حالة الرفع والتنزيل.';

  @override
  String get errorOfflineTitle => 'أنت غير متصل';

  @override
  String get errorOfflineBody =>
      'سيكمل لوكال درايف من حيث توقف عند عودة الاتصال.';

  @override
  String get errorUnreachableTitle => 'تعذّر الوصول إلى هذا الخادم';

  @override
  String get errorUnreachableBody =>
      'قد يكون متوقفًا، أو على شبكة لا يراها هذا الجهاز.';

  @override
  String get errorPermissionTitle => 'ليس لديك صلاحية';

  @override
  String get errorPermissionBody => 'اطلب ممن يملك هذا العنصر أن يشاركه معك.';

  @override
  String get errorNotFoundTitle => 'غير موجود';

  @override
  String get errorNotFoundBody => 'ربما نُقل أو حُذف.';

  @override
  String get errorQuotaTitle => 'لا توجد مساحة كافية';

  @override
  String get errorQuotaBody => 'أفرغ بعض المساحة، أو اطلب حصة أكبر.';

  @override
  String get errorSessionTitle => 'سجّل الدخول مرة أخرى';

  @override
  String get errorSessionBody => 'انتهت هذه الجلسة.';

  @override
  String get errorUnexpectedTitle => 'حدث خطأ ما';

  @override
  String get errorUnexpectedBody => 'لم تنجح العملية. حاول بعد قليل.';

  @override
  String get sortBy => 'الترتيب حسب';

  @override
  String get sortName => 'الاسم';

  @override
  String get sortUpdated => 'آخر تعديل';

  @override
  String get sortSize => 'الحجم';

  @override
  String get viewGrid => 'شبكة';

  @override
  String get viewList => 'قائمة';

  @override
  String get actionSelect => 'تحديد';

  @override
  String selectedCount(int count) {
    return '$count محدد';
  }

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عنصرًا',
      few: '$count عناصر',
      two: 'عنصران',
      one: 'عنصر واحد',
      zero: 'فارغ',
    );
    return '$_temp0';
  }

  @override
  String get folderNameLabel => 'اسم المجلد';

  @override
  String get folderNameHint => 'صور العطلة';

  @override
  String get renameTo => 'الاسم الجديد';

  @override
  String get chooseLibrary => 'أين يُحفظ';

  @override
  String libraryFreeSpace(String free) {
    return '$free متاحة';
  }

  @override
  String get folderColor => 'لون المجلد';

  @override
  String get moveTo => 'النقل إلى';

  @override
  String get confirmTrashTitle => 'النقل إلى سلة المهملات';

  @override
  String confirmTrashBody(String name) {
    return 'سينتقل $name إلى سلة المهملات، ويفقد كل من شاركته معه إمكانية الوصول.';
  }

  @override
  String get confirmDeleteTitle => 'حذف نهائي';

  @override
  String confirmDeleteBody(String name) {
    return 'سيُحذف $name وكل ما بداخله نهائيًا. لا يمكن التراجع عن هذا.';
  }

  @override
  String trashRetentionNote(int days) {
    return 'تُحذف عناصر سلة المهملات نهائيًا بعد $days يومًا.';
  }

  @override
  String get emptyTrashAction => 'إفراغ سلة المهملات';

  @override
  String get sharePeopleTab => 'أشخاص';

  @override
  String get shareLinkTab => 'رابط';

  @override
  String get sharePeopleHint => 'اضغط على شخص لمنحه الوصول.';

  @override
  String get shareRoleViewer => 'يمكنه الاطلاع';

  @override
  String get shareRoleEditor => 'يمكنه التعديل';

  @override
  String get shareRoleNote =>
      'أنت وحدك من يمكنه الحذف أو النقل أو إعادة المشاركة.';

  @override
  String get shareRemoveAccess => 'إزالة الوصول';

  @override
  String get shareCreateLink => 'إنشاء رابط';

  @override
  String get shareLinkAllowDownload => 'السماح بالتنزيل';

  @override
  String get shareLinkPassword => 'كلمة المرور';

  @override
  String get shareLinkPasswordHint => 'يحتاجها كل من يفتح الرابط';

  @override
  String get shareLinkNoPassword => 'بدون كلمة مرور';

  @override
  String get shareLinkExpiry => 'تنتهي الصلاحية';

  @override
  String get shareExpiryDay => 'بعد يوم';

  @override
  String get shareExpiryWeek => 'بعد أسبوع';

  @override
  String get shareExpiryMonth => 'بعد شهر';

  @override
  String get shareExpiryCustom => 'اختر تاريخًا';

  @override
  String get shareRevoke => 'إلغاء هذا الرابط';

  @override
  String get shareRevoked => 'لم يعد هذا الرابط يعمل';

  @override
  String shareReceived(String name, String item) {
    return 'شارك $name معك $item';
  }

  @override
  String get versionHistory => 'سجل الإصدارات';

  @override
  String get versionCurrent => 'الحالي';

  @override
  String get versionRestored => 'تمت استعادة إصدار سابق';

  @override
  String get storageTotal => 'على جميع الأقراص';

  @override
  String get storageYours => 'ملفاتك';

  @override
  String storageUsedOf(String used, String total) {
    return '$used من $total مستخدمة';
  }

  @override
  String sidebarStorageUsed(String used) {
    return '$used مستخدمة';
  }

  @override
  String sidebarStorageFree(String free) {
    return '$free متاحة';
  }

  @override
  String get sidebarStorageDiskLimited => 'مساحة القرص أقل من حصتك';

  @override
  String get storageDefault => 'الافتراضي';

  @override
  String get storageSetDefault => 'جعله الافتراضي';

  @override
  String get storageDetectedDrives => 'الأقراص المكتشفة';

  @override
  String get storageUseThisDrive => 'استخدام هذا القرص';

  @override
  String get storageFormat => 'تهيئة';

  @override
  String get storageEject => 'إخراج';

  @override
  String get storageCombine => 'دمجها في قرص واحد';

  @override
  String get storageOffline => 'غير متصل';

  @override
  String storageOfflineBanner(String name) {
    return 'القرص $name غير متصل حاليًا. كل ما عداه يعمل كالمعتاد.';
  }

  @override
  String get storageSafeToUnplug => 'يمكنك فصل هذا القرص الآن بأمان';

  @override
  String get storageFormatWarning =>
      'سيُحذف كل ما على هذا القرص نهائيًا. اكتب العبارة أدناه للمتابعة.';

  @override
  String get storageFormatPhrase => 'ERASE THIS DRIVE';

  @override
  String get storageFormatPhraseHint => 'اكتب العبارة كما هي';

  @override
  String get storageHelperUnavailable =>
      'إدارة الأقراص غير متاحة في هذا التنصيب.';

  @override
  String get settingsAccount => 'الحساب';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get settingsServer => 'الخادم';

  @override
  String get settingsUsers => 'المستخدمون';

  @override
  String get settingsAbout => 'حول التطبيق';

  @override
  String get settingsSwitchNode => 'تبديل الخادم';

  @override
  String get deepLinkOtherServerTitle => 'هذا الرابط لخادم آخر';

  @override
  String deepLinkOtherServerBody(String server) {
    return 'يشير هذا الرابط إلى $server. أنت مسجّل الدخول في مكان آخر، لذا فتحه يعني تبديل الخادم أولًا.';
  }

  @override
  String get shareReceivedOne => 'أُضيف إلى تحميلاتك';

  @override
  String shareReceivedMany(int count) {
    return 'أُضيفت $count ملفات إلى تحميلاتك';
  }

  @override
  String get trayOpen => 'فتح Local Drive';

  @override
  String get trayTransfers => 'عمليات النقل';

  @override
  String get trayQuit => 'إنهاء';

  @override
  String get launchAtStartup => 'الفتح عند تسجيل الدخول إلى هذا الحاسوب';

  @override
  String get notificationsWhyTitle => 'اسمح لـ Local Drive بعرض تقدّم النقل';

  @override
  String get notificationsWhyBody =>
      'الإشعار هو ما يبقي الرفع مستمرًا بعد مغادرتك التطبيق. بدونه يمكن لجهازك إيقاف النقل بمجرد إطفاء الشاشة.';

  @override
  String get notificationsAllow => 'السماح بالإشعارات';

  @override
  String get notificationsNotNow => 'ليس الآن';

  @override
  String get nearbyWhyTitle => 'معرفة من على هذه الشبكة';

  @override
  String get nearbyWhyBody =>
      'يمكن لـ Local Drive إظهار الأشخاص الموجودين على شبكة الواي فاي هذه الآن، فتصبح المشاركة مع شخص في الغرفة نفسها بضغطة واحدة. لا يبحث إلا أثناء فتح هذه النافذة، والملف يمرّ عبر خادمك أنت في الحالتين.';

  @override
  String get nearbyAllow => 'إظهار من هو قريب';

  @override
  String get settingsSignOut => 'تسجيل الخروج';

  @override
  String get settingsTwoFactor => 'التحقق بخطوتين';

  @override
  String get settingsRequireApproval => 'الموافقة على الأجهزة الجديدة';

  @override
  String get settingsRequireApprovalNote =>
      'الجهاز الذي يسجّل الدخول لأول مرة ينتظر موافقة جهاز تستخدمه بالفعل.';

  @override
  String get settingsLanDiscovery => 'الإعلان على الشبكة المحلية';

  @override
  String get settingsLanDiscoveryNote =>
      'يتيح للتطبيق العثور على هذا الخادم دون كتابة عنوانه.';

  @override
  String get settingsSelfRegistration => 'السماح لأي شخص بإنشاء حساب';

  @override
  String get settingsSelfRegistrationNote =>
      'الإيقاف أكثر أمانًا. ادعُ الأشخاص بدلًا من ذلك.';

  @override
  String get usersInviteSomeone => 'دعوة شخص';

  @override
  String get usersInviteLabel => 'لمن هذه الدعوة';

  @override
  String get usersInviteHint => 'اسم يذكّرك بهم';

  @override
  String get usersInviteCreated =>
      'أرسل له هذا الرمز بالطريقة التي تتواصلان بها عادة.';

  @override
  String get usersResetPassword => 'إعادة تعيين كلمة مروره';

  @override
  String get usersTemporaryPassword => 'كلمة مرور مؤقتة';

  @override
  String get usersTemporaryPasswordNote =>
      'سيُطلب منه اختيار كلمة مرور جديدة عند تسجيل الدخول.';

  @override
  String get usersMakeAdmin => 'ترقيته إلى مشرف';

  @override
  String get usersMakeMember => 'جعله عضوًا';

  @override
  String get devicesThisDevice => 'هذا الجهاز';

  @override
  String devicesLastSeen(String when) {
    return 'آخر ظهور $when';
  }

  @override
  String get devicesRevoke => 'تسجيل خروج هذا الجهاز';

  @override
  String get devicesPendingSection => 'بانتظار الموافقة';

  @override
  String get devicesApprovedToast => 'تمت الموافقة على الجهاز';

  @override
  String get devicesDeniedToast => 'تم رفض الجهاز';

  @override
  String get transfersTitle => 'عمليات النقل';

  @override
  String transfersSummary(int done, int total) {
    return 'تم رفع $done من $total';
  }

  @override
  String transfersNeedAttention(int count) {
    return '$count بحاجة إلى انتباهك';
  }

  @override
  String get transferQueued => 'في الانتظار';

  @override
  String get transferInProgress => 'جارٍ الرفع';

  @override
  String get transferRetrying => 'إعادة المحاولة';

  @override
  String get transferCompleted => 'تم';

  @override
  String get transferFailed => 'فشل';

  @override
  String get transferRetry => 'إعادة المحاولة';

  @override
  String get transferPausedOffline => 'متوقف مؤقتًا بانتظار الاتصال';

  @override
  String get offlineMakeAvailable => 'إتاحته دون اتصال';

  @override
  String get offlineRemoveDownload => 'إزالة النسخة المحفوظة';

  @override
  String offlineRemoved(String name) {
    return 'لم يعد $name محفوظًا على هذا الجهاز';
  }

  @override
  String offlineQueued(String name) {
    return 'سيُحفظ $name على هذا الجهاز';
  }

  @override
  String get offlineOverCapTitle => 'سيتجاوز هذا الحد الذي حددته';

  @override
  String offlineOverCapBody(String projected, String cap) {
    return 'حفظ هذا سيرفع حجم الملفات دون اتصال إلى $projected، وهو أكثر من الحد $cap المحدد على هذا الجهاز. يمكنك المتابعة، أو رفع الحد من الإعدادات.';
  }

  @override
  String get offlineDownloadsTitle => 'التنزيلات على هذا الجهاز';

  @override
  String get offlineDownloadsBody =>
      'المساحة التي تشغلها الملفات المحفوظة للاستخدام دون اتصال. هذه منفصلة عن تخزين الخادم نفسه.';

  @override
  String offlineFilesKept(int count) {
    return '$count ملفات محفوظة';
  }

  @override
  String get offlineChosenIndividually => 'مختارة بشكل فردي';

  @override
  String get offlineClearAll => 'إزالة كل التنزيلات';

  @override
  String get offlineClearAllConfirm =>
      'ستُزال كل الملفات المحفوظة على هذا الجهاز. لن يتغير شيء على الخادم، ويمكنك حفظ أي ملف مجددًا لاحقًا.';

  @override
  String get offlineCleared => 'أُزيلت الملفات المحفوظة';

  @override
  String get offlineSoftCapLabel => 'التنبيه عند تجاوز';

  @override
  String get offlineNoLimit => 'بلا حد';

  @override
  String get offlineNothingKept => 'لا شيء محفوظ على هذا الجهاز بعد';

  @override
  String get offlineNeedsConnection => 'يحتاج إلى اتصال';

  @override
  String get previewCannotPreview => 'لا توجد معاينة لهذا النوع';

  @override
  String get previewCannotOpenTitle => 'تعذّر فتح هذا الملف';

  @override
  String get previewCannotOpenBody =>
      'قد يكون تالفًا، أو محفوظًا بصيغة لا يفهمها هذا العارض. تنزيله وفتحه في تطبيق آخر يُفترض أن ينجح.';

  @override
  String get previewDownloadToOpen => 'نزّله لفتحه في تطبيق آخر';

  @override
  String previewPageOf(String page, String total) {
    return '$page من $total';
  }

  @override
  String get previewPreviousPage => 'الصفحة السابقة';

  @override
  String get previewNextPage => 'الصفحة التالية';

  @override
  String get previewSkipBack => 'رجوع ١٥ ثانية';

  @override
  String get previewSkipForward => 'تقدّم ١٥ ثانية';

  @override
  String get previewTruncated =>
      'هذه بداية الملف فقط. حجمه أكبر من أن يُفتح كاملًا هنا.';

  @override
  String get sheetEmptyTitle => 'لا توجد خلايا في هذا الجدول';

  @override
  String get sheetEmptyBody => 'فُتح الملف، لكن لا يوجد فيه ما يُعرض.';

  @override
  String sheetUnnamed(String number) {
    return 'الورقة $number';
  }

  @override
  String get documentEmptyTitle => 'لا يوجد نص في هذا المستند';

  @override
  String get documentEmptyBody => 'فُتح الملف، لكن لا يوجد فيه ما يُعرض.';

  @override
  String get downloadNoFiles => 'لا يمكن تنزيل المجلدات كملف واحد';

  @override
  String downloadQueuedOne(String name) {
    return 'يجري تنزيل $name';
  }

  @override
  String downloadQueuedMany(int count) {
    return 'يجري تنزيل $count ملفات';
  }

  @override
  String downloadSavedTo(String location) {
    return 'حُفظ في $location';
  }

  @override
  String sizeBytes(String size) {
    return '$size بايت';
  }

  @override
  String sizeKilobytes(String size) {
    return '$size كيلوبايت';
  }

  @override
  String sizeMegabytes(String size) {
    return '$size ميغابايت';
  }

  @override
  String sizeGigabytes(String size) {
    return '$size غيغابايت';
  }

  @override
  String sizeTerabytes(String size) {
    return '$size تيرابايت';
  }

  @override
  String get timeJustNow => 'الآن';

  @override
  String timeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قبل $count دقيقة',
      few: 'قبل $count دقائق',
      two: 'قبل دقيقتين',
      one: 'قبل دقيقة',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قبل $count ساعة',
      few: 'قبل $count ساعات',
      two: 'قبل ساعتين',
      one: 'قبل ساعة',
    );
    return '$_temp0';
  }

  @override
  String timeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قبل $count يومًا',
      few: 'قبل $count أيام',
      two: 'قبل يومين',
      one: 'أمس',
    );
    return '$_temp0';
  }

  @override
  String get twoFactorTitle => 'المصادقة بخطوتين';

  @override
  String get twoFactorRequiredBody =>
      'هذا الحساب يدير الخادم، لذا المصادقة بخطوتين مطلوبة. تستغرق دقيقة تقريبًا.';

  @override
  String get twoFactorOptionalBody =>
      'أضف خطوة ثانية عند تسجيل الدخول. الخيار لك.';

  @override
  String get twoFactorScanTitle => 'أضف هذا إلى تطبيق المصادقة';

  @override
  String get twoFactorUseQr => 'مسح رمز';

  @override
  String get twoFactorUseKey => 'إدخال مفتاح';

  @override
  String get twoFactorKeyBody =>
      'استخدم هذا إذا كان التطبيق على جهاز آخر أو تحفظ الرموز في مدير كلمات المرور.';

  @override
  String get twoFactorConfirmTitle => 'أدخل الرمز المكوّن من ستة أرقام';

  @override
  String get twoFactorCodeHint => 'ستة أرقام';

  @override
  String get twoFactorTurnOn => 'تفعيل المصادقة بخطوتين';

  @override
  String get twoFactorOn => 'المصادقة بخطوتين مفعّلة';

  @override
  String get twoFactorOff => 'معطّلة';

  @override
  String get twoFactorAlreadyOnBody =>
      'هذا الحساب يطلب رمزًا بالفعل عند تسجيل الدخول.';

  @override
  String get recoveryCodesTitle => 'احفظ رموز الاسترداد';

  @override
  String get recoveryCodesBody =>
      'كل رمز يسجّل دخولك مرة واحدة إذا فقدت تطبيق المصادقة. احفظها في مكان غير هذا الجهاز.';

  @override
  String get moreActions => 'المزيد';

  @override
  String get dropToUpload => 'أفلت للرفع';

  @override
  String get dropToUploadHint => 'المجلدات تحتفظ ببنيتها';

  @override
  String get dropToUploadHintWeb => 'تُضاف الملفات إلى هذا المجلد';

  @override
  String get errorFoldersNotSupportedWeb =>
      'لا يمكن إفلات المجلدات في المتصفح. أفلت الملفات التي بداخلها بدلاً من ذلك.';

  @override
  String get uploadClashTitle => 'هذا الاسم موجود بالفعل';

  @override
  String get uploadClashTitleMany => 'بعض الأسماء موجودة بالفعل';

  @override
  String uploadClashBody(String name) {
    return 'هذا المجلد يحتوي بالفعل على ملف باسم $name.';
  }

  @override
  String uploadClashBodyMany(String count) {
    return '$count من الملفات التي ترفعها تحمل أسماء يستخدمها هذا المجلد بالفعل.';
  }

  @override
  String get uploadClashKeepBoth => 'الاحتفاظ بالاثنين';

  @override
  String get uploadClashReplace => 'الاستبدال بالملف الجديد';

  @override
  String get uploadClashSkip => 'تخطي هذه الملفات';

  @override
  String get versionSection => 'الإصدار';

  @override
  String get versionInstalled => 'المثبَّت';

  @override
  String get updateCheck => 'البحث عن تحديثات';

  @override
  String get updateChecking => 'جارٍ البحث';

  @override
  String get updateUpToDate => 'أنت على أحدث إصدار';

  @override
  String updateUpToDateBody(String version) {
    return 'الإصدار $version هو الأحدث.';
  }

  @override
  String updateAvailable(String version) {
    return 'الإصدار $version متاح';
  }

  @override
  String get updateInstall => 'التنزيل والتثبيت';

  @override
  String get updateDownloading => 'جارٍ التنزيل';

  @override
  String get updateInstalling => 'جارٍ التثبيت';

  @override
  String get updateRestartNote =>
      'سيُغلق التطبيق ويُفتح من جديد بعد اكتمال التحديث.';

  @override
  String get updateAndroidNote => 'يطلب أندرويد الإذن قبل التثبيت.';

  @override
  String get updateNotes => 'ما الجديد';

  @override
  String get updateManualOnly => 'يتحدّث هذا الإصدار مع الخادم الذي يقدّمه.';
}
