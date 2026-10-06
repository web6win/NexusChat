import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import '../../data/media/media_size.dart';
import '../../data/models/chat_models.dart';
import '../../data/models/group_models.dart';
import '../../data/waku/message_content.dart';
import '../../shared/feedback.dart';
import '../../shared/layout.dart';
import '../../shared/widgets.dart';
import '../../state/controllers.dart';
import 'image_viewer_page.dart';

/// 单一对话的完整画面：讯息串 + 输入框（含图片 / 语音）。
class ChatView extends ConsumerStatefulWidget {
  const ChatView({
    this.peerDid,
    this.groupId,
    super.key,
    this.showBack = false,
    this.onBack,
  });

  /// 一对一对话的对方 DID。群组模式时为 null。
  final String? peerDid;

  /// 群组模式时的群组 id（网址 `?group=` 带入）。
  final String? groupId;
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

  /// 是否停在底部：只有贴著底部时才自动卷动，避免打断往上翻历史的人。
  bool _atBottom = true;

  /// 使用者正在手动卷动（拖曳 / 甩动）：此时禁止自动卷到底，避免打架。
  bool _userScrolling = false;

  /// 使用者不在底部时累积的新讯息数（显示「新讯息」浮标）。
  int _pendingNew = 0;

  String? _lastMessageId;

  /// 讯息入场动画用：初次载入就存在、或已经播放过动画的讯息 id。
  /// 用它避免旧讯息在「卷动进视野」时反复播放入场动画。
  final Set<String> _seenMessageIds = {};
  bool _seenSeeded = false;

  /// 待发送的图片（已压缩）。
  Uint8List? _pendingImageBytes;
  String? _pendingImageMime;
  String? _pendingImageName;

  /// 待发送的语音（已录制完成，等待使用者确认送出）。
  Uint8List? _pendingAudioBytes;
  String? _pendingAudioMime;
  int? _pendingAudioDur;
  String? _pendingAudioName;

  /// 是否正在录音。
  bool _recording = false;
  int _recordMs = 0;
  Timer? _recordTimer;

  /// 距离底部多少 px 内都算「在底部」。
  static const _bottomThreshold = 120.0;

  bool get _isGroup => widget.groupId != null;

