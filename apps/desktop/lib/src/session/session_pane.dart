part of '../../main.dart';

// ============================================================================
// Session pane: tab strip + terminal + footer
// ============================================================================

class _SessionPane extends StatelessWidget {
  const _SessionPane({
    required this.tabs,
    required this.activeIdx,
    required this.termFocus,
    required this.onTermKey,
    required this.onCloseTab,
    required this.onSwitchTab,
    required this.onMoveTab,
    required this.onDuplicateTab,
    required this.onCloseOtherTabs,
    required this.onCloseTabsToRight,
    required this.onRenameTab,
    required this.onTogglePinTab,
    required this.onSetTabColor,
    required this.onSplitDrop,
    required this.onDetachDrop,
    required this.onDetachActive,
    required this.onResizeSplit,
    required this.onActivateSplit,
    required this.onFocusPrevSplit,
    required this.onFocusNextSplit,
    required this.onToggleMaximizeSplit,
    required this.onAddTab,
    required this.onSplitH,
    required this.onSplitV,
    required this.onCopy,
    required this.onPaste,
    required this.onOpenUrl,
    required this.onWriteBytes,
    required this.onScrollback,
    required this.onReconnect,
    required this.onDisconnect,
    required this.scheduleResize,
    required this.selectedProfile,
    required this.profileById,
  });

  final List<_TabGroup> tabs;
  final int activeIdx;
  final FocusNode termFocus;
  final KeyEventResult Function(FocusNode, KeyEvent) onTermKey;
  final Future<void> Function(int) onCloseTab;
  final void Function(int) onSwitchTab;
  final void Function(int, int) onMoveTab;
  final Future<void> Function(int) onDuplicateTab;
  final Future<void> Function(int) onCloseOtherTabs;
  final Future<void> Function(int) onCloseTabsToRight;
  final Future<void> Function(int) onRenameTab;
  final void Function(int) onTogglePinTab;
  final void Function(int, Color?) onSetTabColor;
  final void Function(int, Axis) onSplitDrop;
  final Future<void> Function(int) onDetachDrop;
  final Future<void> Function() onDetachActive;
  final void Function(_TabGroup, int, double) onResizeSplit;
  final void Function(_TabGroup, int) onActivateSplit;
  final VoidCallback onFocusPrevSplit;
  final VoidCallback onFocusNextSplit;
  final VoidCallback onToggleMaximizeSplit;
  final Future<void> Function() onAddTab;
  final Future<void> Function() onSplitH;
  final Future<void> Function() onSplitV;
  final Future<void> Function() onCopy;
  final Future<void> Function() onPaste;
  final Future<void> Function(String) onOpenUrl;
  final Future<void> Function(List<int>) onWriteBytes;
  final Future<void> Function(_SessionTab, int) onScrollback;
  final Future<void> Function() onReconnect;
  final Future<void> Function() onDisconnect;
  final void Function(_SessionTab, int, int) scheduleResize;
  final rust.Profile? selectedProfile;
  final rust.Profile? Function(String) profileById;

