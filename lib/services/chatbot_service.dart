// ============================================================================
// SERVICE: ChatbotService / BotResponse
// ============================================================================
// Chatbot RULE-BASED sederhana (bukan AI/LLM) — jawaban disimpan statis di
// _responses map (mis. greeting, FAQ, dsb) dengan delay simulasi mengetik.
//
// Isi/tanggung jawab utama:
//  - Kalau mau nambah topik FAQ baru, tambahkan entry baru di _responses.
//  - Untuk chat manusia real-time, app ini pakai Tawk.to (lihat tawk_service.dart) — ini beda fitur.
// ============================================================================

// lib/services/chatbot_service.dart

import 'dart:async';
import '../models/chat_message.dart';

class ChatbotService {
  // Simulate typing delay
  static const Duration _typingDelay = Duration(milliseconds: 1500);

  // Bot responses database
  static final Map<String, BotResponse> _responses = {
    'greeting': BotResponse(
      message:
          'Halo! 👋 Selamat datang di Bindexmall.\n\nSaya adalah asisten virtual Bindexmall. Ada yang bisa saya bantu?',
      quickReplies: [
        QuickReply(id: '1', text: '📦 Lacak Pesanan', action: 'track_order'),
        QuickReply(id: '2', text: '🔄 Return/Refund', action: 'return_refund'),
        QuickReply(id: '3', text: '💳 Metode Pembayaran', action: 'payment'),
        QuickReply(id: '4', text: '👤 Hubungi CS', action: 'contact_agent'),
      ],
    ),
    'track_order': BotResponse(
      message:
          'Untuk melacak pesanan Anda:\n\n1. Buka menu "Pesanan Saya" di halaman Profil\n2. Pilih pesanan yang ingin dilacak\n3. Lihat status pengiriman real-time\n\nAtau, silakan berikan nomor pesanan Anda, saya akan bantu cek statusnya! 📦',
      quickReplies: [
        QuickReply(id: '1', text: '✅ Sudah jelas', action: 'greeting'),
        QuickReply(id: '2', text: '👤 Hubungi CS', action: 'contact_agent'),
      ],
    ),
    'return_refund': BotResponse(
      message:
          'Kebijakan Return & Refund Bindexmall:\n\n✅ Return dapat dilakukan dalam 7 hari\n✅ Produk harus dalam kondisi asli\n✅ Refund diproses 3-5 hari kerja\n\nCara mengajukan return:\n1. Buka detail pesanan\n2. Klik "Ajukan Return"\n3. Pilih alasan & upload foto\n4. Tunggu persetujuan\n\nApakah ada pesanan spesifik yang ingin di-return?',
      quickReplies: [
        QuickReply(id: '1', text: 'Ya, ada pesanan', action: 'contact_agent'),
        QuickReply(id: '2', text: '✅ Sudah jelas', action: 'greeting'),
      ],
    ),
    'payment': BotResponse(
      message:
          'Metode Pembayaran yang tersedia:\n\n💳 Transfer Bank\n• BCA, Mandiri, BNI, BRI\n\n📱 E-Wallet\n• GoPay, OVO, DANA, ShopeePay\n\n💰 Kartu Kredit/Debit\n• Visa, Mastercard, JCB\n\n💵 COD (Cash on Delivery)\n• Tersedia di area tertentu\n\nSemua pembayaran dijamin aman! 🔒',
      quickReplies: [
        QuickReply(id: '1', text: '📦 Lacak Pesanan', action: 'track_order'),
        QuickReply(id: '2', text: '🔄 Return/Refund', action: 'return_refund'),
        QuickReply(id: '3', text: '👤 Hubungi CS', action: 'contact_agent'),
      ],
    ),
    'contact_agent': BotResponse(
      message:
          'Baik, saya akan menghubungkan Anda dengan Customer Service kami. ⏳\n\nAnda juga bisa menghubungi kami melalui:\n\n📧 Email: marketing@bambimeganiaga.co.id\n📱 WhatsApp: +62 822-2173-6953\n☎️ Phone: +62 822-2173-6953\n\nTim kami akan segera membantu Anda!',
      quickReplies: [
        QuickReply(id: '1', text: '🔙 Kembali ke Menu', action: 'greeting'),
      ],
    ),
    'shipping': BotResponse(
      message:
          'Informasi Pengiriman:\n\n📦 Estimasi Waktu:\n• Jawa: 2-5 hari kerja\n• Luar Jawa: 3-7 hari kerja\n• Papua & Maluku: 5-10 hari kerja\n\n🚚 Partner Kurir:\n• JNE, J&T, SiCepat, AnterAja\n\nOngkir dihitung otomatis saat checkout.',
      quickReplies: [
        QuickReply(id: '1', text: '📦 Lacak Pesanan', action: 'track_order'),
        QuickReply(id: '2', text: '🔙 Menu Utama', action: 'greeting'),
      ],
    ),
    'promo': BotResponse(
      message:
          'Promo Terbaru! 🎉\n\n🔥 Flash Sale Setiap Hari\n💰 Diskon hingga 70%\n🎁 Gratis Ongkir min. 50rb\n🌟 Cashback hingga 100rb\n\nCek halaman Deals untuk promo terbaru!',
      quickReplies: [
        QuickReply(id: '1', text: '🛍️ Lihat Deals', action: 'view_deals'),
        QuickReply(id: '2', text: '🔙 Menu Utama', action: 'greeting'),
      ],
    ),
    'account': BotResponse(
      message:
          'Bantuan Akun:\n\n👤 Edit Profil\n🔐 Ganti Password\n📍 Kelola Alamat\n🔔 Pengaturan Notifikasi\n\nSemuanya bisa diakses dari halaman Profil Anda.',
      quickReplies: [
        QuickReply(id: '1', text: '✅ Sudah jelas', action: 'greeting'),
        QuickReply(id: '2', text: '👤 Hubungi CS', action: 'contact_agent'),
      ],
    ),
  };

