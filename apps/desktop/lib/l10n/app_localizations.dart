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
  /// **'Tindra · {profile}'**
  String appTitleWithProfile(Object profile);

  /// No description provided for @profiles.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get profiles;

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

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

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
  /// **'no open sessions'**
  String get noOpenSessions;

  /// No description provided for @pickProfileToOpen.
  ///
  /// In en, this message translates to:
  /// **'Pick a profile to open'**
  String get pickProfileToOpen;

  /// No description provided for @openSelectedProfile.
  ///
  /// In en, this message translates to:
  /// **'Open {name}'**
  String openSelectedProfile(Object name);

  /// No description provided for @pickProfilePrompt.
  ///
  /// In en, this message translates to:
  /// **'Pick a profile on the left, then \"Open\" to start a session.'**
  String get pickProfilePrompt;

  /// No description provided for @connectingTo.
  ///
  /// In en, this message translates to:
  /// **'Connecting to {name}…'**
  String connectingTo(Object name);

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// No description provided for @waitingForFirstChunk.
  ///
  /// In en, this message translates to:
  /// **'waiting for first chunk…'**
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

  /// No description provided for @reconnectTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reconnect (Ctrl+Shift+R)'**
  String get reconnectTooltip;

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
  /// **'first seen'**
  String get firstSeen;

  /// No description provided for @lastSeen.
  ///
  /// In en, this message translates to:
  /// **'last seen'**
  String get lastSeen;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
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
  /// **'optional'**
  String get optional;

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