  @override
  Widget build(BuildContext context) {
    final group = (activeIdx >= 0 && activeIdx < tabs.length)
        ? tabs[activeIdx]
        : null;
    final tab = group?.active;
    final profile = tab == null
        ? null
        : (tab.profileId == _localShellProfileId
              ? null
              : profileById(tab.profileId));
    return Column(
      children: [
        _TabStrip(
          tabs: tabs,
          activeIdx: activeIdx,
          onSwitch: onSwitchTab,
          onClose: onCloseTab,
          onMove: onMoveTab,
          onDuplicate: onDuplicateTab,
          onCloseOthers: onCloseOtherTabs,
          onCloseRight: onCloseTabsToRight,
          onRename: onRenameTab,
          onTogglePin: onTogglePinTab,
          onSetColor: onSetTabColor,
          onSplitDrop: onSplitDrop,
          onDetachDrop: onDetachDrop,
          onDetachActive: onDetachActive,
          onAdd: onAddTab,
          onSplitH: onSplitH,
          onSplitV: onSplitV,
          selectedProfile: selectedProfile,
          profileById: profileById,
        ),
        Expanded(
          child: Container(
            color: _tBg,
            child: Column(
              children: [
                if (tab != null)
                  _TermMeta(
                    tab: tab,
                    profile: profile,
                    splitCount: group?.sessions.length ?? 0,
                    maximized: group?.maximizedIdx != null,
                    onCopy: onCopy,
                    onPaste: onPaste,
                    onFocusPrevSplit: onFocusPrevSplit,
                    onFocusNextSplit: onFocusNextSplit,
                    onToggleMaximizeSplit: onToggleMaximizeSplit,
                    onReconnect: onReconnect,
                    onDisconnect: onDisconnect,
                  ),
                Expanded(
                  child: Focus(
                    key: const ValueKey('terminal-focus'),
                    focusNode: termFocus,
                    autofocus: false,
                    onKeyEvent: onTermKey,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: termFocus.requestFocus,
                      child: _DockDropSurface(
                        onDrop: onSplitDrop,
                        child: _splitView(group),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _SessionFooter(tab: tab, profile: profile),
      ],
    );
  }

  Widget _splitView(_TabGroup? group) {
    if (group == null || group.sessions.isEmpty) {
      return const SizedBox.shrink();
    }
    if (group.sessions.length == 1) {
      return _termBody(group.sessions.first, true);
    }
    group.normalizeWeights();
    if (group.maximizedIdx != null) {
      final idx = group.maximizedIdx!.clamp(0, group.sessions.length - 1);
      group.activeIdx = idx;
      return _termBody(group.sessions[idx], true);
    }
    final children = <Widget>[];
    for (var i = 0; i < group.sessions.length; i++) {
      final s = group.sessions[i];
      final isActive = i == group.activeIdx;
      children.add(
        Expanded(
          flex: (group.splitWeights[i] * 1000).round().clamp(1, 10000),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isActive ? _acc : _line,
                width: isActive ? 1.4 : 1,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            margin: const EdgeInsets.all(4),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onActivateSplit(group, i),
              child: _termBody(s, isActive),
            ),
          ),
        ),
      );
      if (i < group.sessions.length - 1) {
        children.add(
          _SplitResizeHandle(
            axis: group.splitAxis,
            onDrag: (delta) => onResizeSplit(
              group,
              i,
              group.splitAxis == Axis.horizontal ? delta.dx : delta.dy,
            ),
          ),
        );
      }
    }
    return group.splitAxis == Axis.horizontal
        ? Row(children: children)
        : Column(children: children);
  }

  Widget _termBody(_SessionTab tab, bool isFocused) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final probe = TextPainter(
          text: TextSpan(text: 'M', style: _termStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        final charWidth = probe.width;
        final lineHeight = probe.height;
        probe.dispose();

        const padding = 14.0;
        final availW = constraints.maxWidth - padding * 2;
        final availH = constraints.maxHeight - padding * 2;
        final fitCols = (availW / charWidth).floor().clamp(20, 400);
        final fitRows = (availH / lineHeight).floor().clamp(8, 200);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          scheduleResize(tab, fitCols, fitRows);
        });

        return Padding(
          padding: const EdgeInsets.all(padding),
          child: _CellGrid(
            tab: tab,
            isFocused: isFocused && termFocus.hasFocus,
            charWidth: charWidth,
            lineHeight: lineHeight,
            onReconnect: onReconnect,
            onMouseReport: onWriteBytes,
            onScrollback: onScrollback,
            onCopy: onCopy,
            onPaste: onPaste,
            onOpenUrl: onOpenUrl,
          ),
        );
      },
    );
  }
}

class _DetachedSessionWindow extends StatelessWidget {
  const _DetachedSessionWindow({
    super.key,
    required this.item,
    required this.index,
    required this.termFocus,
    required this.onTermKey,
    required this.onMove,
    required this.onReattach,
    required this.onClose,
    required this.onAddTab,
    required this.onSplitH,
    required this.onSplitV,
    required this.onCopy,
    required this.onPaste,
    required this.onWriteBytes,
    required this.onScrollback,
    required this.onReconnect,
    required this.onDisconnect,
    required this.scheduleResize,
    required this.selectedProfile,
    required this.profileById,
  });

  final _DetachedTabGroup item;
  final int index;
  final FocusNode termFocus;
  final KeyEventResult Function(FocusNode, KeyEvent) onTermKey;
  final void Function(int, Offset) onMove;
  final void Function(int) onReattach;
  final Future<void> Function(int) onClose;
  final Future<void> Function() onAddTab;
  final Future<void> Function() onSplitH;
  final Future<void> Function() onSplitV;
  final Future<void> Function() onCopy;
  final Future<void> Function() onPaste;
  final Future<void> Function(List<int>) onWriteBytes;
  final Future<void> Function(_SessionTab, int) onScrollback;
  final Future<void> Function() onReconnect;
  final Future<void> Function() onDisconnect;
  final void Function(_SessionTab, int, int) scheduleResize;
  final rust.Profile? selectedProfile;
  final rust.Profile? Function(String) profileById;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: item.offset.dx,
      top: item.offset.dy,
      width: item.size.width,
      height: item.size.height,
      child: Material(
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _bg0,
            border: Border.all(color: _line),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.34),
                blurRadius: 28,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Column(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (details) => onMove(index, details.delta),
                  child: Container(
                    height: 34,
                    color: _bg1,
                    padding: const EdgeInsets.only(left: 12, right: 4),
                    child: Row(
                      children: [
                        Icon(Icons.open_in_new, size: 14, color: _ink3),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.group.profileName,
                            overflow: TextOverflow.ellipsis,
                            style: _mono(size: 12, color: _ink1),
                          ),
                        ),
                        _IconBtn(
                          icon: Icons.call_merge_outlined,
                          tooltip: 'Attach to main tabs',
                          iconSize: 15,
                          onTap: () => onReattach(index),
                        ),
                        _IconBtn(
                          icon: Icons.close,
                          tooltip: 'Close',
                          iconSize: 15,
                          onTap: () => onClose(index),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: _SessionPane(
                    tabs: [item.group],
                    activeIdx: 0,
                    termFocus: termFocus,
                    onTermKey: onTermKey,
                    onCloseTab: (_) => onClose(index),
                    onSwitchTab: (_) {},
                    onMoveTab: (_, _) {},
                    onDuplicateTab: (_) async {},
                    onCloseOtherTabs: (_) async {},
                    onCloseTabsToRight: (_) async {},
                    onRenameTab: (_) async {},
                    onTogglePinTab: (_) {},
                    onSetTabColor: (_, _) {},
                    onSplitDrop: (_, _) {},
                    onDetachDrop: (_) async {},
                    onDetachActive: () async {},
                    onResizeSplit: (_, _, _) {},
                    onActivateSplit: (group, pane) {
                      group.activeIdx = pane;
                    },
                    onFocusPrevSplit: () {},
                    onFocusNextSplit: () {},
                    onToggleMaximizeSplit: () {},
                    onAddTab: onAddTab,
                    onSplitH: onSplitH,
                    onSplitV: onSplitV,
                    onCopy: onCopy,
                    onPaste: onPaste,
                    onOpenUrl: (_) async {},
                    onWriteBytes: onWriteBytes,
                    onScrollback: onScrollback,
                    onReconnect: onReconnect,
                    onDisconnect: onDisconnect,
                    scheduleResize: scheduleResize,
                    selectedProfile: selectedProfile,
                    profileById: profileById,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DockDropSurface extends StatefulWidget {
  const _DockDropSurface({required this.child, required this.onDrop});

  final Widget child;
  final void Function(int, Axis) onDrop;

  @override
  State<_DockDropSurface> createState() => _DockDropSurfaceState();
}

class _DockDropSurfaceState extends State<_DockDropSurface> {
  Axis _axisForOffset(BuildContext context, Offset global) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return Axis.horizontal;
    final local = box.globalToLocal(global);
    final w = box.size.width;
    final h = box.size.height;
    final dx = (local.dx - w / 2).abs() / w;
    final dy = (local.dy - h / 2).abs() / h;
    return dx >= dy ? Axis.horizontal : Axis.vertical;
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<_TabDragPayload>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        widget.onDrop(
          details.data.index,
          _axisForOffset(context, details.offset),
        );
      },
      builder: (context, candidate, rejected) {
        final active = candidate.isNotEmpty;
        return Stack(
          children: [
            Positioned.fill(child: widget.child),
            if (active)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    margin: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      border: Border.all(color: _acc, width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                      color: _accSoft.withValues(alpha: 0.22),
                    ),
                    child: Center(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: const [
                          _DockHint(
                            icon: Icons.keyboard_arrow_left,
                            label: 'Left',
                          ),
                          _DockHint(
                            icon: Icons.keyboard_arrow_up,
                            label: 'Top',
                          ),
                          _DockHint(
                            icon: Icons.keyboard_arrow_down,
                            label: 'Bottom',
                          ),
                          _DockHint(
                            icon: Icons.keyboard_arrow_right,
                            label: 'Right',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DockHint extends StatelessWidget {
  const _DockHint({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _bg1,
        border: Border.all(color: _line2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _acc),
          const SizedBox(width: 4),
          Text(label, style: _mono(size: 11, color: _ink1)),
        ],
      ),
    );
  }
}

class _SplitResizeHandle extends StatelessWidget {
  const _SplitResizeHandle({required this.axis, required this.onDrag});

  final Axis axis;
  final ValueChanged<Offset> onDrag;

  @override
  Widget build(BuildContext context) {
    final horizontal = axis == Axis.horizontal;
    return MouseRegion(
      cursor: horizontal
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.resizeRow,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) => onDrag(details.delta),
        child: Container(
          width: horizontal ? 8 : double.infinity,
          height: horizontal ? double.infinity : 8,
          alignment: Alignment.center,
          child: Container(
            width: horizontal ? 1 : 48,
            height: horizontal ? 48 : 1,
            color: _line2,
          ),
        ),
      ),
    );
  }
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({
    required this.tabs,
    required this.activeIdx,
    required this.onSwitch,
    required this.onClose,
    required this.onMove,
    required this.onDuplicate,
    required this.onCloseOthers,
    required this.onCloseRight,
    required this.onRename,
    required this.onTogglePin,
    required this.onSetColor,
    required this.onSplitDrop,
    required this.onDetachDrop,
    required this.onDetachActive,
    required this.onAdd,
    required this.onSplitH,
    required this.onSplitV,
    required this.selectedProfile,
    required this.profileById,
  });

  final List<_TabGroup> tabs;
  final int activeIdx;
  final void Function(int) onSwitch;
  final Future<void> Function(int) onClose;
  final void Function(int, int) onMove;
  final Future<void> Function(int) onDuplicate;
  final Future<void> Function(int) onCloseOthers;
  final Future<void> Function(int) onCloseRight;
  final Future<void> Function(int) onRename;
  final void Function(int) onTogglePin;
  final void Function(int, Color?) onSetColor;
  final void Function(int, Axis) onSplitDrop;
  final Future<void> Function(int) onDetachDrop;
  final Future<void> Function() onDetachActive;
  final Future<void> Function() onAdd;
  final Future<void> Function() onSplitH;
  final Future<void> Function() onSplitV;
  final rust.Profile? selectedProfile;
  final rust.Profile? Function(String) profileById;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: _bg1,
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length + 1,
              itemBuilder: (context, i) {
                if (i == tabs.length) {
                  return _addTabButton(context);
                }
                return _DraggableTabPill(
                  group: tabs[i],
                  index: i,
                  active: i == activeIdx,
                  accent: _accentForGroup(tabs[i]),
                  onTap: () => onSwitch(i),
                  onClose: () => onClose(i),
                  onMove: onMove,
                  onDuplicate: onDuplicate,
                  onCloseOthers: onCloseOthers,
                  onCloseRight: onCloseRight,
                  onRename: onRename,
                  onTogglePin: onTogglePin,
                  onSetColor: onSetColor,
                  onDetach: onDetachDrop,
                );
              },
            ),
          ),
          _TabDropAction(
            tooltip: l10n.detachTab,
            onDrop: onDetachDrop,
            child: _IconBtn(
              icon: Icons.open_in_new_outlined,
              tooltip: l10n.detachTab,
              onTap: () => onDetachActive(),
            ),
          ),
          _TabDropAction(
            tooltip: l10n.splitRight,
            onDrop: (idx) => onSplitDrop(idx, Axis.horizontal),
            child: _IconBtn(
              icon: Icons.splitscreen_outlined,
              tooltip: l10n.splitRight,
              onTap: () => onSplitH(),
            ),
          ),
          _TabDropAction(
            tooltip: l10n.splitDown,
            onDrop: (idx) => onSplitDrop(idx, Axis.vertical),
            child: _IconBtn(
              icon: Icons.horizontal_split_outlined,
              tooltip: l10n.splitDown,
              onTap: () => onSplitV(),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Color _accentForGroup(_TabGroup g) {
    final id = g.sessions.first.profileId;
    if (id == _localShellProfileId) return _Pal.cSlate;
    final p = profileById(id);
    if (p == null) return _acc;
    return _accentForProfile(p);
  }

  Widget _addTabButton(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Tooltip(
        message: l10n.pickProfileForNewTab,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onAdd,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Icon(Icons.add, size: 14, color: _ink3),
          ),
        ),
      ),
    );
  }
}

class _TabDropAction extends StatelessWidget {
  const _TabDropAction({
    required this.tooltip,
    required this.onDrop,
    required this.child,
  });

  final String tooltip;
  final FutureOr<void> Function(int) onDrop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DragTarget<_TabDragPayload>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => onDrop(details.data.index),
      builder: (context, candidate, rejected) {
        final active = candidate.isNotEmpty;
        return Tooltip(
          message: tooltip,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: active ? _accSoft : Colors.transparent,
              border: active ? Border.all(color: _acc) : null,
              borderRadius: BorderRadius.circular(6),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

class _DraggableTabPill extends StatefulWidget {
  const _DraggableTabPill({
    required this.group,
    required this.index,
    required this.active,
    required this.accent,
    required this.onTap,
    required this.onClose,
    required this.onMove,
    required this.onDuplicate,
    required this.onCloseOthers,
    required this.onCloseRight,
    required this.onRename,
    required this.onTogglePin,
    required this.onSetColor,
    required this.onDetach,
  });

  final _TabGroup group;
  final int index;
  final bool active;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final void Function(int, int) onMove;
  final Future<void> Function(int) onDuplicate;
  final Future<void> Function(int) onCloseOthers;
  final Future<void> Function(int) onCloseRight;
  final Future<void> Function(int) onRename;
  final void Function(int) onTogglePin;
  final void Function(int, Color?) onSetColor;
  final Future<void> Function(int) onDetach;

  @override
  State<_DraggableTabPill> createState() => _DraggableTabPillState();
}

class _DraggableTabPillState extends State<_DraggableTabPill> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tab = widget.group.active;
    final color = widget.active ? _ink0 : (_hover ? _ink1 : _ink2);
    final label = widget.group.sessions.length > 1
        ? '${widget.group.displayName} x${widget.group.sessions.length}'
        : widget.group.displayName;
    final accent = widget.group.tabColor ?? widget.accent;
    final pill = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onDoubleTap: () => widget.onRename(widget.index),
        onSecondaryTapDown: (details) =>
            _showTabMenu(context, details.globalPosition),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: widget.active ? _bg0 : (_hover ? _bg2 : Colors.transparent),
            border: widget.active
                ? Border(
                    left: BorderSide(color: _line),
                    right: BorderSide(color: _line),
                  )
                : null,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(6),
            ),
          ),
          child: Stack(
            children: [
              if (widget.active)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: Container(height: 2, color: accent),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(12, widget.active ? 6 : 8, 10, 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      constraints: const BoxConstraints.tightFor(
                        width: 6,
                        height: 6,
                      ),
                      decoration: BoxDecoration(
                        color: tab.hasBellActivity
                            ? _Pal.cRose
                            : tab.hasUnreadActivity
                            ? _Pal.cAmber
                            : _stateColor(tab.state, accent),
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (tab.hasBellActivity) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.notifications_active_outlined,
                        size: 12,
                        color: _Pal.cRose,
                      ),
                    ],
                    if (widget.group.pinned) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.push_pin, size: 11, color: _ink3),
                    ],
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: _mono(
                        size: 12.5,
                        color: color,
                        weight: widget.active
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      key: ValueKey('tab-close-${widget.index}'),
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onClose,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(Icons.close, size: 11, color: _ink3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return DragTarget<_TabDragPayload>(
      onWillAcceptWithDetails: (details) => details.data.index != widget.index,
      onAcceptWithDetails: (details) {
        widget.onMove(details.data.index, widget.index);
      },
      builder: (context, candidate, rejected) {
        final highlighted = candidate.isNotEmpty;
        return Container(
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            border: highlighted
                ? Border(left: BorderSide(color: widget.accent, width: 2))
                : null,
          ),
          child: Draggable<_TabDragPayload>(
            data: _TabDragPayload(widget.index),
            feedback: Material(
              color: Colors.transparent,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _bg2,
                  border: Border.all(color: accent),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Opacity(opacity: 0.92, child: pill),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.35, child: pill),
            onDragEnd: (details) {
              if (!details.wasAccepted && details.offset.dy > 90) {
                widget.onDetach(widget.index);
              }
            },
            child: pill,
          ),
        );
      },
    );
  }

  Future<void> _showTabMenu(BuildContext context, Offset position) async {
    final l10n = AppLocalizations.of(context);
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(value: 'rename', child: Text(l10n.renameTab)),
        PopupMenuItem(value: 'duplicate', child: Text(l10n.duplicateTab)),
        PopupMenuItem(
          value: 'pin',
          child: Text(widget.group.pinned ? l10n.unpinTab : l10n.pinTab),
        ),
        PopupMenuItem(value: 'close-others', child: Text(l10n.closeOtherTabs)),
        PopupMenuItem(value: 'close-right', child: Text(l10n.closeTabsToRight)),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'color:none', child: Text(l10n.defaultColor)),
        PopupMenuItem(value: 'color:green', child: Text(l10n.green)),
        PopupMenuItem(value: 'color:amber', child: Text(l10n.paletteAmber)),
        PopupMenuItem(value: 'color:rose', child: Text(l10n.paletteRose)),
        PopupMenuItem(value: 'color:blue', child: Text(l10n.blue)),
      ],
    );
    switch (selected) {
      case 'rename':
        await widget.onRename(widget.index);
        return;
      case 'duplicate':
        await widget.onDuplicate(widget.index);
        return;
      case 'pin':
        widget.onTogglePin(widget.index);
        return;
      case 'close-others':
        await widget.onCloseOthers(widget.index);
        return;
      case 'close-right':
        await widget.onCloseRight(widget.index);
        return;
      case 'color:none':
        widget.onSetColor(widget.index, null);
        return;
      case 'color:green':
        widget.onSetColor(widget.index, _Pal.cEmerald);
        return;
      case 'color:amber':
        widget.onSetColor(widget.index, _Pal.cAmber);
        return;
      case 'color:rose':
        widget.onSetColor(widget.index, _Pal.cRose);
        return;
      case 'color:blue':
        widget.onSetColor(widget.index, _Pal.cSky);
        return;
    }
  }

  Color _stateColor(_ConnState state, Color accent) {
    switch (state) {
      case _ConnState.connecting:
        return _Pal.cAmber;
      case _ConnState.connected:
        return _Pal.cEmerald;
      case _ConnState.disconnected:
        return _Pal.cRose;
    }
  }
}

class _TabPill extends StatefulWidget {
  const _TabPill({
    required this.group,
    required this.index,
    required this.active,
    required this.accent,
    required this.onTap,
    required this.onClose,
    required this.onMove,
  });

  final _TabGroup group;
  final int index;
  final bool active;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final void Function(int, int) onMove;

  @override
  State<_TabPill> createState() => _TabPillState();
}

class _TabPillState extends State<_TabPill> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.group.active;
    final color = widget.active ? _ink0 : (_hover ? _ink1 : _ink2);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        margin: const EdgeInsets.only(right: 2, top: 0, bottom: 0),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            decoration: BoxDecoration(
              color: widget.active
                  ? _bg0
                  : (_hover ? _bg2 : Colors.transparent),
              border: widget.active
                  ? Border(
                      top: BorderSide(color: widget.accent, width: 2),
                      left: BorderSide(color: _line),
                      right: BorderSide(color: _line),
                    )
                  : null,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
            padding: EdgeInsets.fromLTRB(12, widget.active ? 6 : 8, 10, 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 6×6 status dot ??integration tests count these as "tabs".
                Container(
                  width: 6,
                  height: 6,
                  constraints: const BoxConstraints.tightFor(
                    width: 6,
                    height: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _stateColor(s.state, widget.accent),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.group.sessions.length > 1
                      ? '${widget.group.profileName} ·${widget.group.sessions.length}'
                      : widget.group.profileName,
                  style: _mono(
                    size: 12.5,
                    color: color,
                    weight: widget.active ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  key: ValueKey('tab-close-${widget.index}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onClose,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(Icons.close, size: 11, color: _ink3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _stateColor(_ConnState s, Color accent) {
    switch (s) {
      case _ConnState.connecting:
        return _Pal.cAmber;
      case _ConnState.connected:
        // The integration tests assert against the design's emerald shade.
        return _Pal.cEmerald;
      case _ConnState.disconnected:
        return _Pal.cRose;
    }
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.state});
  final _ConnState state;

  @override
  Widget build(BuildContext context) {
    final color = _connStateColor(state);
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (state == _ConnState.connecting)
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.4, color: color),
          )
        else
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: state == _ConnState.connected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.20),
                        blurRadius: 0,
                        spreadRadius: 3,
                      ),
                    ]
                  : null,
            ),
          ),
        const SizedBox(width: 7),
        Text(
          _connStateLabel(state, l10n),
          style: _mono(size: 11.5, color: color),
        ),
      ],
    );
  }
}

