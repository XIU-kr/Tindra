library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

enum TerminalPasteRisk { normal, multiline, large }

@immutable
class TerminalPasteDecision {
  const TerminalPasteDecision({
    required this.text,
    required this.risk,
    required this.lineCount,
    required this.byteCount,
  });

  final String text;
  final TerminalPasteRisk risk;
  final int lineCount;
  final int byteCount;

  bool get shouldConfirm => risk != TerminalPasteRisk.normal;

  String get normalizedForPty => text.replaceAll('\n', '\r');
}

TerminalPasteDecision assessTerminalPaste(
  String text, {
  int largePasteThresholdBytes = 4096,
}) {
  final byteCount = utf8.encode(text).length;
  final lineCount = text.isEmpty ? 0 : '\n'.allMatches(text).length + 1;
  final risk = byteCount >= largePasteThresholdBytes
      ? TerminalPasteRisk.large
      : lineCount > 1
      ? TerminalPasteRisk.multiline
      : TerminalPasteRisk.normal;
  return TerminalPasteDecision(
    text: text,
    risk: risk,
    lineCount: lineCount,
    byteCount: byteCount,
  );
}

String? chooseTerminalCopyText({String? selectionText, String? screenText}) {
  final selection = selectionText?.trimRight();
  if (selection != null && selection.isNotEmpty) return selection;
  final screen = screenText?.trimRight();
  if (screen != null && screen.isNotEmpty) return screen;
  return null;
}

@immutable
class TerminalSearchMatch {
  const TerminalSearchMatch({
    required this.start,
    required this.end,
    required this.line,
    required this.column,
  });

  final int start;
  final int end;
  final int line;
  final int column;
}

List<TerminalSearchMatch> findTerminalTextMatches(
  String text,
  String query, {
  bool caseSensitive = false,
  bool wholeWord = false,
  bool regex = false,
}) {
  if (query.isEmpty) return const [];
  if (regex) {
    return _findRegexTerminalTextMatchesOrNull(
          text,
          query,
          caseSensitive: caseSensitive,
          wholeWord: wholeWord,
        ) ??
        const [];
  }
  final haystack = caseSensitive ? text : text.toLowerCase();
  final needle = caseSensitive ? query : query.toLowerCase();
  final matches = <TerminalSearchMatch>[];
  var offset = 0;
  var line = 0;
  var lineStart = 0;

  while (true) {
    final index = haystack.indexOf(needle, offset);
    if (index == -1) break;
    final isWholeWord =
        !wholeWord || _isWholeWordMatch(text, index, query.length);
    if (!isWholeWord) {
      offset = index + needle.length;
      continue;
    }
    while (lineStart < index) {
      final nextBreak = text.indexOf('\n', lineStart);
      if (nextBreak == -1 || nextBreak >= index) break;
      line++;
      lineStart = nextBreak + 1;
    }
    matches.add(
      TerminalSearchMatch(
        start: index,
        end: index + query.length,
        line: line,
        column: index - lineStart,
      ),
    );
    offset = index + needle.length;
  }

  return matches;
}

List<TerminalSearchMatch>? _findRegexTerminalTextMatchesOrNull(
  String text,
  String query, {
  required bool caseSensitive,
  required bool wholeWord,
}) {
  final RegExp pattern;
  try {
    pattern = RegExp(query, caseSensitive: caseSensitive, multiLine: true);
  } on FormatException {
    return null;
  }
  final matches = <TerminalSearchMatch>[];
  var line = 0;
  var lineStart = 0;
  for (final match in pattern.allMatches(text)) {
    if (match.start == match.end) continue;
    if (wholeWord &&
        !_isWholeWordMatch(text, match.start, match.end - match.start)) {
      continue;
    }
    while (lineStart < match.start) {
      final nextBreak = text.indexOf('\n', lineStart);
      if (nextBreak == -1 || nextBreak >= match.start) break;
      line++;
      lineStart = nextBreak + 1;
    }
    matches.add(
      TerminalSearchMatch(
        start: match.start,
        end: match.end,
        line: line,
        column: match.start - lineStart,
      ),
    );
  }
  return matches;
}

bool _isWholeWordMatch(String text, int start, int length) {
  final before = start <= 0 ? null : text.codeUnitAt(start - 1);
  final afterIndex = start + length;
  final after = afterIndex >= text.length ? null : text.codeUnitAt(afterIndex);
  return !_isWordCodeUnit(before) && !_isWordCodeUnit(after);
}

bool _isWordCodeUnit(int? code) {
  if (code == null) return false;
  return (code >= 0x30 && code <= 0x39) ||
      (code >= 0x41 && code <= 0x5A) ||
      (code >= 0x61 && code <= 0x7A) ||
      code == 0x5F;
}

@immutable
class TerminalSearchState {
  const TerminalSearchState({
    required this.query,
    required this.matches,
    this.currentIndex = 0,
    this.invalidPattern = false,
  });

  final String query;
  final List<TerminalSearchMatch> matches;
  final int currentIndex;
  final bool invalidPattern;

  int get count => matches.length;

  int get displayIndex => matches.isEmpty ? 0 : currentIndex + 1;

