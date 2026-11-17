# Source-to-Target Mapping Data Warehouse

Dokumen ini berisi spesifikasi pemetaan (*mapping*) data dari database OLTP (*AdventureWorks*) ke area *Staging* dan *Data Warehouse* (`dwo_fakta`), strategi SCD, alasan pemilihan tipe data, serta daftar urutan pemuatan (*load order*).

---

## Strategi SCD (Slowly Changing Dimension)
1. **`dim_tanggal` (SCD Tipe 0 / Statis):** Data tanggal kalender bersifat tetap dan tidak pernah berubah.
2. **`dim_kategori` (SCD Tipe 1):** Mengabaikan histori perubahan; nama kategori/subkategori langsung diperbarui (*overwrite*).
3. **`dim_lokasi` (SCD Tipe 1):** Perubahan atribut lokasi langsung ditimpa (*overwrite*).
4. **`dim_rak` (SCD Tipe 1):** Struktur rak/bin ditimpa jika ada pembaruan (*overwrite*).
5. **`dim_produk` (SCD Tipe 2 - Melacak Histori Perubahan):** 
   * **Alasan:** Perubahan harga (`standard_cost`) dan `reorder_point` pada produk bersifat sensitif terhadap analisis nilai inventaris dari waktu ke waktu.
   * **Mekanisme:** Menggunakan *surrogate key* baru setiap kali ada perubahan data produk, serta menyimpan atribut pelacak periode aktif (`date_from`, `date_to`, `is_current`).

---

## Tipe Data Penting dan Alasannya
* **`produk_key` / Primary Key Dimensi (`INT AUTO_INCREMENT`):** Menggunakan *Surrogate Key* berupa integer positif universal agar terpisah dari Natural Key OLTP dan mendukung pelacakan histori SCD Tipe 2.
* **`inventory_key` (`BIGINT(20) AUTO_INCREMENT`):** Menggunakan `BIGINT` sebagai surrogate key tabel fakta agar mampu menampung pertumbuhan baris snapshot inventaris harian dalam jangka panjang tanpa risiko *integer overflow*.
* **`tanggal_key` (`INT` format `YYYYMMDD`):** Menggunakan format integer 8 digit (contoh: `20261117`) untuk optimasi indeks dan performa *join* tabel fakta, dibandingkan tipe data `DATE` atau `DATETIME`.
* **`standard_cost`, `unit_cost`, `nilai_stok` (`DECIMAL(19,4)`):** Menggunakan presisi tinggi 4 angka di belakang koma untuk menghindari galat pembulatan nilai finansial/biaya persediaan.
* **`is_current` (`TINYINT(1)`):** Menggunakan flag boolean `0`/`1` untuk mempermudah filter record aktif terkini pada query OLAP/tabel fakta.

---

## Daftar Tabel Staging (OLTP ke Staging Area)

Tabel *staging* berfungsi sebagai area penampungan sementara (*landing zone*) hasil ekstraksi mentah dari database sumber OLTP (`Production.*`) sebelum dilakukan pembersihan (*cleansing*) dan transformasi ke tabel dimensi maupun fakta.

### Staging: `stg_product_category`
Sumber utama: `Production.ProductCategory`

| Kolom target | Tipe | Tabel.kolom sumber | Transformasi | Aturan NULL |
|--------------|------|--------------------|--------------|-------------|
| `product_category_id` | INT | `Production.ProductCategory.ProductCategoryID` | Langsung (Primary Key OLTP) | - |
| `name` | VARCHAR(100) | `Production.ProductCategory.Name` | Langsung (`TRIM`) | 'Tanpa Kategori' |
| `modified_date` | DATETIME | `Production.ProductCategory.ModifiedDate` | Langsung | `CURRENT_TIMESTAMP` |
| `load_timestamp` | DATETIME | - | Waktu ekstraksi ETL (`NOW()`) | `CURRENT_TIMESTAMP` |

### Staging: `stg_product_subcategory`
Sumber utama: `Production.ProductSubcategory`