Color _connStateColor(_ConnState state) {
  switch (state) {
    case _ConnState.connecting:
      return _Pal.cAmber;
    case _ConnState.connected:
      return _Pal.cEmerald;
    case _ConnState.disconnected:
      return _Pal.cRose;
  }
}

String _connStateLabel(_ConnState state, AppLocalizations l10n) {
  switch (state) {
    case _ConnState.connecting:
      return l10n.connecting;
    case _ConnState.connected:
      return l10n.connected;
    case _ConnState.disconnected:
      return l10n.disconnected;
  }
}

SessionVisualState _toVisualState(_ConnState state) {
  switch (state) {
    case _ConnState.connecting:
      return SessionVisualState.connecting;
    case _ConnState.connected:
      return SessionVisualState.connected;
    case _ConnState.disconnected:
      return SessionVisualState.disconnected;
  }
}

class _TermMeta extends StatelessWidget {
  const _TermMeta({
    required this.tab,
    required this.profile,
    required this.splitCount,
    required this.maximized,
    required this.onCopy,
    required this.onPaste,
    required this.onFocusPrevSplit,
    required this.onFocusNextSplit,
    required this.onToggleMaximizeSplit,
    required this.onReconnect,
    required this.onDisconnect,
  });
  final _SessionTab tab;
  final rust.Profile? profile;
  final int splitCount;
  final bool maximized;
  final Future<void> Function() onCopy;
  final Future<void> Function() onPaste;
  final VoidCallback onFocusPrevSplit;
  final VoidCallback onFocusNextSplit;
  final VoidCallback onToggleMaximizeSplit;
  final Future<void> Function() onReconnect;
  final Future<void> Function() onDisconnect;

