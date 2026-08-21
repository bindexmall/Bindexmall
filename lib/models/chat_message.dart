// ============================================================================
// MODEL: ChatMessage / QuickReply / MessageType / SenderType
// ============================================================================
// Struktur data untuk fitur live chat / chatbot (bukan WhatsApp — chat internal app).
//
// Isi/tanggung jawab utama:
//  - MessageType & SenderType: enum status pesan (text/image, user/bot/admin).
//  - QuickReply: tombol balasan cepat yang ditampilkan chatbot.
//  - Dipakai oleh live_chat_screen.dart & services/chatbot_service.dart.
// ============================================================================

// lib/models/chat_message.dart

enum MessageType {
  text,
  image,
  quickReply,
}

enum SenderType {
  user,
  bot,
  agent,
}

class ChatMessage {
  final String id;
  final String message;
  final MessageType type;
  final SenderType sender;
  final DateTime timestamp;
  final List<QuickReply>? quickReplies;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.message,
    required this.type,
    required this.sender,
    required this.timestamp,
    this.quickReplies,
    this.isRead = false,
  });

  ChatMessage copyWith({
    String? id,
    String? message,
    MessageType? type,
    SenderType? sender,
    DateTime? timestamp,
    List<QuickReply>? quickReplies,
    bool? isRead,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      message: message ?? this.message,
      type: type ?? this.type,
      sender: sender ?? this.sender,
      timestamp: timestamp ?? this.timestamp,
      quickReplies: quickReplies ?? this.quickReplies,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message': message,
      'type': type.toString(),
      'sender': sender.toString(),
      'timestamp': timestamp.toIso8601String(),
      'quickReplies': quickReplies?.map((e) => e.toJson()).toList(),
      'isRead': isRead,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      message: json['message'],
      type: MessageType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => MessageType.text,
      ),
      sender: SenderType.values.firstWhere(
        (e) => e.toString() == json['sender'],
        orElse: () => SenderType.bot,
      ),
      timestamp: DateTime.parse(json['timestamp']),
      quickReplies: json['quickReplies'] != null
          ? (json['quickReplies'] as List)
              .map((e) => QuickReply.fromJson(e))
              .toList()
          : null,
      isRead: json['isRead'] ?? false,
    );
  }
}

class QuickReply {
  final String id;
  final String text;
  final String action;

  QuickReply({
    required this.id,
    required this.text,
    required this.action,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'action': action,
    };
  }

  factory QuickReply.fromJson(Map<String, dynamic> json) {
    return QuickReply(
      id: json['id'],
      text: json['text'],
      action: json['action'],
    );
  }
}