| Kolom target | Tipe | Tabel.kolom sumber | Transformasi | Aturan NULL |
|--------------|------|--------------------|--------------|-------------|
| `product_subcategory_id` | INT | `Production.ProductSubcategory.ProductSubcategoryID` | Langsung (Primary Key OLTP) | - |
| `product_category_id` | INT | `Production.ProductSubcategory.ProductCategoryID` | Langsung (Foreign Key OLTP) | -1 |
| `name` | VARCHAR(100) | `Production.ProductSubcategory.Name` | Langsung (`TRIM`) | 'Tanpa Subkategori' |
| `modified_date` | DATETIME | `Production.ProductSubcategory.ModifiedDate` | Langsung | `CURRENT_TIMESTAMP` |
| `load_timestamp` | DATETIME | - | Waktu ekstraksi ETL (`NOW()`) | `CURRENT_TIMESTAMP` |

### Staging: `stg_location`
Sumber utama: `Production.Location`

| Kolom target | Tipe | Tabel.kolom sumber | Transformasi | Aturan NULL |
|--------------|------|--------------------|--------------|-------------|
| `location_id` | INT | `Production.Location.LocationID` | Langsung (Primary Key OLTP) | - |
| `name` | VARCHAR(100) | `Production.Location.Name` | Langsung (`TRIM`) | 'Tidak Diketahui' |
| `cost_rate` | DECIMAL(10,2) | `Production.Location.CostRate` | Langsung | 0.00 |
| `availability` | DECIMAL(10,2) | `Production.Location.Availability` | Langsung | 0.00 |
| `modified_date` | DATETIME | `Production.Location.ModifiedDate` | Langsung | `CURRENT_TIMESTAMP` |
| `load_timestamp` | DATETIME | - | Waktu ekstraksi ETL (`NOW()`) | `CURRENT_TIMESTAMP` |

### Staging: `stg_product`
Sumber utama: `Production.Product`

| Kolom target | Tipe | Tabel.kolom sumber | Transformasi | Aturan NULL |
|--------------|------|--------------------|--------------|-------------|
| `product_id` | INT | `Production.Product.ProductID` | Langsung (Primary Key OLTP) | - |
| `name` | VARCHAR(100) | `Production.Product.Name` | Langsung (`TRIM`) | 'Tidak Diketahui' |
| `product_number` | VARCHAR(25) | `Production.Product.ProductNumber` | Langsung (`TRIM`) | '-' |
| `product_subcategory_id` | INT | `Production.Product.ProductSubcategoryID` | Langsung | -1 |
| `standard_cost` | DECIMAL(19,4) | `Production.Product.StandardCost` | Langsung | 0.0000 |
| `reorder_point` | INT | `Production.Product.ReorderPoint` | Langsung | 0 |
| `modified_date` | DATETIME | `Production.Product.ModifiedDate` | Langsung | `CURRENT_TIMESTAMP` |
| `load_timestamp` | DATETIME | - | Waktu ekstraksi ETL (`NOW()`) | `CURRENT_TIMESTAMP` |

### Staging: `stg_product_inventory`
Sumber utama: `Production.ProductInventory`

| Kolom target | Tipe | Tabel.kolom sumber | Transformasi | Aturan NULL |
|--------------|------|--------------------|--------------|-------------|
| `product_id` | INT | `Production.ProductInventory.ProductID` | Langsung (Composite PK OLTP) | - |
| `location_id` | INT | `Production.ProductInventory.LocationID` | Langsung (Composite PK OLTP) | - |
| `shelf` | VARCHAR(10) | `Production.ProductInventory.Shelf` | Langsung (`TRIM`) | 'N/A' |
| `bin` | INT | `Production.ProductInventory.Bin` | Langsung | 0 |
| `quantity` | INT | `Production.ProductInventory.Quantity` | Langsung | 0 |
| `modified_date` | DATETIME | `Production.ProductInventory.ModifiedDate` | Langsung | `CURRENT_TIMESTAMP` |
| `load_timestamp` | DATETIME | - | Waktu ekstraksi ETL (`NOW()`) | `CURRENT_TIMESTAMP` |

---

## Target: dim_tanggal   (SCD: tipe 0)
Sumber utama: Skrip Date Generator Standar v1.0

