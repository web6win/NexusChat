import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../data/crypto/did.dart';
import '../../data/media/audio_playback.dart';
import '../../data/media/audio_source.dart';
import '../../data/media/image_util.dart';
import '../../data/models/chat_models.dart';
import '../../data/waku/message_content.dart';
import '../../shared/feedback.dart';
import '../../shared/layout.dart';
import '../../shared/widgets.dart';
import '../../state/controllers.dart';

/// 單一對話的完整畫面：訊息串 + 輸入框（含圖片 / 語音）。
class ChatView extends ConsumerStatefulWidget {
  const ChatView({
    required this.peerDid,
    super.key,
    this.showBack = false,
    this.onBack,
  });

  final String peerDid;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _captionController = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode();
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();

  /// 是否停在底部：只有貼著底部時才自動捲動，避免打斷往上翻歷史的人。
  bool _atBottom = true;

  /// 使用者正在手動捲動（拖曳 / 甩動）：此時禁止自動捲到底，避免打架。
  bool _userScrolling = false;

  /// 使用者不在底部時累積的新訊息數（顯示「新訊息」浮標）。
  int _pendingNew = 0;

  String? _lastMessageId;

  /// 待發送的圖片（已壓縮）。
  Uint8List? _pendingImageBytes;
  String? _pendingImageMime;
  String? _pendingImageName;

  /// 待發送的語音（已錄製完成，等待使用者確認送出）。
  Uint8List? _pendingAudioBytes;
  String? _pendingAudioMime;
  int? _pendingAudioDur;
  String? _pendingAudioName;

  /// 是否正在錄音。
  bool _recording = false;
  int _recordMs = 0;
  Timer? _recordTimer;

