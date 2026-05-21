part of '../../main.dart';

// ============================================================================
// Title bar
// ============================================================================

class _TitleBar extends StatelessWidget {
  const _TitleBar({
    required this.title,
    required this.onPalette,
    required this.sidebarCollapsed,
    required this.onToggleSidebar,
  });
  final String title;
  final VoidCallback onPalette;
  final bool sidebarCollapsed;
  final VoidCallback onToggleSidebar;

  @override
  Widget build(BuildContext context) {
    return DragToMoveArea(
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: _bg1,
          border: Border(bottom: BorderSide(color: _line)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            IgnorePointer(
              child: Center(
                child: Text(
                  title,
                  style: _mono(size: 12, color: _ink2, letterSpacing: 0.3),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Positioned.fill(
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  _IconBtn(
                    icon: sidebarCollapsed
                        ? Icons.menu_open_outlined
                        : Icons.menu_outlined,
                    tooltip: sidebarCollapsed ? 'Show sidebar' : 'Hide sidebar',
                    onTap: onToggleSidebar,
                  ),
                  const Spacer(),
                  _IconBtn(
                    icon: Icons.search,
                    tooltip: 'Ctrl+K',
                    onTap: onPalette,
                  ),
                  const SizedBox(width: 8),
                  const _WindowsWindowControls(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowsWindowControls extends StatefulWidget {
  const _WindowsWindowControls();

  @override
  State<_WindowsWindowControls> createState() => _WindowsWindowControlsState();
}

class _WindowsWindowControlsState extends State<_WindowsWindowControls>
    with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _refresh();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _refresh() async {
    final isMaximized = await windowManager.isMaximized();
    if (!mounted) return;
    setState(() => _isMaximized = isMaximized);
  }

  @override
  void onWindowMaximize() => _refresh();

  @override
  void onWindowUnmaximize() => _refresh();

  @override
  void onWindowRestore() => _refresh();

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          WindowCaptionButton.minimize(
            brightness: Brightness.dark,
            onPressed: () => windowManager.minimize(),
          ),
          if (_isMaximized)
            WindowCaptionButton.unmaximize(
              brightness: Brightness.dark,
              onPressed: _toggleMaximize,
            )
          else
            WindowCaptionButton.maximize(
              brightness: Brightness.dark,
              onPressed: _toggleMaximize,
            ),
          WindowCaptionButton.close(
            brightness: Brightness.dark,
            onPressed: () => windowManager.close(),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatefulWidget {
  const _IconBtn({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.iconSize = 14,
    this.danger = false,
  });
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double iconSize;
  final bool danger;
  static const double size = 28;

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final color = !_hover ? _ink2 : (widget.danger ? _Pal.cRose : _ink0);
    final btn = MouseRegion(
      cursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: _IconBtn.size,
          height: _IconBtn.size,
          decoration: BoxDecoration(
            color: _hover ? _bg2 : null,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Icon(widget.icon, size: widget.iconSize, color: color),
        ),
      ),
    );
    if (widget.tooltip == null) return btn;
    return Tooltip(message: widget.tooltip!, child: btn);
  }
}

// ============================================================================
// Sidebar
// ============================================================================

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    super.key,
    required this.view,
    required this.sessionsCount,
    required this.collapsed,
    required this.onToggleCollapsed,
    required this.onView,
    required this.onPalette,
  });

  final _View view;
  final int sessionsCount;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;
  final ValueChanged<_View> onView;
  final VoidCallback onPalette;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = <_NavSpec>[
      _NavSpec(
        _View.sessions,
        Icons.terminal_outlined,
        l10n.sessions,
        sessionsCount > 0 ? '$sessionsCount' : null,
      ),
      _NavSpec(_View.profiles, Icons.public, l10n.profiles, null),
      _NavSpec(_View.files, Icons.folder_outlined, l10n.files, null),
      _NavSpec(_View.forwards, Icons.swap_horiz, l10n.forwards, null),
      _NavSpec(_View.keys, Icons.vpn_key_outlined, l10n.hostKeys, null),
      _NavSpec(_View.settings, Icons.tune, l10n.settings, null),
    ];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: collapsed ? 56 : 240,
      decoration: BoxDecoration(
        color: _bg1,
        border: Border(right: BorderSide(color: _line)),
      ),
      padding: EdgeInsets.fromLTRB(
        collapsed ? 8 : 12,
        14,
        collapsed ? 8 : 12,
        14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Brand(collapsed: collapsed, onToggleCollapsed: onToggleCollapsed),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final it in items)
                  _NavItem(
                    spec: it,
                    active: it.view == view,
                    collapsed: collapsed,
                    onTap: () => onView(it.view),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _PaletteTrigger(collapsed: collapsed, onTap: onPalette),
          const SizedBox(height: 10),
          _SyncRow(collapsed: collapsed),
        ],
      ),
    );
  }
}

class _NavSpec {
  const _NavSpec(this.view, this.icon, this.label, this.badge);
  final _View view;
  final IconData icon;
  final String label;
  final String? badge;
}

class _Brand extends StatelessWidget {
  const _Brand({required this.collapsed, required this.onToggleCollapsed});
  final bool collapsed;
  final VoidCallback onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 8, vertical: 6),
      child: Row(
        children: [
          const _BrandLogo(),
          if (!collapsed) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tindra',
                    style: _display(
                      size: 18,
                      weight: FontWeight.w600,
                      color: _ink0,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'SSH · SFTP · 26.5.1',
                    style: _mono(
                      size: 9.5,
                      color: _ink3,
                      letterSpacing: 1.2,
                      weight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            _IconBtn(
              icon: Icons.chevron_left,
              tooltip: AppLocalizations.of(context).collapseSidebar,
              iconSize: 16,
              onTap: onToggleCollapsed,
            ),
          ] else ...[
            const Spacer(),
            Tooltip(
              message: AppLocalizations.of(context).expandSidebar,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggleCollapsed,
                child: Icon(Icons.chevron_right, size: 16, color: _ink3),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: Image.asset(
        'assets/brand/tindra_icon.png',
        width: 28,
        height: 28,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.spec,
    required this.active,
    required this.collapsed,
    required this.onTap,
  });
  final _NavSpec spec;
  final bool active;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  Widget? _badgeChip(bool active) {
    final b = widget.spec.badge;
    if (b == null) return null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: active ? _accSoft : _bg3,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        b,
        style: _mono(
          size: 10,
          color: active ? _acc : _ink1,
          weight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final hovering = _hover && !active;
    final bg = active ? _accSoft : (hovering ? _bg2 : Colors.transparent);
    final color = active ? _ink0 : (hovering ? _ink1 : _ink2);
    final item = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 1),
        padding: EdgeInsets.symmetric(
          horizontal: widget.collapsed ? 0 : 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: active ? _acc : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: widget.collapsed
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            Icon(widget.spec.icon, size: 17, color: active ? _acc : color),
            if (!widget.collapsed) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.spec.label,
                  style: _sans(
                    size: 13.5,
                    color: color,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
              ?_badgeChip(active),
            ],
          ],
        ),
      ),
    );
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: widget.collapsed
          ? Tooltip(message: widget.spec.label, child: item)
          : item,
    );
  }
}

class _PaletteTrigger extends StatefulWidget {
  const _PaletteTrigger({required this.collapsed, required this.onTap});
  final bool collapsed;
  final VoidCallback onTap;
  @override
  State<_PaletteTrigger> createState() => _PaletteTriggerState();
}

class _PaletteTriggerState extends State<_PaletteTrigger> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (widget.collapsed) {
      return _IconBtn(
        icon: Icons.search,
        tooltip: l10n.searchRun,
        onTap: widget.onTap,
      );
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: _bg2,
            border: Border.all(color: _hover ? _line2 : _line),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 14, color: _hover ? _ink1 : _ink2),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.searchRun,
                  style: _sans(size: 12.5, color: _hover ? _ink1 : _ink2),
                ),
              ),
              const _Kbd('Ctrl+K'),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncRow extends StatelessWidget {
  const _SyncRow({required this.collapsed});
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 4),
      child: Row(
        mainAxisAlignment: collapsed
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: _Pal.cEmerald,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _Pal.cEmerald.withValues(alpha: 0.18),
                  blurRadius: 0,
                  spreadRadius: 3,
                ),
              ],
            ),
          ),
          if (!collapsed) ...[
            const SizedBox(width: 6),
            Text('${l10n.syncStatus} · ', style: _mono(size: 11, color: _ink3)),
            Text(l10n.pairedDevices(2), style: _mono(size: 11, color: _ink1)),
          ],
        ],
      ),
    );
  }
}