  @override
  Widget build(BuildContext context) {
    final stateColor = _connStateColor(tab.state);
    final visualState = _toVisualState(tab.state);
    final l10n = AppLocalizations.of(context);
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: _bg1,
        border: Border(bottom: BorderSide(color: _line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          _StateBadge(state: tab.state),
          const SizedBox(width: 12),
          Container(width: 1, height: 12, color: _line),
          const SizedBox(width: 12),
          if (profile != null) ...[
            Text(
              '${profile!.username}@${profile!.host}',
              style: _mono(size: 11.5, color: _ink1),
            ),
            if (profile!.jumpHost.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                '??${l10n.via.toLowerCase()} ${profile!.jumpHost}',
                style: _mono(size: 11.5, color: _acc),
              ),
            ],
          ] else
            Text(tab.profileName, style: _mono(size: 11.5, color: _ink1)),
          if (tab.error != null && tab.error!.isNotEmpty) ...[
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                tab.error!,
                overflow: TextOverflow.ellipsis,
                style: _mono(size: 11, color: stateColor),
              ),
            ),
          ],
          const SizedBox(width: 12),
          _TerminalSearchBox(tab: tab),
          const Spacer(),
          _IconBtn(
            icon: Icons.copy_outlined,
            tooltip: l10n.copyScreenTooltip,
            onTap: () => onCopy(),
            iconSize: 13,
          ),
          _IconBtn(
            icon: Icons.content_paste_outlined,
            tooltip: l10n.pasteClipboardTooltip,
            onTap: canPasteToSession(visualState) ? () => onPaste() : null,
            iconSize: 13,
          ),
          if (splitCount > 1) ...[
            _IconBtn(
              icon: Icons.keyboard_arrow_left,
              tooltip: l10n.previousPane,
              onTap: onFocusPrevSplit,
              iconSize: 15,
            ),
            _IconBtn(
              icon: Icons.keyboard_arrow_right,
              tooltip: l10n.nextPane,
              onTap: onFocusNextSplit,
              iconSize: 15,
            ),
            _IconBtn(
              icon: maximized
                  ? Icons.close_fullscreen_outlined
                  : Icons.open_in_full_outlined,
              tooltip: maximized ? l10n.restorePane : l10n.maximizePane,
              onTap: onToggleMaximizeSplit,
              iconSize: 13,
            ),
          ],
          _IconBtn(
            icon: Icons.replay_outlined,
            tooltip: l10n.reconnectTooltip,
            onTap: canReconnectSession(visualState)
                ? () => onReconnect()
                : null,
            iconSize: 13,
          ),
          _IconBtn(
            icon: Icons.power_settings_new,
            tooltip: l10n.disconnectTooltip,
            onTap: canDisconnectSession(visualState)
                ? () => onDisconnect()
                : null,
            iconSize: 13,
            danger: true,
          ),
        ],
      ),
    );
  }
}

