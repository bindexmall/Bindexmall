# Handover — App Bindexmall (Flutter)

Dokumen ini dibuat sebagai panduan untuk developer yang melanjutkan project Bindexmall setelah proses handover. Tujuannya sederhana: supaya developer berikutnya tidak perlu mempelajari atau melakukan reverse-engineering project ini dari awal.

Dokumen ini bukan dokumentasi teknis resmi yang menjelaskan setiap bagian secara detail. Isinya lebih sebagai gambaran umum mengenai struktur aplikasi, alur utama, serta beberapa hal yang perlu diperhatikan sebelum melakukan perubahan.

Setiap file `.dart` juga sudah diberi komentar singkat di bagian paling atas mengenai fungsi file tersebut. Jadi, kalau ada file yang belum familiar, bisa mulai dengan melihat komentar tersebut. Dokumen ini lebih berfungsi sebagai peta besar project.

## Ini App Apa?

Bindexmall adalah aplikasi toko online untuk produk ATK/alat tulis.

Backend aplikasi menggunakan WordPress + WooCommerce di `bindexmall.com`. Aplikasi Flutter berfungsi sebagai frontend yang mengambil dan mengirim data melalui REST API WooCommerce.

Tidak ada backend custom terpisah. Beberapa endpoint tambahan dibuat langsung di sisi WordPress, terutama untuk kebutuhan seperti live settings dan promo banner. Implementasinya berada di plugin custom pada sisi WordPress.

### Teknologi dan service yang digunakan

* Flutter untuk aplikasi Android, dengan state management menggunakan package `provider`
* WooCommerce REST API untuk produk, kategori, pesanan, dan data terkait lainnya
* Custom JWT endpoint di WordPress untuk login, register, dan reset password
* Midtrans Snap untuk proses pembayaran
* RajaOngkir melalui Komerce untuk perhitungan ongkir dan data wilayah
* Cloudinary untuk upload bukti transfer
* Tawk.to untuk live chat dengan CS melalui WebView
* Sentry untuk monitoring error dan crash
* `flutter_local_notifications` untuk notifikasi lokal

> Catatan: notifikasi yang digunakan saat ini adalah **local notification**, bukan push notification menggunakan FCM.

## Struktur Folder

Secara umum, struktur project dibagi seperti berikut:

* `main.dart` — entry point aplikasi. Semua Provider utama didaftarkan di sini.
* `models/` — berisi model data seperti Product, Cart, Address, dan lainnya. Sebisa mungkin tidak berisi business logic.
* `providers/` — state management dan logic utama untuk masing-masing fitur.
* `repositories/` — penghubung antara Provider dengan Service atau local storage.
* `services/` — menangani komunikasi dengan API eksternal seperti WooCommerce, Midtrans, dan service lainnya.
* `screens/` — halaman aplikasi. Umumnya satu file mewakili satu halaman.
* `widgets/` — komponen UI yang digunakan kembali di beberapa halaman.
* `theme/`, `utils/`, `l10n/` — masing-masing berisi konfigurasi theme, utility/helper, dan localization.

Secara umum, alurnya:

**Screen → Provider → Repository → Service / Local Storage**

Provider menangani state dan logic fitur. Repository menentukan apakah data perlu diambil dari API melalui Service atau dari penyimpanan lokal pada device.

### Penyimpanan Data

Hal yang cukup penting untuk diperhatikan:

**Cart, wishlist, dan alamat disimpan secara lokal di device**, bukan di server.

Data tersebut dipisahkan berdasarkan user. Untuk user yang belum login, tersedia juga data untuk guest user. Ketika user kemudian login, data guest akan digabungkan sesuai logic yang sudah tersedia.

Sementara itu, data seperti:

* Produk
* Kategori
* Pesanan

tetap mengambil data langsung dari WooCommerce.

## Alur Checkout

Bagian checkout merupakan salah satu bagian paling kompleks dan perlu diperhatikan jika ingin melakukan perubahan.

File utamanya adalah:

`checkout_screen.dart`

File ini sendiri cukup besar, hampir mencapai 2.500 baris, karena menangani cukup banyak proses dalam satu flow.

Secara umum alurnya:

**Pilih alamat → Pilih kurir & hitung ongkir → Masukkan kupon → Buat order di WooCommerce → Pembayaran melalui Midtrans**

Detailnya:

1. User mengisi atau memilih alamat pengiriman.
2. User memilih kurir.
3. Ongkir dihitung melalui `ShippingProvider`, yang kemudian menggunakan RajaOngkir/Komerce.
4. User dapat memasukkan kupon jika tersedia.
5. Order dibuat di WooCommerce.
6. Setelah order berhasil dibuat, aplikasi membuka WebView untuk proses pembayaran Midtrans.
7. Untuk kebutuhan pembayaran manual, user juga dapat mengupload bukti transfer di luar flow Midtrans.

Sebelum mengubah flow checkout, sebaiknya pahami terlebih dahulu hubungan antara `CheckoutScreen`, `ShippingProvider`, WooCommerce Service, dan Midtrans karena perubahan pada salah satu bagian bisa berdampak ke proses order secara keseluruhan.

## Hal-Hal yang Perlu Diperhatikan

### API Key / Secrets

Sebelumnya beberapa credential seperti WooCommerce, Midtrans, RajaOngkir, dan Cloudinary masih ditulis langsung di masing-masing file service.

Saat ini credential tersebut sudah dipindahkan ke:

`lib/config/secrets.dart`

File `secrets.dart` **tidak di-commit ke repository**. Sebagai gantinya tersedia:

`secrets.example.dart`

yang dapat digunakan sebagai template.

Instruksi untuk konfigurasi juga sudah ditulis di komentar bagian atas `secrets.dart`.

Ada juga file:

`lib/config/gitignore-snippet.txt`

yang berisi baris `.gitignore` yang perlu ditambahkan ke `.gitignore` di root project. Karena folder yang digunakan untuk handover hanya mencakup folder `lib/`, konfigurasi `.gitignore` root tidak dapat disertakan di sini.

### Kondisi Security Saat Ini

Pemindahan credential ke `secrets.dart` merupakan perbaikan dari sisi source code, tetapi **belum sepenuhnya menyelesaikan masalah keamanan credential**.

Saat ini kondisinya:

* ✅ Credential tidak lagi ditulis langsung di source code masing-masing service.
* ✅ `secrets.dart` dapat dikecualikan dari Git sehingga tidak ikut ter-commit lagi.
* ❌ Credential tetap akan masuk ke dalam APK saat aplikasi di-build.
* ❌ APK yang sudah jadi masih memungkinkan untuk dianalisis/decompile sehingga credential dapat ditemukan.

Jadi, pemindahan credential ini lebih tepat dianggap sebagai **perbaikan pengelolaan source code**, bukan solusi untuk menyembunyikan credential dari aplikasi client.

Credential yang paling sensitif adalah:

* **Midtrans Server Key** — dapat digunakan untuk kebutuhan seperti pengecekan atau pembatalan transaksi.
* **WooCommerce Consumer Secret** — memiliki akses untuk membaca/menulis data melalui WooCommerce REST API.

Idealnya, credential tersebut tidak pernah dikirim ke aplikasi Flutter. Langkah berikutnya adalah memindahkan operasi yang membutuhkan credential sensitif ke proxy/backend endpoint sendiri, sehingga aplikasi hanya berkomunikasi dengan endpoint tersebut dan credential tetap berada di server.

Implementasi ini belum dilakukan dan dapat menjadi salah satu pekerjaan lanjutan.

### Credential Lama di Git History

Ada satu hal penting lainnya.

Jika repository sebelumnya pernah di-push ketika API key masih ditulis langsung di source code, memindahkan key ke `secrets.dart` **tidak otomatis menghapus key tersebut dari history Git**.

Siapa pun yang memiliki akses ke repository dan Git history masih mungkin menemukan credential lama.

Karena itu, langkah yang paling aman adalah melakukan **regenerate/rotate credential** pada masing-masing service:

* WooCommerce
* Midtrans
* RajaOngkir/Komerce
* Cloudinary

Setelah credential lama dinonaktifkan, gunakan credential baru di `secrets.dart`.

---

### `Sentry.captureException` di `main.dart`

Di `main.dart` masih terdapat pemanggilan `Sentry.captureException` yang berisi error contoh dari proses setup Sentry.

Kode tersebut kemungkinan merupakan sisa testing dan menyebabkan aplikasi mengirim satu error palsu ke Sentry setiap kali aplikasi dibuka.

Kode tersebut aman untuk dihapus.