class _Kbd extends StatelessWidget {
  const _Kbd(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: _bg3,
        border: Border.all(color: _line2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: _mono(size: 11, color: _ink1)),
    );
  }
}

// ============================================================================
// Command palette
// ============================================================================

class _CommandPalette extends StatefulWidget {
  const _CommandPalette({
    required this.profiles,
    required this.tabs,
    required this.activeTabIndex,
    required this.onClose,
    required this.onOpenProfile,
    required this.onSwitchTab,
    required this.onView,
    required this.onLocalShell,
    required this.onSplitH,
    required this.onSplitV,
    required this.onNewProfile,
    required this.onQuickConnect,
    required this.onRestoreLayout,
    required this.onToggleSidebar,
    required this.onRenameTab,
    required this.onDuplicateTab,
    required this.onCloseOtherTabs,
    required this.onCloseTabsToRight,
    required this.onPrevPane,
    required this.onNextPane,
    required this.onToggleMaximizePane,
    required this.onMoveTabLeft,
    required this.onMoveTabRight,
    required this.onDetachTab,
    required this.onPinTab,
    required this.onClosePane,
  });
  final List<rust.Profile> profiles;
  final List<_TabGroup> tabs;
  final int activeTabIndex;
  final VoidCallback onClose;
  final ValueChanged<rust.Profile> onOpenProfile;
  final ValueChanged<int> onSwitchTab;
  final ValueChanged<_View> onView;
  final VoidCallback onLocalShell;
  final VoidCallback onSplitH;
  final VoidCallback onSplitV;
  final VoidCallback onNewProfile;
  final VoidCallback onQuickConnect;
  final VoidCallback onRestoreLayout;
  final VoidCallback onToggleSidebar;
  final VoidCallback onRenameTab;
  final VoidCallback onDuplicateTab;
  final VoidCallback onCloseOtherTabs;
  final VoidCallback onCloseTabsToRight;
  final VoidCallback onPrevPane;
  final VoidCallback onNextPane;
  final VoidCallback onToggleMaximizePane;
  final VoidCallback onMoveTabLeft;
  final VoidCallback onMoveTabRight;
  final VoidCallback onDetachTab;
  final VoidCallback onPinTab;
  final VoidCallback onClosePane;