  /// 统一的会话键：群组为 `grp:<id>`，一对一为对方 DID。
  String get _peerKey =>
      _isGroup ? 'grp:${widget.groupId}' : (widget.peerDid ?? '');

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatControllerProvider.notifier).markRead(_peerKey);
      _scrollToEnd();
    });
  }

  @override
  void didUpdateWidget(covariant ChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.peerDid != widget.peerDid ||
        oldWidget.groupId != widget.groupId) {
      // 换了对话：重新开始追踪，并直接落在最新一则。
      _lastMessageId = null;
      _pendingNew = 0;
      _atBottom = true;
      _seenSeeded = false;
      _seenMessageIds.clear();
      _clearPending();
      ref.read(chatControllerProvider.notifier).markRead(_peerKey);
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
      // 自己滑回底部就视为已读，清掉提示。
      if (atBottom) _pendingNew = 0;
    });
  }

  /// 收到新讯息时：贴著底部就自动卷到底，否则只提示、不打断阅读。
  /// 若使用者正在拖曳，先不要卷，等手放开再判断。
  void _autoScrollOnNewMessages(List<ChatMessage> messages) {
    if (messages.isEmpty) return;
    final lastId = messages.last.id;
    if (lastId == _lastMessageId) return;
    final isFirstRender = _lastMessageId == null;
    _lastMessageId = lastId;
    // 首次进场由 initState 统一处理，不要在这里多卷一次。
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

  /// 侦测使用者手势开始 / 结束，避免自动卷动跟使用者拖曳打架。
  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      if (mounted) setState(() => _userScrolling = true);
    } else if (notification is ScrollEndNotification) {
      if (mounted) {
        setState(() {
          _userScrolling = false;
          // 手势结束时若已经在底部，顺手清提示。
          if (_atBottom) _pendingNew = 0;
        });
      }
      // 使用者滑到底放手后，若有新讯息搁置，立刻带过去。
      if (_atBottom && _pendingNew > 0) {
        _scrollToEnd();
      }
    }
    return false;
  }

  /// 是否允许撤回：必须是自己发出、已送出（非失败）且尚未撤回。
  bool _canRecall(ChatMessage message) =>
      message.outgoing &&
      message.status != MessageStatus.failed &&
      message.recalledAtMs == null;

  /// 共用的确认对话框，回传使用者是否按下确认。
  Future<bool?> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
  }) {
    final s = context.s;
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  /// 删除单则讯息（只删本机，对方仍看得到）。
  Future<void> _deleteMessage(ChatMessage message) async {
    final s = context.s;
    final ok = await _confirm(
      title: s.delete,
      body: s.chatDeleteMessageConfirm,
      confirmLabel: s.delete,
    );
    if (ok != true) return;
    await ref.read(chatControllerProvider.notifier).deleteMessage(message.id);
    if (!mounted) return;
    showAppSnack(context, s.chatMessageDeleted);
  }

  /// 撤回自己发出的讯息：双方都改显示「讯息已撤回」。
  Future<void> _recallMessage(ChatMessage message) async {
    final s = context.s;
    final ok = await _confirm(
      title: s.chatRecall,
      body: s.chatRecallConfirm,
      confirmLabel: s.chatRecall,
    );
    if (ok != true) return;
    final done = await ref
        .read(chatControllerProvider.notifier)
        .recallMessage(message.id);
    if (!mounted) return;
    if (!done) showAppSnack(context, s.errorGeneric, danger: true);
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
      // 离开页面时若还在录音，直接停掉（舍弃）。
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
    // 画面已经带到最新，顺手标为已读。
    ref.read(chatControllerProvider.notifier).markRead(_peerKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      // 已经贴底就不要再触发动画，避免跟手势打架。
      if (_scroll.offset >= target - 2) return;
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    // 少数平台会把 Enter 的换行插进文字里，送出前先去掉尾部空白。
    final text = _controller.text.trimRight();
    if (text.trim().isEmpty) return;
    _controller.clear();
    setState(() {
      // 自己发的讯息一律带到最新，并清掉「新讯息」提示。
      _pendingNew = 0;
      _atBottom = true;
    });
    // 若换行是在按键事件之后才被补进来，下一帧再清一次，避免残留空行。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_controller.text.trim().isEmpty) _controller.clear();
    });
    final controller = ref.read(chatControllerProvider.notifier);
    if (_isGroup) {
      await controller.sendGroupContent(
        widget.groupId!,
        MessageContent.text(text),
      );
    } else {
      await controller.sendContent(widget.peerDid!, MessageContent.text(text));
    }
    _scrollToEnd();
    ref.read(chatControllerProvider.notifier).markRead(_peerKey);
  }

  // ------------------------------------------------------------------ 图片

  Future<void> _pickImage() async {
    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.gallery,
        // Web 端刻意不传 imageQuality：image_picker_for_web 会走 canvas 重新
        // 编码，该路径在部分浏览器 / 图片格式上会直接抛错（PC 浏览器尤其常见）。
        // 反正后面 compressImage 还会再压一次，这里省掉不会有损失。
        imageQuality: kIsWeb ? null : 85,
      );
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      // 选图期间使用者可能已离开页面：避免在已 dispose 的 State 上 setState。
      if (!mounted) return;
      final compressed = compressImage(Uint8List.fromList(bytes));
      if (compressed == null) {
        // 无法解码（例如 iPhone 的 HEIC）：原样送出对方也解不开，
        // 只会看到破图，因此直接挡在这里并提示改用 JPG / PNG。
        _showError(context.s.chatImageUnsupported);
        return;
      }
      // 用同一份预算检查（kMaxMediaBytes），避免这里放行、送出时却被挡下。
      if (compressed.length > kMaxMediaBytes) {
        _showError(context.s.chatMediaTooLarge);
        return;
      }
      setState(() {
        _pendingImageBytes = compressed;
        _pendingImageMime = 'image/jpeg';
        _pendingImageName = xfile.name;
      });
    } catch (error, stackTrace) {
      // 这里会吞掉真实原因，务必留下痕迹，否则只能看到误导性的权限提示。
      debugPrint('pickImage failed: $error\n$stackTrace');
      // 网页没有「相簿权限」概念，那条文案在浏览器上是错的。
      _showError(
        kIsWeb ? context.s.chatImagePickFailed : context.s.chatPermissionPhotos,
      );
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
    final controller = ref.read(chatControllerProvider.notifier);
    if (_isGroup) {
      await controller.sendGroupContent(widget.groupId!, content);
    } else {
      await controller.sendContent(widget.peerDid!, content);
    }
    _scrollToEnd();
  }

  // ------------------------------------------------------------------ 录音

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
      // 录音启动前若已离开页面，不要回头 setState。
      if (!mounted) return;
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
    // 停止录音前若已离开页面，不要回头 setState。
    if (!mounted) return;
    setState(() => _recording = false);
    if (path == null || path.isEmpty) return;
    final bytes = await readRecordedBytes(path);
    if (bytes.isEmpty || _recordMs < 800) {
      // 太短视为误触，直接舍弃。
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
    final controller = ref.read(chatControllerProvider.notifier);
    if (_isGroup) {
      await controller.sendGroupContent(widget.groupId!, content);
    } else {
      await controller.sendContent(widget.peerDid!, content);
    }
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
    final groupChats = _isGroup
        ? state.groups.where((g) => g.id == widget.groupId).toList()
        : const <GroupChat>[];
    final group = groupChats.isNotEmpty ? groupChats.first : null;
    final contact = contacts
        .where(
          (c) => c.did.toLowerCase() == (widget.peerDid ?? '').toLowerCase(),
        )
        .toList();
    final name = _isGroup
        ? (group != null && group.name.isNotEmpty ? group.name : s.groupTitle)
        : (contact.isNotEmpty
            ? contact.first.name
            : Did.shortDid(widget.peerDid ?? ''));
    final color = _isGroup
        ? AppColors.brand
        : (contact.isNotEmpty ? contact.first.accent : AppColors.brand);

    final messages = state.forPeer(_peerKey);

    // 初次进场把所有既存讯息标记为「已见」，避免一进页面就整批播放入场动画；
    // 之后新送达的讯息才会有淡入上滑的入场效果。
    if (!_seenSeeded) {
      _seenSeeded = true;
      _seenMessageIds.addAll(messages.map((m) => m.id));
    }

    // 用 ref.listen 侦测讯息列表变化，不要直接在 build() 里卷动，
    // 否则图片载入、键盘弹出等重建都会干扰使用者手势。
    ref.listen<ChatState>(chatControllerProvider, (previous, next) {
      final prevMessages = previous?.forPeer(_peerKey) ?? [];
      final nextMessages = next.forPeer(_peerKey);
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
                          _isGroup
                              ? s.groupMembers(group?.memberDids.length ?? 0)
                              : s.chatEncrypted,
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
                case 'info':
                  context.go('/group-info?group=${widget.groupId}');
                  break;
                case 'leave':
                  final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(s.groupLeaveTitle),
                          content: Text(s.groupLeaveConfirm),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(s.cancel),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(
                                s.leave,
                                style:
                                    const TextStyle(color: AppColors.danger),
                              ),
                            ),
                          ],
                        ),
                      ) ??
                      false;
                  if (confirmed) {
                    await controller.leaveGroup(widget.groupId!);
                    if (widget.onBack != null) widget.onBack!();
                  }
                  break;
                case 'pin':
                  await controller.togglePin(_peerKey);
                  break;
                case 'delete':
                  final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(_isGroup
                              ? s.groupDeleteTitle
                              : s.chatDeleteTitle),
                          content: Text(_isGroup
                              ? s.groupDeleteConfirm
                              : s.chatDeleteConfirm(name)),
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
                    if (_isGroup) {
                      await controller.deleteGroup(widget.groupId!);
                    } else {
                      await controller.deleteConversation(widget.peerDid!);
                    }
                    if (widget.onBack != null) widget.onBack!();
                  }
                  break;
              }
            },
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              if (_isGroup)
                PopupMenuItem<String>(
                  value: 'info',
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.info_outline_rounded, size: 19),
                      const SizedBox(width: 12),
                      Text(s.groupInfo),
                    ],
                  ),
                ),
              if (_isGroup)
                PopupMenuItem<String>(
                  value: 'leave',
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.exit_to_app_rounded,
                          size: 19, color: AppColors.danger),
                      const SizedBox(width: 12),
                      Text(s.leave,
                          style: const TextStyle(color: AppColors.danger)),
                    ],
                  ),
                ),
              if (!_isGroup)
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
                                final current = messages[index - 1];
                                final previous =
                                    index >= 2 ? messages[index - 2] : null;
                                final next = index < messages.length
                                    ? messages[index]
                                    : null;
                                final showDay = previous == null ||
                                    _dayKey(previous.timestamp) !=
                                        _dayKey(current.timestamp);
                                final samePrev = previous != null &&
                                    previous.outgoing == current.outgoing;
                                final sameNext = next != null &&
                                    next.outgoing == current.outgoing;
                                // 同日、同方向（同一发送者）的连续讯息视为同一组：
                                // 组内靠拢、只在组尾显示时间，气泡转角收小以「并排」。
                                final groupedWithPrevious = !showDay && samePrev;
                                final groupedWithNext = !showDay && sameNext;
                                final showMeta = showDay || !sameNext;
                                final animate =
                                    !_seenMessageIds.contains(current.id);
                                // 真正的新讯息只播放一次入场动画。
                                if (animate) _seenMessageIds.add(current.id);
                                return Column(
                                  children: <Widget>[
                                    if (showDay)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        child: Center(
                                          child: Text(
                                            Formatters.dayLabel(
                                                current.timestamp, s),
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.45),
                                            ),
                                          ),
                                        ),
                                      ),
                                    _AnimatedAppear(
                                      animate: animate,
                                      child: MessageBubble(
                                      message: current,
                                      color: color,
                                      senderName: _isGroup && !current.outgoing
                                          ? _senderName(
                                              current.senderDid,
                                              contacts,
                                              s,
                                            )
                                          : null,
                                      showMeta: showMeta,
                                        groupedWithPrevious: groupedWithPrevious,
                                        groupedWithNext: groupedWithNext,
                                        onRetry: () => ref
                                            .read(
                                                chatControllerProvider.notifier)
                                            .retry(current.id),
                                        onDelete: () => _deleteMessage(current),
                                        onRecall: _canRecall(current)
                                            ? () => _recallMessage(current)
                                            : null,
                                      ),
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

  // -------------------------------------------------- 待发送预览 / 录音条

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

  /// 群组讯息用的发送者显示名：自己显示「你」，其余取通讯录名称，否则取短 DID。
  String _senderName(String? did, List<Contact> contacts, Strings s) {
    if (did == null) return '';
    if (did.toLowerCase() == ref.read(coreProvider).did.toLowerCase()) {
      return s.groupYou;
    }
    final match =
        contacts.where((c) => c.did.toLowerCase() == did.toLowerCase());
    if (match.isNotEmpty) return match.first.name;
    return Did.shortDid(did);
  }
}