class _TerminalSearchBox extends StatefulWidget {
  const _TerminalSearchBox({required this.tab});

  final _SessionTab tab;

  @override
  State<_TerminalSearchBox> createState() => _TerminalSearchBoxState();
}

class _TerminalSearchBoxState extends State<_TerminalSearchBox> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.tab.terminalSearchQuery);
  }

  @override
  void didUpdateWidget(covariant _TerminalSearchBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tab != widget.tab &&
        _controller.text != widget.tab.terminalSearchQuery) {
      _controller.text = widget.tab.terminalSearchQuery;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = buildTerminalSearchState(
      widget.tab.snapshot?.text ?? '',
      widget.tab.terminalSearchQuery,
      currentIndex: widget.tab.terminalSearchIndex,
      caseSensitive: widget.tab.terminalSearchCaseSensitive,
      wholeWord: widget.tab.terminalSearchWholeWord,
      regex: widget.tab.terminalSearchRegex,
    );
    void move(int delta) {
      if (state.count == 0) return;
      setState(() {
        widget.tab.terminalSearchIndex =
            (state.currentIndex + delta + state.count) % state.count;
      });
    }

    void clear() {
      setState(() {
        _controller.clear();
        widget.tab.terminalSearchQuery = '';
        widget.tab.terminalSearchIndex = 0;
      });
    }

    return SizedBox(
      width: 292,
      height: 28,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: (value) {
                setState(() {
                  widget.tab.terminalSearchQuery = value;
                  widget.tab.terminalSearchIndex = 0;
                });
              },
              onSubmitted: (_) => move(1),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 14, color: _ink3),
                prefixIconConstraints: const BoxConstraints.tightFor(width: 28),
                suffixText: widget.tab.terminalSearchQuery.isEmpty
                    ? null
                    : state.invalidPattern
                    ? 'invalid'
                    : '${state.displayIndex}/${state.count}',
                enabledBorder: state.invalidPattern
                    ? OutlineInputBorder(
                        borderSide: BorderSide(color: _Pal.cRose),
                        borderRadius: BorderRadius.circular(6),
                      )
                    : null,
                focusedBorder: state.invalidPattern
                    ? OutlineInputBorder(
                        borderSide: BorderSide(color: _Pal.cRose, width: 1.4),
                        borderRadius: BorderRadius.circular(6),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 7,
                ),
                hintText: state.invalidPattern
                    ? 'Invalid regex'
                    : AppLocalizations.of(context).search,
              ),
              style: _mono(size: 11, color: _ink0),
            ),
          ),
          _IconBtn(
            icon: Icons.text_fields,
            tooltip: 'Match case',
            iconSize: 13,
            onTap: () => setState(() {
              widget.tab.terminalSearchCaseSensitive =
                  !widget.tab.terminalSearchCaseSensitive;
              widget.tab.terminalSearchIndex = 0;
            }),
            danger: widget.tab.terminalSearchCaseSensitive,
          ),
          _IconBtn(
            icon: Icons.short_text,
            tooltip: 'Whole word',
            iconSize: 13,
            onTap: () => setState(() {
              widget.tab.terminalSearchWholeWord =
                  !widget.tab.terminalSearchWholeWord;
              widget.tab.terminalSearchIndex = 0;
            }),
            danger: widget.tab.terminalSearchWholeWord,
          ),
          _IconBtn(
            icon: Icons.code,
            tooltip: 'Regex',
            iconSize: 13,
            onTap: () => setState(() {
              widget.tab.terminalSearchRegex = !widget.tab.terminalSearchRegex;
              widget.tab.terminalSearchIndex = 0;
            }),
            danger: widget.tab.terminalSearchRegex,
          ),
          _IconBtn(
            icon: Icons.keyboard_arrow_up,
            tooltip: 'Previous match',
            iconSize: 14,
            onTap: state.count == 0 ? null : () => move(-1),
          ),
          _IconBtn(
            icon: Icons.keyboard_arrow_down,
            tooltip: 'Next match',
            iconSize: 14,
            onTap: state.count == 0 ? null : () => move(1),
          ),
          _IconBtn(
            icon: Icons.close,
            tooltip: 'Clear search',
            iconSize: 13,
            onTap: widget.tab.terminalSearchQuery.isEmpty ? null : clear,
          ),
        ],
      ),
    );
  }
}

