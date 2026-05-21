import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

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
    Locale('ko'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Tindra'**
  String get appTitle;

  /// No description provided for @appTitleWithProfile.
  ///
  /// In en, this message translates to:
  /// **'Tindra - {profile}'**
  String appTitleWithProfile(Object profile);

  /// No description provided for @profiles.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get profiles;

  /// No description provided for @sessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get sessions;

  /// No description provided for @files.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get files;

  /// No description provided for @forwards.
  ///
  /// In en, this message translates to:
  /// **'Forwards'**
  String get forwards;

  /// No description provided for @hostKeys.
  ///
  /// In en, this message translates to:
  /// **'Host keys'**
  String get hostKeys;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @newProfile.
  ///
  /// In en, this message translates to:
  /// **'New profile'**
  String get newProfile;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// No description provided for @deleteProfileQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete profile?'**
  String get deleteProfileQuestion;

  /// No description provided for @deleteProfileContent.
  ///
  /// In en, this message translates to:
  /// **'Permanently remove \"{name}\"?'**
  String deleteProfileContent(Object name);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @favorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get favorite;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @recent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recent;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// No description provided for @localPath.
  ///
  /// In en, this message translates to:
  /// **'Local path'**
  String get localPath;

  /// No description provided for @remotePath.
  ///
  /// In en, this message translates to:
  /// **'Remote path'**
  String get remotePath;

  /// No description provided for @localFileNotFound.
  ///
  /// In en, this message translates to:
  /// **'Local file not found: {path}'**
  String localFileNotFound(Object path);

  /// No description provided for @overwrite.
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get overwrite;

  /// No description provided for @overwriteFileQuestion.
  ///
  /// In en, this message translates to:
  /// **'Overwrite local file?'**
  String get overwriteFileQuestion;

  /// No description provided for @overwriteFileContent.
  ///
  /// In en, this message translates to:
  /// **'{path} already exists. Replace it?'**
  String overwriteFileContent(Object path);

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

  /// No description provided for @settingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings (Ctrl+,)'**
  String get settingsTooltip;

  /// No description provided for @noProfilesYet.
  ///
  /// In en, this message translates to:
  /// **'No profiles yet'**
  String get noProfilesYet;

  /// No description provided for @createOne.
  ///
  /// In en, this message translates to:
  /// **'Create one'**
  String get createOne;

  /// No description provided for @openProfile.
  ///
  /// In en, this message translates to:
  /// **'Open {name}'**
  String openProfile(Object name);

  /// No description provided for @openLocalShell.
  ///
  /// In en, this message translates to:
  /// **'Open local shell'**
  String get openLocalShell;

  /// No description provided for @localShell.
  ///
  /// In en, this message translates to:
  /// **'Local shell'**
  String get localShell;

  /// No description provided for @localShellCommand.
  ///
  /// In en, this message translates to:
  /// **'Shell command'**
  String get localShellCommand;

  /// No description provided for @localShellCommandHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use the platform default shell.'**
  String get localShellCommandHint;

  /// No description provided for @localShellWorkingDirectory.
  ///
  /// In en, this message translates to:
  /// **'Working directory'**
  String get localShellWorkingDirectory;

  /// No description provided for @localShellWorkingDirectoryHint.
  ///
  /// In en, this message translates to:
  /// **'Optional start folder for new local shell tabs.'**
  String get localShellWorkingDirectoryHint;

  /// No description provided for @localShellEnvironment.
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get localShellEnvironment;

  /// No description provided for @localShellEnvironmentHint.
  ///
  /// In en, this message translates to:
  /// **'One NAME=value entry per line. Lines starting with # are ignored.'**
  String get localShellEnvironmentHint;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @sftpBrowser.
  ///
  /// In en, this message translates to:
  /// **'SFTP browser'**
  String get sftpBrowser;

  /// No description provided for @portForwards.
  ///
  /// In en, this message translates to:
  /// **'Port forwards'**
  String get portForwards;

  /// No description provided for @keyPassphraseHint.
  ///
  /// In en, this message translates to:
  /// **'Key passphrase (if any)'**
  String get keyPassphraseHint;

  /// No description provided for @noOpenSessions.
  ///
  /// In en, this message translates to:
  /// **'No open sessions'**
  String get noOpenSessions;

  /// No description provided for @noSession.
  ///
  /// In en, this message translates to:
  /// **'No session'**
  String get noSession;

  /// No description provided for @liveSessionsSummary.
  ///
  /// In en, this message translates to:
  /// **'{sessions} live sessions | {profiles} profiles | local workspace ready'**
  String liveSessionsSummary(Object profiles, Object sessions);

  /// No description provided for @quickstart.
  ///
  /// In en, this message translates to:
  /// **'Quickstart'**
  String get quickstart;

  /// No description provided for @pressPaletteHint.
  ///
  /// In en, this message translates to:
  /// **'Press Ctrl+K to summon the palette'**
  String get pressPaletteHint;

  /// No description provided for @pickProfileOrPalette.
  ///
  /// In en, this message translates to:
  /// **'Pick a profile, or press Ctrl+K to run a command.'**
  String get pickProfileOrPalette;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning.'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon.'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening.'**
  String get goodEvening;

  /// No description provided for @profileCount.
  ///
  /// In en, this message translates to:
  /// **'{count} profiles'**
  String profileCount(Object count);

  /// No description provided for @profilesLede.
  ///
  /// In en, this message translates to:
  /// **'Local-only | encrypted at rest. Pair another device to sync.'**
  String get profilesLede;

  /// No description provided for @importKeys.
  ///
  /// In en, this message translates to:
  /// **'Import keys'**
  String get importKeys;

  /// No description provided for @pickProfileToOpen.
  ///
  /// In en, this message translates to:
  /// **'Pick a profile to open'**
  String get pickProfileToOpen;

  /// No description provided for @pickProfileForNewTab.
  ///
  /// In en, this message translates to:
  /// **'Pick a profile for a new tab'**
  String get pickProfileForNewTab;

  /// No description provided for @pickProfileForSplit.
  ///
  /// In en, this message translates to:
  /// **'Pick a profile for the split pane'**
  String get pickProfileForSplit;

  /// No description provided for @openSelectedProfile.
  ///
  /// In en, this message translates to:
  /// **'Open {name}'**
  String openSelectedProfile(Object name);

  /// No description provided for @pickProfilePrompt.
  ///
  /// In en, this message translates to:
  /// **'Pick a profile, then open it to start a session.'**
  String get pickProfilePrompt;

  /// No description provided for @connectingTo.
  ///
  /// In en, this message translates to:
  /// **'Connecting to {name}'**
  String connectingTo(Object name);

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get connecting;

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// No description provided for @sessionDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Session disconnected'**
  String get sessionDisconnected;

  /// No description provided for @sessionDisconnectedMessage.
  ///
  /// In en, this message translates to:
  /// **'The session is disconnected.'**
  String get sessionDisconnectedMessage;

  /// No description provided for @connectionTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out after 20 seconds.'**
  String get connectionTimedOut;

  /// No description provided for @cancelConnection.
  ///
  /// In en, this message translates to:
  /// **'Cancel connection'**
  String get cancelConnection;

  /// No description provided for @waitingForFirstChunk.
  ///
  /// In en, this message translates to:
  /// **'Waiting for first terminal output'**
  String get waitingForFirstChunk;

  /// No description provided for @copyScreenTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy screen (Ctrl+Shift+C)'**
  String get copyScreenTooltip;

  /// No description provided for @pasteClipboardTooltip.
  ///
  /// In en, this message translates to:
  /// **'Paste clipboard (Ctrl+Shift+V)'**
  String get pasteClipboardTooltip;

  /// No description provided for @paste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// No description provided for @confirmPasteTitle.
  ///
  /// In en, this message translates to:
  /// **'Paste into terminal?'**
  String get confirmPasteTitle;

  /// No description provided for @confirmPasteContent.
  ///
  /// In en, this message translates to:
  /// **'This clipboard payload has {lineCount} lines and {byteCount} bytes. Paste it into the active session?'**
  String confirmPasteContent(Object byteCount, Object lineCount);

  /// No description provided for @reconnectTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reconnect (Ctrl+Shift+R)'**
  String get reconnectTooltip;

  /// No description provided for @disconnectTooltip.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnectTooltip;

  /// No description provided for @copyError.
  ///
  /// In en, this message translates to:
  /// **'Copy error'**
  String get copyError;

  /// No description provided for @searchRun.
  ///
  /// In en, this message translates to:
  /// **'Search | run'**
  String get searchRun;

  /// No description provided for @syncStatus.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get syncStatus;

  /// No description provided for @pairedDevices.
  ///
  /// In en, this message translates to:
  /// **'Paired ({count})'**
  String pairedDevices(Object count);

  /// No description provided for @splitRight.
  ///
  /// In en, this message translates to:
  /// **'Split right'**
  String get splitRight;

  /// No description provided for @splitDown.
  ///
  /// In en, this message translates to:
  /// **'Split down'**
  String get splitDown;

  /// No description provided for @toggleSftpBrowser.
  ///
  /// In en, this message translates to:
  /// **'Toggle SFTP browser'**
  String get toggleSftpBrowser;

  /// No description provided for @runCommandOrJump.
  ///
  /// In en, this message translates to:
  /// **'Run a command, or jump to a profile...'**
  String get runCommandOrJump;

  /// No description provided for @paletteProfilesSection.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get paletteProfilesSection;

  /// No description provided for @paletteCommandsSection.
  ///
  /// In en, this message translates to:
  /// **'Commands'**
  String get paletteCommandsSection;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @openLink.
  ///
  /// In en, this message translates to:
  /// **'Open link'**
  String get openLink;

  /// No description provided for @navigate.
  ///
  /// In en, this message translates to:
  /// **'Navigate'**
  String get navigate;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @trustedHostKeys.
  ///
  /// In en, this message translates to:
  /// **'Trusted host keys'**
  String get trustedHostKeys;

  /// No description provided for @trustedHostKeysDescription.
  ///
  /// In en, this message translates to:
  /// **'Tindra uses trust-on-first-use: the first key seen for a host is saved, and later changes are rejected.'**
  String get trustedHostKeysDescription;

  /// No description provided for @noTrustedHostKeys.
  ///
  /// In en, this message translates to:
  /// **'No trusted host keys yet.'**
  String get noTrustedHostKeys;

  /// No description provided for @removeTrustedHostKeyQuestion.
  ///
  /// In en, this message translates to:
  /// **'Remove trusted host key?'**
  String get removeTrustedHostKeyQuestion;

  /// No description provided for @removeTrustedHostKeyContent.
  ///
  /// In en, this message translates to:
  /// **'Remove {host}:{port}?\n\nThe next connection will trust the server key that is presented then.'**
  String removeTrustedHostKeyContent(Object host, Object port);

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @removeTrustedKeyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove trusted key'**
  String get removeTrustedKeyTooltip;

  /// No description provided for @firstSeen.
  ///
  /// In en, this message translates to:
  /// **'First seen'**
  String get firstSeen;

  /// No description provided for @lastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last seen'**
  String get lastSeen;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @terminalFont.
  ///
  /// In en, this message translates to:
  /// **'Terminal font'**
  String get terminalFont;

  /// No description provided for @size.
  ///
  /// In en, this message translates to:
  /// **'Size: {size}'**
  String size(Object size);

  /// No description provided for @quakeGlobalHotkey.
  ///
  /// In en, this message translates to:
  /// **'Quake global hotkey'**
  String get quakeGlobalHotkey;

  /// No description provided for @quakeHotkeyHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. F12 (toggles window show/hide)'**
  String get quakeHotkeyHint;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @systemLanguage.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemLanguage;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @korean.
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get korean;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @host.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get host;

  /// No description provided for @user.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get user;

  /// No description provided for @port.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get port;

  /// No description provided for @transport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get transport;

  /// No description provided for @ssh.
  ///
  /// In en, this message translates to:
  /// **'SSH'**
  String get ssh;

  /// No description provided for @telnetRawTcp.
  ///
  /// In en, this message translates to:
  /// **'Telnet (raw TCP)'**
  String get telnetRawTcp;

  /// No description provided for @auth.
  ///
  /// In en, this message translates to:
  /// **'Auth'**
  String get auth;

  /// No description provided for @privateKey.
  ///
  /// In en, this message translates to:
  /// **'Private key'**
  String get privateKey;

  /// No description provided for @sshAgent.
  ///
  /// In en, this message translates to:
  /// **'SSH agent'**
  String get sshAgent;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @keyboardInteractive.
  ///
  /// In en, this message translates to:
  /// **'Keyboard-interactive'**
  String get keyboardInteractive;

  /// No description provided for @passwordFor.
  ///
  /// In en, this message translates to:
  /// **'Password for {profile}'**
  String passwordFor(Object profile);

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password required.'**
  String get passwordRequired;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @trust.
  ///
  /// In en, this message translates to:
  /// **'Trust'**
  String get trust;

  /// No description provided for @trustHostKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Trust this host key?'**
  String get trustHostKeyTitle;

  /// No description provided for @trustHostKeyContent.
  ///
  /// In en, this message translates to:
  /// **'{host}:{port} presented this fingerprint:\n\n{fingerprint}\n\nOnly trust it if it matches the server you expect.'**
  String trustHostKeyContent(Object fingerprint, Object host, Object port);

  /// No description provided for @hostKeyChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Host key changed'**
  String get hostKeyChangedTitle;

  /// No description provided for @hostKeyChangedContent.
  ///
  /// In en, this message translates to:
  /// **'{host}:{port} presented a different host key.\n\nTrusted:\n{expected}\n\nPresented:\n{actual}\n\nTindra blocked the connection.'**
  String hostKeyChangedContent(
    Object actual,
    Object expected,
    Object host,
    Object port,
  );

  /// No description provided for @replaceHostKey.
  ///
  /// In en, this message translates to:
  /// **'Replace host key'**
  String get replaceHostKey;

  /// No description provided for @hostKeyNotTrusted.
  ///
  /// In en, this message translates to:
  /// **'Host key was not trusted.'**
  String get hostKeyNotTrusted;

  /// No description provided for @privateKeyPath.
  ///
  /// In en, this message translates to:
  /// **'Private key path'**
  String get privateKeyPath;

  /// No description provided for @jumpHost.
  ///
  /// In en, this message translates to:
  /// **'Jump host'**
  String get jumpHost;

  /// No description provided for @keyPath.
  ///
  /// In en, this message translates to:
  /// **'Key path'**
  String get keyPath;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @settingsLede.
  ///
  /// In en, this message translates to:
  /// **'Theme, accent and density apply immediately. Other changes are saved when you click Apply.'**
  String get settingsLede;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @appearanceThemeHint.
  ///
  /// In en, this message translates to:
  /// **'Use dark or light mode for the app shell.'**
  String get appearanceThemeHint;

  /// No description provided for @accent.
  ///
  /// In en, this message translates to:
  /// **'Accent'**
  String get accent;

  /// No description provided for @accentHint.
  ///
  /// In en, this message translates to:
  /// **'Used for live indicators, focus, and highlights.'**
  String get accentHint;

  /// No description provided for @density.
  ///
  /// In en, this message translates to:
  /// **'Density'**
  String get density;

  /// No description provided for @densityHint.
  ///
  /// In en, this message translates to:
  /// **'Tighter rows fit more on a smaller screen.'**
  String get densityHint;

  /// No description provided for @cozy.
  ///
  /// In en, this message translates to:
  /// **'Cozy'**
  String get cozy;

  /// No description provided for @compact.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get compact;

  /// No description provided for @terminal.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get terminal;

  /// No description provided for @font.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get font;

  /// No description provided for @fontHint.
  ///
  /// In en, this message translates to:
  /// **'JetBrains Mono is bundled. Falls back to Cascadia Mono / Consolas.'**
  String get fontHint;

  /// No description provided for @syncSystem.
  ///
  /// In en, this message translates to:
  /// **'Sync · system'**
  String get syncSystem;

  /// No description provided for @diagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnostics;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get appVersion;

  /// No description provided for @rustCoreVersion.
  ///
  /// In en, this message translates to:
  /// **'Rust core version'**
  String get rustCoreVersion;

  /// No description provided for @profilesPath.
  ///
  /// In en, this message translates to:
  /// **'Profiles path'**
  String get profilesPath;

  /// No description provided for @settingsPath.
  ///
  /// In en, this message translates to:
  /// **'Settings path'**
  String get settingsPath;

  /// No description provided for @expectedLogDirectory.
  ///
  /// In en, this message translates to:
  /// **'Expected log directory'**
  String get expectedLogDirectory;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @quakeHotkey.
  ///
  /// In en, this message translates to:
  /// **'Quake hotkey'**
  String get quakeHotkey;

  /// No description provided for @quakeHotkeyDescription.
  ///
  /// In en, this message translates to:
  /// **'Global key to summon Tindra over any window.'**
  String get quakeHotkeyDescription;

  /// No description provided for @newProfileEyebrow.
  ///
  /// In en, this message translates to:
  /// **'New profile'**
  String get newProfileEyebrow;

  /// No description provided for @editProfileEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfileEyebrow;

  /// No description provided for @newProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'A new connection'**
  String get newProfileTitle;

  /// No description provided for @filesSftpEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Files | SFTP'**
  String get filesSftpEyebrow;

  /// No description provided for @browseRemote.
  ///
  /// In en, this message translates to:
  /// **'Browse remote'**
  String get browseRemote;

  /// No description provided for @filesSftpLede.
  ///
  /// In en, this message translates to:
  /// **'Drag in to upload, drag out to download. Transfers queue on the right.'**
  String get filesSftpLede;

  /// No description provided for @up.
  ///
  /// In en, this message translates to:
  /// **'Up'**
  String get up;

  /// No description provided for @tableName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get tableName;

  /// No description provided for @tableSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get tableSize;

  /// No description provided for @tableModified.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get tableModified;

  /// No description provided for @tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tags;

  /// No description provided for @addSshProfileToBrowse.
  ///
  /// In en, this message translates to:
  /// **'Add an SSH profile to browse files.'**
  String get addSshProfileToBrowse;

  /// No description provided for @connectingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connectingEllipsis;

  /// No description provided for @transfers.
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get transfers;

  /// No description provided for @idle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get idle;

  /// No description provided for @activeTransferCount.
  ///
  /// In en, this message translates to:
  /// **'{count} active'**
  String activeTransferCount(Object count);

  /// No description provided for @failedTransferCount.
  ///
  /// In en, this message translates to:
  /// **'{count} failed'**
  String failedTransferCount(Object count);

  /// No description provided for @noTransfersInFlight.
  ///
  /// In en, this message translates to:
  /// **'No transfers in flight'**
  String get noTransfersInFlight;

  /// No description provided for @networkPortForwardsEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Network | port forwards'**
  String get networkPortForwardsEyebrow;

  /// No description provided for @forwardsLede.
  ///
  /// In en, this message translates to:
  /// **'Local tunnels listen on your machine through the selected SSH profile.'**
  String get forwardsLede;

  /// No description provided for @newForward.
  ///
  /// In en, this message translates to:
  /// **'New forward'**
  String get newForward;

  /// No description provided for @noActiveTunnels.
  ///
  /// In en, this message translates to:
  /// **'No active tunnels'**
  String get noActiveTunnels;

  /// No description provided for @pickProfileThenForward.
  ///
  /// In en, this message translates to:
  /// **'Pick a profile, then create a forward.'**
  String get pickProfileThenForward;

  /// No description provided for @openLocalForwardToProfile.
  ///
  /// In en, this message translates to:
  /// **'Open a local forward to {name} to get started.'**
  String openLocalForwardToProfile(Object name);

  /// No description provided for @openStatus.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openStatus;

  /// No description provided for @local.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get local;

  /// No description provided for @remote.
  ///
  /// In en, this message translates to:
  /// **'Remote'**
  String get remote;

  /// No description provided for @via.
  ///
  /// In en, this message translates to:
  /// **'Via'**
  String get via;

  /// No description provided for @reconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get reconnect;

  /// No description provided for @drop.
  ///
  /// In en, this message translates to:
  /// **'Drop'**
  String get drop;

  /// No description provided for @trustHostKeysEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Trust | host keys'**
  String get trustHostKeysEyebrow;

  /// No description provided for @noTrustedKeysYet.
  ///
  /// In en, this message translates to:
  /// **'No trusted keys yet'**
  String get noTrustedKeysYet;

  /// No description provided for @connectOnceRememberHost.
  ///
  /// In en, this message translates to:
  /// **'Connect to a host once and Tindra will remember it.'**
  String get connectOnceRememberHost;

  /// No description provided for @first.
  ///
  /// In en, this message translates to:
  /// **'First'**
  String get first;

  /// No description provided for @last.
  ///
  /// In en, this message translates to:
  /// **'Last'**
  String get last;

  /// No description provided for @started.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get started;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @notAvailable.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get notAvailable;

  /// No description provided for @localForward.
  ///
  /// In en, this message translates to:
  /// **'Local forward'**
  String get localForward;

  /// No description provided for @localForwardDescription.
  ///
  /// In en, this message translates to:
  /// **'A listener on your machine that tunnels through {name}.'**
  String localForwardDescription(Object name);

  /// No description provided for @localAddr.
  ///
  /// In en, this message translates to:
  /// **'Local addr'**
  String get localAddr;

  /// No description provided for @remoteHost.
  ///
  /// In en, this message translates to:
  /// **'Remote host'**
  String get remoteHost;

  /// No description provided for @quickConnect.
  ///
  /// In en, this message translates to:
  /// **'Quick connect'**
  String get quickConnect;

  /// No description provided for @restorePreviousLayout.
  ///
  /// In en, this message translates to:
  /// **'Restore previous layout'**
  String get restorePreviousLayout;

  /// No description provided for @renameTab.
  ///
  /// In en, this message translates to:
  /// **'Rename tab'**
  String get renameTab;

  /// No description provided for @tabName.
  ///
  /// In en, this message translates to:
  /// **'Tab name'**
  String get tabName;

  /// No description provided for @duplicateTab.
  ///
  /// In en, this message translates to:
  /// **'Duplicate tab'**
  String get duplicateTab;

  /// No description provided for @closeOtherTabs.
  ///
  /// In en, this message translates to:
  /// **'Close other tabs'**
  String get closeOtherTabs;

  /// No description provided for @closeTabsToRight.
  ///
  /// In en, this message translates to:
  /// **'Close tabs to the right'**
  String get closeTabsToRight;

  /// No description provided for @previousPane.
  ///
  /// In en, this message translates to:
  /// **'Previous pane'**
  String get previousPane;

  /// No description provided for @nextPane.
  ///
  /// In en, this message translates to:
  /// **'Next pane'**
  String get nextPane;

  /// No description provided for @detachTab.
  ///
  /// In en, this message translates to:
  /// **'Detach tab'**
  String get detachTab;

  /// No description provided for @noDetachableSession.
  ///
  /// In en, this message translates to:
  /// **'No connected session to detach.'**
  String get noDetachableSession;

  /// No description provided for @pinOrUnpinTab.
  ///
  /// In en, this message translates to:
  /// **'Pin or unpin tab'**
  String get pinOrUnpinTab;

  /// No description provided for @pinTab.
  ///
  /// In en, this message translates to:
  /// **'Pin tab'**
  String get pinTab;

  /// No description provided for @unpinTab.
  ///
  /// In en, this message translates to:
  /// **'Unpin tab'**
  String get unpinTab;

  /// No description provided for @closeActivePane.
  ///
  /// In en, this message translates to:
  /// **'Close active pane'**
  String get closeActivePane;

  /// No description provided for @restorePane.
  ///
  /// In en, this message translates to:
  /// **'Restore pane'**
  String get restorePane;

  /// No description provided for @maximizePane.
  ///
  /// In en, this message translates to:
  /// **'Maximize pane'**
  String get maximizePane;

  /// No description provided for @toggleSidebar.
  ///
  /// In en, this message translates to:
  /// **'Toggle sidebar'**
  String get toggleSidebar;

  /// No description provided for @collapseSidebar.
  ///
  /// In en, this message translates to:
  /// **'Collapse sidebar'**
  String get collapseSidebar;

  /// No description provided for @expandSidebar.
  ///
  /// In en, this message translates to:
  /// **'Expand sidebar'**
  String get expandSidebar;

  /// No description provided for @openTabs.
  ///
  /// In en, this message translates to:
  /// **'Open tabs'**
  String get openTabs;

  /// No description provided for @themePreset.
  ///
  /// In en, this message translates to:
  /// **'Theme preset'**
  String get themePreset;

  /// No description provided for @themePresetHint.
  ///
  /// In en, this message translates to:
  /// **'Copy or paste appearance JSON'**
  String get themePresetHint;

  /// No description provided for @exportTheme.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportTheme;

  /// No description provided for @importTheme.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importTheme;

  /// No description provided for @keyboardShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get keyboardShortcuts;

  /// No description provided for @newTab.
  ///
  /// In en, this message translates to:
  /// **'New tab'**
  String get newTab;

  /// No description provided for @closeTab.
  ///
  /// In en, this message translates to:
  /// **'Close tab'**
  String get closeTab;

  /// No description provided for @nextTab.
  ///
  /// In en, this message translates to:
  /// **'Next tab'**
  String get nextTab;

  /// No description provided for @previousTab.
  ///
  /// In en, this message translates to:
  /// **'Previous tab'**
  String get previousTab;

  /// No description provided for @commandPalette.
  ///
  /// In en, this message translates to:
  /// **'Command palette'**
  String get commandPalette;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @moveTabLeft.
  ///
  /// In en, this message translates to:
  /// **'Move tab left'**
  String get moveTabLeft;

  /// No description provided for @moveTabRight.
  ///
  /// In en, this message translates to:
  /// **'Move tab right'**
  String get moveTabRight;

  /// No description provided for @closePane.
  ///
  /// In en, this message translates to:
  /// **'Close pane'**
  String get closePane;

  /// No description provided for @paletteFrost.
  ///
  /// In en, this message translates to:
  /// **'Frost'**
  String get paletteFrost;

  /// No description provided for @paletteAurora.
  ///
  /// In en, this message translates to:
  /// **'Aurora'**
  String get paletteAurora;

  /// No description provided for @paletteGlacier.
  ///
  /// In en, this message translates to:
  /// **'Glacier'**
  String get paletteGlacier;

  /// No description provided for @paletteTwilight.
  ///
  /// In en, this message translates to:
  /// **'Twilight'**
  String get paletteTwilight;

  /// No description provided for @paletteCoal.
  ///
  /// In en, this message translates to:
  /// **'Coal'**
  String get paletteCoal;

  /// No description provided for @paletteSnow.
  ///
  /// In en, this message translates to:
  /// **'Snow'**
  String get paletteSnow;

  /// No description provided for @paletteRose.
  ///
  /// In en, this message translates to:
  /// **'Rose'**
  String get paletteRose;

  /// No description provided for @paletteAmber.
  ///
  /// In en, this message translates to:
  /// **'Amber'**
  String get paletteAmber;

  /// No description provided for @defaultColor.
  ///
  /// In en, this message translates to:
  /// **'Default color'**
  String get defaultColor;

  /// No description provided for @green.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get green;

  /// No description provided for @blue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get blue;

  /// No description provided for @unnamed.
  ///
  /// In en, this message translates to:
  /// **'(unnamed)'**
  String get unnamed;
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
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
