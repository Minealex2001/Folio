part of 'package:folio/features/workspace/editor/block_editor.dart';

/// File/image/video/audio picking for block attachments. Delegates the
/// actual upload to [_CollabMediaUpload] once a local file is chosen. Split
/// out of `block_editor_state.dart` as a self-contained concern.
mixin _BlockMediaPicking on State<BlockEditor> {
  BlockEditorState get _pickingSelf => this as BlockEditorState;

  /// En escritorio `image_picker` suele lanzar [MissingPluginException]; ahí usamos diálogo nativo.
  bool get _pickImageViaFileDialog {
    if (FolioAdaptive.isAndroidDesktopLikeWidth(
      MediaQuery.sizeOf(context).width,
    )) {
      return true;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.linux ||
      TargetPlatform.macOS => true,
      _ => false,
    };
  }

  Future<void> _pickImageForBlock(
    String pageId,
    String blockId,
    int index,
  ) async {
    final st = _pickingSelf;
    File? file;
    String? webRel;
    if (_pickImageViaFileDialog || kIsWeb) {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: kIsWeb,
      );
      if (kIsWeb) {
        final bytes = result?.files.single.bytes;
        if (bytes != null) {
          final ext = p.extension(result!.files.single.name);
          webRel = await VaultPaths.importAttachmentBytes(bytes, ext);
        }
      } else {
        final path = result?.files.single.path;
        if (path != null) {
          file = File(path);
        }
      }
    } else {
      final picker = ImagePicker();
      final x = await picker.pickImage(source: ImageSource.gallery);
      if (x != null) {
        file = File(x.path);
      }
    }
    if (!mounted || (file == null && webRel == null)) return;
    if (file != null && !kIsWeb && !file.existsSync()) return;
    final rel = webRel ?? await VaultPaths.importAttachmentFile(file!);
    if (!mounted) return;
    st._ignoreShortcuts = true;
    st._s.updateBlockText(pageId, blockId, rel);
    if (index < st._controllers.length) {
      st._controllers[index].value = TextEditingValue(
        text: rel,
        selection: TextSelection.collapsed(offset: rel.length),
      );
    }
    st._ignoreShortcuts = false;
    setState(() {});
    if (file != null) {
      st._enqueueCollabMediaUpload(
        pageId: pageId,
        blockId: blockId,
        localFile: file,
        mediaKind: 'image',
        onCommittedUri: (uri) {
          st._ignoreShortcuts = true;
          st._s.updateBlockText(pageId, blockId, uri);
          if (index < st._controllers.length) {
            st._controllers[index].value = TextEditingValue(
              text: uri,
              selection: TextSelection.collapsed(offset: uri.length),
            );
          }
          st._ignoreShortcuts = false;
        },
      );
    }
  }

  Future<void> _clearImageBlock(
    String pageId,
    String blockId,
    int index,
  ) async {
    final st = _pickingSelf;
    st._ignoreShortcuts = true;
    st._s.updateBlockText(pageId, blockId, '');
    if (index < st._controllers.length) {
      st._controllers[index].clear();
    }
    st._ignoreShortcuts = false;
    setState(() {});
  }

  Future<void> _pickFileForBlock(String pageId, String blockId) async {
    final st = _pickingSelf;
    final result = await FilePicker.pickFiles(withData: kIsWeb);
    if (result == null) return;
    if (kIsWeb) {
      final bytes = result.files.single.bytes;
      if (bytes != null) {
        final ext = p.extension(result.files.single.name);
        final rel = await VaultPaths.importAttachmentBytes(
          bytes,
          ext,
          preferredName: result.files.single.name,
        );
        st._s.updateBlockUrl(pageId, blockId, rel);
        setState(() {});
      }
    } else if (result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final rel = await VaultPaths.importAttachmentFile(
        file,
        preserveExtension: true,
        preserveFileName: true,
      );
      st._s.updateBlockUrl(pageId, blockId, rel);
      setState(() {});
      st._enqueueCollabMediaUpload(
        pageId: pageId,
        blockId: blockId,
        localFile: file,
        mediaKind: 'file',
        onCommittedUri: (uri) => st._s.updateBlockUrl(pageId, blockId, uri),
      );
    }
  }

  Future<void> _pickVideoForBlock(String pageId, String blockId) async {
    final st = _pickingSelf;
    final result = await FilePicker.pickFiles(
      type: FileType.video,
      withData: kIsWeb,
    );
    if (result == null) return;
    if (kIsWeb) {
      final bytes = result.files.single.bytes;
      if (bytes != null) {
        final ext = p.extension(result.files.single.name);
        final rel = await VaultPaths.importAttachmentBytes(
          bytes,
          ext,
          preferredName: result.files.single.name,
        );
        st._s.updateBlockUrl(pageId, blockId, rel);
        setState(() {});
      }
    } else if (result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final rel = await VaultPaths.importAttachmentFile(
        file,
        preserveExtension: true,
        preserveFileName: true,
      );
      st._s.updateBlockUrl(pageId, blockId, rel);
      setState(() {});
      st._enqueueCollabMediaUpload(
        pageId: pageId,
        blockId: blockId,
        localFile: file,
        mediaKind: 'video',
        onCommittedUri: (uri) => st._s.updateBlockUrl(pageId, blockId, uri),
      );
    }
  }

  Future<void> _pickAudioForBlock(String pageId, String blockId) async {
    final st = _pickingSelf;
    final result = await FilePicker.pickFiles(
      type: FileType.audio,
      withData: kIsWeb,
    );
    if (result == null) return;
    if (kIsWeb) {
      final bytes = result.files.single.bytes;
      if (bytes != null) {
        final ext = p.extension(result.files.single.name);
        final rel = await VaultPaths.importAttachmentBytes(
          bytes,
          ext,
          preferredName: result.files.single.name,
        );
        st._s.updateBlockUrl(pageId, blockId, rel);
        setState(() {});
      }
    } else if (result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final rel = await VaultPaths.importAttachmentFile(
        file,
        preserveExtension: true,
        preserveFileName: true,
      );
      st._s.updateBlockUrl(pageId, blockId, rel);
      setState(() {});
      st._enqueueCollabMediaUpload(
        pageId: pageId,
        blockId: blockId,
        localFile: file,
        mediaKind: 'audio',
        onCommittedUri: (uri) => st._s.updateBlockUrl(pageId, blockId, uri),
      );
    }
  }
}
