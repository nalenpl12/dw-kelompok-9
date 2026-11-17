# Kamus Data (Data Dictionary) — Data Warehouse `dwo_fakta`

Dokumen ini mendefinisikan struktur fisik, tipe data, *constraint*, nilai bawaan (*default*), dan makna bisnis untuk setiap kolom pada seluruh tabel **Data Warehouse** (`dwo_fakta`) serta tabel **Staging** pendukung proses ETL.

---

## 1. Penjelasan Khusus `dim_tanggal` (Versi 1.0)

* **Versi Skrip yang Digunakan:** `dim_tanggal` Standar **Versi 1.0** (dengan baris *Unknown Member* `tanggal_key = -1`).
* **Fungsi Dimensi Waktu dalam Analisis Bisnis:**  
  Tabel `dim_tanggal` berperan sebagai sumbu analisis kronologis untuk seluruh snapshot persediaan pada `fact_inventory`. Melalui atribut kalender yang sudah dipecah ke dalam tingkat hierarki waktu (`tahun`, `semester`, `kuartal`, `bulan`, `minggu_dalam_tahun`, hingga `nama_hari` dan `is_akhir_pekan`), manajemen dapat membandingkan tren tingkat stok antar-kuartal, memantau pergerakan persediaan bulanan, serta mengevaluasi perbedaan beban stok pada hari kerja versus akhir pekan tanpa perlu menulis fungsi manipulasi tanggal yang berat pada saat *query* laporan.
* **Alasan Pemilihan Integer `YYYYMMDD` sebagai `tanggal_key`:**  
  Kolom `tanggal_key` menggunakan tipe data `INT(11)` berformat `YYYYMMDD` (contoh: `20261117` untuk 17 November 2026) daripada tipe `DATE` asli. Penggunaan *smart surrogate key* bertipe integer membuat ukuran indeks lebih ringkas, mempercepat operasi *JOIN* dan *GROUP BY* dengan tabel fakta yang berukuran besar, sekaligus tetap mudah dibaca oleh pengembang maupun analis data.
* **Peran Baris `-1` (*Unknown Member*):**  
  Baris dengan `tanggal_key = -1` (`tanggal = '1900-01-01'`, keterangan `'Tidak diketahui'`) disiapkan sebagai nilai rujukan darurat (*fallback*). Apabila saat proses ETL ditemukan baris data inventaris dengan `ModifiedDate` kosong (`NULL`) atau di luar rentang kalender, proses *lookup* akan mengarahkannya ke `tanggal_key = -1` sehingga data tetap tercatat tanpa memicu kegagalan *Foreign Key Constraint*.

---

## 2. Kamus Data Tabel Dimensi

### 2.1 `dim_tanggal` (SCD Tipe 0 — Statis)
Menyimpan daftar tanggal kalender standar untuk analisis berbasis waktu.

| Nama Kolom | Tipe Data | Constraint | Nilai Default | Deskripsi Bisnis |
|------------|-----------|------------|---------------|------------------|
| `tanggal_key` | `INT(11)` | `PRIMARY KEY`, `NOT NULL` | `-1` | Kunci utama (*surrogate key*) unik berformat integer `YYYYMMDD`; `-1` untuk tanggal tidak diketahui. |
| `tanggal` | `DATE` | `NOT NULL` | `'1900-01-01'` | Tanggal kalender aktual dalam format standar ISO (`YYYY-MM-DD`). |
| `tahun` | `INT(11)` | `NOT NULL` | `0` | Tahun kalender 4 digit (contoh: `2026`). |
| `semester` | `INT(11)` | `NOT NULL` | `0` | Penanda semester dalam setahun (`1` untuk Jan–Jun, `2` untuk Jul–Des). |
| `kuartal` | `INT(11)` | `NOT NULL` | `0` | Penanda kuartal dalam setahun (`1` sampai `4`). |
| `bulan` | `INT(11)` | `NOT NULL` | `0` | Nomor urut bulan dalam setahun (`1` untuk Januari sampai `12` untuk Desember). |
| `nama_bulan` | `VARCHAR(15)` | `NOT NULL` | `'Tidak diketahui'` | Nama bulan dalam bahasa Indonesia (contoh: `'Januari'`, `'Februari'`). |
| `minggu_dalam_tahun` | `INT(11)` | `NOT NULL` | `0` | Nomor urut minggu ke-berapa dalam satu tahun berjalan (`1`–`53`). |
| `tanggal_dalam_bulan` | `INT(11)` | `NOT NULL` | `0` | Angka tanggal dalam satu bulan (`1`–`31`). |
| `hari_dalam_minggu` | `INT(11)` | `NOT NULL` | `0` | Indeks numerik hari dalam seminggu (`1` = Minggu sampai `7` = Sabtu). |
| `nama_hari` | `VARCHAR(15)` | `NOT NULL` | `'Tidak diketahui'` | Nama hari dalam bahasa Indonesia (contoh: `'Senin'`, `'Selasa'`). |
| `is_akhir_pekan` | `TINYINT(1)` | `NOT NULL` | `0` | Penanda apakah tanggal jatuh pada akhir pekan (`1` = Ya/Sabtu-Minggu, `0` = Hari Kerja). |