class _SessionFooter extends StatelessWidget {
  const _SessionFooter({required this.tab, required this.profile});
  final _SessionTab? tab;
  final rust.Profile? profile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final connected = tab?.state == _ConnState.connected;
    final snap = tab?.snapshot;
    final transport = profile == null
        ? (tab?.profileId == _localShellProfileId ? 'PTY' : l10n.notAvailable)
        : (profile!.transport.isEmpty
              ? 'SSH'
              : profile!.transport.toUpperCase());
    return Container(
      height: 26,
      decoration: BoxDecoration(
        color: _bg1,
        border: Border(top: BorderSide(color: _line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          if (connected)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _Pal.cEmerald,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$transport | ${l10n.active.toLowerCase()}',
                  style: _mono(size: 11, color: _Pal.cEmerald),
                ),
              ],
            )
          else
            Text(transport, style: _mono(size: 11, color: _ink3)),
          if (profile != null) ...[
            _footSep(),
            Text(
              '${profile!.username}@${profile!.host}:${profile!.port}',
              style: _mono(size: 11, color: _ink2),
            ),
          ],
          if (tab != null) ...[
            _footSep(),
            Text(
              '${l10n.started.toLowerCase()} ${_fmtTime(tab!.startedAt)}',
              style: _mono(size: 11, color: _ink3),
            ),
          ],
          const Spacer(),
          Text('UTF-8', style: _mono(size: 11, color: _ink3)),
          _footSep(),
          Text(
            '${appSettings.value.fontFamily} | ${appSettings.value.fontSize.toStringAsFixed(0)}',
            style: _mono(size: 11, color: _ink3),
          ),
          if (snap != null) ...[
            _footSep(),
            Text(
              '${snap.cols}x${snap.rows}',
              style: _mono(size: 11, color: _ink3),
            ),
          ],
        ],
      ),
    );
  }

  Widget _footSep() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Text(
      '|',
      style: _mono(size: 11, color: _ink3.withValues(alpha: 0.5)),
    ),
  );

  String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ============================================================================
