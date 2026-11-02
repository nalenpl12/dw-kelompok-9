# Laporan Data Profiling — Inventory Snapshot AdventureWorks

## 1. Tujuan

Data profiling dilaksanakan untuk menilai kesiapan data sumber **MySQL `dwo`** sebelum dimuat ke Data Warehouse **MySQL `dwo_fakta`**. Pemeriksaan meliputi jumlah baris, rentang tanggal perubahan record, nilai `NULL`, keunikan kombinasi produk–lokasi, integritas referensi, distribusi kuantitas, dan baseline perhitungan stok. Hasilnya digunakan sebagai dasar rancangan satu tabel fakta `fact_inventory_snapshot` dan tiga dimensi (`dim_waktu`, `dim_produk`, `dim_lokasi`).

**Ruang lingkup bisnis:** posisi persediaan (*inventory snapshot*), bukan transaksi pergerakan persediaan. Lima pertanyaan bisnis Q1–Q5 dijelaskan dalam [`pertanyaan-bisnis.md`](pertanyaan-bisnis.md).

## 2. Lingkungan dan metadata pemeriksaan

| Item | Nilai |
|---|---|
| DBMS | MySQL (melalui phpMyAdmin / klien MySQL) |
| Database sumber | `dwo` |
| Database target | `dwo_fakta` |
| Script pemeriksaan | [`profiling.sql`](profiling.sql) |
| Tanggal dan waktu pemeriksaan | **[Isi berdasarkan `NOW()` dari query]** |
| Versi MySQL | **[Isi berdasarkan `VERSION()`]** |
| Pelaksana | **[Nama anggota / NPM]** |
| Bukti hasil eksekusi | **[Tautan screenshot atau lampiran hasil SQL]** |

> **Status hasil:** angka dan temuan di bawah merupakan tempat pengisian, **bukan** klaim hasil eksekusi. Masukkan nilai aktual dari database sebelum dokumen dikumpulkan.

## 3. Tabel dan kolom sumber

| Tabel | Peran dalam analisis | Kolom utama |
|---|---|---|
| `dwo.production_productinventory` | Sumber kuantitas stok per produk dan lokasi | `productid`, `locationid`, `quantity`, `modifieddate` |
| `dwo.production_product` | Identitas, biaya standar, dan batas pemesanan ulang | `productid`, `name`, `productsubcategoryid`, `standardcost`, `reorderpoint` |
| `dwo.production_productsubcategory` | Klasifikasi subkategori | `productsubcategoryid`, `productcategoryid`, `name` |
| `dwo.production_productcategory` | Klasifikasi kategori | `productcategoryid`, `name` |
| `dwo.production_location` | Identitas lokasi penyimpanan | `locationid`, `name` |

Struktur data aktual diverifikasi melalui `information_schema` pada Bagian 01 di `profiling.sql`. Hubungan antartabel memakai kunci **ID numerik**, bukan pembandingan nama teks lintas database yang dapat terkena perbedaan *collation*.

## 4. Metode pemeriksaan

Jalankan `profiling.sql` pada koneksi MySQL yang mempunyai akses baca ke `dwo`, lalu dokumentasikan keluaran setiap bagian. Semua statement aktif dalam script bersifat `SELECT` (tidak mengubah sumber). Apabila database sedang menerima perubahan transaksi, hasil beberapa query yang dijalankan dalam sesi terpisah mungkin tidak merepresentasikan kondisi data yang persis sama. Untuk konsistensi pembacaan, gunakan satu transaksi **consistent read** pada sesi yang sama atau lakukan profiling terhadap staging yang dibekukan saat ekstraksi.

**Aturan waktu:** `modifieddate` adalah waktu terakhir sebuah record diubah, **bukan** timestamp snapshot bersama. Tanggal snapshot pada `dim_waktu` ditetapkan saat ekstraksi; seluruh baris dalam satu batch harus memakai snapshot yang sama. Dengan kunci tanggal harian, model ini mendukung paling banyak satu snapshot per tanggal tanpa modifikasi grain.

## 5. Hasil data profiling

### 5.1 Jumlah baris tiap tabel

