// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Tindra';

  @override
  String appTitleWithProfile(Object profile) {
    return 'Tindra · $profile';
  }

  @override
  String get profiles => 'Profiles';

  @override
  String get newProfile => 'New profile';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get deleteProfileQuestion => 'Delete profile?';

  @override
  String deleteProfileContent(Object name) {
    return 'Permanently remove \"$name\"?';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get create => 'Create';

  @override
  String get close => 'Close';

  @override
  String get refresh => 'Refresh';

  @override
  String get settings => 'Settings';

  @override
  String get settingsTooltip => 'Settings (Ctrl+,)';

  @override
  String get noProfilesYet => 'No profiles yet';

  @override
  String get createOne => 'Create one';

  @override
  String openProfile(Object name) {
    return 'Open $name';
  }

  @override
  String get openLocalShell => 'Open local shell';

  @override
  String get edit => 'Edit';

  @override
  String get sftpBrowser => 'SFTP browser';

  @override
  String get portForwards => 'Port forwards';

  @override
  String get keyPassphraseHint => 'Key passphrase (if any)';

  @override
  String get noOpenSessions => 'no open sessions';

  @override
  String get pickProfileToOpen => 'Pick a profile to open';

  @override
  String openSelectedProfile(Object name) {
    return 'Open $name';
  }

  @override
  String get pickProfilePrompt =>
      'Pick a profile on the left, then \"Open\" to start a session.';

  @override
  String connectingTo(Object name) {
    return 'Connecting to $name…';
  }

  @override
  String get disconnected => 'Disconnected';

  @override
  String get waitingForFirstChunk => 'waiting for first chunk…';

  @override
  String get copyScreenTooltip => 'Copy screen (Ctrl+Shift+C)';

  @override
  String get pasteClipboardTooltip => 'Paste clipboard (Ctrl+Shift+V)';

  @override
  String get reconnectTooltip => 'Reconnect (Ctrl+Shift+R)';

  @override
  String get trustedHostKeys => 'Trusted host keys';

  @override
  String get trustedHostKeysDescription =>
      'Tindra uses trust-on-first-use: the first key seen for a host is saved, and later changes are rejected.';

  @override
  String get noTrustedHostKeys => 'No trusted host keys yet.';

  @override
  String get removeTrustedHostKeyQuestion => 'Remove trusted host key?';

  @override
  String removeTrustedHostKeyContent(Object host, Object port) {
    return 'Remove $host:$port?\n\nThe next connection will trust the server key that is presented then.';
  }

  @override
  String get remove => 'Remove';

  @override
  String get removeTrustedKeyTooltip => 'Remove trusted key';

  @override
  String get firstSeen => 'first seen';

  @override
  String get lastSeen => 'last seen';

  @override
  String get unknown => 'unknown';

  @override
  String get theme => 'Theme';

  @override
  String get dark => 'Dark';

  @override
  String get light => 'Light';

  @override
  String get terminalFont => 'Terminal font';

  @override
  String size(Object size) {
    return 'Size: $size';
  }

  @override
  String get quakeGlobalHotkey => 'Quake global hotkey';

  @override
  String get quakeHotkeyHint => 'e.g. F12 (toggles window show/hide)';

  @override
  String get language => 'Language';

  @override
  String get systemLanguage => 'System';

  @override
  String get english => 'English';

  @override
  String get korean => 'Korean';

  @override
  String get name => 'Name';

  @override
  String get host => 'Host';

  @override
  String get user => 'User';

  @override
  String get port => 'Port';

  @override
  String get transport => 'Transport';

  @override
  String get ssh => 'SSH';

  @override
  String get telnetRawTcp => 'Telnet (raw TCP)';

  @override
  String get auth => 'Auth';

  @override
  String get privateKey => 'Private key';

  @override
  String get sshAgent => 'SSH agent';

  @override
  String get privateKeyPath => 'Private key path';

  @override
  String get jumpHost => 'Jump host';

  @override
  String get keyPath => 'Key path';

  @override
  String get notes => 'Notes';

  @override
  String get optional => 'optional';

  @override
  String get unnamed => '(unnamed)';
}