  /// 距離底部多少 px 內都算「在底部」。
  static const _bottomThreshold = 120.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatControllerProvider.notifier).markRead(widget.peerDid);
      _scrollToEnd();
    });
  }

  @override
  void didUpdateWidget(covariant ChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.peerDid != widget.peerDid) {
      // 換了對話：重新開始追蹤，並直接落在最新一則。
      _lastMessageId = null;
      _pendingNew = 0;
      _atBottom = true;
      _clearPending();
      ref.read(chatControllerProvider.notifier).markRead(widget.peerDid);
      _scrollToEnd();
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final atBottom =
        _scroll.position.maxScrollExtent - _scroll.offset <= _bottomThreshold;
    if (atBottom == _atBottom) return;
    setState(() {
      _atBottom = atBottom;
      // 自己滑回底部就視為已讀，清掉提示。
      if (atBottom) _pendingNew = 0;
    });
  }

  /// 收到新訊息時：貼著底部就自動捲到底，否則只提示、不打斷閱讀。
  /// 若使用者正在拖曳，先不要捲，等手放開再判斷。
  void _autoScrollOnNewMessages(List<ChatMessage> messages) {
    if (messages.isEmpty) return;
    final lastId = messages.last.id;
    if (lastId == _lastMessageId) return;
    final isFirstRender = _lastMessageId == null;
    _lastMessageId = lastId;
    // 首次進場由 initState 統一處理，不要在這裡多捲一次。
    if (isFirstRender) return;
    if (_atBottom && !_userScrolling) {
      _scrollToEnd();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _pendingNew++);
      });
    }
  }

  /// 偵測使用者手勢開始 / 結束，避免自動捲動跟使用者拖曳打架。
  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      if (mounted) setState(() => _userScrolling = true);
    } else if (notification is ScrollEndNotification) {
      if (mounted) {
        setState(() {
          _userScrolling = false;
          // 手勢結束時若已經在底部，順手清提示。
          if (_atBottom) _pendingNew = 0;
        });
      }
      // 使用者滑到底放手後，若有新訊息擱置，立刻帶過去。
      if (_atBottom && _pendingNew > 0) {
        _scrollToEnd();
      }
    }
    return false;
  }

  void _jumpToBottom() {
    setState(() {
      _pendingNew = 0;
      _atBottom = true;
      _userScrolling = false;
    });
    _scrollToEnd();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _recordTimer?.cancel();
    if (_recording) {
      // 離開頁面時若還在錄音，直接停掉（捨棄）。
      _recorder.stop().catchError((_) => '');
    }
    _recorder.dispose();
    _controller.dispose();
    _captionController.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    if (!_scroll.hasClients) return;
    // 畫面已經帶到最新，順手標為已讀。
    ref.read(chatControllerProvider.notifier).markRead(widget.peerDid);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      // 已經貼底就不要再觸發動畫，避免跟手勢打架。
      if (_scroll.offset >= target - 2) return;
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    // 少數平台會把 Enter 的換行插進文字裡，送出前先去掉尾部空白。
    final text = _controller.text.trimRight();
    if (text.trim().isEmpty) return;
    _controller.clear();
    setState(() {
      // 自己發的訊息一律帶到最新，並清掉「新訊息」提示。
      _pendingNew = 0;
      _atBottom = true;
    });
    // 若換行是在按鍵事件之後才被補進來，下一幀再清一次，避免殘留空行。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_controller.text.trim().isEmpty) _controller.clear();
    });
    await ref
        .read(chatControllerProvider.notifier)
        .sendContent(widget.peerDid, MessageContent.text(text));
    _scrollToEnd();
    ref.read(chatControllerProvider.notifier).markRead(widget.peerDid);
  }

  // ------------------------------------------------------------------ 圖片

  Future<void> _pickImage() async {
    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      final compressed = compressImage(Uint8List.fromList(bytes));
      if (compressed.length > 700 * 1024) {
        _showError(context.s.chatMediaTooLarge);
        return;
      }
      setState(() {
        _pendingImageBytes = compressed;
        _pendingImageMime = 'image/jpeg';
        _pendingImageName = xfile.name;
      });
    } catch (_) {
      _showError(context.s.chatPermissionPhotos);
    }
  }

  Future<void> _sendPendingImage() async {
    if (_pendingImageBytes == null) return;
    final content = MessageContent.image(
      text: _captionController.text.trim(),
      mediaBytes: _pendingImageBytes!,
      mediaMime: _pendingImageMime ?? 'image/jpeg',
      mediaName: _pendingImageName,
    );
    _clearPending();
    await ref
        .read(chatControllerProvider.notifier)
        .sendContent(widget.peerDid, content);
    _scrollToEnd();
  }

  // ------------------------------------------------------------------ 錄音

  Future<void> _startRecord() async {
    try {
      if (!await _recorder.hasPermission()) {
        _showError(context.s.chatPermissionMicrophone);
        return;
      }
      var path = '';
      if (!kIsWeb) {
        final dir = await getTemporaryDirectory();
        path = '${dir.path}/voice_${const Uuid().v4()}.m4a';
      }
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 16000,
        ),
        path: path,
      );
      setState(() {
        _recording = true;
        _recordMs = 0;
      });
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1),
          (_) => setState(() => _recordMs += 1000));
    } catch (_) {
      _showError(context.s.chatPermissionMicrophone);
    }
  }

  Future<void> _stopRecord() async {
    if (!_recording) return;
    _recordTimer?.cancel();
    _recordTimer = null;
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {
      path = null;
    }
    setState(() => _recording = false);
    if (path == null || path.isEmpty) return;
    final bytes = await readRecordedBytes(path);
    if (bytes.isEmpty || _recordMs < 800) {
      // 太短視為誤觸，直接捨棄。
      return;
    }
    final mime = kIsWeb ? 'audio/webm' : 'audio/mp4';
    setState(() {
      _pendingAudioBytes = bytes;
      _pendingAudioMime = mime;
      _pendingAudioDur = _recordMs;
      _pendingAudioName = 'voice';
    });
  }

  Future<void> _cancelRecord() async {
    if (!_recording) return;
    _recordTimer?.cancel();
    _recordTimer = null;
    try {
      await _recorder.stop();
    } catch (_) {
      // 忽略
    }
    setState(() {
      _recording = false;
      _recordMs = 0;
    });
  }

  Future<void> _sendPendingAudio() async {
    if (_pendingAudioBytes == null) return;
    final content = MessageContent.audio(
      mediaBytes: _pendingAudioBytes!,
      mediaMime: _pendingAudioMime ?? 'audio/mp4',
      mediaDurationMs: _pendingAudioDur,
      mediaName: _pendingAudioName,
    );
    _clearPending();
    await ref
        .read(chatControllerProvider.notifier)
        .sendContent(widget.peerDid, content);
    _scrollToEnd();
  }

  void _clearPending() {
    _captionController.clear();
    setState(() {
      _pendingImageBytes = null;
      _pendingImageMime = null;
      _pendingImageName = null;
      _pendingAudioBytes = null;
      _pendingAudioMime = null;
      _pendingAudioDur = null;
      _pendingAudioName = null;
    });
  }

  void _showError(String msg) {
    if (!mounted) return;
    showAppSnack(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final state = ref.watch(chatControllerProvider);
    final contacts = ref.watch(contactsProvider);
    final contact = contacts
        .where((c) => c.did.toLowerCase() == widget.peerDid.toLowerCase())
        .toList();
    final name = contact.isNotEmpty
        ? contact.first.name
        : Did.shortDid(widget.peerDid);
    final color = contact.isNotEmpty
        ? contact.first.accent
        : AppColors.brand;

    final messages = state.forPeer(widget.peerDid);

    // 用 ref.listen 偵測訊息列表變化，不要直接在 build() 裡捲動，
    // 否則圖片載入、鍵盤彈出等重建都會干擾使用者手勢。
    ref.listen<ChatState>(chatControllerProvider, (previous, next) {
      final prevMessages = previous?.forPeer(widget.peerDid) ?? [];
      final nextMessages = next.forPeer(widget.peerDid);
      final changed = prevMessages.length != nextMessages.length ||
          (prevMessages.isNotEmpty &&
              nextMessages.isNotEmpty &&
              prevMessages.last.id != nextMessages.last.id);
      if (changed) {
        _autoScrollOnNewMessages(nextMessages);
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: widget.showBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed:
                    widget.onBack ?? () => Navigator.of(context).maybePop(),
              )
            : null,
        titleSpacing: widget.showBack ? 0 : 16,
        title: Row(
          children: <Widget>[
            AppAvatar(
                name: name,
                color: color,
                size: 38,
                showPresence: true,
                present: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.lock_rounded,
                        size: 11,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          s.chatEncrypted,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: <Widget>[
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) async {
              final controller = ref.read(chatControllerProvider.notifier);
              switch (value) {
                case 'pin':
                  await controller.togglePin(widget.peerDid);
                  break;
                case 'delete':
                  final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(s.chatDeleteTitle),
                          content: Text(s.chatDeleteConfirm(name)),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(s.cancel),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(
                                s.delete,
                                style:
                                    const TextStyle(color: AppColors.danger),
                              ),
                            ),
                          ],
                        ),
                      ) ??
                      false;
                  if (confirmed) {
                    await controller.deleteConversation(widget.peerDid);
                    if (widget.onBack != null) widget.onBack!();
                  }
                  break;
              }
            },
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'pin',
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.push_pin_outlined, size: 19),
                    const SizedBox(width: 12),
                    Text(s.edit),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.delete_outline_rounded,
                        size: 19, color: AppColors.danger),
                    const SizedBox(width: 12),
                    Text(s.delete,
                        style: const TextStyle(color: AppColors.danger)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: ContentColumn(
                    maxWidth: AppBreakpoints.conversation,
                    child: messages.isEmpty
                        ? EmptyState(
                            icon: Icons.lock_person_rounded,
                            title: s.chatSecureTitle,
                            description: s.chatSecureDesc,
                          )
                        : NotificationListener<ScrollNotification>(
                            onNotification: _onScrollNotification,
                            child: ListView.builder(
                              controller: _scroll,
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 16, 16),
                              itemCount: messages.length + 1,
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Center(
                                      child: Pill(
                                        label: s.chatEncrypted,
                                        icon: Icons.enhanced_encryption_rounded,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  );
                                }
                                final message = messages[index - 1];
                                final previous =
                                    index >= 2 ? messages[index - 2] : null;
                                final showDay = previous == null ||
                                    _dayKey(previous.timestamp) !=
                                        _dayKey(message.timestamp);
                                return Column(
                                  children: <Widget>[
                                    if (showDay)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        child: Center(
                                          child: Text(
                                            Formatters.dayLabel(
                                                message.timestamp, s),
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.45),
                                            ),
                                          ),
                                        ),
                                      ),
                                    MessageBubble(
                                      message: message,
                                      color: color,
                                      onRetry: () => ref
                                          .read(
                                              chatControllerProvider.notifier)
                                          .retry(message.id),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                  ),
                ),
                if (_pendingNew > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 14,
                    child: ContentColumn(
                      maxWidth: AppBreakpoints.conversation,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: _NewMessagesPill(
                            label: s.chatNewMessages,
                            count: _pendingNew,
                            onTap: _jumpToBottom,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_pendingAudioBytes != null && !_recording)
            ContentColumn(
              maxWidth: AppBreakpoints.conversation,
              child: _audioPreviewRow(),
            ),
          if (_pendingImageBytes != null)
            ContentColumn(
              maxWidth: AppBreakpoints.conversation,
              child: _imagePreviewRow(),
            ),
          if (_recording)
            ContentColumn(
              maxWidth: AppBreakpoints.conversation,
              child: _recordingBar(),
            )
          else
            ContentColumn(
              maxWidth: AppBreakpoints.conversation,
              child: _Composer(
                controller: _controller,
                focusNode: _focus,
                onSend: _send,
                onChanged: () => setState(() {}),
                onPickImage: _pickImage,
                onToggleRecord: _startRecord,
              ),
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------- 待發送預覽 / 錄音條

  Widget _imagePreviewRow() {
    final s = context.s;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .onSurface
              .withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              _pendingImageBytes!,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _captionController,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: s.chatSendImage,
                border: InputBorder.none,
                isDense: true,
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.danger),
            onPressed: _clearPending,
          ),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: AppColors.brand),
            onPressed: _sendPendingImage,
          ),
        ],
      ),
    );
  }

  Widget _audioPreviewRow() {
    final s = context.s;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .onSurface
              .withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.graphic_eq_rounded, color: AppColors.brand),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${s.chatVoice} · ${_formatDuration(Duration(milliseconds: _pendingAudioDur ?? 0))}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.danger),
            onPressed: _clearPending,
          ),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: AppColors.brand),
            onPressed: _sendPendingAudio,
          ),
        ],
      ),
    );
  }

  Widget _recordingBar() {
    final s = context.s;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.mic_rounded, color: AppColors.danger),
          const SizedBox(width: 10),
          Text(
            _formatDuration(Duration(milliseconds: _recordMs)),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 6),
          Text(s.chatRecording,
              style: TextStyle(color: AppColors.danger.withValues(alpha: 0.8))),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.danger),
            onPressed: _cancelRecord,
            tooltip: s.chatCancel,
          ),
          IconButton(
            icon: const Icon(Icons.stop_circle_rounded, color: AppColors.danger),
            onPressed: _stopRecord,
            tooltip: s.chatStop,
          ),
        ],
      ),
    );
  }

  String _dayKey(DateTime time) =>
      '${time.year}-${time.month}-${time.day}';
}

