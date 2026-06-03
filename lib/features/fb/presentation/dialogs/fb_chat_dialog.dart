// lib/features/fb/presentation/dialogs/fb_chat_dialog.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smf_app/features/alarm/domain/sleep_session.dart';
import 'package:smf_app/features/fb/infrastructure/api/rag_analyze_client.dart';
import 'package:smf_app/features/fb/infrastructure/payload/sleep_payload_builder.dart';

class FbChatDialog extends StatefulWidget {
  const FbChatDialog({super.key, required this.session, required this.memo});

  final SleepSession session;
  final String memo;

  @override
  State<FbChatDialog> createState() => _FbChatDialogState();
}

class _FbChatDialogState extends State<FbChatDialog> {
  final _ragClient = RagAnalyzeClient();
  final _payloadBuilder = SleepPayloadBuilder();
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  /// [{role: 'user'|'assistant', content: '...'}]
  final List<Map<String, String>> _messages = [];
  bool _isSending = false;

  String get _prefsKey => 'fb_chat_history_${widget.session.id}';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => Map<String, String>.from(e as Map))
          .toList();
      if (mounted) {
        setState(() => _messages.addAll(list));
        _scrollToBottom();
      }
    } catch (_) {
      await prefs.remove(_prefsKey);
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_messages));
  }

  Future<void> _sendMessage() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _isSending) return;

    _textCtrl.clear();
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isSending = true;
    });

    _scrollToBottom();

    // history は直前のやり取り（最後のアシスタントメッセージより前）を渡す
    final history = _messages
        .take(_messages.length - 1)
        .map((m) => {'role': m['role']!, 'content': m['content']!})
        .toList();

    try {
      final payload = await _payloadBuilder.build(
        targetSession: widget.session,
      );
      final result = await _ragClient.analyze(
        query: text,
        adviceType: 'chat',
        sleepData: payload,
        chatHistory: history,
      );
      final reply = result.text;

      if (mounted) {
        setState(() {
          _messages.add({'role': 'assistant', 'content': reply});
          _isSending = false;
        });
        _scrollToBottom();
        await _saveHistory();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': '申し訳ありません。エラーが発生しました。もう一度お試しください。',
          });
          _isSending = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        children: [
          // ヘッダー
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'AI睡眠アドバイザー',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Divider(),

          // メッセージ一覧
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '睡眠についての質問をどうぞ',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '例：「もっと深く寝るには？」',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    itemCount: _messages.length + (_isSending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _isSending) {
                        return _buildTypingIndicator();
                      }
                      final msg = _messages[index];
                      final isUser = msg['role'] == 'user';
                      return _buildMessageBubble(
                        text: msg['content']!,
                        isUser: isUser,
                      );
                    },
                  ),
          ),

          const SizedBox(height: 8),

          // 入力エリア
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textCtrl,
                  enabled: !_isSending,
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: '質問を入力...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: _isSending ? Colors.grey : Colors.blue,
                child: IconButton(
                  onPressed: _isSending ? null : _sendMessage,
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({required String text, required bool isUser}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.blue.shade100,
              child: const Icon(
                Icons.auto_awesome,
                size: 16,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? Colors.blue : Colors.grey.shade100,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
                  bottomRight: isUser ? Radius.zero : const Radius.circular(16),
                ),
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black87,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 6),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Colors.blue.shade100,
            child: const Icon(Icons.auto_awesome, size: 16, color: Colors.blue),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const SizedBox(
              width: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _DotBlink(delay: 0),
                  _DotBlink(delay: 200),
                  _DotBlink(delay: 400),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DotBlink extends StatefulWidget {
  const _DotBlink({required this.delay});
  final int delay;

  @override
  State<_DotBlink> createState() => _DotBlinkState();
}

class _DotBlinkState extends State<_DotBlink>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.grey,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
