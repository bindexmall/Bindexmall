// ============================================================================
// SERVICE: TawkService
// ============================================================================
// Generate HTML embed untuk widget live chat Tawk.to (ditampilkan di WebView).
//
// Isi/tanggung jawab utama:
//  - propertyId & widgetId Tawk.to hardcoded di sini — kalau ganti akun Tawk.to,
//  -   cukup update dua konstanta ini.
//  - Ini chat dengan ADMIN/CS manusia via Tawk.to — beda dengan chatbot_service.dart
//  -   yang rule-based dan jalan lokal di app.
// ============================================================================

// lib/services/tawk_service.dart

class TawkService {
  // Property ID dan Widget ID dari akun Tawk.to Anda
  // Dari screenshot: https://tawk.to/chat/68f6ebe4559a7e194c802005/1j828iu09
  static const String propertyId = '68f6ebe4559a7e194c802005';
  static const String widgetId = '1j828iu09';
  
  /// Generate HTML untuk Tawk.to widget
  static String getTawkHtml({
    String? userName,
    String? userEmail,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>Tawk.to Chat</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            height: 100vh;
            overflow: hidden;
        }
        #tawk-container {
            width: 100%;
            height: 100vh;
        }
    </style>
</head>
<body>
    <div id="tawk-container"></div>
    
    <!--Start of Tawk.to Script-->
    <script type="text/javascript">
        var Tawk_API = Tawk_API || {}, Tawk_LoadStart = new Date();
        
        // Set user attributes jika ada
        ${userName != null || userEmail != null ? '''
        Tawk_API.visitor = {
            name: '${userName ?? 'Guest'}',
            email: '${userEmail ?? ''}'
        };
        ''' : ''}
        
        // Maximize chat widget secara default
        Tawk_API.onLoad = function(){
            Tawk_API.maximize();
        };
        
        // Handle minimize - notify Flutter app
        Tawk_API.onChatMinimized = function(){
            if (window.flutter_inappwebview) {
                window.flutter_inappwebview.callHandler('chatMinimized');
            }
        };
        
        // Handle new message
        Tawk_API.onChatMessageVisitor = function(message){
            console.log('New message from visitor: ' + message);
        };
        
        Tawk_API.onChatMessageAgent = function(message){
            console.log('New message from agent: ' + message);
            if (window.flutter_inappwebview) {
                window.flutter_inappwebview.callHandler('newMessage', message);
            }
        };
        
        (function(){
            var s1 = document.createElement("script"), s0 = document.getElementsByTagName("script")[0];
            s1.async = true;
            s1.src = 'https://embed.tawk.to/$propertyId/$widgetId';
            s1.charset = 'UTF-8';
            s1.setAttribute('crossorigin', '*');
            s0.parentNode.insertBefore(s1, s0);
        })();
    </script>
    <!--End of Tawk.to Script-->
</body>
</html>
    ''';
  }
  
  /// Get direct chat URL
  static String getDirectChatUrl() {
    return 'https://tawk.to/chat/$propertyId/$widgetId';
  }
}