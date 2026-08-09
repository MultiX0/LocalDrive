import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L10n
/// returned by `L10n.of(context)`.
///
/// Applications need to include `L10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L10n.localizationsDelegates,
///   supportedLocales: L10n.supportedLocales,
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
/// be consistent with the languages listed in the L10n.supportedLocales
/// property.
abstract class L10n {
  L10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n)!;
  }

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

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
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Local Drive'**
  String get appName;

  /// No description provided for @actionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get actionContinue;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionRetry;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get actionRemove;

  /// No description provided for @actionCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get actionCopy;

  /// No description provided for @actionCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get actionCopyLink;

  /// No description provided for @actionCopyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get actionCopyCode;

  /// No description provided for @actionCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get actionCopied;

  /// No description provided for @actionPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get actionPlay;

  /// No description provided for @actionPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get actionPause;

  /// No description provided for @actionFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get actionFullscreen;

  /// No description provided for @actionExitFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Exit full screen'**
  String get actionExitFullscreen;

  /// No description provided for @actionMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get actionMute;

  /// No description provided for @actionUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get actionUnmute;

  /// No description provided for @actionOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get actionOpen;

  /// No description provided for @actionRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get actionRename;

  /// No description provided for @actionMove.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get actionMove;

  /// No description provided for @actionShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get actionShare;

  /// No description provided for @actionBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// No description provided for @actionRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get actionRefresh;

  /// No description provided for @actionDeselect.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get actionDeselect;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// No description provided for @navCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get navCreate;

  /// No description provided for @navShared.
  ///
  /// In en, this message translates to:
  /// **'Shared'**
  String get navShared;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @myFiles.
  ///
  /// In en, this message translates to:
  /// **'My Files'**
  String get myFiles;

  /// No description provided for @newFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get newFolder;

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// No description provided for @uploadFile.
  ///
  /// In en, this message translates to:
  /// **'Upload a file'**
  String get uploadFile;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @galleryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No photos yet'**
  String get galleryEmptyTitle;

  /// No description provided for @galleryEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Anything you upload that is a picture or a clip shows up here, newest first.'**
  String get galleryEmptyBody;

  /// No description provided for @shareOneAtATime.
  ///
  /// In en, this message translates to:
  /// **'Share one photo at a time, so each person gets the access you meant'**
  String get shareOneAtATime;

  /// No description provided for @gallerySortTitle.
  ///
  /// In en, this message translates to:
  /// **'Sort and group'**
  String get gallerySortTitle;

  /// No description provided for @gallerySortTaken.
  ///
  /// In en, this message translates to:
  /// **'Date taken'**
  String get gallerySortTaken;

  /// No description provided for @gallerySortAdded.
  ///
  /// In en, this message translates to:
  /// **'Date added'**
  String get gallerySortAdded;

  /// No description provided for @gallerySortModified.
  ///
  /// In en, this message translates to:
  /// **'Date modified'**
  String get gallerySortModified;

  /// No description provided for @gallerySortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get gallerySortName;

  /// No description provided for @gallerySortSize.
  ///
  /// In en, this message translates to:
  /// **'File size'**
  String get gallerySortSize;

  /// No description provided for @galleryGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Group by'**
  String get galleryGroupTitle;

  /// No description provided for @galleryGroupDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get galleryGroupDay;

  /// No description provided for @galleryGroupMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get galleryGroupMonth;

  /// No description provided for @galleryGroupYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get galleryGroupYear;

  /// No description provided for @galleryGroupNone.
  ///
  /// In en, this message translates to:
  /// **'Do not group'**
  String get galleryGroupNone;

  /// No description provided for @galleryGroupUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Grouping only applies when photos are ordered by date.'**
  String get galleryGroupUnavailable;

  /// No description provided for @galleryPositionOf.
  ///
  /// In en, this message translates to:
  /// **'{position} of {total}'**
  String galleryPositionOf(String position, String total);

  /// No description provided for @gallerySummary.
  ///
  /// In en, this message translates to:
  /// **'{photos} photos, {videos} videos'**
  String gallerySummary(int photos, int videos);

  /// No description provided for @gallerySelected.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String gallerySelected(int count);

  /// No description provided for @galleryColumns.
  ///
  /// In en, this message translates to:
  /// **'Tile size'**
  String get galleryColumns;

  /// No description provided for @galleryToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get galleryToday;

  /// No description provided for @galleryYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get galleryYesterday;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @sharedWithMe.
  ///
  /// In en, this message translates to:
  /// **'Shared with me'**
  String get sharedWithMe;

  /// No description provided for @recent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recent;

  /// No description provided for @starred.
  ///
  /// In en, this message translates to:
  /// **'Starred'**
  String get starred;

  /// No description provided for @trash.
  ///
  /// In en, this message translates to:
  /// **'Trash'**
  String get trash;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @storage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get storage;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @activity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activity;

  /// No description provided for @devices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get devices;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @permanentlyDelete.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete'**
  String get permanentlyDelete;

  /// No description provided for @pendingApproval.
  ///
  /// In en, this message translates to:
  /// **'Pending approval'**
  String get pendingApproval;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @deny.
  ///
  /// In en, this message translates to:
  /// **'Deny'**
  String get deny;

  /// No description provided for @scanForServers.
  ///
  /// In en, this message translates to:
  /// **'Scan for servers'**
  String get scanForServers;

  /// No description provided for @linkExpiration.
  ///
  /// In en, this message translates to:
  /// **'Link expiration'**
  String get linkExpiration;

  /// No description provided for @neverExpires.
  ///
  /// In en, this message translates to:
  /// **'Never expires'**
  String get neverExpires;

  /// No description provided for @setUpThisServer.
  ///
  /// In en, this message translates to:
  /// **'Set up this server'**
  String get setUpThisServer;

  /// No description provided for @invite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get invite;

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get roleAdmin;

  /// No description provided for @roleMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get roleMember;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPassword;

  /// No description provided for @sharedWithPerson.
  ///
  /// In en, this message translates to:
  /// **'Share with a person'**
  String get sharedWithPerson;

  /// No description provided for @nearby.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get nearby;

  /// No description provided for @availableOffline.
  ///
  /// In en, this message translates to:
  /// **'Available offline'**
  String get availableOffline;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Your files, your hardware'**
  String get welcomeTitle;

  /// No description provided for @welcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Local Drive keeps everything on a server you run, in a place you can point at.'**
  String get welcomeBody;

  /// No description provided for @welcomeStart.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get welcomeStart;

  /// No description provided for @welcomePointHardware.
  ///
  /// In en, this message translates to:
  /// **'Files live on hardware you own. Nothing is copied to anyone else\'s machine.'**
  String get welcomePointHardware;

  /// No description provided for @welcomePointKeys.
  ///
  /// In en, this message translates to:
  /// **'No account, no subscription, and no telemetry. Nothing is reported anywhere.'**
  String get welcomePointKeys;

  /// No description provided for @welcomePointDevices.
  ///
  /// In en, this message translates to:
  /// **'Phone, tablet, laptop, and browser reach the same library.'**
  String get welcomePointDevices;

  /// No description provided for @connectTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect to a server'**
  String get connectTitle;

  /// No description provided for @connectBody.
  ///
  /// In en, this message translates to:
  /// **'Pick one found on your network, or type its address.'**
  String get connectBody;

  /// No description provided for @scanningNetwork.
  ///
  /// In en, this message translates to:
  /// **'Scanning your network'**
  String get scanningNetwork;

  /// No description provided for @scanAgain.
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get scanAgain;

  /// No description provided for @enterAddressManually.
  ///
  /// In en, this message translates to:
  /// **'Enter address manually'**
  String get enterAddressManually;

  /// No description provided for @addressHint.
  ///
  /// In en, this message translates to:
  /// **'192.168.1.10 or drive.example.com'**
  String get addressHint;

  /// No description provided for @nothingFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing found on this network'**
  String get nothingFound;

  /// No description provided for @nothingFoundBody.
  ///
  /// In en, this message translates to:
  /// **'That is normal on a different subnet, or if discovery is turned off. Type the address instead.'**
  String get nothingFoundBody;

  /// No description provided for @serverReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get serverReady;

  /// No description provided for @serverNeedsSetup.
  ///
  /// In en, this message translates to:
  /// **'Needs setup'**
  String get serverNeedsSetup;

  /// No description provided for @connectAction.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connectAction;

  /// No description provided for @couldNotReachServer.
  ///
  /// In en, this message translates to:
  /// **'Could not reach that address'**
  String get couldNotReachServer;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a language'**
  String get languageTitle;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @setupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up this server'**
  String get setupTitle;

  /// No description provided for @setupBody.
  ///
  /// In en, this message translates to:
  /// **'This is a brand new server. The account you make now is its admin.'**
  String get setupBody;

  /// No description provided for @setupAdminSection.
  ///
  /// In en, this message translates to:
  /// **'Admin account'**
  String get setupAdminSection;

  /// No description provided for @setupOnceNotice.
  ///
  /// In en, this message translates to:
  /// **'This screen runs once. As soon as this account exists the server stops accepting setup, and everyone else joins by invite.'**
  String get setupOnceNotice;

  /// No description provided for @serverNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Server name'**
  String get serverNameLabel;

  /// No description provided for @serverNameHint.
  ///
  /// In en, this message translates to:
  /// **'What people see when they connect'**
  String get serverNameHint;

  /// No description provided for @usernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameLabel;

  /// No description provided for @usernameHint.
  ///
  /// In en, this message translates to:
  /// **'The name you sign in with'**
  String get usernameHint;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @passwordHintNew.
  ///
  /// In en, this message translates to:
  /// **'At least 10 characters'**
  String get passwordHintNew;

  /// No description provided for @passwordHintExisting.
  ///
  /// In en, this message translates to:
  /// **'The password for this account'**
  String get passwordHintExisting;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPasswordLabel;

  /// No description provided for @confirmPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Type the same password again'**
  String get confirmPasswordHint;

  /// No description provided for @inviteCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get inviteCodeLabel;

  /// No description provided for @inviteCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Like ABCD-1234'**
  String get inviteCodeHint;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Those passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least 10 characters'**
  String get passwordTooShort;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get signInTitle;

  /// No description provided for @signInBody.
  ///
  /// In en, this message translates to:
  /// **'Sign in to {serverName}.'**
  String signInBody(String serverName);

  /// No description provided for @createAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get createAccountTitle;

  /// No description provided for @createAccountBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the invite code you were given.'**
  String get createAccountBody;

  /// No description provided for @noAccountYet.
  ///
  /// In en, this message translates to:
  /// **'No account yet?'**
  String get noAccountYet;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @twoFactorCode.
  ///
  /// In en, this message translates to:
  /// **'Two-factor code'**
  String get twoFactorCode;

  /// No description provided for @twoFactorHint.
  ///
  /// In en, this message translates to:
  /// **'From your authenticator app'**
  String get twoFactorHint;

  /// No description provided for @waitingForApprovalTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval'**
  String get waitingForApprovalTitle;

  /// No description provided for @waitingForApprovalBody.
  ///
  /// In en, this message translates to:
  /// **'This device is new. Approve it from Settings on a device you are already signed in to.'**
  String get waitingForApprovalBody;

  /// No description provided for @deviceApproved.
  ///
  /// In en, this message translates to:
  /// **'This device was approved'**
  String get deviceApproved;

  /// No description provided for @deviceDeniedTitle.
  ///
  /// In en, this message translates to:
  /// **'This device was not approved'**
  String get deviceDeniedTitle;

  /// No description provided for @deviceDeniedBody.
  ///
  /// In en, this message translates to:
  /// **'Ask whoever manages this server, or try signing in again.'**
  String get deviceDeniedBody;

  /// No description provided for @mustChangePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a new password'**
  String get mustChangePasswordTitle;

  /// No description provided for @mustChangePasswordBody.
  ///
  /// In en, this message translates to:
  /// **'This account is on a temporary password. Nothing else works until it is changed.'**
  String get mustChangePasswordBody;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get passwordChanged;

  /// No description provided for @emptyFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get emptyFolderTitle;

  /// No description provided for @emptyFolderBody.
  ///
  /// In en, this message translates to:
  /// **'Upload a file or make a folder to get started.'**
  String get emptyFolderBody;

  /// No description provided for @emptySharedTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing shared with you'**
  String get emptySharedTitle;

  /// No description provided for @emptySharedBody.
  ///
  /// In en, this message translates to:
  /// **'Anything someone shares will show up here.'**
  String get emptySharedBody;

  /// No description provided for @emptyStarredTitle.
  ///
  /// In en, this message translates to:
  /// **'No starred items'**
  String get emptyStarredTitle;

  /// No description provided for @emptyStarredBody.
  ///
  /// In en, this message translates to:
  /// **'Star anything you want to find quickly.'**
  String get emptyStarredBody;

  /// No description provided for @emptyRecentTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing recent'**
  String get emptyRecentTitle;

  /// No description provided for @emptyRecentBody.
  ///
  /// In en, this message translates to:
  /// **'Files you change will appear here.'**
  String get emptyRecentBody;

  /// No description provided for @emptyTrashTitle.
  ///
  /// In en, this message translates to:
  /// **'The trash is empty'**
  String get emptyTrashTitle;

  /// No description provided for @emptyTrashBody.
  ///
  /// In en, this message translates to:
  /// **'Items you delete wait here before they go for good.'**
  String get emptyTrashBody;

  /// No description provided for @emptySearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing matched'**
  String get emptySearchTitle;

  /// No description provided for @emptySearchBody.
  ///
  /// In en, this message translates to:
  /// **'Try a different word.'**
  String get emptySearchBody;

  /// No description provided for @emptyActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing has happened yet'**
  String get emptyActivityTitle;

  /// No description provided for @emptyDevicesTitle.
  ///
  /// In en, this message translates to:
  /// **'No other devices'**
  String get emptyDevicesTitle;

  /// No description provided for @emptyUsersTitle.
  ///
  /// In en, this message translates to:
  /// **'Only you so far'**
  String get emptyUsersTitle;

  /// No description provided for @emptyUsersBody.
  ///
  /// In en, this message translates to:
  /// **'Invite someone to give them their own space.'**
  String get emptyUsersBody;

  /// No description provided for @emptyTransfersTitle.
  ///
  /// In en, this message translates to:
  /// **'No transfers'**
  String get emptyTransfersTitle;

  /// No description provided for @emptyTransfersBody.
  ///
  /// In en, this message translates to:
  /// **'Uploads and downloads show their progress here.'**
  String get emptyTransfersBody;

  /// No description provided for @errorOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'You are offline'**
  String get errorOfflineTitle;

  /// No description provided for @errorOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'Local Drive will pick up where it left off once you are back.'**
  String get errorOfflineBody;

  /// No description provided for @errorUnreachableTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not reach this server'**
  String get errorUnreachableTitle;

  /// No description provided for @errorUnreachableBody.
  ///
  /// In en, this message translates to:
  /// **'It may be off, or on a network this device cannot see.'**
  String get errorUnreachableBody;

  /// No description provided for @errorPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'You do not have access'**
  String get errorPermissionTitle;

  /// No description provided for @errorPermissionBody.
  ///
  /// In en, this message translates to:
  /// **'Ask whoever owns this to share it with you.'**
  String get errorPermissionBody;

  /// No description provided for @errorNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get errorNotFoundTitle;

  /// No description provided for @errorNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'It may have been moved or deleted.'**
  String get errorNotFoundBody;

  /// No description provided for @errorQuotaTitle.
  ///
  /// In en, this message translates to:
  /// **'Out of space'**
  String get errorQuotaTitle;

  /// No description provided for @errorQuotaBody.
  ///
  /// In en, this message translates to:
  /// **'Free some room, or ask for a larger quota.'**
  String get errorQuotaBody;

  /// No description provided for @errorSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in again'**
  String get errorSessionTitle;

  /// No description provided for @errorSessionBody.
  ///
  /// In en, this message translates to:
  /// **'This session has ended.'**
  String get errorSessionBody;

  /// No description provided for @errorUnexpectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorUnexpectedTitle;

  /// No description provided for @errorUnexpectedBody.
  ///
  /// In en, this message translates to:
  /// **'That did not work. Try again in a moment.'**
  String get errorUnexpectedBody;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// No description provided for @sortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get sortName;

  /// No description provided for @sortUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last changed'**
  String get sortUpdated;

  /// No description provided for @sortSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get sortSize;

  /// No description provided for @viewGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get viewGrid;

  /// No description provided for @viewList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get viewList;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(int count);

  /// No description provided for @itemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Empty} =1{1 item} other{{count} items}}'**
  String itemCount(int count);

  /// No description provided for @folderNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get folderNameLabel;

  /// No description provided for @folderNameHint.
  ///
  /// In en, this message translates to:
  /// **'Holiday photos'**
  String get folderNameHint;

  /// No description provided for @renameTo.
  ///
  /// In en, this message translates to:
  /// **'New name'**
  String get renameTo;

  /// No description provided for @chooseLibrary.
  ///
  /// In en, this message translates to:
  /// **'Where should it live'**
  String get chooseLibrary;

  /// No description provided for @libraryFreeSpace.
  ///
  /// In en, this message translates to:
  /// **'{free} free'**
  String libraryFreeSpace(String free);

  /// No description provided for @folderColor.
  ///
  /// In en, this message translates to:
  /// **'Folder color'**
  String get folderColor;

  /// No description provided for @moveTo.
  ///
  /// In en, this message translates to:
  /// **'Move to'**
  String get moveTo;

  /// No description provided for @confirmTrashTitle.
  ///
  /// In en, this message translates to:
  /// **'Move to trash'**
  String get confirmTrashTitle;

  /// No description provided for @confirmTrashBody.
  ///
  /// In en, this message translates to:
  /// **'{name} goes to the trash. Anyone it was shared with loses access.'**
  String confirmTrashBody(String name);

  /// No description provided for @confirmDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete for good'**
  String get confirmDeleteTitle;

  /// No description provided for @confirmDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'{name} and everything inside it will be gone. This cannot be undone.'**
  String confirmDeleteBody(String name);

  /// No description provided for @trashRetentionNote.
  ///
  /// In en, this message translates to:
  /// **'Items in the trash are removed after {days} days.'**
  String trashRetentionNote(int days);

  /// No description provided for @emptyTrashAction.
  ///
  /// In en, this message translates to:
  /// **'Empty the trash'**
  String get emptyTrashAction;

  /// No description provided for @sharePeopleTab.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get sharePeopleTab;

  /// No description provided for @shareLinkTab.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get shareLinkTab;

  /// No description provided for @sharePeopleHint.
  ///
  /// In en, this message translates to:
  /// **'Tap someone to give them access.'**
  String get sharePeopleHint;

  /// No description provided for @shareRoleViewer.
  ///
  /// In en, this message translates to:
  /// **'Can view'**
  String get shareRoleViewer;

  /// No description provided for @shareRoleEditor.
  ///
  /// In en, this message translates to:
  /// **'Can edit'**
  String get shareRoleEditor;

  /// No description provided for @shareRoleNote.
  ///
  /// In en, this message translates to:
  /// **'Only you can delete, move, or reshare this.'**
  String get shareRoleNote;

  /// No description provided for @shareRemoveAccess.
  ///
  /// In en, this message translates to:
  /// **'Remove access'**
  String get shareRemoveAccess;

  /// No description provided for @shareCreateLink.
  ///
  /// In en, this message translates to:
  /// **'Create a link'**
  String get shareCreateLink;

  /// No description provided for @shareLinkAllowDownload.
  ///
  /// In en, this message translates to:
  /// **'Allow download'**
  String get shareLinkAllowDownload;

  /// No description provided for @shareLinkPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get shareLinkPassword;

  /// No description provided for @shareLinkPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Anyone opening the link needs this'**
  String get shareLinkPasswordHint;

  /// No description provided for @shareLinkNoPassword.
  ///
  /// In en, this message translates to:
  /// **'No password'**
  String get shareLinkNoPassword;

  /// No description provided for @shareLinkExpiry.
  ///
  /// In en, this message translates to:
  /// **'Expires'**
  String get shareLinkExpiry;

  /// No description provided for @shareExpiryDay.
  ///
  /// In en, this message translates to:
  /// **'In a day'**
  String get shareExpiryDay;

  /// No description provided for @shareExpiryWeek.
  ///
  /// In en, this message translates to:
  /// **'In a week'**
  String get shareExpiryWeek;

  /// No description provided for @shareExpiryMonth.
  ///
  /// In en, this message translates to:
  /// **'In a month'**
  String get shareExpiryMonth;

  /// No description provided for @shareExpiryCustom.
  ///
  /// In en, this message translates to:
  /// **'Pick a date'**
  String get shareExpiryCustom;

  /// No description provided for @shareRevoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke this link'**
  String get shareRevoke;

  /// No description provided for @shareRevoked.
  ///
  /// In en, this message translates to:
  /// **'That link no longer works'**
  String get shareRevoked;

  /// No description provided for @shareReceived.
  ///
  /// In en, this message translates to:
  /// **'{name} shared {item} with you'**
  String shareReceived(String name, String item);

  /// No description provided for @versionHistory.
  ///
  /// In en, this message translates to:
  /// **'Version history'**
  String get versionHistory;

  /// No description provided for @versionCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get versionCurrent;

  /// No description provided for @versionRestored.
  ///
  /// In en, this message translates to:
  /// **'Restored an earlier version'**
  String get versionRestored;

  /// No description provided for @storageTotal.
  ///
  /// In en, this message translates to:
  /// **'Across every drive'**
  String get storageTotal;

  /// No description provided for @storageYours.
  ///
  /// In en, this message translates to:
  /// **'Your files'**
  String get storageYours;

  /// No description provided for @storageUsedOf.
  ///
  /// In en, this message translates to:
  /// **'{used} of {total} used'**
  String storageUsedOf(String used, String total);

  /// No description provided for @sidebarStorageUsed.
  ///
  /// In en, this message translates to:
  /// **'{used} used'**
  String sidebarStorageUsed(String used);

  /// No description provided for @sidebarStorageFree.
  ///
  /// In en, this message translates to:
  /// **'{free} free'**
  String sidebarStorageFree(String free);

  /// No description provided for @sidebarStorageDiskLimited.
  ///
  /// In en, this message translates to:
  /// **'Disk is lower than your quota'**
  String get sidebarStorageDiskLimited;

  /// No description provided for @storageDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get storageDefault;

  /// No description provided for @storageSetDefault.
  ///
  /// In en, this message translates to:
  /// **'Make default'**
  String get storageSetDefault;

  /// No description provided for @storageDetectedDrives.
  ///
  /// In en, this message translates to:
  /// **'Detected drives'**
  String get storageDetectedDrives;

  /// No description provided for @storageUseThisDrive.
  ///
  /// In en, this message translates to:
  /// **'Use this drive'**
  String get storageUseThisDrive;

  /// No description provided for @storageFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get storageFormat;

  /// No description provided for @storageEject.
  ///
  /// In en, this message translates to:
  /// **'Eject'**
  String get storageEject;

  /// No description provided for @storageCombine.
  ///
  /// In en, this message translates to:
  /// **'Combine into one drive'**
  String get storageCombine;

  /// No description provided for @storageOffline.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get storageOffline;

  /// No description provided for @storageOfflineBanner.
  ///
  /// In en, this message translates to:
  /// **'{name} is not connected right now. Everything else keeps working.'**
  String storageOfflineBanner(String name);

  /// No description provided for @storageSafeToUnplug.
  ///
  /// In en, this message translates to:
  /// **'It is safe to unplug this drive now'**
  String get storageSafeToUnplug;

  /// No description provided for @storageFormatWarning.
  ///
  /// In en, this message translates to:
  /// **'Everything on this drive will be permanently deleted. Type the phrase below to continue.'**
  String get storageFormatWarning;

  /// No description provided for @storageFormatPhrase.
  ///
  /// In en, this message translates to:
  /// **'ERASE THIS DRIVE'**
  String get storageFormatPhrase;

  /// No description provided for @storageFormatPhraseHint.
  ///
  /// In en, this message translates to:
  /// **'Type the phrase exactly'**
  String get storageFormatPhraseHint;

  /// No description provided for @storageHelperUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Drive management is not available on this deployment.'**
  String get storageHelperUnavailable;

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get settingsServer;

  /// No description provided for @settingsUsers.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get settingsUsers;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsSwitchNode.
  ///
  /// In en, this message translates to:
  /// **'Switch server'**
  String get settingsSwitchNode;

  /// No description provided for @deepLinkOtherServerTitle.
  ///
  /// In en, this message translates to:
  /// **'That link is for a different server'**
  String get deepLinkOtherServerTitle;

  /// No description provided for @deepLinkOtherServerBody.
  ///
  /// In en, this message translates to:
  /// **'This link points at {server}. You are signed in somewhere else, so opening it means switching servers first.'**
  String deepLinkOtherServerBody(String server);

  /// No description provided for @shareReceivedOne.
  ///
  /// In en, this message translates to:
  /// **'Added to your uploads'**
  String get shareReceivedOne;

  /// No description provided for @shareReceivedMany.
  ///
  /// In en, this message translates to:
  /// **'{count} files added to your uploads'**
  String shareReceivedMany(int count);

  /// No description provided for @trayOpen.
  ///
  /// In en, this message translates to:
  /// **'Open Local Drive'**
  String get trayOpen;

  /// No description provided for @trayTransfers.
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get trayTransfers;

  /// No description provided for @trayQuit.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get trayQuit;

  /// No description provided for @launchAtStartup.
  ///
  /// In en, this message translates to:
  /// **'Open when I sign in to this computer'**
  String get launchAtStartup;

  /// No description provided for @notificationsWhyTitle.
  ///
  /// In en, this message translates to:
  /// **'Let Local Drive show transfer progress'**
  String get notificationsWhyTitle;

  /// No description provided for @notificationsWhyBody.
  ///
  /// In en, this message translates to:
  /// **'A notification is what keeps an upload running after you leave the app. Without it your device is free to stop the transfer as soon as the screen turns off.'**
  String get notificationsWhyBody;

  /// No description provided for @notificationsAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications'**
  String get notificationsAllow;

  /// No description provided for @notificationsNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notificationsNotNow;

  /// No description provided for @nearbyWhyTitle.
  ///
  /// In en, this message translates to:
  /// **'See who is on this network'**
  String get nearbyWhyTitle;

  /// No description provided for @nearbyWhyBody.
  ///
  /// In en, this message translates to:
  /// **'Local Drive can show which people are on this Wi-Fi right now, so sharing with someone in the same room is one tap. It only looks while this sheet is open, and the file still goes through your own server either way.'**
  String get nearbyWhyBody;

  /// No description provided for @nearbyAllow.
  ///
  /// In en, this message translates to:
  /// **'Show who is nearby'**
  String get nearbyAllow;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;

  /// No description provided for @settingsTwoFactor.
  ///
  /// In en, this message translates to:
  /// **'Two-factor authentication'**
  String get settingsTwoFactor;

  /// No description provided for @settingsRequireApproval.
  ///
  /// In en, this message translates to:
  /// **'Approve new devices'**
  String get settingsRequireApproval;

  /// No description provided for @settingsRequireApprovalNote.
  ///
  /// In en, this message translates to:
  /// **'A device signing in for the first time waits until one you already use lets it in.'**
  String get settingsRequireApprovalNote;

  /// No description provided for @settingsLanDiscovery.
  ///
  /// In en, this message translates to:
  /// **'Announce on the local network'**
  String get settingsLanDiscovery;

  /// No description provided for @settingsLanDiscoveryNote.
  ///
  /// In en, this message translates to:
  /// **'Lets the app find this server without typing its address.'**
  String get settingsLanDiscoveryNote;

  /// No description provided for @settingsSelfRegistration.
  ///
  /// In en, this message translates to:
  /// **'Anyone can create an account'**
  String get settingsSelfRegistration;

  /// No description provided for @settingsSelfRegistrationNote.
  ///
  /// In en, this message translates to:
  /// **'Off is safer. Invite people instead.'**
  String get settingsSelfRegistrationNote;

  /// No description provided for @usersInviteSomeone.
  ///
  /// In en, this message translates to:
  /// **'Invite someone'**
  String get usersInviteSomeone;

  /// No description provided for @usersInviteLabel.
  ///
  /// In en, this message translates to:
  /// **'Who is this for'**
  String get usersInviteLabel;

  /// No description provided for @usersInviteHint.
  ///
  /// In en, this message translates to:
  /// **'A name to remember them by'**
  String get usersInviteHint;

  /// No description provided for @usersInviteCreated.
  ///
  /// In en, this message translates to:
  /// **'Send them this code however you already talk.'**
  String get usersInviteCreated;

  /// No description provided for @usersResetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset their password'**
  String get usersResetPassword;

  /// No description provided for @usersTemporaryPassword.
  ///
  /// In en, this message translates to:
  /// **'Temporary password'**
  String get usersTemporaryPassword;

  /// No description provided for @usersTemporaryPasswordNote.
  ///
  /// In en, this message translates to:
  /// **'They will be asked to choose a new one when they sign in.'**
  String get usersTemporaryPasswordNote;

  /// No description provided for @usersMakeAdmin.
  ///
  /// In en, this message translates to:
  /// **'Make admin'**
  String get usersMakeAdmin;

  /// No description provided for @usersMakeMember.
  ///
  /// In en, this message translates to:
  /// **'Make member'**
  String get usersMakeMember;

  /// No description provided for @devicesThisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get devicesThisDevice;

  /// No description provided for @devicesLastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last seen {when}'**
  String devicesLastSeen(String when);

  /// No description provided for @devicesRevoke.
  ///
  /// In en, this message translates to:
  /// **'Sign this device out'**
  String get devicesRevoke;

  /// No description provided for @devicesPendingSection.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval'**
  String get devicesPendingSection;

  /// No description provided for @devicesApprovedToast.
  ///
  /// In en, this message translates to:
  /// **'Device approved'**
  String get devicesApprovedToast;

  /// No description provided for @devicesDeniedToast.
  ///
  /// In en, this message translates to:
  /// **'Device denied'**
  String get devicesDeniedToast;

  /// No description provided for @transfersTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get transfersTitle;

  /// No description provided for @transfersSummary.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} uploaded'**
  String transfersSummary(int done, int total);

  /// No description provided for @transfersNeedAttention.
  ///
  /// In en, this message translates to:
  /// **'{count} need attention'**
  String transfersNeedAttention(int count);

  /// No description provided for @transferQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get transferQueued;

  /// No description provided for @transferInProgress.
  ///
  /// In en, this message translates to:
  /// **'Uploading'**
  String get transferInProgress;

  /// No description provided for @transferRetrying.
  ///
  /// In en, this message translates to:
  /// **'Retrying'**
  String get transferRetrying;

  /// No description provided for @transferCompleted.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get transferCompleted;

  /// No description provided for @transferFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get transferFailed;

  /// No description provided for @transferRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get transferRetry;

  /// No description provided for @transferPausedOffline.
  ///
  /// In en, this message translates to:
  /// **'Paused, waiting for a connection'**
  String get transferPausedOffline;

  /// No description provided for @offlineMakeAvailable.
  ///
  /// In en, this message translates to:
  /// **'Make available offline'**
  String get offlineMakeAvailable;

  /// No description provided for @offlineRemoveDownload.
  ///
  /// In en, this message translates to:
  /// **'Remove the download'**
  String get offlineRemoveDownload;

  /// No description provided for @offlineRemoved.
  ///
  /// In en, this message translates to:
  /// **'{name} is no longer kept on this device'**
  String offlineRemoved(String name);

  /// No description provided for @offlineQueued.
  ///
  /// In en, this message translates to:
  /// **'{name} will be kept on this device'**
  String offlineQueued(String name);

  /// No description provided for @offlineOverCapTitle.
  ///
  /// In en, this message translates to:
  /// **'This will use more space than your limit'**
  String get offlineOverCapTitle;

  /// No description provided for @offlineOverCapBody.
  ///
  /// In en, this message translates to:
  /// **'Keeping this would bring offline files to {projected}, past the {cap} limit set on this device. You can continue, or raise the limit in Settings.'**
  String offlineOverCapBody(String projected, String cap);

  /// No description provided for @offlineDownloadsTitle.
  ///
  /// In en, this message translates to:
  /// **'Downloads on this device'**
  String get offlineDownloadsTitle;

  /// No description provided for @offlineDownloadsBody.
  ///
  /// In en, this message translates to:
  /// **'Space used by files kept for offline use. This is separate from the server\'s own storage.'**
  String get offlineDownloadsBody;

  /// No description provided for @offlineFilesKept.
  ///
  /// In en, this message translates to:
  /// **'{count} files kept'**
  String offlineFilesKept(int count);

  /// No description provided for @offlineChosenIndividually.
  ///
  /// In en, this message translates to:
  /// **'Chosen individually'**
  String get offlineChosenIndividually;

  /// No description provided for @offlineClearAll.
  ///
  /// In en, this message translates to:
  /// **'Remove all downloads'**
  String get offlineClearAll;

  /// No description provided for @offlineClearAllConfirm.
  ///
  /// In en, this message translates to:
  /// **'Every file kept on this device is removed. Nothing on the server changes, and you can mark anything offline again later.'**
  String get offlineClearAllConfirm;

  /// No description provided for @offlineCleared.
  ///
  /// In en, this message translates to:
  /// **'Offline files removed'**
  String get offlineCleared;

  /// No description provided for @offlineSoftCapLabel.
  ///
  /// In en, this message translates to:
  /// **'Warn above'**
  String get offlineSoftCapLabel;

  /// No description provided for @offlineNoLimit.
  ///
  /// In en, this message translates to:
  /// **'No limit'**
  String get offlineNoLimit;

  /// No description provided for @offlineNothingKept.
  ///
  /// In en, this message translates to:
  /// **'Nothing is kept on this device yet'**
  String get offlineNothingKept;

  /// No description provided for @offlineNeedsConnection.
  ///
  /// In en, this message translates to:
  /// **'Needs a connection'**
  String get offlineNeedsConnection;

  /// No description provided for @previewCannotPreview.
  ///
  /// In en, this message translates to:
  /// **'This type has no preview'**
  String get previewCannotPreview;

  /// No description provided for @previewCannotOpenTitle.
  ///
  /// In en, this message translates to:
  /// **'This file would not open'**
  String get previewCannotOpenTitle;

  /// No description provided for @previewCannotOpenBody.
  ///
  /// In en, this message translates to:
  /// **'It may be damaged, or saved in a format this reader does not understand. Downloading it and opening it in another app should still work.'**
  String get previewCannotOpenBody;

  /// No description provided for @previewDownloadToOpen.
  ///
  /// In en, this message translates to:
  /// **'Download it to open it in another app'**
  String get previewDownloadToOpen;

  /// No description provided for @previewPageOf.
  ///
  /// In en, this message translates to:
  /// **'{page} of {total}'**
  String previewPageOf(String page, String total);

  /// No description provided for @previewPreviousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get previewPreviousPage;

  /// No description provided for @previewNextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get previewNextPage;

  /// No description provided for @previewSkipBack.
  ///
  /// In en, this message translates to:
  /// **'Back 15 seconds'**
  String get previewSkipBack;

  /// No description provided for @previewSkipForward.
  ///
  /// In en, this message translates to:
  /// **'Forward 15 seconds'**
  String get previewSkipForward;

  /// No description provided for @previewTruncated.
  ///
  /// In en, this message translates to:
  /// **'Showing the start of this file. It is too large to open in full here.'**
  String get previewTruncated;

  /// No description provided for @sheetEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'This spreadsheet has no cells'**
  String get sheetEmptyTitle;

  /// No description provided for @sheetEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'It opened, but there is nothing in it to show.'**
  String get sheetEmptyBody;

  /// No description provided for @sheetUnnamed.
  ///
  /// In en, this message translates to:
  /// **'Sheet {number}'**
  String sheetUnnamed(String number);

  /// No description provided for @documentEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'This document has no text'**
  String get documentEmptyTitle;

  /// No description provided for @documentEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'It opened, but there is nothing in it to show.'**
  String get documentEmptyBody;

  /// No description provided for @downloadNoFiles.
  ///
  /// In en, this message translates to:
  /// **'Folders cannot be downloaded as one file'**
  String get downloadNoFiles;

  /// No description provided for @downloadQueuedOne.
  ///
  /// In en, this message translates to:
  /// **'{name} is downloading'**
  String downloadQueuedOne(String name);

  /// No description provided for @downloadQueuedMany.
  ///
  /// In en, this message translates to:
  /// **'{count} files are downloading'**
  String downloadQueuedMany(int count);

  /// No description provided for @downloadSavedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved to {location}'**
  String downloadSavedTo(String location);

  /// No description provided for @sizeBytes.
  ///
  /// In en, this message translates to:
  /// **'{size} B'**
  String sizeBytes(String size);

  /// No description provided for @sizeKilobytes.
  ///
  /// In en, this message translates to:
  /// **'{size} KB'**
  String sizeKilobytes(String size);

  /// No description provided for @sizeMegabytes.
  ///
  /// In en, this message translates to:
  /// **'{size} MB'**
  String sizeMegabytes(String size);

  /// No description provided for @sizeGigabytes.
  ///
  /// In en, this message translates to:
  /// **'{size} GB'**
  String sizeGigabytes(String size);

  /// No description provided for @sizeTerabytes.
  ///
  /// In en, this message translates to:
  /// **'{size} TB'**
  String sizeTerabytes(String size);

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute ago} other{{count} minutes ago}}'**
  String timeMinutesAgo(int count);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String timeHoursAgo(int count);

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Yesterday} other{{count} days ago}}'**
  String timeDaysAgo(int count);

  /// No description provided for @twoFactorTitle.
  ///
  /// In en, this message translates to:
  /// **'Two-factor authentication'**
  String get twoFactorTitle;

  /// No description provided for @twoFactorRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'This account manages the server, so two-factor is required. It takes about a minute.'**
  String get twoFactorRequiredBody;

  /// No description provided for @twoFactorOptionalBody.
  ///
  /// In en, this message translates to:
  /// **'Add a second step when signing in. You choose whether to use it.'**
  String get twoFactorOptionalBody;

  /// No description provided for @twoFactorScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Add this to your authenticator app'**
  String get twoFactorScanTitle;

  /// No description provided for @twoFactorUseQr.
  ///
  /// In en, this message translates to:
  /// **'Scan a code'**
  String get twoFactorUseQr;

  /// No description provided for @twoFactorUseKey.
  ///
  /// In en, this message translates to:
  /// **'Enter a key'**
  String get twoFactorUseKey;

  /// No description provided for @twoFactorKeyBody.
  ///
  /// In en, this message translates to:
  /// **'Use this if the app is on another device, or you keep codes in a password manager.'**
  String get twoFactorKeyBody;

  /// No description provided for @twoFactorConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the six digit code it shows'**
  String get twoFactorConfirmTitle;

  /// No description provided for @twoFactorCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Six digits'**
  String get twoFactorCodeHint;

  /// No description provided for @twoFactorTurnOn.
  ///
  /// In en, this message translates to:
  /// **'Turn on two-factor'**
  String get twoFactorTurnOn;

  /// No description provided for @twoFactorOn.
  ///
  /// In en, this message translates to:
  /// **'Two-factor is on'**
  String get twoFactorOn;

  /// No description provided for @twoFactorOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get twoFactorOff;

  /// No description provided for @twoFactorAlreadyOnBody.
  ///
  /// In en, this message translates to:
  /// **'This account already asks for a code when signing in.'**
  String get twoFactorAlreadyOnBody;

  /// No description provided for @recoveryCodesTitle.
  ///
  /// In en, this message translates to:
  /// **'Save these recovery codes'**
  String get recoveryCodesTitle;

  /// No description provided for @recoveryCodesBody.
  ///
  /// In en, this message translates to:
  /// **'Each one signs you in once if you lose the authenticator. Keep them somewhere other than this device.'**
  String get recoveryCodesBody;

  /// No description provided for @moreActions.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get moreActions;

  /// No description provided for @dropToUpload.
  ///
  /// In en, this message translates to:
  /// **'Drop to upload'**
  String get dropToUpload;

  /// No description provided for @dropToUploadHint.
  ///
  /// In en, this message translates to:
  /// **'Folders keep their structure'**
  String get dropToUploadHint;

  /// No description provided for @dropToUploadHintWeb.
  ///
  /// In en, this message translates to:
  /// **'Files are added to this folder'**
  String get dropToUploadHintWeb;

  /// No description provided for @errorFoldersNotSupportedWeb.
  ///
  /// In en, this message translates to:
  /// **'Folders cannot be dropped in a browser. Drop the files inside it instead.'**
  String get errorFoldersNotSupportedWeb;

  /// No description provided for @uploadClashTitle.
  ///
  /// In en, this message translates to:
  /// **'That name is already here'**
  String get uploadClashTitle;

  /// No description provided for @uploadClashTitleMany.
  ///
  /// In en, this message translates to:
  /// **'Some names are already here'**
  String get uploadClashTitleMany;

  /// No description provided for @uploadClashBody.
  ///
  /// In en, this message translates to:
  /// **'This folder already has a file called {name}.'**
  String uploadClashBody(String name);

  /// No description provided for @uploadClashBodyMany.
  ///
  /// In en, this message translates to:
  /// **'{count} of the files you are uploading have names this folder already uses.'**
  String uploadClashBodyMany(String count);

  /// No description provided for @uploadClashKeepBoth.
  ///
  /// In en, this message translates to:
  /// **'Keep both'**
  String get uploadClashKeepBoth;

  /// No description provided for @uploadClashReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace with the new one'**
  String get uploadClashReplace;

  /// No description provided for @uploadClashSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip these'**
  String get uploadClashSkip;

  /// No description provided for @versionSection.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get versionSection;

  /// No description provided for @versionInstalled.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get versionInstalled;

  /// No description provided for @updateCheck.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get updateCheck;

  /// No description provided for @updateChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking'**
  String get updateChecking;

  /// No description provided for @updateUpToDate.
  ///
  /// In en, this message translates to:
  /// **'You are up to date'**
  String get updateUpToDate;

  /// No description provided for @updateUpToDateBody.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is the newest release.'**
  String updateUpToDateBody(String version);

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available'**
  String updateAvailable(String version);

  /// No description provided for @updateInstall.
  ///
  /// In en, this message translates to:
  /// **'Download and install'**
  String get updateInstall;

  /// No description provided for @updateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get updateDownloading;

  /// No description provided for @updateInstalling.
  ///
  /// In en, this message translates to:
  /// **'Installing'**
  String get updateInstalling;

  /// No description provided for @updateRestartNote.
  ///
  /// In en, this message translates to:
  /// **'The app closes and reopens once the update is in place.'**
  String get updateRestartNote;

  /// No description provided for @updateAndroidNote.
  ///
  /// In en, this message translates to:
  /// **'Android asks for permission before it installs.'**
  String get updateAndroidNote;

  /// No description provided for @updateNotes.
  ///
  /// In en, this message translates to:
  /// **'What changed'**
  String get updateNotes;

  /// No description provided for @updateManualOnly.
  ///
  /// In en, this message translates to:
  /// **'This build updates with whatever is serving it.'**
  String get updateManualOnly;
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  Future<L10n> load(Locale locale) {
    return SynchronousFuture<L10n>(lookupL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}

L10n lookupL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return L10nAr();
    case 'en':
      return L10nEn();
  }

  throw FlutterError(
    'L10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