| Kolom target | Tipe | Tabel.kolom sumber | Transformasi | Aturan NULL |
|--------------|------|--------------------|--------------|-------------|
| `tanggal_key` | INT(11) | - | Ekstrak tanggal ke format `YYYYMMDD` | -1 |
| `tanggal` | DATE | - | Ekstrak tanggal `YYYY-MM-DD` | '1900-01-01' |
| `tahun` | INT(11) | - | `YEAR(tanggal)` | 0 |
| `semester` | INT(11) | - | `CASE WHEN MONTH(tanggal) <= 6 THEN 1 ELSE 2 END` | 0 |
| `kuartal` | INT(11) | - | `QUARTER(tanggal)` | 0 |
| `bulan` | INT(11) | - | `MONTH(tanggal)` | 0 |
| `nama_bulan` | VARCHAR(15) | - | Nama bulan Indonesia (misal: 'Januari') | 'Tidak diketahui' |
| `minggu_dalam_tahun` | INT(11) | - | `WEEKOFYEAR(tanggal)` | 0 |
| `tanggal_dalam_bulan` | INT(11) | - | `DAYOFMONTH(tanggal)` | 0 |
| `hari_dalam_minggu` | INT(11) | - | `DAYOFWEEK(tanggal)` | 0 |
| `nama_hari` | VARCHAR(15) | - | Nama hari Indonesia (misal: 'Senin') | 'Tidak diketahui' |
| `is_akhir_pekan` | TINYINT(1) | - | `CASE WHEN hari_dalam_minggu IN (1,7) THEN 1 ELSE 0 END` | 0 |

---

## Target: dim_kategori   (SCD: tipe 1)
Sumber utama: `stg_product_category`, `stg_product_subcategory` (`Production.ProductCategory`, `Production.ProductSubcategory`)

| Kolom target | Tipe | Tabel.kolom sumber | Transformasi | Aturan NULL |
|--------------|------|--------------------|--------------|-------------|
| `kategori_key` | INT(11) | - | Surrogate key dari DW (`AUTO_INCREMENT`) | -1 |
| `nama_kategori` | VARCHAR(100) | `Production.ProductCategory.Name` | Langsung (via `LEFT JOIN` ke `ProductSubcategory`) | 'Tanpa Kategori' |
| `nama_subkategori` | VARCHAR(100) | `Production.ProductSubcategory.Name` | Langsung | 'Tanpa Subkategori' |

---

## Target: dim_lokasi   (SCD: tipe 1)
Sumber utama: `stg_location` (`Production.Location`)

| Kolom target | Tipe | Tabel.kolom sumber | Transformasi | Aturan NULL |
|--------------|------|--------------------|--------------|-------------|
| `lokasi_key` | INT(11) | - | Surrogate key dari DW (`AUTO_INCREMENT`) | -1 |
| `nama_lokasi` | VARCHAR(100) | `Production.Location.Name` | Langsung | 'Tidak Diketahui' |
| `cost_rate` | DECIMAL(10,2) | `Production.Location.CostRate` | Langsung | 0.00 |
| `availability` | DECIMAL(10,2) | `Production.Location.Availability` | Langsung | 0.00 |

---

## Target: dim_rak   (SCD: tipe 1)
Sumber utama: `stg_product_inventory` (`Production.ProductInventory`)

| Kolom target | Tipe | Tabel.kolom sumber | Transformasi | Aturan NULL |
|--------------|------|--------------------|--------------|-------------|
| `rak_key` | INT(11) | - | Surrogate key dari DW (Generate unik kombinasi `Shelf` & `Bin`) | -1 |
| `shelf` | VARCHAR(10) | `Production.ProductInventory.Shelf` | Langsung (`SELECT DISTINCT Shelf, Bin`) | 'N/A' |
| `bin` | INT(11) | `Production.ProductInventory.Bin` | Langsung (`SELECT DISTINCT Shelf, Bin`) | 0 |

---

## Target: dim_produk   (SCD: tipe 2)
Sumber utama: `stg_product` (`Production.Product`)

