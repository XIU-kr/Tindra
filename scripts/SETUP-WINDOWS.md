# Tindra — Windows quickstart

이 가이드는 **Windows 데스크톱 빌드 하나만** 돌리기 위한 최소 절차입니다. Android·iOS·Linux·macOS는 무시.

## 설치 (한 번만)

### 1. Visual Studio 2022 Build Tools (C++ 워크로드)

C++ 컴파일러는 Flutter Windows desktop과 일부 Rust 크레이트(rusqlite의 SQLCipher 번들 빌드 등) 모두에 필요합니다.

```powershell
winget install Microsoft.VisualStudio.2022.BuildTools --override "--passive --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
```

또는 [installer 직접 다운로드](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022) → **"Desktop development with C++"** 워크로드 체크.

### 2. Rust (stable)

```powershell
winget install Rustlang.Rustup
# 새 PowerShell 창 열고:
rustup default stable
rustup component add rustfmt clippy
```

확인: `rustc --version` → 1.78 이상.

### 3. Flutter (stable, Windows desktop 활성화)

```powershell
winget install Flutter.Flutter
# 새 창에서:
flutter config --enable-windows-desktop
flutter doctor   # 빨간 항목 있으면 메시지대로 해결
```

확인: `flutter --version` → 3.24 이상, `flutter doctor` 모두 ✓ 또는 ! (Android·iOS는 빨간색이어도 무시).

### 4. flutter_rust_bridge codegen

```powershell
cargo install flutter_rust_bridge_codegen --version "^2"
```

확인: `flutter_rust_bridge_codegen --version` 출력.

### 5. Git LFS (선택)

큰 폰트 파일/바이너리가 들어오기 시작하면 필요. 지금은 스킵 가능.

---

## 부트스트랩 (한 번만)

설치 끝났으면 레포 루트에서:

```powershell
# 1. Rust 워크스페이스 컴파일 확인 (네트워크에서 deps 받음, 5–10분 걸림)
Set-Location core
cargo check --workspace
Set-Location ..

# 2. Flutter 데스크톱 앱 생성 (Windows만)
flutter create --org sh.tindra --project-name tindra_desktop --platforms=windows apps\desktop

# 3. shared_ui 패키지 생성
flutter create --template=package --project-name tindra_shared_ui apps\shared_ui

# 4. tindra-core 라이브러리를 Flutter에서 쓸 수 있게 frb 플러그인 추가
Set-Location apps\desktop
flutter pub add flutter_rust_bridge
Set-Location ..\..

# 5. frb 코드젠 — Rust API → Dart 바인딩 생성
.\scripts\codegen.ps1
```

성공 시 `apps/shared_ui/lib/src/bridge/` 아래에 `frb_generated.dart` 등이 만들어집니다.

---

## 헬로월드 검증

`apps/desktop/lib/main.dart`를 열어 다음으로 교체:

```dart
import 'package:flutter/material.dart';
import 'package:tindra_shared_ui/src/bridge/frb_generated.dart';

Future<void> main() async {
  await TindraBridge.init();
  runApp(const TindraApp());
}

class TindraApp extends StatelessWidget {
  const TindraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tindra',
      theme: ThemeData.dark(useMaterial3: true),
      home: const HelloScreen(),
    );
  }
}

class HelloScreen extends StatelessWidget {
  const HelloScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tindra (Phase 0)')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('echo: ${echo(msg: "hello")}'),
            const SizedBox(height: 8),
            Text('core_version: ${coreVersion()}'),
          ],
        ),
      ),
    );
  }
}
```

(`echo`/`coreVersion` import 경로는 frb 코드젠 산출물에 따라 자동 보정됩니다. IDE의 import quickfix에 맡겨도 OK.)

`apps/desktop/pubspec.yaml`의 `dependencies:` 아래 `tindra_shared_ui: { path: ../shared_ui }` 추가.

실행:

```powershell
Set-Location apps\desktop
flutter run -d windows
```

**기대 결과**: 창이 뜨고 `echo: Tindra core says: hello`와 `core_version: 0.0.0`이 표시됨. 이게 보이면 Phase 0 완료.

---

## 트러블슈팅

| 증상 | 원인 / 해결 |
|---|---|
| `cargo check`가 `link.exe not found` | VS Build Tools에서 C++ 워크로드 미설치. 위 1번 다시. |
| `flutter doctor`가 Visual Studio 빨간색 | 위 1번 미설치. |
| `flutter run`이 `No supported devices found` | `flutter config --enable-windows-desktop` 빠짐. 새 창 열기. |
| frb codegen이 `tindra-core not found` | `bridge/flutter_rust_bridge.yaml`의 경로가 레포 구조와 맞는지 확인. |
| `cargo install flutter_rust_bridge_codegen`이 link 에러 | VS Build Tools 미설치 또는 PATH 새로고침 필요 (창 다시 열기). |

---

## 다음 단계

헬로월드가 뜨면 Phase 1 시작:
1. `apps/shared_ui`에 터미널 그리드 위젯 (`alacritty_terminal` 그리드 → Skia)
2. `tindra-ssh`에 첫 SSH 연결 — `russh` 의존성 활성, key auth, 채널 open
3. `tindra-pty`에 ConPTY 통합 (Local Shell 탭)
4. 단일 SSH 세션으로 `vim`/`top` 정상 동작 검증

이 단계는 다음 세션에서 함께 진행합니다.
