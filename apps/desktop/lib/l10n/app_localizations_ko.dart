// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'Tindra';

  @override
  String appTitleWithProfile(Object profile) {
    return 'Tindra - $profile';
  }

  @override
  String get profiles => '프로필';

  @override
  String get sessions => '세션';

  @override
  String get files => '파일';

  @override
  String get forwards => '포워딩';

  @override
  String get hostKeys => '호스트 키';

  @override
  String get home => '홈';

  @override
  String get newProfile => '새 프로필';

  @override
  String get editProfile => '프로필 편집';

  @override
  String get deleteProfileQuestion => '프로필을 삭제할까요?';

  @override
  String deleteProfileContent(Object name) {
    return '\"$name\" 프로필을 영구적으로 삭제할까요?';
  }

  @override
  String get cancel => '취소';

  @override
  String get delete => '삭제';

  @override
  String get save => '저장';

  @override
  String get create => '생성';

  @override
  String get close => '닫기';

  @override
  String get refresh => '새로고침';

  @override
  String get retry => '재시도';

  @override
  String get download => '다운로드';

  @override
  String get upload => '업로드';

  @override
  String get localPath => '로컬 경로';

  @override
  String get remotePath => '원격 경로';

  @override
  String localFileNotFound(Object path) {
    return '로컬 파일을 찾을 수 없습니다: $path';
  }

  @override
  String get overwrite => '덮어쓰기';

  @override
  String get overwriteFileQuestion => '로컬 파일을 덮어쓸까요?';

  @override
  String overwriteFileContent(Object path) {
    return '$path 파일이 이미 있습니다. 바꿀까요?';
  }

  @override
  String get settings => '설정';

  @override
  String get search => '검색';

  @override
  String get settingsTooltip => '설정 (Ctrl+,)';

  @override
  String get noProfilesYet => '아직 프로필이 없습니다';

  @override
  String get createOne => '프로필 만들기';

  @override
  String openProfile(Object name) {
    return '$name 열기';
  }

  @override
  String get openLocalShell => '로컬 셸 열기';

  @override
  String get localShell => '로컬 셸';

  @override
  String get localShellCommand => '로컬 셸 명령';

  @override
  String get localShellCommandHint => '비워두면 플랫폼 기본 셸을 사용합니다.';

  @override
  String get localShellWorkingDirectory => '시작 디렉터리';

  @override
  String get localShellWorkingDirectoryHint => '새 로컬 셸 탭이 시작될 선택 경로입니다.';

  @override
  String get localShellEnvironment => '환경 변수';

  @override
  String get localShellEnvironmentHint =>
      '한 줄에 NAME=value 하나씩 입력합니다. #으로 시작하는 줄은 무시합니다.';

  @override
  String get edit => '편집';

  @override
  String get sftpBrowser => 'SFTP 브라우저';

  @override
  String get portForwards => '포트 포워딩';

  @override
  String get keyPassphraseHint => '키 암호문 (선택)';

  @override
  String get noOpenSessions => '열린 세션 없음';

  @override
  String liveSessionsSummary(Object profiles, Object sessions) {
    return '활성 세션 $sessions개 · 프로필 $profiles개 · 로컬 작업 공간 준비됨';
  }

  @override
  String get quickstart => '빠른 시작';

  @override
  String get pressPaletteHint => 'Ctrl+K로 팔레트를 여세요';

  @override
  String get pickProfileOrPalette => '프로필을 선택하거나 Ctrl+K로 명령을 실행하세요.';

  @override
  String get all => '전체';

  @override
  String get goodMorning => '좋은 아침입니다.';

  @override
  String get goodAfternoon => '좋은 오후입니다.';

  @override
  String get goodEvening => '좋은 저녁입니다.';

  @override
  String profileCount(Object count) {
    return '프로필 $count개';
  }

  @override
  String get profilesLede => '로컬 전용 · 저장 데이터 암호화. 다른 기기와 페어링해 동기화할 수 있습니다.';

  @override
  String get importKeys => '키 가져오기';

  @override
  String get pickProfileToOpen => '열 프로필 선택';

  @override
  String get pickProfileForNewTab => '새 탭에 연결할 프로필 선택';

  @override
  String get pickProfileForSplit => '분할 패널에 연결할 프로필 선택';

  @override
  String openSelectedProfile(Object name) {
    return '$name 열기';
  }

  @override
  String get pickProfilePrompt => '프로필을 선택한 뒤 열어서 세션을 시작하세요.';

  @override
  String connectingTo(Object name) {
    return '$name에 연결 중';
  }

  @override
  String get connected => '연결됨';

  @override
  String get connecting => '연결 중';

  @override
  String get disconnected => '연결 끊김';

  @override
  String get sessionDisconnected => '세션 연결 끊김';

  @override
  String get sessionDisconnectedMessage => '세션 연결이 끊어졌습니다.';

  @override
  String get waitingForFirstChunk => '첫 터미널 출력을 기다리는 중';

  @override
  String get copyScreenTooltip => '화면 복사 (Ctrl+Shift+C)';

  @override
  String get pasteClipboardTooltip => '클립보드 붙여넣기 (Ctrl+Shift+V)';

  @override
  String get paste => '붙여넣기';

  @override
  String get confirmPasteTitle => '터미널에 붙여넣을까요?';

  @override
  String confirmPasteContent(Object byteCount, Object lineCount) {
    return '클립보드 내용은 $lineCount줄, $byteCount바이트입니다. 활성 세션에 붙여넣을까요?';
  }

  @override
  String get reconnectTooltip => '다시 연결 (Ctrl+Shift+R)';

  @override
  String get disconnectTooltip => '연결 끊기';

  @override
  String get copyError => '오류 복사';

  @override
  String get searchRun => '검색 · 실행';

  @override
  String get syncStatus => '동기화';

  @override
  String pairedDevices(Object count) {
    return '페어링됨 ($count)';
  }

  @override
  String get splitRight => '오른쪽 분할';

  @override
  String get splitDown => '아래쪽 분할';

  @override
  String get toggleSftpBrowser => 'SFTP 브라우저 전환';

  @override
  String get runCommandOrJump => '명령을 실행하거나 프로필로 이동…';

  @override
  String get paletteProfilesSection => '프로필';

  @override
  String get paletteCommandsSection => '명령';

  @override
  String get open => '열기';

  @override
  String get navigate => '이동';

  @override
  String get select => '선택';

  @override
  String get trustedHostKeys => '신뢰한 호스트 키';

  @override
  String get trustedHostKeysDescription =>
      'Tindra는 최초 접속 시 신뢰(TOFU) 방식을 사용합니다. 처음 본 호스트 키를 저장하고, 이후 키가 바뀌면 연결을 거부합니다.';

  @override
  String get noTrustedHostKeys => '아직 신뢰한 호스트 키가 없습니다.';

  @override
  String get removeTrustedHostKeyQuestion => '신뢰한 호스트 키를 삭제할까요?';

  @override
  String removeTrustedHostKeyContent(Object host, Object port) {
    return '$host:$port 키를 삭제할까요?\n\n다음 연결에서는 그때 제시되는 서버 키를 새로 신뢰합니다.';
  }

  @override
  String get remove => '삭제';

  @override
  String get removeTrustedKeyTooltip => '신뢰한 키 삭제';

  @override
  String get firstSeen => '처음 확인';

  @override
  String get lastSeen => '최근 확인';

  @override
  String get unknown => '알 수 없음';

  @override
  String get theme => '테마';

  @override
  String get dark => '다크';

  @override
  String get light => '라이트';

  @override
  String get terminalFont => '터미널 글꼴';

  @override
  String size(Object size) {
    return '크기: $size';
  }

  @override
  String get quakeGlobalHotkey => 'Quake 전역 단축키';

  @override
  String get quakeHotkeyHint => '예: F12 (창 표시/숨김 전환)';

  @override
  String get language => '언어';

  @override
  String get systemLanguage => '시스템';

  @override
  String get english => '영어';

  @override
  String get korean => '한국어';

  @override
  String get name => '이름';

  @override
  String get host => '호스트';

  @override
  String get user => '사용자';

  @override
  String get port => '포트';

  @override
  String get transport => '전송 방식';

  @override
  String get ssh => 'SSH';

  @override
  String get telnetRawTcp => 'Telnet (raw TCP)';

  @override
  String get auth => '인증';

  @override
  String get privateKey => '개인 키';

  @override
  String get sshAgent => 'SSH 에이전트';

  @override
  String get password => '비밀번호';

  @override
  String get keyboardInteractive => '키보드 대화형';

  @override
  String passwordFor(Object profile) {
    return '$profile 비밀번호';
  }

  @override
  String get passwordRequired => '비밀번호가 필요합니다.';

  @override
  String get connect => '연결';

  @override
  String get trust => '신뢰';

  @override
  String get trustHostKeyTitle => '이 호스트 키를 신뢰할까요?';

  @override
  String trustHostKeyContent(Object fingerprint, Object host, Object port) {
    return '$host:$port 서버가 이 fingerprint를 제시했습니다:\n\n$fingerprint\n\n예상한 서버와 일치할 때만 신뢰하세요.';
  }

  @override
  String get hostKeyChangedTitle => '호스트 키가 변경됨';

  @override
  String hostKeyChangedContent(
    Object actual,
    Object expected,
    Object host,
    Object port,
  ) {
    return '$host:$port 서버가 다른 호스트 키를 제시했습니다.\n\n신뢰된 키:\n$expected\n\n제시된 키:\n$actual\n\nTindra가 연결을 차단했습니다.';
  }

  @override
  String get replaceHostKey => '호스트 키 교체';

  @override
  String get hostKeyNotTrusted => '호스트 키를 신뢰하지 않았습니다.';

  @override
  String get privateKeyPath => '개인 키 경로';

  @override
  String get jumpHost => '점프 호스트';

  @override
  String get keyPath => '키 경로';

  @override
  String get notes => '메모';

  @override
  String get optional => '선택 사항';

  @override
  String get preferences => '환경설정';

  @override
  String get settingsLede => '테마, 강조색, 밀도는 즉시 적용됩니다. 다른 변경사항은 적용을 누르면 저장됩니다.';

  @override
  String get apply => '적용';

  @override
  String get appearance => '모양';

  @override
  String get appearanceThemeHint => '앱 화면에 다크 또는 라이트 모드를 사용합니다.';

  @override
  String get accent => '강조색';

  @override
  String get accentHint => '연결 상태, 포커스, 강조 표시에 사용합니다.';

  @override
  String get density => '밀도';

  @override
  String get densityHint => '좁은 화면에서 더 많은 행을 볼 수 있게 간격을 줄입니다.';

  @override
  String get cozy => '기본';

  @override
  String get compact => '조밀';

  @override
  String get terminal => '터미널';

  @override
  String get font => '글꼴';

  @override
  String get fontHint =>
      'JetBrains Mono가 기본 포함됩니다. Cascadia Mono / Consolas로 대체됩니다.';

  @override
  String get syncSystem => '동기화 · 시스템';

  @override
  String get diagnostics => '진단';

  @override
  String get appVersion => '앱 버전';

  @override
  String get rustCoreVersion => 'Rust 코어 버전';

  @override
  String get profilesPath => '프로필 경로';

  @override
  String get settingsPath => '설정 경로';

  @override
  String get expectedLogDirectory => '예상 로그 디렉터리';

  @override
  String get loading => '불러오는 중...';

  @override
  String get quakeHotkey => 'Quake 단축키';

  @override
  String get quakeHotkeyDescription => '어떤 창 위에서도 Tindra를 불러오는 전역 키입니다.';

  @override
  String get newProfileEyebrow => '새 프로필';

  @override
  String get editProfileEyebrow => '프로필 편집';

  @override
  String get newProfileTitle => '새 연결';

  @override
  String get filesSftpEyebrow => '파일 | SFTP';

  @override
  String get browseRemote => '원격 탐색';

  @override
  String get filesSftpLede =>
      '끌어 넣으면 업로드하고, 끌어 내면 다운로드합니다. 전송 대기열은 오른쪽에 표시됩니다.';

  @override
  String get up => '상위';

  @override
  String get tableName => '이름';

  @override
  String get tableSize => '크기';

  @override
  String get tableModified => '수정일';

  @override
  String get tags => '태그';

  @override
  String get addSshProfileToBrowse => '파일을 탐색하려면 SSH 프로필을 추가하세요.';

  @override
  String get connectingEllipsis => '연결 중...';

  @override
  String get transfers => '전송';

  @override
  String get idle => '대기';

  @override
  String activeTransferCount(Object count) {
    return '$count개 진행 중';
  }

  @override
  String failedTransferCount(Object count) {
    return '$count개 실패';
  }

  @override
  String get noTransfersInFlight => '진행 중인 전송 없음';

  @override
  String get networkPortForwardsEyebrow => '네트워크 | 포트 포워딩';

  @override
  String get forwardsLede => '로컬 터널은 선택한 SSH 프로필을 통해 이 컴퓨터에서 대기합니다.';

  @override
  String get newForward => '새 포워딩';

  @override
  String get noActiveTunnels => '활성 터널 없음';

  @override
  String get pickProfileThenForward => '프로필을 선택한 뒤 포워딩을 만드세요.';

  @override
  String openLocalForwardToProfile(Object name) {
    return '$name에 대한 로컬 포워딩을 열어 시작하세요.';
  }

  @override
  String get openStatus => '열림';

  @override
  String get local => '로컬';

  @override
  String get remote => '원격';

  @override
  String get via => '경유';

  @override
  String get reconnect => '다시 연결';

  @override
  String get drop => '중지';

  @override
  String get trustHostKeysEyebrow => '신뢰 | 호스트 키';

  @override
  String get noTrustedKeysYet => '아직 신뢰한 키가 없습니다';

  @override
  String get connectOnceRememberHost => '호스트에 한 번 연결하면 Tindra가 기억합니다.';

  @override
  String get first => '처음';

  @override
  String get last => '최근';

  @override
  String get started => '시작';

  @override
  String get active => '활성';

  @override
  String get notAvailable => '없음';

  @override
  String get localForward => '로컬 포워딩';

  @override
  String localForwardDescription(Object name) {
    return '이 컴퓨터에서 대기하고 $name을 통해 터널링합니다.';
  }

  @override
  String get localAddr => '로컬 주소';

  @override
  String get remoteHost => '원격 호스트';

  @override
  String get quickConnect => '빠른 연결';

  @override
  String get restorePreviousLayout => '이전 레이아웃 복원';

  @override
  String get renameTab => '탭 이름 변경';

  @override
  String get tabName => '탭 이름';

  @override
  String get duplicateTab => '탭 복제';

  @override
  String get closeOtherTabs => '다른 탭 닫기';

  @override
  String get closeTabsToRight => '오른쪽 탭 닫기';

  @override
  String get previousPane => '이전 패널';

  @override
  String get nextPane => '다음 패널';

  @override
  String get detachTab => '탭 분리';

  @override
  String get pinOrUnpinTab => '탭 고정 또는 해제';

  @override
  String get pinTab => '탭 고정';

  @override
  String get unpinTab => '탭 고정 해제';

  @override
  String get closeActivePane => '활성 패널 닫기';

  @override
  String get restorePane => '패널 복원';

  @override
  String get maximizePane => '패널 최대화';

  @override
  String get toggleSidebar => '사이드바 전환';

  @override
  String get collapseSidebar => '사이드바 접기';

  @override
  String get expandSidebar => '사이드바 펼치기';

  @override
  String get openTabs => '열린 탭';

  @override
  String get themePreset => '테마 프리셋';

  @override
  String get themePresetHint => '외형 JSON을 복사하거나 붙여넣습니다';

  @override
  String get exportTheme => '내보내기';

  @override
  String get importTheme => '가져오기';

  @override
  String get keyboardShortcuts => '키보드 단축키';

  @override
  String get newTab => '새 탭';

  @override
  String get closeTab => '탭 닫기';

  @override
  String get nextTab => '다음 탭';

  @override
  String get previousTab => '이전 탭';

  @override
  String get commandPalette => '명령 팔레트';

  @override
  String get copy => '복사';

  @override
  String get moveTabLeft => '탭 왼쪽으로 이동';

  @override
  String get moveTabRight => '탭 오른쪽으로 이동';

  @override
  String get closePane => '패널 닫기';

  @override
  String get paletteFrost => '프로스트';

  @override
  String get paletteAurora => '오로라';

  @override
  String get paletteGlacier => '글레이셔';

  @override
  String get paletteTwilight => '트와일라이트';

  @override
  String get paletteCoal => '콜';

  @override
  String get paletteSnow => '스노우';

  @override
  String get paletteRose => '로즈';

  @override
  String get paletteAmber => '앰버';

  @override
  String get defaultColor => '기본 색상';

  @override
  String get green => '초록';

  @override
  String get blue => '파랑';

  @override
  String get unnamed => '(이름 없음)';
}