/// 解码已保存的媒体 Base64。
///
/// null、空字串，或内容不是合法 Base64 时一律回传 null（视为「没有媒体」）。
/// 这样呼叫端不必再各自处理例外，也不会把空字串喂给 `Image.memory` /
/// 播放器造成塌陷或崩溃。
Uint8List? _decodeMediaBytes(String? b64) {
  if (b64 == null || b64.isEmpty) return null;
  final cached = _mediaBytesCache[b64];
  if (cached != null) return cached;
  try {
    final bytes = base64Decode(b64);
    if (bytes.isEmpty) return null;
    // 有界快取：超过上限时丢掉最旧的一笔，避免长期占用记忆体。
    if (_mediaBytesCache.length >= _mediaBytesCacheLimit) {
      _mediaBytesCache.remove(_mediaBytesCache.keys.first);
    }
    _mediaBytesCache[b64] = bytes;
    return bytes;
  } catch (_) {
    return null;
  }
}

/// base64 内容 → 解码后位元组的快取（插入序，超过上限丢最旧）。
///
/// 为什么需要它：`Image.memory` 内部以 `MemoryImage` 为图片快取键，而该键
/// 的相等性取决于**位元组物件的身份**。若每次 build 都重新 base64 解码，就会
/// 产生新的 `Uint8List`，图片快取永远命不中、每次重绘都重新非同步解码，
/// 在解码完成前的那一帧尺寸为 0，气泡便塌成一个看不懂的小圆点（卷动列表时
/// 因频繁重建而特别明显）。快取同一段 base64 的解码结果，让每次 build 拿到
/// 同一个物件，即可命中图片快取、稳定显示。
final Map<String, Uint8List> _mediaBytesCache = <String, Uint8List>{};
const int _mediaBytesCacheLimit = 32;

