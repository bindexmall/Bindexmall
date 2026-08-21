# Handover — App Bindexmall (Flutter)

Halo, siapapun yang megang project ini setelah gue. Gue tulis dokumen ini
karena gue resign dan pengen yang lanjutin ga harus reverse-engineer semua
dari nol. Ini bukan dokumentasi resmi rapi ala perusahaan besar, cuma
catatan jujur soal gimana app ini disusun dan apa aja yang perlu diwaspadai.

Tiap file `.dart` juga udah gue kasih komentar singkat di paling atas
tentang fungsinya. Jadi kalau bingung satu file ngapain, buka aja, biasanya
udah kejawab di situ. Dokumen ini lebih ke peta besarnya aja.

## Ini app apa

Bindexmall — toko online ATK/alat tulis + aksesoris apparel outdoor punya
Bambi Group. Backend-nya WordPress + WooCommerce di bindexmall.com, app
Flutter ini cuma "muka depan" yang narik data dari REST API WooCommerce.
Ga ada backend custom terpisah — kecuali dua-tiga endpoint kecil yang
ditambahin sendiri di WordPress (live settings sama promo banner), itu
juga kemungkinan lewat plugin/functions.php di sisi WP, bukan aplikasi
terpisah.

Yang dipakai:
- Flutter buat Android, state management pakai package `provider`
- WooCommerce REST API buat produk/kategori/pesanan
- Endpoint JWT custom di WordPress buat login/register/reset password
- Midtrans Snap buat pembayaran
- RajaOngkir (lewat Komerce) buat ongkir & data wilayah
- Cloudinary buat upload bukti transfer
- Tawk.to buat live chat sama CS (dibuka lewat WebView)
- Sentry buat pantau error/crash
- flutter_local_notifications buat notif (ini notif lokal ya, bukan push/FCM)

## Struktur folder, singkatnya

- `main.dart` — titik masuk, di sini semua Provider didaftarin
- `models/` — kelas data doang (Product, Cart, Address, dst), ga ada logic
- `providers/` — state management, "otak" tiap fitur
- `repositories/` — jembatan antara provider dengan service/local storage
- `services/` — yang ngomong ke API luar (WooCommerce, Midtrans, dll)
- `screens/` — halaman-halaman, 1 file biasanya 1 halaman
- `widgets/` — komponen yang dipakai berulang-ulang di beberapa halaman
- `theme/`, `utils/`, `l10n/` — self-explanatory

Alurnya biasanya begini: Screen manggil Provider, Provider manggil
Repository, Repository yang mutusin datanya diambil dari API (lewat
Service) atau dari penyimpanan lokal HP (SharedPreferences).

Yang penting diinget: **cart, wishlist, sama alamat itu disimpen lokal di
HP**, bukan di server. Dipisah per user (dan ada versi "guest" buat yang
belum login, nanti otomatis digabung pas dia login). Sementara produk,
kategori, pesanan itu selalu dari WooCommerce langsung.

## Alur checkout, biar ga kaget

Ini bagian paling gede & paling rawan kalau mau diutak-atik
(`checkout_screen.dart`, sendirian aja hampir 2500 baris). Urutannya:
isi/pilih alamat → pilih kurir & hitung ongkir (lewat ShippingProvider,
yang manggil RajaOngkir) → pasang kupon kalau ada → order dibikin di
WooCommerce → baru dibuka WebView Midtrans buat bayar. Abis bayar, user
juga bisa upload bukti transfer manual sebagai jaga-jaga di luar flow
Midtrans.

## Hal-hal yang perlu lo tau sebelum pegang ini lebih jauh

**Soal API key — udah gue benerin sebagian, tapi belum kelar.**
Sebelumnya semua key (WooCommerce, Midtrans, RajaOngkir, Cloudinary)
nangkring polos di masing-masing file service. Sekarang gue udah pindahin
semua ke satu file: `lib/config/secrets.dart`. File itu ga ikut gue
commit-in ke git (ada juga `secrets.example.dart` sebagai template kosong
yang aman di-commit). Instruksi cara pasang ada di komentar paling atas
`secrets.dart` itu sendiri, dan ada catatan tambahan di
`lib/config/gitignore-snippet.txt` soal naruh baris gitignore-nya di
root project (karena yang di-share ke lo cuma folder `lib/`, gue ga bisa
taruh `.gitignore` di tempat yang seharusnya).

Yang perlu lo tau, ini **baru setengah jalan**:
- ✅ Udah beres: secret ga lagi ketulis di source code, ga bakal
  ke-commit lagi ke git ke depannya
- ❌ Belum beres: kalau APK-nya di-build terus di-decompile orang, key
  ini tetap kebaca — soalnya pas build, isi `secrets.dart` tetap ikut
  ke-compile masuk APK juga. Cuma pindah dari "kebaca di source" jadi
  "kebaca kalau APK dibongkar"