/// 訊息氣泡：依種類渲染文字 / 圖片 / 語音。
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    required this.color,
    super.key,
    this.onRetry,
  });

  final ChatMessage message;
  final Color color;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final outgoing = message.outgoing;
    final palette = context.palette;
    final isMedia = message.kind != MediaKind.text;

    return Align(
      alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 3,
          bottom: 3,
          left: outgoing ? 56 : 0,
          right: outgoing ? 0 : 56,
        ),
        child: Column(
          crossAxisAlignment:
              outgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: isMedia
                  ? const EdgeInsets.all(4)
                  : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: outgoing ? AppColors.brandGradient : null,
                color: outgoing ? null : palette.bubbleOther,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(outgoing ? 18 : 6),
                  bottomRight: Radius.circular(outgoing ? 6 : 18),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: palette.shadow.withValues(alpha: 0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: _bubbleContent(outgoing, palette, s),
            ),
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    Formatters.clock(message.timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.42),
                    ),
                  ),
                  if (outgoing) ...<Widget>[
                    const SizedBox(width: 4),
                    _StatusIcon(status: message.status),
                  ],
                ],
              ),
            ),
            if (message.status == MessageStatus.failed)
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 4),
                child: InkWell(
                  onTap: onRetry,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.refresh_rounded,
                          size: 13, color: AppColors.danger),
                      const SizedBox(width: 4),
                      Text(
                        s.retry,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bubbleContent(bool outgoing, palette, Strings s) {
    switch (message.kind) {
      case MediaKind.image:
        final bytes = message.mediaB64 == null
            ? null
            : base64Decode(message.mediaB64!);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (bytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 240,
                    maxHeight: 280,
                  ),
                  child: Image.memory(bytes, fit: BoxFit.cover),
                ),
              ),
            if (message.text.isNotEmpty)
              Padding(
                padding: bytes != null
                    ? const EdgeInsets.only(top: 8, left: 4, right: 4)
                    : EdgeInsets.zero,
                child: Text(
                  message.text,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.42,
                    color: outgoing
                        ? palette.bubbleMeText
                        : palette.bubbleOtherText,
                  ),
                ),
              ),
          ],
        );
      case MediaKind.audio:
        final bytes = message.mediaB64 == null
            ? Uint8List(0)
            : base64Decode(message.mediaB64!);
        return _AudioBubble(
          bytes: bytes,
          mime: message.mediaMime ?? 'audio/mp4',
          durationMs: message.mediaDurationMs ?? 0,
          outgoing: outgoing,
        );
      case MediaKind.text:
        return Text(
          message.text,
          style: TextStyle(
            fontSize: 15,
            height: 1.42,
            color: outgoing ? palette.bubbleMeText : palette.bubbleOtherText,
          ),
        );
    }
  }
}

