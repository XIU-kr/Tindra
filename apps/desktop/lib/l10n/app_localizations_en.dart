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
    return 'Tindra - $profile';
  }

  @override
  String get profiles => 'Profiles';

  @override
  String get sessions => 'Sessions';

  @override
  String get files => 'Files';

  @override
  String get forwards => 'Forwards';

  @override
  String get hostKeys => 'Host keys';

  @override
  String get home => 'Home';

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
  String get favorite => 'Favorite';

  @override
  String get favorites => 'Favorites';

  @override
  String get recent => 'Recent';

  @override
  String get refresh => 'Refresh';

  @override
  String get retry => 'Retry';

  @override
  String get download => 'Download';

  @override
  String get upload => 'Upload';

  @override
  String get localPath => 'Local path';

  @override
  String get remotePath => 'Remote path';

  @override
  String localFileNotFound(Object path) {
    return 'Local file not found: $path';
  }

  @override
  String get overwrite => 'Overwrite';

  @override
  String get overwriteFileQuestion => 'Overwrite local file?';

  @override
  String overwriteFileContent(Object path) {
    return '$path already exists. Replace it?';
  }

  @override
  String get settings => 'Settings';

  @override
  String get search => 'Search';

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
  String get localShell => 'Local shell';

  @override
  String get localShellCommand => 'Shell command';

  @override
  String get localShellCommandHint =>
      'Leave empty to use the platform default shell.';

  @override
  String get localShellWorkingDirectory => 'Working directory';

  @override
  String get localShellWorkingDirectoryHint =>
      'Optional start folder for new local shell tabs.';

  @override
  String get localShellEnvironment => 'Environment';

  @override
  String get localShellEnvironmentHint =>
      'One NAME=value entry per line. Lines starting with # are ignored.';

  @override
  String get edit => 'Edit';

  @override
  String get sftpBrowser => 'SFTP browser';

  @override
  String get portForwards => 'Port forwards';

  @override
  String get keyPassphraseHint => 'Key passphrase (if any)';

  @override
  String get noOpenSessions => 'No open sessions';

  @override
  String get noSession => 'No session';

  @override
  String liveSessionsSummary(Object profiles, Object sessions) {
    return '$sessions live sessions | $profiles profiles | local workspace ready';
  }

  @override
  String get quickstart => 'Quickstart';

  @override
  String get pressPaletteHint => 'Press Ctrl+K to summon the palette';

  @override
  String get pickProfileOrPalette =>
      'Pick a profile, or press Ctrl+K to run a command.';

  @override
  String get all => 'All';

  @override
  String get goodMorning => 'Good morning.';

  @override
  String get goodAfternoon => 'Good afternoon.';

  @override
  String get goodEvening => 'Good evening.';

  @override
  String profileCount(Object count) {
    return '$count profiles';
  }

  @override
  String get profilesLede =>
      'Local-only | encrypted at rest. Pair another device to sync.';

  @override
  String get importKeys => 'Import keys';

  @override
  String get pickProfileToOpen => 'Pick a profile to open';

  @override
  String get pickProfileForNewTab => 'Pick a profile for a new tab';

  @override
  String get pickProfileForSplit => 'Pick a profile for the split pane';

  @override
  String openSelectedProfile(Object name) {
    return 'Open $name';
  }

  @override
  String get pickProfilePrompt =>
      'Pick a profile, then open it to start a session.';

  @override
  String connectingTo(Object name) {
    return 'Connecting to $name';
  }

  @override
  String get connected => 'Connected';

  @override
  String get connecting => 'Connecting';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get sessionDisconnected => 'Session disconnected';

  @override
  String get sessionDisconnectedMessage => 'The session is disconnected.';

  @override
  String get waitingForFirstChunk => 'Waiting for first terminal output';

  @override
  String get copyScreenTooltip => 'Copy screen (Ctrl+Shift+C)';

  @override
  String get pasteClipboardTooltip => 'Paste clipboard (Ctrl+Shift+V)';

  @override
  String get paste => 'Paste';

  @override
  String get confirmPasteTitle => 'Paste into terminal?';

  @override
  String confirmPasteContent(Object byteCount, Object lineCount) {
    return 'This clipboard payload has $lineCount lines and $byteCount bytes. Paste it into the active session?';
  }

  @override
  String get reconnectTooltip => 'Reconnect (Ctrl+Shift+R)';

  @override
  String get disconnectTooltip => 'Disconnect';

  @override
  String get copyError => 'Copy error';

  @override
  String get searchRun => 'Search | run';

  @override
  String get syncStatus => 'Sync';

  @override
  String pairedDevices(Object count) {
    return 'Paired ($count)';
  }

  @override
  String get splitRight => 'Split right';

  @override
  String get splitDown => 'Split down';

  @override
  String get toggleSftpBrowser => 'Toggle SFTP browser';

  @override
  String get runCommandOrJump => 'Run a command, or jump to a profile...';

  @override
  String get paletteProfilesSection => 'Profiles';

  @override
  String get paletteCommandsSection => 'Commands';

  @override
  String get open => 'Open';

  @override
  String get openLink => 'Open link';

  @override
  String get navigate => 'Navigate';

  @override
  String get select => 'Select';

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
  String get firstSeen => 'First seen';

  @override
  String get lastSeen => 'Last seen';

  @override
  String get unknown => 'Unknown';

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
  String get password => 'Password';

  @override
  String get keyboardInteractive => 'Keyboard-interactive';

  @override
  String passwordFor(Object profile) {
    return 'Password for $profile';
  }

  @override
  String get passwordRequired => 'Password required.';

  @override
  String get connect => 'Connect';

  @override
  String get trust => 'Trust';

  @override
  String get trustHostKeyTitle => 'Trust this host key?';

  @override
  String trustHostKeyContent(Object fingerprint, Object host, Object port) {
    return '$host:$port presented this fingerprint:\n\n$fingerprint\n\nOnly trust it if it matches the server you expect.';
  }

  @override
  String get hostKeyChangedTitle => 'Host key changed';

  @override
  String hostKeyChangedContent(
    Object actual,
    Object expected,
    Object host,
    Object port,
  ) {
    return '$host:$port presented a different host key.\n\nTrusted:\n$expected\n\nPresented:\n$actual\n\nTindra blocked the connection.';
  }

  @override
  String get replaceHostKey => 'Replace host key';

  @override
  String get hostKeyNotTrusted => 'Host key was not trusted.';

  @override
  String get privateKeyPath => 'Private key path';

  @override
  String get jumpHost => 'Jump host';

  @override
  String get keyPath => 'Key path';

  @override
  String get notes => 'Notes';

  @override
  String get optional => 'Optional';

  @override
  String get preferences => 'Preferences';

  @override
  String get settingsLede =>
      'Theme, accent and density apply immediately. Other changes are saved when you click Apply.';

  @override
  String get apply => 'Apply';

  @override
  String get appearance => 'Appearance';

  @override
  String get appearanceThemeHint => 'Use dark or light mode for the app shell.';

  @override
  String get accent => 'Accent';

  @override
  String get accentHint => 'Used for live indicators, focus, and highlights.';

  @override
  String get density => 'Density';

  @override
  String get densityHint => 'Tighter rows fit more on a smaller screen.';

  @override
  String get cozy => 'Cozy';

  @override
  String get compact => 'Compact';

  @override
  String get terminal => 'Terminal';

  @override
  String get font => 'Font';

  @override
  String get fontHint =>
      'JetBrains Mono is bundled. Falls back to Cascadia Mono / Consolas.';

  @override
  String get syncSystem => 'Sync · system';

  @override
  String get diagnostics => 'Diagnostics';

  @override
  String get appVersion => 'App version';

  @override
  String get rustCoreVersion => 'Rust core version';

  @override
  String get profilesPath => 'Profiles path';

  @override
  String get settingsPath => 'Settings path';

  @override
  String get expectedLogDirectory => 'Expected log directory';

  @override
  String get loading => 'Loading...';

  @override
  String get quakeHotkey => 'Quake hotkey';

  @override
  String get quakeHotkeyDescription =>
      'Global key to summon Tindra over any window.';

  @override
  String get newProfileEyebrow => 'New profile';

  @override
  String get editProfileEyebrow => 'Edit profile';

  @override
  String get newProfileTitle => 'A new connection';

  @override
  String get filesSftpEyebrow => 'Files | SFTP';

  @override
  String get browseRemote => 'Browse remote';

  @override
  String get filesSftpLede =>
      'Drag in to upload, drag out to download. Transfers queue on the right.';

  @override
  String get up => 'Up';

  @override
  String get tableName => 'Name';

  @override
  String get tableSize => 'Size';

  @override
  String get tableModified => 'Modified';

  @override
  String get tags => 'Tags';

  @override
  String get addSshProfileToBrowse => 'Add an SSH profile to browse files.';

  @override
  String get connectingEllipsis => 'Connecting...';

  @override
  String get transfers => 'Transfers';

  @override
  String get idle => 'Idle';

  @override
  String activeTransferCount(Object count) {
    return '$count active';
  }

  @override
  String failedTransferCount(Object count) {
    return '$count failed';
  }

  @override
  String get noTransfersInFlight => 'No transfers in flight';

  @override
  String get networkPortForwardsEyebrow => 'Network | port forwards';

  @override
  String get forwardsLede =>
      'Local tunnels listen on your machine through the selected SSH profile.';

  @override
  String get newForward => 'New forward';

  @override
  String get noActiveTunnels => 'No active tunnels';

  @override
  String get pickProfileThenForward => 'Pick a profile, then create a forward.';

  @override
  String openLocalForwardToProfile(Object name) {
    return 'Open a local forward to $name to get started.';
  }

  @override
  String get openStatus => 'Open';

  @override
  String get local => 'Local';

  @override
  String get remote => 'Remote';

  @override
  String get via => 'Via';

  @override
  String get reconnect => 'Reconnect';

  @override
  String get drop => 'Drop';

  @override
  String get trustHostKeysEyebrow => 'Trust | host keys';

  @override
  String get noTrustedKeysYet => 'No trusted keys yet';

  @override
  String get connectOnceRememberHost =>
      'Connect to a host once and Tindra will remember it.';

  @override
  String get first => 'First';

  @override
  String get last => 'Last';

  @override
  String get started => 'Started';

  @override
  String get active => 'Active';

  @override
  String get notAvailable => 'N/A';

  @override
  String get localForward => 'Local forward';

  @override
  String localForwardDescription(Object name) {
    return 'A listener on your machine that tunnels through $name.';
  }

  @override
  String get localAddr => 'Local addr';

  @override
  String get remoteHost => 'Remote host';

  @override
  String get quickConnect => 'Quick connect';

  @override
  String get restorePreviousLayout => 'Restore previous layout';

  @override
  String get renameTab => 'Rename tab';

  @override
  String get tabName => 'Tab name';

  @override
  String get duplicateTab => 'Duplicate tab';

  @override
  String get closeOtherTabs => 'Close other tabs';

  @override
  String get closeTabsToRight => 'Close tabs to the right';

  @override
  String get previousPane => 'Previous pane';

  @override
  String get nextPane => 'Next pane';

  @override
  String get detachTab => 'Detach tab';

  @override
  String get noDetachableSession => 'No connected session to detach.';

  @override
  String get pinOrUnpinTab => 'Pin or unpin tab';

  @override
  String get pinTab => 'Pin tab';

  @override
  String get unpinTab => 'Unpin tab';

  @override
  String get closeActivePane => 'Close active pane';

  @override
  String get restorePane => 'Restore pane';

  @override
  String get maximizePane => 'Maximize pane';

  @override
  String get toggleSidebar => 'Toggle sidebar';

  @override
  String get collapseSidebar => 'Collapse sidebar';

  @override
  String get expandSidebar => 'Expand sidebar';

  @override
  String get openTabs => 'Open tabs';

  @override
  String get themePreset => 'Theme preset';

  @override
  String get themePresetHint => 'Copy or paste appearance JSON';

  @override
  String get exportTheme => 'Export';

  @override
  String get importTheme => 'Import';

  @override
  String get keyboardShortcuts => 'Keyboard shortcuts';

  @override
  String get newTab => 'New tab';

  @override
  String get closeTab => 'Close tab';

  @override
  String get nextTab => 'Next tab';

  @override
  String get previousTab => 'Previous tab';

  @override
  String get commandPalette => 'Command palette';

  @override
  String get copy => 'Copy';

  @override
  String get moveTabLeft => 'Move tab left';

  @override
  String get moveTabRight => 'Move tab right';

  @override
  String get closePane => 'Close pane';

  @override
  String get paletteFrost => 'Frost';

  @override
  String get paletteAurora => 'Aurora';

  @override
  String get paletteGlacier => 'Glacier';

  @override
  String get paletteTwilight => 'Twilight';

  @override
  String get paletteCoal => 'Coal';

  @override
  String get paletteSnow => 'Snow';

  @override
  String get paletteRose => 'Rose';

  @override
  String get paletteAmber => 'Amber';

  @override
  String get defaultColor => 'Default color';

  @override
  String get green => 'Green';

  @override
  String get blue => 'Blue';

  @override
  String get unnamed => '(unnamed)';
}
