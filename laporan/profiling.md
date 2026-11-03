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
| `production_productinventory` | 1069 |
| `production_product` | 504 |
| `production_productsubcategory` | 37 |
| `production_productcategory` | 4 |
| `production_location` | 14 |

**Interpretasi:** **[Uraikan perbandingan ukuran tabel dan relevansinya terhadap sumber tabel fakta.]**

### 5.2 Nilai `NULL`

Masukkan output dari Bagian 04 `profiling.sql`. Jika suatu nilai tidak tersedia, jangan isi dengan nol tanpa menjalankan query.

| Tabel | Kolom diperiksa | Jumlah `NULL` | Tindak lanjut |
|---|---|---:|---|
| ProductInventory | `productid` | 0 | Periksa identitas produk |
| ProductInventory | `locationid` | 0 | Periksa identitas lokasi |
| ProductInventory | `quantity` | 0 | Evaluasi kelayakan ukuran stok |
| ProductInventory | `modifieddate` | 0 | Catat kualitas metadata sumber |
| Product | `productsubcategoryid` | 209 | Evaluasi kategori belum terklasifikasi |
| Product | `standardcost` | 0 | Pengaruh ke Q5 / `stock_value` |
| Product | `reorderpoint` | 0 | Pengaruh ke Q4 |
| ProductSubcategory | `productcategoryid` | 0 | Periksa klasifikasi kategori |
| ProductCategory | `name` | 0 | Periksa nama kategori |
| Location | `locationid`, `name` | 0 | Validasi dimensi lokasi |

**Interpretasi dan keputusan pembersihan:** **[Isi berdasarkan temuan aktual; bedakan NULL yang memang diperbolehkan dari yang merusak analisis.]**

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
