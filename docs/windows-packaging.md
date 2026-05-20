# Windows Packaging

Current build output:

```powershell
cd apps/desktop
flutter build windows
```

Executable:

```text
apps/desktop/build/windows/x64/runner/Release/tindra_desktop.exe
```

Product metadata currently lives in:
- `apps/desktop/windows/runner/Runner.rc`
- `apps/desktop/windows/runner/main.cpp`
- `apps/desktop/pubspec.yaml`

Versioning policy:
- Use `apps/desktop/pubspec.yaml` as the source of truth.
- `version: x.y.z+n` maps to product/file version during Flutter Windows builds.
- Release builds must not override build name/number without updating release notes.

Installer target:
- Prefer MSIX for Windows Store/private distribution.
- Add a conventional installer only if MSIX blocks SSH-agent, file association, or enterprise deployment requirements.

Diagnostics target:
- Add a Settings diagnostics section that shows app version, profile store path, settings path, Rust core version, and latest log path.
- Logs should live under the platform data directory in `Tindra/logs/`.