Masukkan output dari Bagian 02 `profiling.sql`.

| Tabel | Jumlah baris aktual |
|---|---:|
| `production_productinventory` | **[isi]** |
| `production_product` | **[isi]** |
| `production_productsubcategory` | **[isi]** |
| `production_productcategory` | **[isi]** |
| `production_location` | **[isi]** |

**Interpretasi:** **[Uraikan perbandingan ukuran tabel dan relevansinya terhadap sumber tabel fakta.]**

### 5.2 Rentang tanggal dan tanggal snapshot

Masukkan output dari Bagian 03 `profiling.sql`.

| Metrik | Hasil |
|---|---|
| `MIN(modifieddate)` pada `production_productinventory` | **[isi]** |
| `MAX(modifieddate)` pada `production_productinventory` | **[isi]** |
| Jumlah `NULL` pada `modifieddate` | **[isi]** |
| Tanggal snapshot yang direncanakan/ditetapkan saat load DW | **[YYYY-MM-DD]** |
| Waktu/cut-off ekstraksi (jika dicatat) | **[isi, zona waktu]** |

**Interpretasi:** rentang modifikasi record tidak dapat dipakai untuk menyimpulkan histori jumlah stok. Semua pertanyaan bisnis harus menggunakan **satu `date_key` snapshot yang sama**.

### 5.3 Nilai `NULL`

Masukkan output dari Bagian 04 `profiling.sql`. Jika suatu nilai tidak tersedia, jangan isi dengan nol tanpa menjalankan query.

| Tabel | Kolom diperiksa | Jumlah `NULL` | Tindak lanjut |
|---|---|---:|---|
| ProductInventory | `productid` | **[isi]** | Periksa identitas produk |
| ProductInventory | `locationid` | **[isi]** | Periksa identitas lokasi |
| ProductInventory | `quantity` | **[isi]** | Evaluasi kelayakan ukuran stok |
| ProductInventory | `modifieddate` | **[isi]** | Catat kualitas metadata sumber |
| Product | `productsubcategoryid` | **[isi]** | Evaluasi kategori belum terklasifikasi |
| Product | `standardcost` | **[isi]** | Pengaruh ke Q5 / `stock_value` |
| Product | `reorderpoint` | **[isi]** | Pengaruh ke Q4 |
| ProductSubcategory | `productcategoryid` | **[isi]** | Periksa klasifikasi kategori |
| ProductCategory | `name` | **[isi]** | Periksa nama kategori |
| Location | `locationid`, `name` | **[isi masing-masing]** | Validasi dimensi lokasi |

**Interpretasi dan keputusan pembersihan:** **[Isi berdasarkan temuan aktual; bedakan NULL yang memang diperbolehkan dari yang merusak analisis.]**

### 5.4 Keunikan grain dan validitas quantity

Masukkan output dari Bagian 05–06 `profiling.sql`.

| Pengujian | Hasil aktual | Kriteria / tindak lanjut |
|---|---:|---|
| Jumlah produk dengan stok | **[isi]** | Informasi cakupan Q2 dan Q4 |
| Jumlah lokasi dengan stok | **[isi]** | Informasi cakupan Q3 |
| Total `SUM(quantity)` sumber | **[isi]** | Baseline rekonsiliasi |
| Quantity negatif | **[isi]** | Investigasi jika ditemukan |
| Quantity nol | **[isi]** | Teliti apakah sah secara bisnis |
| Kombinasi `productid, locationid` berulang | **[isi]** | **Harus ditangani** sebelum memuat grain produk–lokasi |

**Keputusan grain:** satu baris fakta = satu **tanggal snapshot × produk × lokasi**. Jika sumber memiliki beberapa baris per kombinasi produk–lokasi, telusuri penyebabnya; apabila benar-benar merupakan detail bin/rak, agregasikan `SUM(quantity)` ke tingkat produk–lokasi sebelum load, dan hitung nilai stok dengan biaya standar yang konsisten. Jangan langsung memasukkan baris duplikat ke fakta yang memiliki `UNIQUE(date_key, product_key, location_key)`.

### 5.5 Integritas relasi dan kelengkapan kategori

