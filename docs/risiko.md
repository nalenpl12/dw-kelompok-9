# Daftar Risiko Awal — Data Warehouse Inventory Snapshot

## 1. Tujuan

Dokumen ini mengidentifikasi risiko yang dapat memengaruhi konsistensi snapshot, keakuratan ukuran stok, dan keandalan hasil analisis pada Data Warehouse MySQL `dwo_fakta`. Identifikasi dilakukan sebelum ETL dan pengujian dashboard Q1–Q5.

## 2. Register risiko

| ID | Risiko awal | Dampak | Rencana penanganan | Bukti/pengujian |
|---|---|---|---|---|
| **R1** | Pengambilan data dari tabel sumber tidak konsisten waktunya | Jumlah stok, kategori, dan biaya standar dapat merefleksikan keadaan berbeda | Ekstraksi satu snapshot secara konsisten (misalnya transaksi baca konsisten/staging pada satu *cut-off*); gunakan satu tanggal snapshot untuk seluruh baris | Catatan waktu ekstraksi, jumlah baris, hasil rekonsiliasi |
| **R2** | Duplikasi kombinasi produk–lokasi dalam snapshot | `SUM(quantity)` dan `SUM(stock_value)` terhitung ganda | Profiling kombinasi `productid, locationid`; terapkan `UNIQUE(date_key, product_key, location_key)` pada fakta | Query duplikasi menghasilkan 0 baris |
| **R3** | NULL atau nilai tak valid pada `quantity`, `standardcost`, dan `reorderpoint` | Nilai stok salah, Q4 tidak dapat dievaluasi, atau Q5 terhitung sebagian | Data profiling, tetapkan aturan kualitas data; jangan mengubah NULL menjadi nol tanpa dasar | Jumlah NULL dan daftar pengecualian yang terdokumentasi |
| **R4** | `productid`/`locationid` sumber tidak cocok dengan dimensi | Sebagian stok hilang saat `INNER JOIN` untuk pemuatan fakta | Validasi relasi sebelum load; tangani atau dokumentasikan record yang tidak memiliki pasangan | Anti-join sumber–dimensi dan rekonsiliasi baris |
| **R5** | `standard_cost` atau `reorder_point` berubah setelah snapshot disimpan | Nilai historis atau status alert untuk snapshot lama berubah | Simpan `stock_value` saat ETL; apabila histori multi-snapshot diperlukan, pertahankan versi `reorder_point` yang berlaku (SCD atau atribut snapshot) | Pengujian ulang hasil snapshot lama setelah perubahan dimensi |
| **R6** | Agregasi salah pada Q4 karena satu produk tersimpan di beberapa lokasi | Produk salah teridentifikasi sebagai perlu dipesan ulang | Jumlahkan stok **per produk** terlebih dahulu, lalu bandingkan dengan `MAX(reorder_point)` yang valid untuk produk | Query Q4 memakai `GROUP BY product_id` dan `HAVING` setelah agregasi |
| **R7** | Kesalahan konfigurasi MySQL atau perbedaan collation saat `JOIN` data teks lintas database | Query ETL gagal (contoh `Illegal mix of collations`) | Untuk kunci relasi gunakan ID numerik bila tersedia; bila membandingkan teks, periksa dan samakan collation secara eksplisit | Uji JOIN dan pemeriksaan `information_schema.columns` |
| **R8** | Sisa tabel fakta dari eksperimen model *inventory movement* di `dwo_fakta` | Dokumen menyatakan satu fakta, tetapi implementasi berisi fakta lain yang tidak termasuk cakupan | Audit tabel yang ada; arsipkan/backup tabel lama terlebih dahulu sebelum perubahan, tanpa menghapus data secara langsung | Daftar tabel final dan diagram Star Schema yang selaras |

## 3. Prioritas penanganan

1. **Sebelum ekstraksi:** tangani R1, R2, R3, dan R4; pastikan satu snapshot terdefinisi dan sumber layak dimuat.
2. **Saat pemodelan dan ETL:** tangani R5, R6, dan R7; pastikan aturan ukuran dan join valid.
3. **Sebelum penyerahan:** tangani R8; samakan struktur aktual, dokumentasi, dan visualisasi.

## 4. Kriteria penerimaan risiko

- Tidak ada duplikasi kombinasi `date_key, product_key, location_key` pada snapshot yang dipilih.
- Semua baris fakta memiliki dimensi yang sesuai dan menggunakan tanggal snapshot yang sama untuk satu batch analisis.
- Nilai `SUM(quantity)` dan `SUM(stock_value)` sesuai dengan ekstraksi sumber yang sama, setelah pengecualian terdokumentasi.
- Perhitungan Q4 dilakukan pada tingkat produk, bukan per lokasi.
- Tidak ada perbedaan antara tabel fakta yang dinyatakan dalam laporan dan tabel fakta yang benar-benar digunakan pada dashboard.

## 5. Catatan pelaksanaan

Status setiap risiko (**belum diperiksa / terdeteksi / ditangani**) dan bukti hasil pengujiannya diisi setelah ETL dan validasi dilakukan. Tabel di atas merupakan **identifikasi risiko awal**, bukan klaim bahwa risiko sudah terjadi atau sudah terselesaikan.

**Terkait:** [`piagam-proyek.md`](piagam-proyek.md), [`grain.md`](grain.md).