  // Keywords mapping
  static final Map<String, String> _keywordMapping = {
    // Greetings
    'halo': 'greeting',
    'hai': 'greeting',
    'hi': 'greeting',
    'hello': 'greeting',
    'pagi': 'greeting',
    'siang': 'greeting',
    'sore': 'greeting',
    'malam': 'greeting',

    // Track order
    'lacak': 'track_order',
    'track': 'track_order',
    'cek pesanan': 'track_order',
    'pesanan': 'track_order',
    'order': 'track_order',
    'resi': 'track_order',

    // Return/Refund
    'return': 'return_refund',
    'refund': 'return_refund',
    'pengembalian': 'return_refund',
    'komplain': 'return_refund',
    'rusak': 'return_refund',
    'salah': 'return_refund',

    // Payment
    'bayar': 'payment',
    'pembayaran': 'payment',
    'payment': 'payment',
    'transfer': 'payment',
    'gopay': 'payment',
    'ovo': 'payment',
    'dana': 'payment',
    'cod': 'payment',

    // Shipping
    'kirim': 'shipping',
    'pengiriman': 'shipping',
    'ongkir': 'shipping',
    'kurir': 'shipping',
    'jne': 'shipping',
    'j&t': 'shipping',

    // Promo
    'promo': 'promo',
    'diskon': 'promo',
    'discount': 'promo',
    'voucher': 'promo',
    'cashback': 'promo',
    'gratis': 'promo',

    // Account
    'akun': 'account',
    'account': 'account',
    'profil': 'account',
    'profile': 'account',
    'password': 'account',
    'alamat': 'account',

    // Contact agent
    'cs': 'contact_agent',
    'customer service': 'contact_agent',
    'hubungi': 'contact_agent',
    'manusia': 'contact_agent',
    'agent': 'contact_agent',
  };

  // Get bot response based on user message
  static Future<ChatMessage> getBotResponse(String userMessage) async {
    // Simulate typing delay
    await Future.delayed(_typingDelay);

    String responseKey = _findResponseKey(userMessage.toLowerCase());
    BotResponse botResponse =
        _responses[responseKey] ?? _responses['greeting']!;

    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      message: botResponse.message,
      type: MessageType.text,
      sender: SenderType.bot,
      timestamp: DateTime.now(),
      quickReplies: botResponse.quickReplies,
    );
  }

  // Find appropriate response key based on keywords
  static String _findResponseKey(String message) {
    // Check for exact matches first
    if (_responses.containsKey(message)) {
      return message;
    }

    // Check for keyword matches
    for (var entry in _keywordMapping.entries) {
      if (message.contains(entry.key)) {
        return entry.value;
      }
    }

    // Default response
    return 'greeting';
  }

  // Get initial greeting
  static ChatMessage getInitialGreeting() {
    BotResponse greeting = _responses['greeting']!;
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      message: greeting.message,
      type: MessageType.text,
      sender: SenderType.bot,
      timestamp: DateTime.now(),
      quickReplies: greeting.quickReplies,
    );
  }

  // Handle quick reply action
  static Future<ChatMessage> handleQuickReply(String action) async {
    await Future.delayed(_typingDelay);

    BotResponse? botResponse = _responses[action];

    if (botResponse == null) {
      // Handle special actions
      if (action == 'view_deals') {
        return ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          message: 'Membuka halaman Deals untuk Anda... 🛍️',
          type: MessageType.text,
          sender: SenderType.bot,
          timestamp: DateTime.now(),
        );
      }

      botResponse = _responses['greeting']!;
    }

    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      message: botResponse.message,
      type: MessageType.text,
      sender: SenderType.bot,
      timestamp: DateTime.now(),
      quickReplies: botResponse.quickReplies,
    );
  }
}

// Bot response model
class BotResponse {
  final String message;
  final List<QuickReply>? quickReplies;

  BotResponse({
    required this.message,
    this.quickReplies,
  });
}
