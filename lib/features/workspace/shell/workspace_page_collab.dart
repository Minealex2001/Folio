part of 'workspace_page.dart';

extension _WorkspacePageCollabModule on _WorkspacePageState {
  bool _isValidCollabRoomId(String? raw) {
    final rid = raw?.trim();
    if (rid == null || rid.isEmpty) return false;
    if (RegExp(r'^[-—]+$').hasMatch(rid)) return false;
    return true;
  }

  void _onCollabController() {
    if (!mounted) return;
    _updateCollabUnreadState();
    _setStateSafe(() {});
  }

  bool _isCompactWorkspaceNow() {
    final width = MediaQuery.sizeOf(context).width;
    final androidMobileWorkspace = FolioAdaptive.shouldUseMobileWorkspace(
      width,
    );
    return width < FolioDesktop.compactBreakpoint || androidMobileWorkspace;
  }

  bool _isCollabUiVisibleNow() {
    final compact = _isCompactWorkspaceNow();
    if (compact) {
      return _collabSheetOpen;
    }
    return !_collabPanelCollapsed;
  }

  void _markCollabAsRead() {
    final roomId = _collab.activeRoomId;
    if (!_isValidCollabRoomId(roomId)) return;
    final msgs = _collab.messages;
    _collabUnreadCount = 0;
    _lastCollabObservedRoomId = roomId;
    _lastCollabObservedMessageId = msgs.isEmpty ? null : msgs.last.id;
  }

  void _updateCollabUnreadState() {
    final roomId = _collab.activeRoomId;
    if (!_isValidCollabRoomId(roomId)) {
      _collabUnreadCount = 0;
      _lastCollabObservedRoomId = null;
      _lastCollabObservedMessageId = null;
      return;
    }
    final msgs = _collab.messages;
    final latest = msgs.isEmpty ? null : msgs.last;
    final latestId = latest?.id;
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final incomingFromOther =
        latest != null && (myUid == null || latest.authorUid != myUid);
    final roomChanged = _lastCollabObservedRoomId != roomId;
    final hasNewMessage =
        latestId != null && latestId != _lastCollabObservedMessageId;

    if (_isCollabUiVisibleNow()) {
      _markCollabAsRead();
      return;
    }

    if (roomChanged) {
      _collabUnreadCount = 0;
      _lastCollabObservedRoomId = roomId;
      _lastCollabObservedMessageId = latestId;
      return;
    }

    if (hasNewMessage && incomingFromOther) {
      _collabUnreadCount += 1;
    }
    _lastCollabObservedRoomId = roomId;
    _lastCollabObservedMessageId = latestId;
  }

  void _syncCollabForSelectedPage() {
    final id = _s.selectedPageId;
    final page = id == null
        ? null
        : _s.pages.firstWhereOrNull((p) => p.id == id);
    final rid = page?.collabRoomId?.trim();
    if (_isValidCollabRoomId(rid) &&
        Firebase.apps.isNotEmpty &&
        widget.cloudAccountController.isSignedIn) {
      _collab.attach(
        pageId: page!.id,
        roomId: rid!,
        initialJoinCode: page.collabJoinCode,
      );
    } else {
      _collab.detach();
    }
  }

  Future<void> _openCollaborationSheet() async {
    final pageId = _s.selectedPageId;
    if (pageId == null) return;
    final page = _s.pages.firstWhereOrNull((p) => p.id == pageId);
    if (page == null) return;
    if (_collabSheetOpen) return;
    _setStateSafe(() {
      _collabSheetOpen = true;
      _markCollabAsRead();
    });
    try {
      await showCollaborationSheet(
        context,
        collab: _collab,
        pageId: pageId,
        canHostCollab: widget.folioCloudEntitlements.snapshot.canRealtimeCollab,
      );
    } finally {
      if (mounted) {
        _setStateSafe(() {
          _collabSheetOpen = false;
          _markCollabAsRead();
        });
      }
    }
  }

  void _toggleCollaborationPanel({required bool compact}) {
    final pageId = _s.selectedPageId;
    if (pageId == null) return;
    final hasCollabRoom = _isValidCollabRoomId(_s.selectedPage?.collabRoomId);
    if (compact || !hasCollabRoom) {
      unawaited(_openCollaborationSheet());
    } else {
      _setStateSafe(() {
        _collabPanelCollapsed = !_collabPanelCollapsed;
        if (!_collabPanelCollapsed) {
          _markCollabAsRead();
        }
      });
    }
  }

  Widget _buildCollabFabIcon(
    ColorScheme scheme, {
    Color? iconColor,
    double iconSize = 24,
  }) {
    final hasUnread = _collabUnreadCount > 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(Icons.groups_2_rounded, color: iconColor, size: iconSize),
        if (hasUnread)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: scheme.error,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: scheme.surface, width: 1.5),
              ),
              child: Center(
                child: Text(
                  _collabUnreadCount > 99 ? '99+' : '$_collabUnreadCount',
                  style: TextStyle(
                    color: scheme.onError,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCollabCollapsedFab(BuildContext context, ColorScheme scheme) {
    final l10n = AppLocalizations.of(context);
    return Tooltip(
      message: l10n.collabMenuAction,
      child: Material(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _setStateSafe(() {
            _collabPanelCollapsed = false;
            _markCollabAsRead();
          }),
          child: SizedBox(
            width: 56,
            height: 56,
            child: Center(
              child: _buildCollabFabIcon(
                scheme,
                iconColor: scheme.onSecondaryContainer,
                iconSize: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollabDockPanel(BuildContext context) {
    final pageId = _s.selectedPageId;
    if (pageId == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: CollaborationSheetBody(
        collab: _collab,
        pageId: pageId,
        canHostCollab: widget.folioCloudEntitlements.snapshot.canRealtimeCollab,
        embedded: true,
        onRequestMinimize: () => _setStateSafe(() => _collabPanelCollapsed = true),
      ),
    );
  }
}