Yang paling sensitif — **Midtrans server key** (bisa buat cek/batalin
transaksi) sama **WooCommerce consumer secret** (bisa baca-tulis data
toko) — idealnya next step-nya dipindah ke proxy endpoint di server
sendiri, biar key-nya ga pernah nyampe ke APK sama sekali. Belum sempet
gue kerjain, jadi ini gue titip sebagai PR berikutnya.

Satu hal lagi yang PENTING: kalau repo ini sebelumnya udah pernah
di-push ke git dengan key yang masih hardcoded (kemungkinan besar iya),
mindahin ke file terpisah **ga otomatis ngilangin key itu dari riwayat
commit lama**. Orang yang punya akses ke history git masih bisa gali key
lama. Paling aman: regenerate/rotate semua key ini di masing-masing
dashboard (WooCommerce, Midtrans, RajaOngkir, Cloudinary) biar yang lama
otomatis ga berlaku lagi, baru pasang yang baru di `secrets.dart`.

**Ada baris nyisa di main.dart.** Cari `Sentry.captureException` yang
isinya error contoh — itu ketinggalan dari waktu setup Sentry dulu.
Efeknya app kirim 1 error palsu ke Sentry tiap kali dibuka. Aman dihapus,
tapi cek dulu dashboard Sentry-nya barangkali ada yang udah kebiasa liat
angka itu.

**Ada tiga file beda yang sama-sama punya class namanya
`SelectLocationScreen`.** Satu di `add_address_screen.dart`, satu di
`select_shipping_screen.dart`, satu lagi versi lokal di dalem
`checkout_screen.dart` sendiri. Beda-beda implementasinya, kebetulan
namanya sama aja. Kalau mau ubah tampilan pilih lokasi, pastiin dulu lo
ngedit yang bener sesuai alur mana yang lagi dikerjain.

**Ada dua provider bahasa** — `LanguageProvider` sama `LocaleProvider`,
fungsinya mirip-mirip. Gue ga sempet beresin ini, jadi kalau mau
sederhanain sistem bahasa, telusuran dulu di main.dart yang mana yang
beneran kepake sebelum hapus salah satunya.

**Class `Order` sama `OrderItem` ada di dalem `orders_screen.dart`**,
bukan di folder models kayak yang lain. Kalau nanti butuh struktur order
di tempat lain juga, mending dipindahin ke models biar ga dobel definisi.

**`test_connection_screen.dart`** kayaknya tools buat cek koneksi pas
development dulu. Cek dulu masih ke-route ke UI apa nggak sebelum
diutak-atik atau dihapus.

**Soal PPN** — dulu pernah ada bug pajak kehitung dobel (harga dari
WooCommerce udah termasuk PPN, terus di app dihitung pajak lagi). Udah
dibenerin di cart sama checkout. Kalau nanti ada yang mau nambahin
kalkulasi pajak lagi di jalur cart/checkout, mohon dicek dulu apa harga
dari WooCommerce udah termasuk pajak apa belum, biar ga keulang bug yang
sama.

## Kalau mau ngerjain sesuatu, mulai dari mana

- Ubah tampilan kartu produk di semua halaman → `widgets/product_card.dart`
- Ubah halaman utama → `home_screen.dart` + folder `widgets/Home/`
- Logic checkout/ongkir/biaya → `checkout_screen.dart`
- Nambah field produk baru dari WooCommerce → mulai dari `models/product.dart`,
  lanjut ke `repositories/product_repository.dart`
- Nambah endpoint WooCommerce baru → tambahin method-nya di
  `woocommerce_service.dart`, jangan bikin koneksi baru sendiri
- Notifikasi lokal → `notification_service.dart`
- Warna/tema → `theme/app_theme.dart`
- Teks terjemahan ID/EN → edit `l10n/app_id.arb` & `app_en.arb`, terus
  jalanin `flutter gen-l10n` (jangan edit `app_localizations.dart`
  langsung, itu file hasil generate, bakal ketiban pas di-generate ulang)

## Yang ga ikut di-share di sini

Folder yang gue kasih cuma `lib/`. Yang ga termasuk: `pubspec.yaml`,
folder `android/` (konfigurasi native, signing key), dan akses ke
dashboard-dashboard yang dipake (WooCommerce/wp-admin, Midtrans,
Cloudinary, RajaOngkir/Komerce, Tawk.to, Sentry, Google Analytics). Semua
key yang disebut di atas juga cuma jalan kalau akun-akun itu masih aktif
dan dipegang tim.

Segitu aja dari gue. Semoga lanjutannya lancar. Kalau ada yang aneh dan
ga kejelasin di sini, cek dulu komentar di masing-masing file — kalau
masih ga ketemu juga, ya itu risiko namanya warisan kode 🙂