/// 語音氣泡：點擊播放 / 暫停，並顯示進度與時長。
class _AudioBubble extends StatefulWidget {
  const _AudioBubble({
    required this.bytes,
    required this.mime,
    required this.durationMs,
    required this.outgoing,
  });

  final Uint8List bytes;
  final String mime;
  final int durationMs;
  final bool outgoing;

  @override
  State<_AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<_AudioBubble> {
  late final AudioPlayer _player;
  bool _playing = false;
  Duration _pos = Duration.zero;
  late Duration _total;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _total = Duration(milliseconds: widget.durationMs);
    _player.onPositionChanged.listen((d) {
      if (mounted) setState(() => _pos = d);
    });
    _player.onDurationChanged.listen((d) {
      if (d > Duration.zero && mounted) setState(() => _total = d);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playing = false;
          _pos = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      if (mounted) setState(() => _playing = false);
      return;
    }
    try {
      if (_pos > Duration.zero) {
        await _player.resume();
      } else {
        final source = await createAudioSource(widget.bytes, widget.mime);
        await _player.play(source);
      }
      if (mounted) setState(() => _playing = true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _playing = false;
          _pos = Duration.zero;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tint = widget.outgoing ? Colors.white : AppColors.brand;
    final value = _total.inMilliseconds == 0
        ? 0.0
        : (_pos.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          onPressed: _toggle,
          icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
          color: tint,
          iconSize: 30,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 150,
              child: LinearProgressIndicator(
                value: value,
                color: tint,
                backgroundColor: tint.withValues(alpha: 0.25),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${_formatDuration(_pos)} / ${_formatDuration(_total)}',
              style: TextStyle(
                fontSize: 11,
                color: tint.withValues(alpha: 0.85),
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _formatDuration(Duration d) {
  final m = d.inMinutes;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final MessageStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sending:
        return const SizedBox(
          width: 11,
          height: 11,
          child: CircularProgressIndicator(strokeWidth: 1.4),
        );
      case MessageStatus.failed:
        return const Icon(Icons.error_outline_rounded,
            size: 13, color: AppColors.danger);
      case MessageStatus.read:
        return const Icon(Icons.done_all_rounded,
            size: 15, color: AppColors.accent);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all_rounded, size: 15, color: Colors.grey);
      case MessageStatus.sent:
        return const Icon(Icons.check_rounded, size: 14, color: Colors.grey);
    }
  }
}

/// 使用者往上翻歷史時的新訊息提示：點一下回到最新。
class _NewMessagesPill extends StatelessWidget {
  const _NewMessagesPill({
    required this.label,
    required this.count,
    required this.onTap,
  });

  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.brand,
            borderRadius: BorderRadius.circular(22),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.arrow_downward_rounded,
                size: 15,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                count > 1 ? '$label · $count' : label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 底部輸入框。
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onChanged,
    required this.onPickImage,
    required this.onToggleRecord,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final VoidCallback onChanged;
  final VoidCallback onPickImage;
  final VoidCallback onToggleRecord;

  /// 實體鍵盤：Shift+Enter 送出訊息，單按 Enter 維持原本的換行行為。
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.enter &&
        key != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    // 輸入法組字中（例如中文候選詞），Enter 是確認候選字，不送出。
    final composing = controller.value.composing;
    if (composing.isValid && !composing.isCollapsed) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    final isShiftEnter = keyboard.isShiftPressed &&
        !keyboard.isControlPressed &&
        !keyboard.isAltPressed &&
        !keyboard.isMetaPressed;
    if (!isShiftEnter) return KeyEventResult.ignored;
    // 一律吃掉事件，避免平台再補一個換行進輸入框。
    if (controller.text.trim().isNotEmpty) onSend();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final hasText = controller.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.07),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Semantics(
              button: true,
              child: Tooltip(
                message: s.chatSendImage,
                child: InkWell(
                  onTap: onPickImage,
                  borderRadius: BorderRadius.circular(26),
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.image_rounded,
                      size: 22,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
            Semantics(
              button: true,
              child: Tooltip(
                message: s.chatRecord,
                child: InkWell(
                  onTap: onToggleRecord,
                  borderRadius: BorderRadius.circular(26),
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.mic_rounded,
                      size: 22,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              // 用 Focus 攔截實體鍵盤事件：Shift+Enter 送出，Enter 維持換行。
              child: Focus(
                canRequestFocus: false,
                onKeyEvent: _handleKeyEvent,
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    keyboardType: TextInputType.multiline,
                    onChanged: (_) => onChanged(),
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: s.chatHint,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Semantics(
              button: true,
              child: Tooltip(
                message: s.chatEnterTip,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onSend();
                  },
                  borderRadius: BorderRadius.circular(26),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: hasText ? AppColors.brandGradient : null,
                      color: hasText
                          ? null
                          : theme.colorScheme.onSurface.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.send_rounded,
                      size: 21,
                      color: hasText
                          ? Colors.white
                          : theme.colorScheme.onSurface
                              .withValues(alpha: 0.35),
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
}