  TerminalSearchMatch? get currentMatch {
    if (matches.isEmpty) return null;
    return matches[currentIndex.clamp(0, matches.length - 1)];
  }
}

TerminalSearchState buildTerminalSearchState(
  String text,
  String query, {
  int currentIndex = 0,
  bool caseSensitive = false,
  bool wholeWord = false,
  bool regex = false,
}) {
  var invalidPattern = false;
  final List<TerminalSearchMatch> matches;
  if (regex) {
    final regexMatches = _findRegexTerminalTextMatchesOrNull(
      text,
      query,
      caseSensitive: caseSensitive,
      wholeWord: wholeWord,
    );
    invalidPattern = query.isNotEmpty && regexMatches == null;
    matches = regexMatches ?? const [];
  } else {
    matches = findTerminalTextMatches(
      text,
      query,
      caseSensitive: caseSensitive,
      wholeWord: wholeWord,
    );
  }
  return TerminalSearchState(
    query: query,
    matches: matches,
    currentIndex: matches.isEmpty
        ? 0
        : currentIndex.clamp(0, matches.length - 1),
    invalidPattern: invalidPattern,
  );
}

enum TindraTransferDirection { upload, download }

enum TindraAuthMethod { key, agent, password, keyboardInteractive }

enum TindraTransport { ssh, telnet }

enum TindraSecretBackend {
  dpapi,
  keychain,
  libsecret,
  androidKeystore,
  unavailable,
}

@immutable
class TindraProfileViewModel {
  const TindraProfileViewModel({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    this.authMethod = TindraAuthMethod.key,
    this.transport = TindraTransport.ssh,
    this.jumpHost = '',
  });

  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final TindraAuthMethod authMethod;
  final TindraTransport transport;
  final String jumpHost;

  String get endpoint => '$username@$host:$port';

  bool get usesJumpHost => jumpHost.trim().isNotEmpty;
}

enum TindraSessionVisualState { connecting, connected, disconnected }

@immutable
class TindraSessionViewModel {
  const TindraSessionViewModel({
    required this.id,
    required this.profileName,
    required this.state,
    this.errorMessage,
  });

  final String id;
  final String profileName;
  final TindraSessionVisualState state;
  final String? errorMessage;

  bool get canPaste => state == TindraSessionVisualState.connected;

  bool get canReconnect => state == TindraSessionVisualState.disconnected;
}

enum TindraTransferStatus { queued, running, succeeded, failed, canceled }

@immutable
class TindraTransferItem {
  const TindraTransferItem({
    required this.id,
    required this.name,
    required this.direction,
    required this.localPath,
    required this.remotePath,
    this.status = TindraTransferStatus.queued,
    this.bytesTransferred = 0,
    this.totalBytes,
    this.errorMessage,
  });

  final String id;
  final String name;
  final TindraTransferDirection direction;
  final String localPath;
  final String remotePath;
  final TindraTransferStatus status;
  final int bytesTransferred;
  final int? totalBytes;
  final String? errorMessage;

  double? get progress {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return (bytesTransferred / total).clamp(0, 1).toDouble();
  }

  bool get isActive =>
      status == TindraTransferStatus.queued ||
      status == TindraTransferStatus.running;

  bool get canRetry => status == TindraTransferStatus.failed;

  bool get canCancel => isActive;

  TindraTransferItem copyWith({
    String? id,
    String? name,
    TindraTransferDirection? direction,
    String? localPath,
    String? remotePath,
    TindraTransferStatus? status,
    int? bytesTransferred,
    int? totalBytes,
    String? errorMessage,
  }) {
    return TindraTransferItem(
      id: id ?? this.id,
      name: name ?? this.name,
      direction: direction ?? this.direction,
      localPath: localPath ?? this.localPath,
      remotePath: remotePath ?? this.remotePath,
      status: status ?? this.status,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      totalBytes: totalBytes ?? this.totalBytes,
      errorMessage: errorMessage,
    );
  }
}

class TindraTransferQueue extends ChangeNotifier {
  final List<TindraTransferItem> _items = [];

  List<TindraTransferItem> get items => List.unmodifiable(_items);

  int get activeCount => _items.where((item) => item.isActive).length;

  int get failedCount =>
      _items.where((item) => item.status == TindraTransferStatus.failed).length;

  bool get hasWork => _items.isNotEmpty;

  void enqueue(TindraTransferItem item) {
    _items.add(item);
    notifyListeners();
  }

  void update(
    String id,
    TindraTransferItem Function(TindraTransferItem) update,
  ) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index == -1) return;
    _items[index] = update(_items[index]);
    notifyListeners();
  }

  void markCanceled(String id) {
    update(id, (item) => item.copyWith(status: TindraTransferStatus.canceled));
  }

  void markRetrying(String id) {
    update(
      id,
      (item) => item.copyWith(
        status: TindraTransferStatus.queued,
        bytesTransferred: 0,
        errorMessage: null,
      ),
    );
  }

  void removeFinished() {
    _items.removeWhere(
      (item) =>
          item.status == TindraTransferStatus.succeeded ||
          item.status == TindraTransferStatus.canceled,
    );
    notifyListeners();
  }
}