/// 媒体无法显示时的替代方块（固定尺寸，避免气泡塌成一个小点）。
class _MediaUnavailable extends StatelessWidget {
  const _MediaUnavailable({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.45);
    return Container(
      width: 180,
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.broken_image_outlined, size: 26, color: muted),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// 讯息气泡：依种类渲染文字 / 图片 / 语音。
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    required this.color,
    this.senderName,
    super.key,
    this.onRetry,
    this.onDelete,
    this.onRecall,
    this.showMeta = true,
    this.groupedWithPrevious = false,
    this.groupedWithNext = false,
  });

  final ChatMessage message;
  final Color color;

  /// 群组讯息中显示的发送者名称；为 null 时不显示（一对一讯息用不到）。
  final String? senderName;
  final VoidCallback? onRetry;

  /// 删除本机讯息（确认对话框由父层处理）。
  final VoidCallback? onDelete;

  /// 撤回讯息；为 null 表示这则不允许撤回（例如对方发的、或已撤回）。
  final VoidCallback? onRecall;
  final bool showMeta;
  final bool groupedWithPrevious;
  final bool groupedWithNext;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final outgoing = message.outgoing;
    final palette = context.palette;
    final isMedia = message.kind != MediaKind.text;
    final recalled = message.recalledAtMs != null;

    return Align(
      alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: groupedWithPrevious ? 1 : 4,
          bottom: groupedWithNext ? 1 : 4,
          left: outgoing ? 56 : 0,
          right: outgoing ? 0 : 56,
        ),
        child: Column(
          crossAxisAlignment:
              outgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: <Widget>[
            if (senderName != null && senderName!.isNotEmpty && !outgoing)
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 2),
                child: Text(
                  senderName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            GestureDetector(
              // 长按开启操作选单：复制 / 撤回 / 删除。
              onLongPress: () => _showMessageMenu(context, s),
              child: Container(
                padding: isMedia && !recalled
                    ? const EdgeInsets.all(4)
                    : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: outgoing ? AppColors.brandGradient : null,
                  color: outgoing ? null : palette.bubbleOther,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(
                        outgoing ? 18 : (groupedWithPrevious ? 6 : 18)),
                    topRight: Radius.circular(
                        outgoing ? (groupedWithPrevious ? 6 : 18) : 18),
                    bottomLeft: Radius.circular(
                        outgoing ? 18 : (groupedWithNext ? 6 : 18)),
                    bottomRight: Radius.circular(
                        outgoing ? (groupedWithNext ? 6 : 18) : 18),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: palette.shadow.withValues(alpha: 0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: recalled
                    ? _recalledContent(outgoing, palette, s)
                    : _bubbleContent(context, outgoing, palette, s),
              ),
            ),
            if (showMeta)
              Padding(
                padding: const EdgeInsets.only(top: 3, left: 6, right: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      Formatters.clock(message.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.42),
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

  /// 已撤回讯息的占位内容：不再显示原文，只留一行提示。
  Widget _recalledContent(bool outgoing, palette, Strings s) {
    final textColor = (outgoing ? palette.bubbleMeText : palette.bubbleOtherText)
        .withValues(alpha: 0.8);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.undo_rounded, size: 14, color: textColor),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            s.chatRecalled,
            style: TextStyle(
              fontSize: 13.5,
              fontStyle: FontStyle.italic,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }

  /// 长按气泡后的操作选单：复制 / 撤回 / 删除。
  ///
  /// 撤回只对自己发出的讯息出现（[onRecall] 为 null 时不显示该项）；
  /// 删除则一律可用，但它只影响本机，对方仍看得到原讯息。
  void _showMessageMenu(BuildContext context, Strings s) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (message.kind == MediaKind.text && message.text.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: Text(s.copy),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Clipboard.setData(ClipboardData(text: message.text));
                },
              ),
            if (onRecall != null)
              ListTile(
                leading: const Icon(Icons.undo_rounded),
                title: Text(s.chatRecall),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onRecall!();
                },
              ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.danger,
              ),
              title: Text(
                s.delete,
                style: const TextStyle(color: AppColors.danger),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                onDelete?.call();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 开启全萤图片检视页。
  ///
  /// 用 MaterialPageRoute 而不是 router：图片位元组只在记忆体里，没必要
  /// （也无法）放进 URL。
  void _openImageViewer(BuildContext context, Uint8List bytes) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ImageViewerPage(
          bytes: bytes,
          fileName: imageFileNameFor(message.mediaName, message.timestampMs),
        ),
      ),
    );
  }

  Widget _bubbleContent(BuildContext context, bool outgoing, palette, Strings s) {
    switch (message.kind) {
      case MediaKind.image:
        final bytes = _decodeMediaBytes(message.mediaB64);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (bytes == null)
              _MediaUnavailable(label: s.chatImageUnavailable)
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 240,
                    maxHeight: 280,
                  ),
                  child: GestureDetector(
                    // 点开大图：可缩放、可下载。
                    onTap: () => _openImageViewer(context, bytes),
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.cover,
                      // 解码完成前先撑出固定尺寸，避免 RenderImage 在没有
                      // 可量测的图时尺寸为 0、气泡塌成一个小点。
                      frameBuilder: (context, child, frame, wasSync) {
                        if (wasSync || frame != null) return child;
                        // 解码期间显示微光骨架，体感更「即时」、不会是空的方块。
                        return const _ShimmerBox(width: 180, height: 180, radius: 14);
                      },
                      // 图片来源不变时沿用上一帧，避免重绘时闪成空白 / 小点。
                      gaplessPlayback: true,
                      // 坏资料 / 不支援的格式：显示明确的替代方块。
                      errorBuilder: (context, error, stackTrace) =>
                          _MediaUnavailable(label: s.chatImageUnavailable),
                    ),
                  ),
                ),
              ),
            if (message.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
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
        return _AudioBubble(
          bytes: _decodeMediaBytes(message.mediaB64) ?? Uint8List(0),
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

/// 语音气泡：点击播放 / 暂停，并显示进度与时长。
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

/// 使用者往上翻历史时的新讯息提示：点一下回到最新。
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

/// 讯息入场动画：透明度 0→1 搭配轻微上滑（8% 高度）。
///
/// [animate] 为 false 时直接显示最终状态（不播动画），用来避免旧讯息在卷动
/// 进视野时反复播放。呼叫端负责决定哪些讯息才需要动画（见 `_seenMessageIds`）。
class _AnimatedAppear extends StatefulWidget {
  const _AnimatedAppear({required this.child, required this.animate});

  final Widget child;
  final bool animate;

  @override
  State<_AnimatedAppear> createState() => _AnimatedAppearState();
}

class _AnimatedAppearState extends State<_AnimatedAppear>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  late final Animation<double> _opacity =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  late final Animation<Offset> _offset = Tween<Offset>(
    begin: const Offset(0, 0.08),
    end: Offset.zero,
  ).animate(_opacity);

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedAppear oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 若从「需要动画」变成「不需要」（通常是父层重绘已把 id 标记为已见），
    // 直接停在终态，避免动画播到一半被卡住。
    if (!widget.animate && _controller.status != AnimationStatus.dismissed) {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _opacity,
        child: SlideTransition(position: _offset, child: widget.child),
      );
}

/// 图片解码期间的「微光」骨架占位：底色上一道亮带循环扫过。
class _ShimmerBox extends StatefulWidget {
  const _ShimmerBox({this.width = 180, this.height = 180, this.radius = 14});

  final double width;
  final double height;
  final double radius;

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final base = palette.softSurface;
    final highlight =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final a = (t - 0.4).clamp(0.0, 1.0);
        final b = (t - 0.1).clamp(0.0, 1.0);
        final c = (t + 0.2).clamp(0.0, 1.0);
        return ShaderMask(
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: <double>[0.0, a, b, c, 1.0],
            colors: <Color>[base, base, highlight, base, base],
          ).createShader(rect),
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(widget.radius),
            ),
          ),
        );
      },
    );
  }
}

/// 底部输入框。
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

  /// 实体键盘：Shift+Enter 送出讯息，单按 Enter 维持原本的换行行为。
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.enter &&
        key != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    // 输入法组字中（例如中文候选词），Enter 是确认候选字，不送出。
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
    // 一律吃掉事件，避免平台再补一个换行进输入框。
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
              // 用 Focus 拦截实体键盘事件：Shift+Enter 送出，Enter 维持换行。
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