// Cell grid ??terminal renderer
// ============================================================================

class _CellGrid extends StatelessWidget {
  const _CellGrid({
    required this.tab,
    required this.isFocused,
    required this.charWidth,
    required this.lineHeight,
    required this.onReconnect,
    required this.onMouseReport,
    required this.onScrollback,
    required this.onCopy,
    required this.onPaste,
    required this.onOpenUrl,
  });

  final _SessionTab tab;
  final bool isFocused;
  final double charWidth;
  final double lineHeight;
  final Future<void> Function() onReconnect;
  final Future<void> Function(List<int>) onMouseReport;
  final Future<void> Function(_SessionTab, int) onScrollback;
  final Future<void> Function() onCopy;
  final Future<void> Function() onPaste;
  final Future<void> Function(String) onOpenUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (tab.state == _ConnState.connecting) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                color: _Pal.cAmber,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.connectingTo(tab.profileName),
              style: _mono(size: 12, color: _ink2),
            ),
          ],
        ),
      );
    }
    if (tab.state == _ConnState.disconnected && tab.snapshot == null) {
      return Center(
        child: _TerminalProblem(tab: tab, onReconnect: onReconnect),
      );
    }
    final s = tab.snapshot;
    if (s == null) {
      return Center(
        child: Text(
          l10n.waitingForFirstChunk,
          style: _mono(size: 12, color: _ink2),
        ),
      );
    }
    final spans = _buildSpans(s);
    final firstUrl = RegExp(
      r'https?://[^\s<>"\]]+',
    ).firstMatch(s.text)?.group(0);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: s.mouseReportingMode
          ? (event) =>
                _sendMouse(event.localPosition, charWidth, lineHeight, true)
          : null,
      onPointerUp: s.mouseReportingMode
          ? (event) =>
                _sendMouse(event.localPosition, charWidth, lineHeight, false)
          : null,
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          final next =
              (s.scrollbackPosition + (event.scrollDelta.dy > 0 ? -4 : 4))
                  .clamp(0, terminalPrefs.value.scrollbackLimit);
          unawaited(onScrollback(tab, next));
        }
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onSecondaryTapDown: (details) =>
                  _showTerminalMenu(context, details.globalPosition, firstUrl),
              child: SelectableText.rich(
                TextSpan(children: spans),
                style: _termStyle,
                contextMenuBuilder: (context, state) =>
                    AdaptiveTextSelectionToolbar.buttonItems(
                      anchors: state.contextMenuAnchors,
                      buttonItems: [
                        ContextMenuButtonItem(
                          label: l10n.copy,
                          onPressed: () {
                            state.hideToolbar();
                            unawaited(onCopy());
                          },
                        ),
                        ContextMenuButtonItem(
                          label: l10n.paste,
                          onPressed: () {
                            state.hideToolbar();
                            unawaited(onPaste());
                          },
                        ),
                        if (firstUrl != null)
                          ContextMenuButtonItem(
                            label: l10n.openLink,
                            onPressed: () {
                              state.hideToolbar();
                              unawaited(onOpenUrl(firstUrl));
                            },
                          ),
                      ],
                    ),
                onSelectionChanged: (selection, cause) {
                  final text = s.text;
                  if (!selection.isValid || selection.isCollapsed) {
                    tab.selectedTerminalText = null;
                    return;
                  }
                  final start = selection.start.clamp(0, text.length);
                  final end = selection.end.clamp(0, text.length);
                  if (start >= end) {
                    tab.selectedTerminalText = null;
                    return;
                  }
                  tab.selectedTerminalText = text.substring(start, end);
                  if (terminalPrefs.value.copyOnSelect) {
                    unawaited(
                      Clipboard.setData(
                        ClipboardData(text: tab.selectedTerminalText!),
                      ),
                    );
                  }
                },
              ),
            ),
          ),
          if (s.cursorVisible && tab.state == _ConnState.connected)
            Positioned(
              left: s.cursorCol * charWidth,
              top: s.cursorRow * lineHeight,
              width: _cursorWidth(charWidth),
              height: _cursorHeight(lineHeight),
              child: IgnorePointer(
                child: Transform.translate(
                  offset: _cursorOffset(lineHeight),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isFocused
                          ? _tFg.withValues(alpha: 0.85)
                          : _tFg.withValues(alpha: 0.20),
                      border: isFocused
                          ? null
                          : Border.all(
                              color: _tFg.withValues(alpha: 0.6),
                              width: 1,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          if (tab.state == _ConnState.disconnected)
            Positioned(
              top: 6,
              right: 6,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _Pal.cRose.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    l10n.disconnected.toUpperCase(),
                    style: _mono(
                      size: 10,
                      color: Colors.white,
                      weight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
              ),
            ),
          if (tab.state == _ConnState.disconnected &&
              tab.error != null &&
              tab.error!.isNotEmpty)
            Positioned(
              left: 8,
              bottom: 8,
              right: 8,
              child: _TerminalProblem(
                tab: tab,
                onReconnect: onReconnect,
                compact: true,
              ),
            ),
        ],
      ),
    );
  }

  double _cursorWidth(double charWidth) {
    return switch (terminalPrefs.value.cursorStyle) {
      _TerminalCursorStyle.block => charWidth,
      _TerminalCursorStyle.bar => 2,
      _TerminalCursorStyle.underline => charWidth,
    };
  }

  double _cursorHeight(double lineHeight) {
    return switch (terminalPrefs.value.cursorStyle) {
      _TerminalCursorStyle.block => lineHeight,
      _TerminalCursorStyle.bar => lineHeight,
      _TerminalCursorStyle.underline => 2,
    };
  }

  Offset _cursorOffset(double lineHeight) {
    return switch (terminalPrefs.value.cursorStyle) {
      _TerminalCursorStyle.block || _TerminalCursorStyle.bar => Offset.zero,
      _TerminalCursorStyle.underline => Offset(0, lineHeight - 2),
    };
  }

  Future<void> _showTerminalMenu(
    BuildContext context,
    Offset position,
    String? firstUrl,
  ) async {
    final l10n = AppLocalizations.of(context);
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(value: 'copy', child: Text(l10n.copy)),
        PopupMenuItem(value: 'paste', child: Text(l10n.paste)),
        if (firstUrl != null)
          PopupMenuItem(value: 'open-url', child: Text(l10n.openLink)),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'reconnect', child: Text(l10n.reconnect)),
      ],
    );
    switch (selected) {
      case 'copy':
        await onCopy();
        return;
      case 'paste':
        await onPaste();
        return;
      case 'open-url':
        if (firstUrl != null) await onOpenUrl(firstUrl);
        return;
      case 'reconnect':
        await onReconnect();
        return;
    }
  }

  void _sendMouse(
    Offset offset,
    double charWidth,
    double lineHeight,
    bool down,
  ) {
    final col = (offset.dx / charWidth).floor().clamp(0, tab.cols - 1) + 1;
    final row = (offset.dy / lineHeight).floor().clamp(0, tab.rows - 1) + 1;
    final code = down ? 0 : 3;
    final suffix = down ? 'M' : 'm';
    unawaited(onMouseReport(utf8.encode('\x1b[<$code;$col;$row$suffix')));
  }

  List<TextSpan> _buildSpans(rust.TerminalSnapshot s) {
    final searchState = buildTerminalSearchState(
      s.text,
      tab.terminalSearchQuery,
      currentIndex: tab.terminalSearchIndex,
      caseSensitive: tab.terminalSearchCaseSensitive,
      wholeWord: tab.terminalSearchWholeWord,
      regex: tab.terminalSearchRegex,
    );
    final ranges = searchState.matches;
    final currentRange = searchState.currentMatch;
    final spans = <TextSpan>[];
    StringBuffer? buf;
    TextStyle? curStyle;

    void flush() {
      if (buf != null && buf!.isNotEmpty) {
        spans.add(TextSpan(text: buf!.toString(), style: curStyle));
      }
      buf = null;
      curStyle = null;
    }

    final cols = s.cols;
    final rows = s.rows;
    var textOffset = 0;
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final idx = row * cols + col;
        if (idx >= s.cells.length) break;
        final cell = s.cells[idx];
        final ch = cell.ch.isEmpty ? ' ' : cell.ch;
        var style = _styleForCell(cell);
        final charStart = textOffset;
        final charEnd = textOffset + ch.length;
        final inCurrent =
            currentRange != null &&
            charStart < currentRange.end &&
            charEnd > currentRange.start;
        final inAny =
            !inCurrent &&
            ranges.any(
              (match) => charStart < match.end && charEnd > match.start,
            );
        if (inCurrent) {
          style = style.copyWith(
            backgroundColor: _Pal.cAmber.withValues(alpha: 0.72),
            color: Colors.black,
          );
        } else if (inAny) {
          style = style.copyWith(backgroundColor: _acc.withValues(alpha: 0.34));
        }
        if (style != curStyle) {
          flush();
          curStyle = style;
          buf = StringBuffer();
        }
        buf!.write(ch);
        textOffset = charEnd;
      }
      flush();
      if (row + 1 < rows) {
        spans.add(const TextSpan(text: '\n'));
        textOffset += 1;
      }
    }
    flush();
    return spans;
  }
}