  @override
  State<_CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<_CommandPalette> {
  final _q = TextEditingController();
  final _focus = FocusNode();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _q.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cmds = [
      _PaletteCmd(
        icon: Icons.bolt_outlined,
        label: l10n.quickConnect,
        hint: 'ssh',
        run: widget.onQuickConnect,
      ),
      _PaletteCmd(
        icon: Icons.restore_outlined,
        label: l10n.restorePreviousLayout,
        hint: null,
        run: widget.onRestoreLayout,
      ),
      _PaletteCmd(
        icon: Icons.add,
        label: l10n.newProfile,
        hint: 'Ctrl+N',
        run: widget.onNewProfile,
      ),
      _PaletteCmd(
        icon: Icons.terminal_outlined,
        label: l10n.openLocalShell,
        hint: 'Ctrl+L',
        run: widget.onLocalShell,
      ),
      _PaletteCmd(
        icon: Icons.splitscreen_outlined,
        label: l10n.splitRight,
        hint: 'Ctrl+Shift+H',
        run: widget.onSplitH,
      ),
      _PaletteCmd(
        icon: Icons.horizontal_split_outlined,
        label: l10n.splitDown,
        hint: 'Ctrl+Shift+E',
        run: widget.onSplitV,
      ),
      _PaletteCmd(
        icon: Icons.drive_file_rename_outline,
        label: l10n.renameTab,
        hint: null,
        run: widget.onRenameTab,
      ),
      _PaletteCmd(
        icon: Icons.content_copy_outlined,
        label: l10n.duplicateTab,
        hint: shortcutPrefs.value.bindingFor('duplicateTab'),
        run: widget.onDuplicateTab,
      ),
      _PaletteCmd(
        icon: Icons.filter_1_outlined,
        label: l10n.closeOtherTabs,
        hint: shortcutPrefs.value.bindingFor('closeOtherTabs'),
        run: widget.onCloseOtherTabs,
      ),
      _PaletteCmd(
        icon: Icons.last_page_outlined,
        label: l10n.closeTabsToRight,
        hint: shortcutPrefs.value.bindingFor('closeTabsToRight'),
        run: widget.onCloseTabsToRight,
      ),
      _PaletteCmd(
        icon: Icons.keyboard_arrow_left,
        label: l10n.previousPane,
        hint: shortcutPrefs.value.bindingFor('prevPane'),
        run: widget.onPrevPane,
      ),
      _PaletteCmd(
        icon: Icons.keyboard_arrow_right,
        label: l10n.nextPane,
        hint: shortcutPrefs.value.bindingFor('nextPane'),
        run: widget.onNextPane,
      ),
      _PaletteCmd(
        icon: Icons.open_in_full_outlined,
        label: 'Maximize or restore pane',
        hint: shortcutPrefs.value.bindingFor('maximizePane'),
        run: widget.onToggleMaximizePane,
      ),
      _PaletteCmd(
        icon: Icons.keyboard_double_arrow_left,
        label: 'Move tab left',
        hint: shortcutPrefs.value.bindingFor('moveTabLeft'),
        run: widget.onMoveTabLeft,
      ),
      _PaletteCmd(
        icon: Icons.keyboard_double_arrow_right,
        label: 'Move tab right',
        hint: shortcutPrefs.value.bindingFor('moveTabRight'),
        run: widget.onMoveTabRight,
      ),
      _PaletteCmd(
        icon: Icons.open_in_new_outlined,
        label: l10n.detachTab,
        hint: shortcutPrefs.value.bindingFor('detachTab'),
        run: widget.onDetachTab,
      ),
      _PaletteCmd(
        icon: Icons.push_pin_outlined,
        label: l10n.pinOrUnpinTab,
        hint: shortcutPrefs.value.bindingFor('pinTab'),
        run: widget.onPinTab,
      ),
      _PaletteCmd(
        icon: Icons.close_fullscreen_outlined,
        label: l10n.closeActivePane,
        hint: shortcutPrefs.value.bindingFor('closePane'),
        run: widget.onClosePane,
      ),
      _PaletteCmd(
        icon: Icons.menu_outlined,
        label: l10n.toggleSidebar,
        hint: null,
        run: widget.onToggleSidebar,
      ),
      _PaletteCmd(
        icon: Icons.folder_outlined,
        label: l10n.toggleSftpBrowser,
        hint: 'Ctrl+B',
        run: () => widget.onView(_View.files),
      ),
      _PaletteCmd(
        icon: Icons.swap_horiz,
        label: l10n.forwards,
        hint: null,
        run: () => widget.onView(_View.forwards),
      ),
      _PaletteCmd(
        icon: Icons.vpn_key_outlined,
        label: l10n.hostKeys,
        hint: null,
        run: () => widget.onView(_View.keys),
      ),
      _PaletteCmd(
        icon: Icons.tune,
        label: l10n.settings,
        hint: 'Ctrl+,',
        run: () => widget.onView(_View.settings),
      ),
    ];
    final q = _q.text.toLowerCase();
    final profMatches = widget.profiles
        .where(
          (p) =>
              q.isEmpty ||
              p.name.toLowerCase().contains(q) ||
              p.host.toLowerCase().contains(q),
        )
        .toList();
    final tabMatches = <(int, _TabGroup)>[
      for (var i = 0; i < widget.tabs.length; i++)
        if (q.isEmpty ||
            widget.tabs[i].displayName.toLowerCase().contains(q) ||
            widget.tabs[i].profileName.toLowerCase().contains(q))
          (i, widget.tabs[i]),
    ];
    final cmdMatches = cmds
        .where((c) => q.isEmpty || c.label.toLowerCase().contains(q))
        .toList();
    final profileCount = profMatches.take(5).length;
    final tabCount = tabMatches.take(8).length;
    final totalMatches = profileCount + tabCount + cmdMatches.length;
    if (_selectedIndex >= totalMatches) {
      _selectedIndex = totalMatches == 0 ? 0 : totalMatches - 1;
    }

    void moveSelection(int delta) {
      if (totalMatches == 0) return;
      setState(() {
        _selectedIndex = (_selectedIndex + delta + totalMatches) % totalMatches;
      });
    }

    void activateSelection() {
      if (totalMatches == 0) return;
      if (_selectedIndex < profileCount) {
        widget.onOpenProfile(profMatches[_selectedIndex]);
        return;
      }
      final tabOffset = _selectedIndex - profileCount;
      if (tabOffset < tabCount) {
        widget.onSwitchTab(tabMatches[tabOffset].$1);
        return;
      }
      final cmdOffset = _selectedIndex - profileCount - tabCount;
      widget.onClose();
      cmdMatches[cmdOffset].run();
    }

    return Material(
      color: Colors.transparent,
      child: KeyboardListener(
        focusNode: FocusNode(skipTraversal: true),
        autofocus: true,
        onKeyEvent: (event) {
          if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            moveSelection(1);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            moveSelection(-1);
          } else if (event.logicalKey == LogicalKeyboardKey.enter) {
            activateSelection();
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
            widget.onClose();
          }
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: widget.onClose,
                child: Container(color: const Color(0x95080604)),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).size.height * 0.10,
                ),
                child: GestureDetector(
                  onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                  child: Container(
                    width: 640,
                    decoration: BoxDecoration(
                      color: _bg1,
                      border: Border.all(color: _line2),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.55),
                          blurRadius: 40,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: _line)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search, size: 16, color: _ink2),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  focusNode: _focus,
                                  controller: _q,
                                  onChanged: (_) {
                                    setState(() => _selectedIndex = 0);
                                  },
                                  onSubmitted: (_) => activateSelection(),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    filled: false,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                    hintText: l10n.runCommandOrJump,
                                    hintStyle: _display(
                                      size: 22,
                                      color: _ink3,
                                      weight: FontWeight.w500,
                                    ),
                                  ),
                                  style: _display(
                                    size: 22,
                                    color: _ink0,
                                    weight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              _Kbd('esc'),
                            ],
                          ),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 360),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (profMatches.isNotEmpty)
                                  _section(l10n.paletteProfilesSection),
                                for (final entry in profMatches.take(5).indexed)
                                  _palItem(
                                    leading: _BarMark(
                                      accent: _accentForProfile(entry.$2),
                                    ),
                                    title: entry.$2.name,
                                    sub:
                                        '${entry.$2.username}@${entry.$2.host}',
                                    hint: l10n.open,
                                    selected: _selectedIndex == entry.$1,
                                    onTap: () => widget.onOpenProfile(entry.$2),
                                  ),
                                if (tabMatches.isNotEmpty)
                                  _section(l10n.openTabs.toUpperCase()),
                                for (final entry in tabMatches.take(8).indexed)
                                  _palItem(
                                    leading: Icon(
                                      entry.$2.$1 == widget.activeTabIndex
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_unchecked,
                                      size: 14,
                                      color:
                                          entry.$2.$1 == widget.activeTabIndex
                                          ? _acc
                                          : _ink2,
                                    ),
                                    title: entry.$2.$2.displayName,
                                    sub: entry.$2.$2.sessions.length > 1
                                        ? '${entry.$2.$2.sessions.length} panes'
                                        : entry.$2.$2.active.profileName,
                                    hint: 'Switch',
                                    selected:
                                        _selectedIndex ==
                                        profileCount + entry.$1,
                                    onTap: () =>
                                        widget.onSwitchTab(entry.$2.$1),
                                  ),
                                if (cmdMatches.isNotEmpty)
                                  _section(l10n.paletteCommandsSection),
                                for (final entry in cmdMatches.indexed)
                                  _palItem(
                                    leading: Icon(
                                      entry.$2.icon,
                                      size: 14,
                                      color: _ink2,
                                    ),
                                    title: entry.$2.label,
                                    sub: null,
                                    hint: entry.$2.hint,
                                    selected:
                                        _selectedIndex ==
                                        profileCount + tabCount + entry.$1,
                                    onTap: () {
                                      widget.onClose();
                                      entry.$2.run();
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: _line)),
                          ),
                          child: Row(
                            children: [
                              const _Kbd('Up/Down'),
                              const SizedBox(width: 6),
                              Text(
                                l10n.navigate,
                                style: _mono(size: 10.5, color: _ink3),
                              ),
                              const SizedBox(width: 14),
                              const _Kbd('Enter'),
                              const SizedBox(width: 6),
                              Text(
                                l10n.select,
                                style: _mono(size: 10.5, color: _ink3),
                              ),
                              const Spacer(),
                              const _Kbd('Esc'),
                              const SizedBox(width: 6),
                              Text(
                                l10n.close,
                                style: _mono(size: 10.5, color: _ink3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
    child: Text(
      label,
      style: _mono(
        size: 10,
        color: _ink3,
        letterSpacing: 1.5,
        weight: FontWeight.w500,
      ),
    ),
  );

  Widget _palItem({
    required Widget leading,
    required String title,
    required String? sub,
    required String? hint,
    bool selected = false,
    required VoidCallback onTap,
  }) {
    return _PalItem(
      leading: leading,
      title: title,
      sub: sub,
      hint: hint,
      selected: selected,
      onTap: onTap,
    );
  }
}

class _PaletteCmd {
  const _PaletteCmd({
    required this.icon,
    required this.label,
    required this.hint,
    required this.run,
  });
  final IconData icon;
  final String label;
  final String? hint;
  final VoidCallback run;
}

class _PalItem extends StatefulWidget {
  const _PalItem({
    required this.leading,
    required this.title,
    required this.sub,
    required this.hint,
    required this.selected,
    required this.onTap,
  });
  final Widget leading;
  final String title;
  final String? sub;
  final String? hint;
  final bool selected;
  final VoidCallback onTap;
  @override
  State<_PalItem> createState() => _PalItemState();
}

class _PalItemState extends State<_PalItem> {
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    _ensureVisibleIfSelected();
  }

  @override
  void didUpdateWidget(covariant _PalItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.selected && widget.selected) {
      _ensureVisibleIfSelected();
    }
  }

  void _ensureVisibleIfSelected() {
    if (!widget.selected) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.selected) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
          decoration: BoxDecoration(
            color: widget.selected ? _accSoft : (_hover ? _bg2 : null),
            border: Border(
              left: BorderSide(
                color: widget.selected || _hover ? _acc : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            children: [
              SizedBox(width: 16, child: Center(child: widget.leading)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: _sans(
                        size: 13.5,
                        color: _ink0,
                        weight: FontWeight.w500,
                      ),
                    ),
                    if (widget.sub != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          widget.sub!,
                          style: _mono(size: 11.5, color: _ink3),
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.hint != null)
                Text(widget.hint!, style: _mono(size: 11, color: _ink3)),
            ],
          ),
        ),
      ),
    );
  }
}