---

### 2.2 `dim_lokasi` (SCD Tipe 1 — Overwrite)
Menyimpan data master area, gudang, atau departemen penyimpanan persediaan fisik.

| Nama Kolom | Tipe Data | Constraint | Nilai Default | Deskripsi Bisnis |
|------------|-----------|------------|---------------|------------------|
| `lokasi_key` | `INT(11)` | `PRIMARY KEY`, `AUTO_INCREMENT`, `NOT NULL` | `-1` (baris unknown) | Kunci pengganti (*surrogate key*) unik untuk setiap lokasi penyimpanan di DW. |
| `nama_lokasi` | `VARCHAR(100)` | `NOT NULL` | `'Tidak Diketahui'` | Nama area atau fasilitas penyimpanan barang (contoh: `'Tool Crib'`, `'Finished Goods Storage'`). |
| `cost_rate` | `DECIMAL(10,2)` | `NOT NULL` | `0.00` | Tarif biaya operasional standar per jam kerja pada lokasi tersebut. |
| `availability` | `DECIMAL(10,2)` | `NOT NULL` | `0.00` | Kapasitas ketersediaan jam kerja operasional pada lokasi penyimpanan. |

---

### 2.3 `dim_kategori` (SCD Tipe 1 — Overwrite)
Menyimpan hierarki klasifikasi kategori dan subkategori produk.

| Nama Kolom | Tipe Data | Constraint | Nilai Default | Deskripsi Bisnis |
|------------|-----------|------------|---------------|------------------|
| `kategori_key` | `INT(11)` | `PRIMARY KEY`, `AUTO_INCREMENT`, `NOT NULL` | `-1` (baris unknown) | Kunci pengganti (*surrogate key*) unik kombinasi kategori dan subkategori produk. |
| `nama_kategori` | `VARCHAR(100)` | `NOT NULL` | `'Tanpa Kategori'` | Nama pengelompokan utama produk tingkat atas (contoh: `'Bikes'`, `'Components'`). |
| `nama_subkategori` | `VARCHAR(100)` | `NOT NULL` | `'Tanpa Subkategori'` | Nama pengelompokan turunan yang lebih spesifik di bawah kategori utama (contoh: `'Mountain Bikes'`). |

---

### 2.4 `dim_produk` (SCD Tipe 2 — Historical Tracking)
Menyimpan data master barang/produk beserta riwayat perubahan biaya standar dan batas pemesanan ulang.

