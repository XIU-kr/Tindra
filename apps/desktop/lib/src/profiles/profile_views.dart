part of '../../main.dart';

// ============================================================================
// Profile card (home view)
// ============================================================================

class _ProfileCard extends StatefulWidget {
  const _ProfileCard({
    required this.profile,
    required this.selected,
    required this.dense,
    required this.onSelect,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });
  final rust.Profile profile;
  final bool selected;
  final bool dense;
  final VoidCallback onSelect;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = widget.profile;
    final accent = _accentForProfile(p);
    final tags = p.notes
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onSelect,
        onDoubleTap: widget.onOpen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.all(widget.dense ? 12 : 16),
          decoration: BoxDecoration(
            color: _hover ? _bg2 : _bg1,
            border: Border.all(color: _hover ? _line2 : _line),
            borderRadius: BorderRadius.circular(10),
          ),
          transform: _hover
              ? (Matrix4.identity()..translateByDouble(0.0, -1.0, 0.0, 1.0))
              : Matrix4.identity(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _BarMark(accent: accent),
                  const Spacer(),
                  _StatusPill(connected: false),
                ],
              ),
              SizedBox(height: widget.dense ? 4 : 8),
              Text(
                p.name.isEmpty ? l10n.unnamed : p.name,
                style: widget.dense
                    ? _sans(size: 15.5, weight: FontWeight.w600, color: _ink0)
                    : _display(
                        size: 18,
                        weight: FontWeight.w500,
                        color: _ink0,
                        letterSpacing: -0.2,
                      ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: p.username,
                            style: _mono(size: 11.5, color: _ink1),
                          ),
                          TextSpan(
                            text: '@',
                            style: _mono(size: 11.5, color: _ink3),
                          ),
                          TextSpan(
                            text: p.host,
                            style: _mono(size: 11.5, color: _ink1),
                          ),
                          if (p.port != 22 && p.port != 0)
                            TextSpan(
                              text: ':${p.port}',
                              style: _mono(size: 11.5, color: _acc),
                            ),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    (p.transport.isEmpty ? 'ssh' : p.transport).toUpperCase(),
                    style: _mono(size: 10.5, color: _ink2, letterSpacing: 1.0),
                  ),
                  Text(' | ', style: _mono(size: 10.5, color: _ink3)),
                  Text(
                    p.authMethod.isEmpty ? 'key' : p.authMethod,
                    style: _mono(size: 10.5, color: _ink3, letterSpacing: 1.0),
                  ),
                  if (p.jumpHost.isNotEmpty) ...[
                    Text(' | ', style: _mono(size: 10.5, color: _ink3)),
                    Flexible(
                      child: Text(
                        '${l10n.via.toLowerCase()} ${p.jumpHost}',
                        style: _mono(
                          size: 10.5,
                          color: _ink3,
                          letterSpacing: 1.0,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: widget.dense ? 8 : 12),
              Container(height: 1, color: _line),
              SizedBox(height: widget.dense ? 6 : 10),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final t in tags.take(3)) _Tag(t),
                        if (tags.length > 3) _Tag('+${tags.length - 3}'),
                      ],
                    ),
                  ),
                  if (widget.selected)
                    Tooltip(
                      message: l10n.openProfile(p.name),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onOpen,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _acc,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            l10n.open.toUpperCase(),
                            style: _mono(
                              size: 10,
                              weight: FontWeight.w700,
                              letterSpacing: 1.4,
                              color: _isLight ? Colors.white : _Pal.dBg0,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _accentForProfile(rust.Profile p) {
  // Stable accent rotation by id hash so each card feels distinct.
  const palette = [
    _Pal.cRose,
    _Pal.cAmber,
    _Pal.cEmerald,
    _Pal.cSky,
    _Pal.cViolet,
  ];
  final h = p.id.hashCode.abs();
  return palette[h % palette.length];
}

class _BarMark extends StatelessWidget {
  const _BarMark({required this.accent});
  final Color accent;
  @override
  Widget build(BuildContext context) {
    Widget bar(double height, double opacity) => Container(
      width: 3,
      height: height,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(1),
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        bar(14, 0.9),
        const SizedBox(width: 2),
        bar(9, 0.55),
        const SizedBox(width: 2),
        bar(5, 0.35),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.connected});
  final bool connected;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: connected ? _Pal.cEmerald : _ink3,
            shape: BoxShape.circle,
            boxShadow: connected
                ? [
                    BoxShadow(
                      color: _Pal.cEmerald.withValues(alpha: 0.22),
                      blurRadius: 0,
                      spreadRadius: 3,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          (connected ? l10n.active : l10n.idle).toUpperCase(),
          style: _mono(
            size: 10,
            color: connected ? _Pal.cEmerald : _ink3,
            letterSpacing: 1.4,
            weight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: _bg3,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: _mono(size: 10, color: _ink2, letterSpacing: 0.4),
      ),
    );
  }
}

// ============================================================================
// Profiles table
// ============================================================================

class _ProfilesTable extends StatelessWidget {
  const _ProfilesTable({
    required this.profiles,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });
  final List<rust.Profile> profiles;
  final ValueChanged<rust.Profile> onOpen;
  final ValueChanged<rust.Profile> onEdit;
  final ValueChanged<rust.Profile> onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: _bg1,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _profHead(l10n),
          for (var i = 0; i < profiles.length; i++)
            _ProfileRow(
              profile: profiles[i],
              last: i == profiles.length - 1,
              onOpen: () => onOpen(profiles[i]),
              onEdit: () => onEdit(profiles[i]),
              onDelete: () => onDelete(profiles[i]),
            ),
        ],
      ),
    );
  }

  Widget _profHead(AppLocalizations l10n) {
    Widget cell(String s) => Text(
      s.toUpperCase(),
      style: _mono(size: 10.5, color: _ink3, letterSpacing: 1.5),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      decoration: BoxDecoration(
        color: _bg1,
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          Expanded(flex: 16, child: cell(l10n.name)),
          Expanded(flex: 16, child: cell(l10n.host)),
          Expanded(flex: 7, child: cell(l10n.auth)),
          Expanded(flex: 11, child: cell(l10n.tags)),
          Expanded(flex: 9, child: cell(l10n.last)),
          const SizedBox(width: 110),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatefulWidget {
  const _ProfileRow({
    required this.profile,
    required this.last,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });
  final rust.Profile profile;
  final bool last;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_ProfileRow> createState() => _ProfileRowState();
}

class _ProfileRowState extends State<_ProfileRow> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = widget.profile;
    final accent = _accentForProfile(p);
    final tags = p.notes
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
        decoration: BoxDecoration(
          color: _hover ? _bg2 : null,
          border: Border(
            bottom: BorderSide(color: widget.last ? Colors.transparent : _line),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 16,
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      p.name.isEmpty ? l10n.unnamed : p.name,
                      style: _display(
                        size: 15.5,
                        weight: FontWeight.w500,
                        color: _ink0,
                        letterSpacing: -0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 16,
              child: Text(
                '${p.username}@${p.host}${p.port != 22 && p.port != 0 ? ':${p.port}' : ''}',
                style: _mono(size: 12, color: _ink1),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 7,
              child: Text(
                (p.authMethod.isEmpty ? 'key' : p.authMethod).toUpperCase(),
                style: _mono(size: 11, color: _ink2, letterSpacing: 1.0),
              ),
            ),
            Expanded(
              flex: 11,
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [for (final t in tags.take(3)) _Tag(t)],
              ),
            ),
            Expanded(
              flex: 9,
              child: Text(
                l10n.notAvailable,
                style: _mono(size: 11, color: _ink3),
              ),
            ),
            SizedBox(
              width: 110,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _TinyButton(
                    icon: Icons.play_arrow_rounded,
                    label: l10n.open.toLowerCase(),
                    onTap: widget.onOpen,
                  ),
                  const SizedBox(width: 4),
                  _IconBtn(
                    icon: Icons.edit_outlined,
                    onTap: widget.onEdit,
                    iconSize: 13,
                  ),
                  _IconBtn(
                    icon: Icons.delete_outline,
                    onTap: widget.onDelete,
                    iconSize: 13,
                    danger: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Profile dialog (real implementation)
// ============================================================================

class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({this.initial});
  final rust.Profile? initial;
  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  late final TextEditingController _name;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _user;
  late final TextEditingController _key;
  late final TextEditingController _notes;
  late final TextEditingController _jumpHost;
  late final TextEditingController _jumpPort;
  late final TextEditingController _jumpUser;
  late final TextEditingController _jumpKey;
  late String _authMethod;
  late bool _showJump;
  late String _transport;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _name = TextEditingController(text: p?.name ?? '');
    _host = TextEditingController(text: p?.host ?? '');
    _port = TextEditingController(text: (p?.port ?? 22).toString());
    _user = TextEditingController(text: p?.username ?? '');
    _key = TextEditingController(
      text: p?.privateKeyPath ?? r'C:\Users\XIU\.ssh\id_ed25519',
    );
    _notes = TextEditingController(text: p?.notes ?? '');
    _jumpHost = TextEditingController(text: p?.jumpHost ?? '');
    _jumpPort = TextEditingController(
      text: ((p?.jumpPort ?? 0) == 0 ? 22 : p!.jumpPort).toString(),
    );
    _jumpUser = TextEditingController(text: p?.jumpUsername ?? '');
    _jumpKey = TextEditingController(text: p?.jumpPrivateKeyPath ?? '');
    _authMethod = (p?.authMethod.isEmpty ?? true) ? 'key' : p!.authMethod;
    _showJump = (p?.jumpHost.isNotEmpty ?? false);
    _transport = (p?.transport.isEmpty ?? true) ? 'ssh' : p!.transport;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _host,
      _port,
      _user,
      _key,
      _notes,
      _jumpHost,
      _jumpPort,
      _jumpUser,
      _jumpKey,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final port = int.tryParse(_port.text.trim()) ?? 22;
    final jumpPort = int.tryParse(_jumpPort.text.trim()) ?? 22;
    final p = rust.Profile(
      id: widget.initial?.id ?? '',
      name: _name.text.trim().isEmpty
          ? '${_user.text.trim()}@${_host.text.trim()}'
          : _name.text.trim(),
      host: _host.text.trim(),
      port: port,
      username: _user.text.trim(),
      privateKeyPath: _key.text.trim(),
      notes: _notes.text,
      authMethod: _authMethod,
      jumpHost: _showJump ? _jumpHost.text.trim() : '',
      jumpPort: jumpPort,
      jumpUsername: _showJump ? _jumpUser.text.trim() : '',
      jumpPrivateKeyPath: _showJump ? _jumpKey.text.trim() : '',
      transport: _transport,
    );
    Navigator.pop(context, p);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.initial == null;
    final l10n = AppLocalizations.of(context);
    return Dialog(
      backgroundColor: _bg1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: _line2),
      ),
      child: Container(
        width: 480,
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  (isNew ? l10n.newProfileEyebrow : l10n.editProfileEyebrow)
                      .toUpperCase(),
                  style: _eyebrow(),
                ),
                const Spacer(),
                _IconBtn(
                  icon: Icons.close,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isNew ? l10n.newProfileTitle : _name.text,
              style: _display(size: 24, weight: FontWeight.w500, color: _ink0),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _row(l10n.name, _name, hint: 'edge-prod-01'),
                    _row(
                      l10n.host,
                      _host,
                      hint: 'localhost / 1.2.3.4 / dev.example.com',
                    ),
                    Row(
                      children: [
                        Expanded(child: _row(l10n.user, _user, hint: 'XIU')),
                        const SizedBox(width: 8),
                        SizedBox(width: 100, child: _row(l10n.port, _port)),
                      ],
                    ),
                    _segLabel(l10n.transport),
                    _segments(
                      value: _transport,
                      options: [
                        ('ssh', l10n.ssh),
                        ('telnet', l10n.telnetRawTcp),
                      ],
                      onChanged: (v) => setState(() => _transport = v),
                    ),
                    if (_transport == 'ssh') ...[
                      _segLabel(l10n.auth),
                      _segments(
                        value: _authMethod,
                        options: [
                          ('key', l10n.privateKey),
                          ('agent', l10n.sshAgent),
                          ('password', l10n.password),
                          ('keyboard-interactive', l10n.keyboardInteractive),
                        ],
                        onChanged: (v) => setState(() => _authMethod = v),
                      ),
                      if (shouldShowPrivateKeyFieldForAuthMethod(_authMethod))
                        _row(l10n.privateKeyPath, _key),
                    ],
                    _jumpSection(l10n),
                    _row(l10n.notes, _notes, hint: l10n.optional, maxLines: 2),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _GhostButton(
                  icon: Icons.close,
                  label: l10n.cancel.toUpperCase(),
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                _PrimaryButton(
                  icon: isNew ? Icons.add : Icons.check,
                  label: (isNew ? l10n.create : l10n.save).toUpperCase(),
                  onTap: _host.text.trim().isEmpty || _user.text.trim().isEmpty
                      ? null
                      : _save,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _segLabel(String label) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 6, left: 4),
    child: Text(
      label.toUpperCase(),
      style: _mono(size: 10.5, color: _ink3, letterSpacing: 1.3),
    ),
  );

  Widget _segments({
    required String value,
    required List<(String, String)> options,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: _bg2,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          for (final (val, label) in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(val),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: value == val ? _bg0 : null,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: value == val
                        ? [
                            BoxShadow(
                              color: _line2,
                              blurRadius: 0,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label.toUpperCase(),
                    style: _mono(
                      size: 11,
                      color: value == val ? _ink0 : _ink2,
                      letterSpacing: 0.6,
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _jumpSection(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _segLabel(l10n.jumpHost),
              const Spacer(),
              Switch(
                value: _showJump,
                activeThumbColor: _isLight ? Colors.white : _Pal.dBg0,
                activeTrackColor: _acc,
                onChanged: (v) => setState(() => _showJump = v),
              ),
            ],
          ),
          if (_showJump) ...[
            Row(
              children: [
                Expanded(
                  child: _row(l10n.host, _jumpHost, hint: 'jump.example.com'),
                ),
                const SizedBox(width: 8),
                SizedBox(width: 100, child: _row(l10n.port, _jumpPort)),
              ],
            ),
            Row(
              children: [
                Expanded(child: _row(l10n.user, _jumpUser, hint: 'XIU')),
                const SizedBox(width: 8),
                Expanded(child: _row(l10n.keyPath, _jumpKey)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(
    String label,
    TextEditingController c, {
    String? hint,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              label.toUpperCase(),
              style: _mono(size: 10.5, color: _ink3, letterSpacing: 1.3),
            ),
          ),
          TextField(
            controller: c,
            maxLines: maxLines,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(hintText: hint, isDense: true),
            style: _mono(size: 12.5, color: _ink0),
          ),
        ],
      ),
    );
  }
}