class _TerminalProblem extends StatelessWidget {
  const _TerminalProblem({
    required this.tab,
    required this.onReconnect,
    this.compact = false,
  });

  final _SessionTab tab;
  final Future<void> Function() onReconnect;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final error = tab.error?.trim();
    final message = (error == null || error.isEmpty)
        ? l10n.sessionDisconnectedMessage
        : error;
    return Container(
      constraints: BoxConstraints(maxWidth: compact ? double.infinity : 560),
      padding: EdgeInsets.all(compact ? 10 : 18),
      decoration: BoxDecoration(
        color: _bg1.withValues(alpha: compact ? 0.96 : 1),
        border: Border.all(color: _Pal.cRose.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link_off, size: compact ? 15 : 18, color: _Pal.cRose),
              const SizedBox(width: 8),
              Text(
                compact ? l10n.disconnected : l10n.sessionDisconnected,
                style: _mono(
                  size: compact ? 11 : 13,
                  color: _Pal.cRose,
                  weight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              _IconBtn(
                icon: Icons.replay_outlined,
                tooltip: l10n.reconnectTooltip,
                onTap: () => onReconnect(),
                iconSize: 13,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            maxLines: compact ? 2 : 5,
            overflow: TextOverflow.ellipsis,
            style: _mono(size: compact ? 10.5 : 12, color: _ink1),
          ),
          if (!compact && error != null && error.isNotEmpty) ...[
            const SizedBox(height: 12),
            _TinyButton(
              icon: Icons.copy_outlined,
              label: l10n.copyError,
              onTap: () => Clipboard.setData(ClipboardData(text: error)),
            ),
          ],
        ],
      ),
    );
  }
}

TextStyle _styleForCell(rust.Cell c) {
  final inverse = (c.attrs & 8) != 0;
  Color fg = c.fg.default_ ? _tFg : Color.fromARGB(255, c.fg.r, c.fg.g, c.fg.b);
  Color? bg = c.bg.default_
      ? null
      : Color.fromARGB(255, c.bg.r, c.bg.g, c.bg.b);
  if (inverse) {
    final tmpFg = fg;
    fg = bg ?? _tBg;
    bg = tmpFg;
  }
  final base = _termStyle;
  return base.copyWith(
    color: fg,
    backgroundColor: bg,
    fontWeight: (c.attrs & 1) != 0 ? FontWeight.bold : null,
    fontStyle: (c.attrs & 2) != 0 ? FontStyle.italic : null,
    decoration: (c.attrs & 4) != 0 ? TextDecoration.underline : null,
    inherit: true,
  );
}