Sebelum menghapusnya, sebaiknya cek dashboard Sentry terlebih dahulu untuk memastikan apakah error tersebut masih digunakan sebagai referensi monitoring.

---

### Tiga `SelectLocationScreen`

Terdapat tiga implementasi class dengan nama `SelectLocationScreen`:

1. `add_address_screen.dart`
2. `select_shipping_screen.dart`
3. Implementasi lokal di dalam `checkout_screen.dart`

Ketiganya memiliki implementasi yang berbeda meskipun menggunakan nama class yang sama.

Jika ingin mengubah tampilan atau behavior pemilihan lokasi, pastikan terlebih dahulu screen mana yang digunakan oleh flow yang sedang dikerjakan. Jangan langsung mengubah salah satu class berdasarkan nama saja.

---

### Dua Provider Bahasa

Terdapat dua provider yang berkaitan dengan bahasa:

* `LanguageProvider`
* `LocaleProvider`

Fungsinya cukup mirip dan belum sempat disederhanakan menjadi satu sistem.

Jika nantinya ingin merapikan sistem localization, cek terlebih dahulu `main.dart` dan penggunaan masing-masing provider di project untuk memastikan provider mana yang benar-benar masih digunakan sebelum menghapus salah satunya.

---

### Class `Order` dan `OrderItem`

Class `Order` dan `OrderItem` saat ini berada di:

`orders_screen.dart`

berbeda dengan model lainnya yang berada di folder `models/`.

Jika struktur order nantinya perlu digunakan di beberapa bagian aplikasi, sebaiknya kedua class tersebut dipindahkan ke folder `models/` agar struktur project lebih konsisten dan tidak perlu membuat definisi model tambahan.

---

### `test_connection_screen.dart`

`test_connection_screen.dart` kemungkinan merupakan screen yang digunakan untuk testing koneksi pada tahap development.

Sebelum dihapus, cek terlebih dahulu apakah screen tersebut masih digunakan atau masih terdaftar pada routing aplikasi.

---

### Perhitungan PPN

Sebelumnya pernah terdapat bug pada perhitungan pajak.

Harga produk dari WooCommerce sudah termasuk PPN, tetapi aplikasi sempat menghitung pajak kembali pada proses cart dan checkout sehingga nominal pajak menjadi terhitung dua kali.

Perhitungan tersebut sudah diperbaiki pada bagian cart dan checkout.

Jika nantinya ada perubahan atau penambahan kalkulasi pajak pada flow cart/checkout, pastikan terlebih dahulu apakah harga yang diterima dari WooCommerce sudah termasuk pajak atau belum.

Hal ini perlu diperhatikan agar bug perhitungan pajak ganda tidak muncul kembali.

## Kalau Mau Mengerjakan Sesuatu, Mulai dari Mana?

Beberapa lokasi yang paling sering akan menjadi titik awal saat melakukan perubahan:

| Kebutuhan                                   | File / Folder                                                  |
| ------------------------------------------- | -------------------------------------------------------------- |
| Mengubah tampilan product card              | `widgets/product_card.dart`                                    |
| Mengubah halaman utama                      | `home_screen.dart` + `widgets/Home/`                           |
| Mengubah logic checkout, ongkir, atau biaya | `checkout_screen.dart`                                         |
| Menambahkan field produk dari WooCommerce   | `models/product.dart` → `repositories/product_repository.dart` |
| Menambahkan endpoint WooCommerce            | `woocommerce_service.dart`                                     |
| Notifikasi lokal                            | `notification_service.dart`                                    |
| Mengubah warna atau theme                   | `theme/app_theme.dart`                                         |
| Mengubah teks bahasa Indonesia/Inggris      | `l10n/app_id.arb` & `app_en.arb`                               |

Untuk endpoint WooCommerce baru, sebaiknya tambahkan method pada `woocommerce_service.dart` yang sudah ada daripada membuat koneksi baru di file lain. Dengan begitu struktur komunikasi API tetap konsisten.

Untuk localization, edit file:

* `l10n/app_id.arb`
* `l10n/app_en.arb`

Setelah itu jalankan:

```bash
flutter gen-l10n
```

Jangan melakukan perubahan langsung pada:

`app_localizations.dart`

karena file tersebut merupakan hasil generate dan perubahan manual akan tertimpa ketika proses `flutter gen-l10n` dijalankan kembali.