| Kolom target | Tipe | Tabel.kolom sumber | Transformasi | Aturan NULL |
|--------------|------|--------------------|--------------|-------------|
| `produk_key` | INT(11) | - | Surrogate key dari DW (`AUTO_INCREMENT` SCD2) | -1 |
| `produk_id` | INT(11) | `Production.Product.ProductID` | Langsung (Natural Key) | -1 |
| `nama_produk` | VARCHAR(100) | `Production.Product.Name` | Langsung | 'Tidak Diketahui' |
| `nomor_produk` | VARCHAR(25) | `Production.Product.ProductNumber` | Langsung | '-' |
| `standard_cost` | DECIMAL(19,4) | `Production.Product.StandardCost` | Langsung | 0.0000 |
| `reorder_point` | INT(11) | `Production.Product.ReorderPoint` | Langsung | 0 |
| `date_from` | DATE | - | Tanggal awal versi record berlaku | '1900-01-01' |
| `date_to` | DATE | - | Tanggal akhir versi record berlaku (`9999-12-31` jika aktif) | '9999-12-31' |
| `is_current` | TINYINT(1) | - | `1` jika record versi aktif terkini, `0` jika historis | 1 |

---

## Target: fact_inventory   (grain: Satu baris per kombinasi produk, kategori, lokasi, dan rak pada satu tanggal pencatatan snapshot inventaris)
Sumber utama: `stg_product_inventory`, `stg_product` (`Production.ProductInventory`, `Production.Product`)

| Kolom target | Tipe | Tabel.kolom sumber | Transformasi | Aturan NULL |
|--------------|------|--------------------|--------------|-------------|
| `inventory_key` | BIGINT(20) | - | Surrogate key fakta dari DW (`AUTO_INCREMENT`) | - |
| `tanggal_key` | INT(11) | `Production.ProductInventory.ModifiedDate` | Konversi tanggal snapshot ke integer `YYYYMMDD` (Lookup `dim_tanggal`) | -1 |
| `produk_key` | INT(11) | `Production.ProductInventory.ProductID` | Lookup `dim_produk.produk_key` (pada `is_current = 1`) | -1 |
| `kategori_key` | INT(11) | `Production.Product.ProductSubcategoryID` | Lookup `dim_kategori.kategori_key` via kategori/subkategori produk | -1 |
| `lokasi_key` | INT(11) | `Production.ProductInventory.LocationID` | Lookup `dim_lokasi.lokasi_key` via `LocationID` | -1 |
| `rak_key` | INT(11) | `Production.ProductInventory.Shelf`, `Bin` | Lookup `dim_rak.rak_key` via kombinasi (`Shelf`, `Bin`) | -1 |
| `quantity_stok` | INT(11) | `Production.ProductInventory.Quantity` | Langsung | 0 |
| `unit_cost` | DECIMAL(19,4) | `Production.Product.StandardCost` | Lookup biaya standar produk saat snapshot (`dim_produk.standard_cost`) | 0.0000 |
| `nilai_stok` | DECIMAL(19,4) | `Production.ProductInventory.Quantity`, `Production.Product.StandardCost` | Kalkulasi: `quantity_stok * unit_cost` | 0.0000 |

---

## Urutan Load
Pemuatan data dari sumber OLTP hingga ke tabel fakta dilakukan secara bertahap berdasarkan dependensi relasi (*referential integrity*):

1. **Pemuatan Staging (Tahap Ekstraksi Raw Data):**
   * `stg_product_category` & `stg_product_subcategory`
   * `stg_location`
   * `stg_product`
   * `stg_product_inventory`

2. **Pemuatan Dimensi Statis & Utama (Level 1 - Tanpa Dependensi):**
   * `dim_tanggal` (Dipasang awal menggunakan skrip kalender standar v1.0).
   * `dim_lokasi` (Dimuat langsung dari `stg_location`).
   * `dim_rak` (Dimuat dari kombinasi unik `shelf` dan `bin` pada `stg_product_inventory`).

3. **Pemuatan Dimensi Hirarki & SCD Tipe 2 (Level 2 - Dengan Dependensi/Histori):**
   * `dim_kategori` (Hasil *join* antara `stg_product_category` dan `stg_product_subcategory`).
   * `dim_produk` (Dimuat dengan mekanisme SCD Tipe 2 untuk mencatat histori perubahan `standard_cost` dan `reorder_point`).

4. **Pemuatan Tabel Fakta (Level 3 - Tahap Akhir):**
   * `fact_inventory` (Dimuat paling akhir setelah seluruh *surrogate key* dari `dim_tanggal`, `dim_produk`, `dim_kategori`, `dim_lokasi`, dan `dim_rak` tersedia untuk proses *lookup*, lalu menghitung `nilai_stok = quantity_stok * unit_cost`).