Masukkan output dari Bagian 07–08 `profiling.sql`.

| Pengujian | Hasil aktual | Dampak |
|---|---:|---|
| Baris inventory tanpa pasangan produk | **[isi]** | Risiko tidak termuat saat `INNER JOIN` |
| Baris inventory tanpa pasangan lokasi | **[isi]** | Risiko tidak termuat saat `INNER JOIN` |
| Produk tanpa subkategori | **[isi]** | Kategori belum dapat ditentukan |
| Referensi subkategori/kategori tidak ditemukan | **[isi]** | Kategori dan Q1/Q5 tidak lengkap |

Jika ditemukan masalah, dokumentasikan jumlah baris yang dikecualikan dan aturan penanganannya sebelum ETL. Jangan membuang baris bermasalah tanpa catatan.

### 5.6 Baseline rekonsiliasi ukuran

Masukkan output dari Bagian 09 `profiling.sql`.

| Ukuran | Hasil pada data sumber | Hasil pada fakta (snapshot sama) | Selisih |
|---|---:|---:|---:|
| Jumlah baris pada grain yang disepakati | **[isi]** | **[isi]** | **[isi]** |
| `SUM(quantity)` | **[isi]** | **[isi]** | **[isi]** |
| `SUM(quantity × standardcost)` dibanding `SUM(stock_value)` | **[isi]** | **[isi]** | **[isi]** |

Perhatikan: jika duplikasi sumber **diagregasikan** ke produk–lokasi, jumlah baris sumber mentah tidak harus sama dengan jumlah baris fakta. Bandingkan jumlah baris setelah pengelompokan pada grain yang sama. Rekonsiliasi `quantity` dan `stock_value` harus menggunakan **ekstraksi sumber yang sama**, bukan tabel sumber yang mungkin sudah berubah setelah snapshot dimuat.

Rumus estimasi nilai stok:

`stock_value = quantity × standardcost`

Bila `standardcost` bernilai `NULL`, hasil perkalian juga `NULL`; `SUM()` dapat mengabaikan baris tersebut. Baris yang gagal dinilai harus dicatat agar total Q5 tidak tampak lengkap secara keliru.

## 6. Kaitan pemeriksaan dengan lima pertanyaan bisnis

| Pertanyaan | Kebutuhan kualitas data | Pengujian pendukung |
|---|---|---|
| Q1 — Stok per kategori | Quantity dan kategori produk lengkap | Bagian 04, 08, 09 |
| Q2 — Stok tertinggi/terendah per produk | Identitas produk valid dan quantity konsisten | Bagian 05, 06, 07 |
| Q3 — Stok terbesar per lokasi | Identitas lokasi valid | Bagian 05, 07 |
| Q4 — Di bawah reorder point | Stok agregat per produk; reorder point valid | Bagian 04, 06, 09 |
| Q5 — Nilai stok kategori × lokasi | Standard cost, kategori, lokasi valid | Bagian 04, 07, 08, 09 |

## 7. Kesimpulan dan keputusan menuju ETL

**Status profiling:** **[Belum diverifikasi / Selesai dengan temuan / Selesai tanpa temuan — pilih berdasarkan output]**.

**Temuan utama:** **[Isi 2–4 poin berdasarkan hasil aktual, bukan perkiraan.]**

**Keputusan tindak lanjut:** **[Jelaskan apakah data dapat dimuat langsung, perlu pengelompokan produk–lokasi, perlu pemetaan kategori, atau perlu penanganan NULL.]**

**Kriteria lanjut ke ETL:** kunci produk dan lokasi valid, grain telah dipastikan, metode snapshot konsisten, dan baseline kuantitas/nilai stok terdokumentasi. Daftar risiko terdapat pada [`risiko.md`](risiko.md) dan modelnya pada [`grain.md`](grain.md).

## 8. Lampiran bukti

- **[Screenshot/ekspor output query jumlah baris]**
- **[Screenshot/ekspor output rentang tanggal dan NULL]**
- **[Screenshot/ekspor hasil duplikasi dan integritas referensi]**
- **[Screenshot/ekspor baseline quantity dan stock value]**