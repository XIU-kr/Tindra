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
    return 'Tindra · $profile';
  }

  @override
  String get profiles => '프로필';

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
  String get settings => '설정';

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
  String get edit => '편집';

  @override
  String get sftpBrowser => 'SFTP 브라우저';

  @override
  String get portForwards => '포트 포워딩';

  @override
  String get keyPassphraseHint => '키 암호문 (있는 경우)';

  @override
  String get noOpenSessions => '열린 세션 없음';

  @override
  String get pickProfileToOpen => '열 프로필을 선택하세요';

  @override
  String openSelectedProfile(Object name) {
    return '$name 열기';
  }

  @override
  String get pickProfilePrompt => '왼쪽에서 프로필을 선택한 뒤 \"열기\"를 눌러 세션을 시작하세요.';

  @override
  String connectingTo(Object name) {
    return '$name에 연결 중…';
  }

  @override
  String get disconnected => '연결 끊김';

  @override
  String get waitingForFirstChunk => '첫 데이터를 기다리는 중…';

  @override
  String get copyScreenTooltip => '화면 복사 (Ctrl+Shift+C)';

  @override
  String get pasteClipboardTooltip => '클립보드 붙여넣기 (Ctrl+Shift+V)';

  @override
  String get reconnectTooltip => '다시 연결 (Ctrl+Shift+R)';

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
    return '$host:$port 키를 삭제할까요?\n\n다음 연결 시 그때 제시되는 서버 키를 다시 신뢰하게 됩니다.';
  }

  @override
  String get remove => '삭제';

  @override
  String get removeTrustedKeyTooltip => '신뢰한 키 삭제';

  @override
  String get firstSeen => '최초 확인';

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
  String get unnamed => '(이름 없음)';
}
