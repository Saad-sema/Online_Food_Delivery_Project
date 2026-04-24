import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/api_service.dart';

class ChatScreen extends StatefulWidget {
  final int orderId;
  final String? recipientName;
  final String myRole; // 'customer' or 'delivery_boy'
  const ChatScreen({super.key, required this.orderId, this.recipientName, this.myRole = 'delivery_boy'});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgC = TextEditingController();
  final _scrollC = ScrollController();
  List<dynamic> _messages = [];
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _loadSilent());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _msgC.dispose();
    _scrollC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService.getMessages(widget.orderId);
      if (res.data['success'] == true) _messages = res.data['data'] ?? [];
    } catch (_) {}
    setState(() => _loading = false);
    _scrollDown();
  }

  Future<void> _loadSilent() async {
    try {
      final res = await ApiService.getMessages(widget.orderId);
      if (res.data['success'] == true) {
        setState(() => _messages = res.data['data'] ?? []);
      }
    } catch (_) {}
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollC.hasClients) {
        _scrollC.animateTo(_scrollC.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final msg = _msgC.text.trim();
    if (msg.isEmpty) return;
    _msgC.clear();
    try {
      await ApiService.sendMessage(widget.orderId, msg);
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(
          widget.recipientName != null
              ? 'Chat w/ ${widget.recipientName}'
              : 'Chat – Order #${widget.orderId}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
                : _messages.isEmpty
                    ? const Center(child: Text('No messages yet. Start the conversation!', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        controller: _scrollC,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => _bubble(_messages[i]),
                      ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
            ),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _msgC,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    filled: true,
                    fillColor: const Color(0xFFF0F2F5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: const BoxDecoration(color: Color(0xFF4F46E5), shape: BoxShape.circle),
                child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: _send),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _bubble(Map<String, dynamic> m) {
    // Determine if message is from me based on sender_role matching myRole
    final senderRole = m['sender_role'] ?? '';
    final isMe = senderRole == widget.myRole;
    final timeStr = (m['created_at'] ?? m['timestamp'] ?? '').toString();
    final shortTime = timeStr.length >= 16 ? timeStr.substring(11, 16) : '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF4F46E5) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (m['sender_name'] != null && !isMe)
              Text(m['sender_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
            Text(m['message'] ?? '', style: TextStyle(color: isMe ? Colors.white : Colors.black87)),
            const SizedBox(height: 2),
            Text(shortTime, style: TextStyle(fontSize: 10, color: isMe ? Colors.white54 : Colors.grey)),
          ],
        ),
      ),
    );
  }
}