| Nama Kolom | Tipe Data | Constraint | Nilai Default | Deskripsi Bisnis |
|------------|-----------|------------|---------------|------------------|
| `produk_key` | `INT(11)` | `PRIMARY KEY`, `AUTO_INCREMENT`, `NOT NULL` | `-1` (baris unknown) | Kunci pengganti (*surrogate key*) unik untuk setiap versi rekaman produk (mendukung SCD Tipe 2). |
| `produk_id` | `INT(11)` | `NOT NULL` | `-1` | Kunci alami (*natural key*) `ProductID` yang berasal dari sistem sumber OLTP AdventureWorks. |
| `nama_produk` | `VARCHAR(100)` | `NOT NULL` | `'Tidak Diketahui'` | Nama resmi barang atau item inventaris. |
| `nomor_produk` | `VARCHAR(25)` | `NOT NULL` | `'-'` | Kode unik SKU / nomor katalog produk (contoh: `'AR-5381'`). |
| `standard_cost` | `DECIMAL(19,4)` | `NOT NULL` | `0.0000` | Biaya standar produksi atau perolehan per unit produk pada periode versi tersebut. |
| `reorder_point` | `INT(11)` | `NOT NULL` | `0` | Batas ambang minimum jumlah stok; jika stok di bawah angka ini maka perlu dilakukan pemesanan ulang. |
| `date_from` | `DATE` | `NOT NULL` | `'1900-01-01'` | Tanggal mulai berlakunya versi atribut produk ini (SCD Tipe 2). |
| `date_to` | `DATE` | `NOT NULL` | `'9999-12-31'` | Tanggal berakhirnya masa berlaku versi produk ini; `'9999-12-31'` menandakan masih berlaku. |
| `is_current` | `TINYINT(1)` | `NOT NULL` | `1` | Indikator status versi produk (`1` = versi terbaru yang sedang aktif, `0` = versi historis lama). |

---

### 2.5 `dim_rak` (SCD Tipe 1 — Overwrite)
Menyimpan detail posisi fisik rak (*shelf*) dan kompartemen kotak (*bin*) tempat barang disimpan.

| Nama Kolom | Tipe Data | Constraint | Nilai Default | Deskripsi Bisnis |
|------------|-----------|------------|---------------|------------------|
| `rak_key` | `INT(11)` | `PRIMARY KEY`, `AUTO_INCREMENT`, `NOT NULL` | `-1` (baris unknown) | Kunci pengganti (*surrogate key*) unik kombinasi posisi rak dan bin penyimpanan. |
| `shelf` | `VARCHAR(10)` | `NOT NULL` | `'N/A'` | Kode atau label huruf/angka baris rak penyimpanan di dalam gudang (contoh: `'A'`, `'B'`, `'N/A'`). |
| `bin` | `INT(11)` | `NOT NULL` | `0` | Nomor urut kompartemen/kotak penyimpanan spesifik di dalam sebuah rak (`0`–`100`). |

---

## 3. Kamus Data Tabel Fakta

### 3.1 `fact_inventory`
Menyimpan ukuran (*measure*) kuantitas dan valuasi stok persediaan per kombinasi produk, kategori, lokasi, dan rak pada tanggal pencatatan snapshot.

| Nama Kolom | Tipe Data | Constraint | Nilai Default | Deskripsi Bisnis |
|------------|-----------|------------|---------------|------------------|
| `inventory_key` | `BIGINT(20)` | `PRIMARY KEY`, `AUTO_INCREMENT`, `NOT NULL` | - | Kunci utama unik (*surrogate key*) untuk setiap baris fakta snapshot persediaan. |
| `tanggal_key` | `INT(11)` | `FOREIGN KEY`, `INDEX`, `NOT NULL` | `-1` | Referensi ke `dim_tanggal(tanggal_key)` yang menunjukkan tanggal pencatatan snapshot stok. |
| `produk_key` | `INT(11)` | `FOREIGN KEY`, `INDEX`, `NOT NULL` | `-1` | Referensi ke `dim_produk(produk_key)` untuk mengidentifikasi produk spesifik yang dicatat. |
| `kategori_key` | `INT(11)` | `FOREIGN KEY`, `INDEX`, `NOT NULL` | `-1` | Referensi ke `dim_kategori(kategori_key)` untuk pengelompokan stok berdasarkan kategori/subkategori. |
| `lokasi_key` | `INT(11)` | `FOREIGN KEY`, `INDEX`, `NOT NULL` | `-1` | Referensi ke `dim_lokasi(lokasi_key)` untuk mengetahui gudang/lokasi tempat stok berada. |
| `rak_key` | `INT(11)` | `FOREIGN KEY`, `INDEX`, `NOT NULL` | `-1` | Referensi ke `dim_rak(rak_key)` untuk melacak posisi rak dan bin penyimpanan barang. |
| `quantity_stok` | `INT(11)` | `NOT NULL` | `0` | Ukuran (*measure*) jumlah fisik unit barang yang tersedia pada titik snapshot tersebut. |
| `unit_cost` | `DECIMAL(19,4)` | `NOT NULL` | `0.0000` | Ukuran (*measure*) harga pokok/biaya standar per unit produk pada saat snapshot dicatat. |
| `nilai_stok` | `DECIMAL(19,4)` | `NOT NULL` | `0.0000` | Ukuran (*measure*) turunan total valuasi nilai persediaan (`quantity_stok × unit_cost`). |

