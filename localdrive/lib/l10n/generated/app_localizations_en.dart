// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class L10nEn extends L10n {
  L10nEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Local Drive';

  @override
  String get actionContinue => 'Continue';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionSave => 'Save';

  @override
  String get actionDone => 'Done';

  @override
  String get actionRetry => 'Try again';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionRemove => 'Remove';

  @override
  String get actionCopy => 'Copy';

  @override
  String get actionCopyLink => 'Copy link';

  @override
  String get actionCopyCode => 'Copy code';

  @override
  String get actionCopied => 'Copied';

  @override
  String get actionPlay => 'Play';

  @override
  String get actionPause => 'Pause';

  @override
  String get actionFullscreen => 'Full screen';

  @override
  String get actionExitFullscreen => 'Exit full screen';

  @override
  String get actionMute => 'Mute';

  @override
  String get actionUnmute => 'Unmute';

  @override
  String get actionOpen => 'Open';

  @override
  String get actionRename => 'Rename';

  @override
  String get actionMove => 'Move';

  @override
  String get actionShare => 'Share';

  @override
  String get actionBack => 'Back';

  @override
  String get actionRefresh => 'Refresh';

  @override
  String get actionDeselect => 'Clear selection';

  @override
  String get navHome => 'Home';

  @override
  String get navSearch => 'Search';

  @override
  String get navCreate => 'Create';

  @override
  String get navShared => 'Shared';

  @override
  String get navSettings => 'Settings';

  @override
  String get myFiles => 'My Files';

  @override
  String get newFolder => 'New folder';

  @override
  String get upload => 'Upload';

  @override
  String get uploadFile => 'Upload a file';

  @override
  String get download => 'Download';

  @override
  String get gallery => 'Gallery';

  @override
  String get galleryEmptyTitle => 'No photos yet';

  @override
  String get galleryEmptyBody =>
      'Anything you upload that is a picture or a clip shows up here, newest first.';

  @override
  String get shareOneAtATime =>
      'Share one photo at a time, so each person gets the access you meant';

  @override
  String get gallerySortTitle => 'Sort and group';

  @override
  String get gallerySortTaken => 'Date taken';

  @override
  String get gallerySortAdded => 'Date added';

  @override
  String get gallerySortModified => 'Date modified';

  @override
  String get gallerySortName => 'Name';

  @override
  String get gallerySortSize => 'File size';

  @override
  String get galleryGroupTitle => 'Group by';

  @override
  String get galleryGroupDay => 'Day';

  @override
  String get galleryGroupMonth => 'Month';

  @override
  String get galleryGroupYear => 'Year';

  @override
  String get galleryGroupNone => 'Do not group';

  @override
  String get galleryGroupUnavailable =>
      'Grouping only applies when photos are ordered by date.';

  @override
  String galleryPositionOf(String position, String total) {
    return '$position of $total';
  }

  @override
  String gallerySummary(int photos, int videos) {
    return '$photos photos, $videos videos';
  }

  @override
  String gallerySelected(int count) {
    return '$count selected';
  }

  @override
  String get galleryColumns => 'Tile size';

  @override
  String get galleryToday => 'Today';

  @override
  String get galleryYesterday => 'Yesterday';

  @override
  String get share => 'Share';

  @override
  String get sharedWithMe => 'Shared with me';

  @override
  String get recent => 'Recent';

  @override
  String get starred => 'Starred';

  @override
  String get trash => 'Trash';

  @override
  String get restore => 'Restore';

  @override
  String get storage => 'Storage';

  @override
  String get settings => 'Settings';

  @override
  String get search => 'Search';

  @override
  String get activity => 'Activity';

  @override
  String get devices => 'Devices';

  @override
  String get signIn => 'Sign in';

  @override
  String get createAccount => 'Create account';

  @override
  String get permanentlyDelete => 'Permanently delete';

  @override
  String get pendingApproval => 'Pending approval';

  @override
  String get approve => 'Approve';

  @override
  String get deny => 'Deny';

  @override
  String get scanForServers => 'Scan for servers';

  @override
  String get linkExpiration => 'Link expiration';

  @override
  String get neverExpires => 'Never expires';

  @override
  String get setUpThisServer => 'Set up this server';

  @override
  String get invite => 'Invite';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get roleMember => 'Member';

  @override
  String get resetPassword => 'Reset password';

  @override
  String get sharedWithPerson => 'Share with a person';

  @override
  String get nearby => 'Nearby';

  @override
  String get availableOffline => 'Available offline';

  @override
  String get welcomeTitle => 'Your files, your hardware';

  @override
  String get welcomeBody =>
      'Local Drive keeps everything on a server you run, in a place you can point at.';

  @override
  String get welcomeStart => 'Get started';

  @override
  String get welcomePointHardware =>
      'Files live on hardware you own. Nothing is copied to anyone else\'s machine.';

  @override
  String get welcomePointKeys =>
      'No account, no subscription, and no telemetry. Nothing is reported anywhere.';

  @override
  String get welcomePointDevices =>
      'Phone, tablet, laptop, and browser reach the same library.';

  @override
  String get connectTitle => 'Connect to a server';

  @override
  String get connectBody =>
      'Pick one found on your network, or type its address.';

  @override
  String get scanningNetwork => 'Scanning your network';

  @override
  String get scanAgain => 'Scan again';

  @override
  String get enterAddressManually => 'Enter address manually';

  @override
  String get addressHint => '192.168.1.10 or drive.example.com';

  @override
  String get nothingFound => 'Nothing found on this network';

  @override
  String get nothingFoundBody =>
      'That is normal on a different subnet, or if discovery is turned off. Type the address instead.';

  @override
  String get serverReady => 'Ready';

  @override
  String get serverNeedsSetup => 'Needs setup';

  @override
  String get connectAction => 'Connect';

  @override
  String get couldNotReachServer => 'Could not reach that address';

  @override
  String get languageTitle => 'Choose a language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageArabic => 'العربية';

  @override
  String get setupTitle => 'Set up this server';

  @override
  String get setupBody =>
      'This is a brand new server. The account you make now is its admin.';

  @override
  String get setupAdminSection => 'Admin account';

  @override
  String get setupOnceNotice =>
      'This screen runs once. As soon as this account exists the server stops accepting setup, and everyone else joins by invite.';

  @override
  String get serverNameLabel => 'Server name';

  @override
  String get serverNameHint => 'What people see when they connect';

  @override
  String get usernameLabel => 'Username';

  @override
  String get usernameHint => 'The name you sign in with';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordHintNew => 'At least 10 characters';

  @override
  String get passwordHintExisting => 'The password for this account';

  @override
  String get confirmPasswordLabel => 'Confirm password';

  @override
  String get confirmPasswordHint => 'Type the same password again';

  @override
  String get inviteCodeLabel => 'Invite code';

  @override
  String get inviteCodeHint => 'Like ABCD-1234';

  @override
  String get passwordsDoNotMatch => 'Those passwords do not match';

  @override
  String get passwordTooShort => 'Use at least 10 characters';

  @override
  String get signInTitle => 'Welcome back';

  @override
  String signInBody(String serverName) {
    return 'Sign in to $serverName.';
  }

  @override
  String get createAccountTitle => 'Create your account';

  @override
  String get createAccountBody => 'Enter the invite code you were given.';

  @override
  String get noAccountYet => 'No account yet?';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get twoFactorCode => 'Two-factor code';

  @override
  String get twoFactorHint => 'From your authenticator app';

  @override
  String get waitingForApprovalTitle => 'Waiting for approval';

  @override
  String get waitingForApprovalBody =>
      'This device is new. Approve it from Settings on a device you are already signed in to.';

  @override
  String get deviceApproved => 'This device was approved';

  @override
  String get deviceDeniedTitle => 'This device was not approved';

  @override
  String get deviceDeniedBody =>
      'Ask whoever manages this server, or try signing in again.';

  @override
  String get mustChangePasswordTitle => 'Choose a new password';

  @override
  String get mustChangePasswordBody =>
      'This account is on a temporary password. Nothing else works until it is changed.';

  @override
  String get currentPassword => 'Current password';

  @override
  String get newPassword => 'New password';

  @override
  String get passwordChanged => 'Password changed';

  @override
  String get emptyFolderTitle => 'Nothing here yet';

  @override
  String get emptyFolderBody =>
      'Upload a file or make a folder to get started.';

  @override
  String get emptySharedTitle => 'Nothing shared with you';

  @override
  String get emptySharedBody => 'Anything someone shares will show up here.';

  @override
  String get emptyStarredTitle => 'No starred items';

  @override
  String get emptyStarredBody => 'Star anything you want to find quickly.';

  @override
  String get emptyRecentTitle => 'Nothing recent';

  @override
  String get emptyRecentBody => 'Files you change will appear here.';

  @override
  String get emptyTrashTitle => 'The trash is empty';

  @override
  String get emptyTrashBody =>
      'Items you delete wait here before they go for good.';

  @override
  String get emptySearchTitle => 'Nothing matched';

  @override
  String get emptySearchBody => 'Try a different word.';

  @override
  String get emptyActivityTitle => 'Nothing has happened yet';

  @override
  String get emptyDevicesTitle => 'No other devices';

  @override
  String get emptyUsersTitle => 'Only you so far';

  @override
  String get emptyUsersBody => 'Invite someone to give them their own space.';

  @override
  String get emptyTransfersTitle => 'No transfers';

  @override
  String get emptyTransfersBody =>
      'Uploads and downloads show their progress here.';

  @override
  String get errorOfflineTitle => 'You are offline';

  @override
  String get errorOfflineBody =>
      'Local Drive will pick up where it left off once you are back.';

  @override
  String get errorUnreachableTitle => 'Could not reach this server';

  @override
  String get errorUnreachableBody =>
      'It may be off, or on a network this device cannot see.';

  @override
  String get errorPermissionTitle => 'You do not have access';

  @override
  String get errorPermissionBody =>
      'Ask whoever owns this to share it with you.';

  @override
  String get errorNotFoundTitle => 'Not found';

  @override
  String get errorNotFoundBody => 'It may have been moved or deleted.';

  @override
  String get errorQuotaTitle => 'Out of space';

  @override
  String get errorQuotaBody => 'Free some room, or ask for a larger quota.';

  @override
  String get errorSessionTitle => 'Sign in again';

  @override
  String get errorSessionBody => 'This session has ended.';

  @override
  String get errorUnexpectedTitle => 'Something went wrong';

  @override
  String get errorUnexpectedBody => 'That did not work. Try again in a moment.';

  @override
  String get sortBy => 'Sort by';

  @override
  String get sortName => 'Name';

  @override
  String get sortUpdated => 'Last changed';

  @override
  String get sortSize => 'Size';

  @override
  String get viewGrid => 'Grid';

  @override
  String get viewList => 'List';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
      zero: 'Empty',
    );
    return '$_temp0';
  }

  @override
  String get folderNameLabel => 'Folder name';

  @override
  String get folderNameHint => 'Holiday photos';

  @override
  String get renameTo => 'New name';

  @override
  String get chooseLibrary => 'Where should it live';

  @override
  String libraryFreeSpace(String free) {
    return '$free free';
  }

  @override
  String get folderColor => 'Folder color';

  @override
  String get moveTo => 'Move to';

  @override
  String get confirmTrashTitle => 'Move to trash';

  @override
  String confirmTrashBody(String name) {
    return '$name goes to the trash. Anyone it was shared with loses access.';
  }

  @override
  String get confirmDeleteTitle => 'Delete for good';

  @override
  String confirmDeleteBody(String name) {
    return '$name and everything inside it will be gone. This cannot be undone.';
  }

  @override
  String trashRetentionNote(int days) {
    return 'Items in the trash are removed after $days days.';
  }

  @override
  String get emptyTrashAction => 'Empty the trash';

  @override
  String get sharePeopleTab => 'People';

  @override
  String get shareLinkTab => 'Link';

  @override
  String get sharePeopleHint => 'Tap someone to give them access.';

  @override
  String get shareRoleViewer => 'Can view';

  @override
  String get shareRoleEditor => 'Can edit';

  @override
  String get shareRoleNote => 'Only you can delete, move, or reshare this.';

  @override
  String get shareRemoveAccess => 'Remove access';

  @override
  String get shareCreateLink => 'Create a link';

  @override
  String get shareLinkAllowDownload => 'Allow download';

  @override
  String get shareLinkPassword => 'Password';

  @override
  String get shareLinkPasswordHint => 'Anyone opening the link needs this';

  @override
  String get shareLinkNoPassword => 'No password';

  @override
  String get shareLinkExpiry => 'Expires';

  @override
  String get shareExpiryDay => 'In a day';

  @override
  String get shareExpiryWeek => 'In a week';

  @override
  String get shareExpiryMonth => 'In a month';

  @override
  String get shareExpiryCustom => 'Pick a date';

  @override
  String get shareRevoke => 'Revoke this link';

  @override
  String get shareRevoked => 'That link no longer works';

  @override
  String shareReceived(String name, String item) {
    return '$name shared $item with you';
  }

  @override
  String get versionHistory => 'Version history';

  @override
  String get versionCurrent => 'Current';

  @override
  String get versionRestored => 'Restored an earlier version';

  @override
  String get storageTotal => 'Across every drive';

  @override
  String get storageYours => 'Your files';

  @override
  String storageUsedOf(String used, String total) {
    return '$used of $total used';
  }

  @override
  String sidebarStorageUsed(String used) {
    return '$used used';
  }

  @override
  String sidebarStorageFree(String free) {
    return '$free free';
  }

  @override
  String get sidebarStorageDiskLimited => 'Disk is lower than your quota';

  @override
  String get storageDefault => 'Default';

  @override
  String get storageSetDefault => 'Make default';

  @override
  String get storageDetectedDrives => 'Detected drives';

  @override
  String get storageUseThisDrive => 'Use this drive';

  @override
  String get storageFormat => 'Format';

  @override
  String get storageEject => 'Eject';

  @override
  String get storageCombine => 'Combine into one drive';

  @override
  String get storageOffline => 'Not connected';

  @override
  String storageOfflineBanner(String name) {
    return '$name is not connected right now. Everything else keeps working.';
  }

  @override
  String get storageSafeToUnplug => 'It is safe to unplug this drive now';

  @override
  String get storageFormatWarning =>
      'Everything on this drive will be permanently deleted. Type the phrase below to continue.';

  @override
  String get storageFormatPhrase => 'ERASE THIS DRIVE';

  @override
  String get storageFormatPhraseHint => 'Type the phrase exactly';

  @override
  String get storageHelperUnavailable =>
      'Drive management is not available on this deployment.';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsServer => 'Server';

  @override
  String get settingsUsers => 'Users';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsSwitchNode => 'Switch server';

  @override
  String get deepLinkOtherServerTitle => 'That link is for a different server';

  @override
  String deepLinkOtherServerBody(String server) {
    return 'This link points at $server. You are signed in somewhere else, so opening it means switching servers first.';
  }

  @override
  String get shareReceivedOne => 'Added to your uploads';

  @override
  String shareReceivedMany(int count) {
    return '$count files added to your uploads';
  }

  @override
  String get trayOpen => 'Open Local Drive';

  @override
  String get trayTransfers => 'Transfers';

  @override
  String get trayQuit => 'Quit';

  @override
  String get launchAtStartup => 'Open when I sign in to this computer';

  @override
  String get notificationsWhyTitle => 'Let Local Drive show transfer progress';

  @override
  String get notificationsWhyBody =>
      'A notification is what keeps an upload running after you leave the app. Without it your device is free to stop the transfer as soon as the screen turns off.';

  @override
  String get notificationsAllow => 'Allow notifications';

  @override
  String get notificationsNotNow => 'Not now';

  @override
  String get nearbyWhyTitle => 'See who is on this network';

  @override
  String get nearbyWhyBody =>
      'Local Drive can show which people are on this Wi-Fi right now, so sharing with someone in the same room is one tap. It only looks while this sheet is open, and the file still goes through your own server either way.';

  @override
  String get nearbyAllow => 'Show who is nearby';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get settingsTwoFactor => 'Two-factor authentication';

  @override
  String get settingsRequireApproval => 'Approve new devices';

  @override
  String get settingsRequireApprovalNote =>
      'A device signing in for the first time waits until one you already use lets it in.';

  @override
  String get settingsLanDiscovery => 'Announce on the local network';

  @override
  String get settingsLanDiscoveryNote =>
      'Lets the app find this server without typing its address.';

  @override
  String get settingsSelfRegistration => 'Anyone can create an account';

  @override
  String get settingsSelfRegistrationNote =>
      'Off is safer. Invite people instead.';

  @override
  String get usersInviteSomeone => 'Invite someone';

  @override
  String get usersInviteLabel => 'Who is this for';

  @override
  String get usersInviteHint => 'A name to remember them by';

  @override
  String get usersInviteCreated =>
      'Send them this code however you already talk.';

  @override
  String get usersResetPassword => 'Reset their password';

  @override
  String get usersTemporaryPassword => 'Temporary password';

  @override
  String get usersTemporaryPasswordNote =>
      'They will be asked to choose a new one when they sign in.';

  @override
  String get usersMakeAdmin => 'Make admin';

  @override
  String get usersMakeMember => 'Make member';

  @override
  String get devicesThisDevice => 'This device';

  @override
  String devicesLastSeen(String when) {
    return 'Last seen $when';
  }

  @override
  String get devicesRevoke => 'Sign this device out';

  @override
  String get devicesPendingSection => 'Waiting for approval';

  @override
  String get devicesApprovedToast => 'Device approved';

  @override
  String get devicesDeniedToast => 'Device denied';

  @override
  String get transfersTitle => 'Transfers';

  @override
  String transfersSummary(int done, int total) {
    return '$done of $total uploaded';
  }

  @override
  String transfersNeedAttention(int count) {
    return '$count need attention';
  }

  @override
  String get transferQueued => 'Queued';

  @override
  String get transferInProgress => 'Uploading';

  @override
  String get transferRetrying => 'Retrying';

  @override
  String get transferCompleted => 'Done';

  @override
  String get transferFailed => 'Failed';

  @override
  String get transferRetry => 'Retry';

  @override
  String get transferPausedOffline => 'Paused, waiting for a connection';

  @override
  String get offlineMakeAvailable => 'Make available offline';

  @override
  String get offlineRemoveDownload => 'Remove the download';

  @override
  String offlineRemoved(String name) {
    return '$name is no longer kept on this device';
  }

  @override
  String offlineQueued(String name) {
    return '$name will be kept on this device';
  }

  @override
  String get offlineOverCapTitle => 'This will use more space than your limit';

  @override
  String offlineOverCapBody(String projected, String cap) {
    return 'Keeping this would bring offline files to $projected, past the $cap limit set on this device. You can continue, or raise the limit in Settings.';
  }

  @override
  String get offlineDownloadsTitle => 'Downloads on this device';

  @override
  String get offlineDownloadsBody =>
      'Space used by files kept for offline use. This is separate from the server\'s own storage.';

  @override
  String offlineFilesKept(int count) {
    return '$count files kept';
  }

  @override
  String get offlineChosenIndividually => 'Chosen individually';

  @override
  String get offlineClearAll => 'Remove all downloads';

  @override
  String get offlineClearAllConfirm =>
      'Every file kept on this device is removed. Nothing on the server changes, and you can mark anything offline again later.';

  @override
  String get offlineCleared => 'Offline files removed';

  @override
  String get offlineSoftCapLabel => 'Warn above';

  @override
  String get offlineNoLimit => 'No limit';

  @override
  String get offlineNothingKept => 'Nothing is kept on this device yet';

  @override
  String get offlineNeedsConnection => 'Needs a connection';

  @override
  String get previewCannotPreview => 'This type has no preview';

  @override
  String get previewCannotOpenTitle => 'This file would not open';

  @override
  String get previewCannotOpenBody =>
      'It may be damaged, or saved in a format this reader does not understand. Downloading it and opening it in another app should still work.';

  @override
  String get previewDownloadToOpen => 'Download it to open it in another app';

  @override
  String previewPageOf(String page, String total) {
    return '$page of $total';
  }

  @override
  String get previewPreviousPage => 'Previous page';

  @override
  String get previewNextPage => 'Next page';

  @override
  String get previewSkipBack => 'Back 15 seconds';

  @override
  String get previewSkipForward => 'Forward 15 seconds';

  @override
  String get previewTruncated =>
      'Showing the start of this file. It is too large to open in full here.';

  @override
  String get sheetEmptyTitle => 'This spreadsheet has no cells';

  @override
  String get sheetEmptyBody => 'It opened, but there is nothing in it to show.';

  @override
  String sheetUnnamed(String number) {
    return 'Sheet $number';
  }

  @override
  String get documentEmptyTitle => 'This document has no text';

  @override
  String get documentEmptyBody =>
      'It opened, but there is nothing in it to show.';

  @override
  String get downloadNoFiles => 'Folders cannot be downloaded as one file';

  @override
  String downloadQueuedOne(String name) {
    return '$name is downloading';
  }

  @override
  String downloadQueuedMany(int count) {
    return '$count files are downloading';
  }

  @override
  String downloadSavedTo(String location) {
    return 'Saved to $location';
  }

  @override
  String sizeBytes(String size) {
    return '$size B';
  }

  @override
  String sizeKilobytes(String size) {
    return '$size KB';
  }

  @override
  String sizeMegabytes(String size) {
    return '$size MB';
  }

  @override
  String sizeGigabytes(String size) {
    return '$size GB';
  }

  @override
  String sizeTerabytes(String size) {
    return '$size TB';
  }

  @override
  String get timeJustNow => 'Just now';

  @override
  String timeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String timeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: 'Yesterday',
    );
    return '$_temp0';
  }

  @override
  String get twoFactorTitle => 'Two-factor authentication';

  @override
  String get twoFactorRequiredBody =>
      'This account manages the server, so two-factor is required. It takes about a minute.';

  @override
  String get twoFactorOptionalBody =>
      'Add a second step when signing in. You choose whether to use it.';

  @override
  String get twoFactorScanTitle => 'Add this to your authenticator app';

  @override
  String get twoFactorUseQr => 'Scan a code';

  @override
  String get twoFactorUseKey => 'Enter a key';

  @override
  String get twoFactorKeyBody =>
      'Use this if the app is on another device, or you keep codes in a password manager.';

  @override
  String get twoFactorConfirmTitle => 'Enter the six digit code it shows';

  @override
  String get twoFactorCodeHint => 'Six digits';

  @override
  String get twoFactorTurnOn => 'Turn on two-factor';

  @override
  String get twoFactorOn => 'Two-factor is on';

  @override
  String get twoFactorOff => 'Off';

  @override
  String get twoFactorAlreadyOnBody =>
      'This account already asks for a code when signing in.';

  @override
  String get recoveryCodesTitle => 'Save these recovery codes';

  @override
  String get recoveryCodesBody =>
      'Each one signs you in once if you lose the authenticator. Keep them somewhere other than this device.';

  @override
  String get moreActions => 'More';

  @override
  String get dropToUpload => 'Drop to upload';

  @override
  String get dropToUploadHint => 'Folders keep their structure';

  @override
  String get dropToUploadHintWeb => 'Files are added to this folder';

  @override
  String get errorFoldersNotSupportedWeb =>
      'Folders cannot be dropped in a browser. Drop the files inside it instead.';

  @override
  String get uploadClashTitle => 'That name is already here';

  @override
  String get uploadClashTitleMany => 'Some names are already here';

  @override
  String uploadClashBody(String name) {
    return 'This folder already has a file called $name.';
  }

  @override
  String uploadClashBodyMany(String count) {
    return '$count of the files you are uploading have names this folder already uses.';
  }

  @override
  String get uploadClashKeepBoth => 'Keep both';

  @override
  String get uploadClashReplace => 'Replace with the new one';

  @override
  String get uploadClashSkip => 'Skip these';

  @override
  String get versionSection => 'Version';

  @override
  String get versionInstalled => 'Installed';

  @override
  String get updateCheck => 'Check for updates';

  @override
  String get updateChecking => 'Checking';

  @override
  String get updateUpToDate => 'You are up to date';

  @override
  String updateUpToDateBody(String version) {
    return 'Version $version is the newest release.';
  }

  @override
  String updateAvailable(String version) {
    return 'Version $version is available';
  }

  @override
  String get updateInstall => 'Download and install';

  @override
  String get updateDownloading => 'Downloading';

  @override
  String get updateInstalling => 'Installing';

  @override
  String get updateRestartNote =>
      'The app closes and reopens once the update is in place.';

  @override
  String get updateAndroidNote =>
      'Android asks for permission before it installs.';

  @override
  String get updateNotes => 'What changed';

  @override
  String get updateManualOnly =>
      'This build updates with whatever is serving it.';
}