---

## 4. Daftar Tabel Staging & Tipe Datanya (Pendukung Jalur ETL / n8n)

Tabel *staging* disimpan sebagai penampung sementara hasil ekstraksi dari skema sumber `Production.*` sebelum dimuat ke tabel dimensi dan fakta.

| Nama Tabel Staging | Nama Kolom | Tipe Data | Keterangan Sumber OLTP |
|--------------------|------------|-----------|-----------------------|
| **`stg_product_category`** | `product_category_id` | `INT(11)` | `Production.ProductCategory.ProductCategoryID` (PK) |
| | `name` | `VARCHAR(100)` | `Production.ProductCategory.Name` |
| | `modified_date` | `DATETIME` | `Production.ProductCategory.ModifiedDate` |
| | `load_timestamp` | `DATETIME` | Timestamp waktu ekstraksi ke staging |
| **`stg_product_subcategory`** | `product_subcategory_id` | `INT(11)` | `Production.ProductSubcategory.ProductSubcategoryID` (PK) |
| | `product_category_id` | `INT(11)` | `Production.ProductSubcategory.ProductCategoryID` |
| | `name` | `VARCHAR(100)` | `Production.ProductSubcategory.Name` |
| | `modified_date` | `DATETIME` | `Production.ProductSubcategory.ModifiedDate` |
| | `load_timestamp` | `DATETIME` | Timestamp waktu ekstraksi ke staging |
| **`stg_location`** | `location_id` | `INT(11)` | `Production.Location.LocationID` (PK) |
| | `name` | `VARCHAR(100)` | `Production.Location.Name` |
| | `cost_rate` | `DECIMAL(10,2)` | `Production.Location.CostRate` |
| | `availability` | `DECIMAL(10,2)` | `Production.Location.Availability` |
| | `modified_date` | `DATETIME` | `Production.Location.ModifiedDate` |
| | `load_timestamp` | `DATETIME` | Timestamp waktu ekstraksi ke staging |
| **`stg_product`** | `product_id` | `INT(11)` | `Production.Product.ProductID` (PK) |
| | `name` | `VARCHAR(100)` | `Production.Product.Name` |
| | `product_number` | `VARCHAR(25)` | `Production.Product.ProductNumber` |
| | `product_subcategory_id` | `INT(11)` | `Production.Product.ProductSubcategoryID` |
| | `standard_cost` | `DECIMAL(19,4)` | `Production.Product.StandardCost` |
| | `reorder_point` | `INT(11)` | `Production.Product.ReorderPoint` |
| | `modified_date` | `DATETIME` | `Production.Product.ModifiedDate` |
| | `load_timestamp` | `DATETIME` | Timestamp waktu ekstraksi ke staging |
| **`stg_product_inventory`** | `product_id` | `INT(11)` | `Production.ProductInventory.ProductID` (PK) |
| | `location_id` | `INT(11)` | `Production.ProductInventory.LocationID` (PK) |
| | `shelf` | `VARCHAR(10)` | `Production.ProductInventory.Shelf` |
| | `bin` | `INT(11)` | `Production.ProductInventory.Bin` |
| | `quantity` | `INT(11)` | `Production.ProductInventory.Quantity` |
| | `modified_date` | `DATETIME` | `Production.ProductInventory.ModifiedDate` |
| | `load_timestamp` | `DATETIME` | Timestamp waktu ekstraksi ke staging |
