# Source-to-Target Mapping Data Warehouse

Dokumen ini berisi spesifikasi pemetaan (*mapping*) data dari database OLTP (*AdventureWorks*) ke Data Warehouse, strategi SCD, alasan pemilihan tipe data, serta daftar urutan pemuatan (*load order*).

---

## Strategi SCD (Surrogate Key & Change Data Capture)
1. **`dim_tanggal` (SCD Tipe 0 / Statis):** Data tanggal kalender tidak pernah berubah.
2. **`dim_kategori` (SCD Tipe 1):** Mengabaikan histori perubahan; nama kategori/subkategori langsung diperbarui (*overwrite*).
3. **`dim_lokasi` (SCD Tipe 1):** Perubahan atribut lokasi langsung ditimpa (*overwrite*).
4. **`dim_rak` (SCD Tipe 1):** Struktur rak/bin ditimpa jika ada pembaruan (*overwrite*).
5. **`dim_produk` (SCD Tipe 2 - Melacak Histori Perubahan):** 
   * **Alasan:** Perubahan harga (`standard_cost`) dan `reorder_point` pada produk bersifat sensitif terhadap analisis nilai inventaris dari waktu ke waktu.
   * **Mekanisme:** Menggunakan *surrogate key* baru setiap kali ada perubahan data produk, serta menyimpan atribut melacak periode aktif (`date_from`, `date_to`, `is_current`).

---

## Tipe Data Penting dan Alasannya
* **`produk_key` / Primary Key Dimensi (INT AUTO_INCREMENT):** Menggunakan *Surrogate Key* berupa integer positif universal agar terpisah dari Natural Key OLTP dan mendukung melacak histori SCD Tipe 2.
* **`tanggal_key` (INT format YYYYMMDD):** Menggunakan format integer 8 digit (contoh: `20261109`) untuk optimasi indeks dan performa join tabel fakta, dibandingkan tipe data `DATE` atau `DATETIME`.
* **`standard_cost` (DECIMAL 19,4):** Menggunakan `DECIMAL(19,4)` presisi tinggi untuk menghindari pembulatan nilai finansial/biaya produksi.
* **`is_current` (TINYINT 1):** Menggunakan flag boolean 0/1 untuk mempermudah filter record teraktif pada query OLAP/tabel fakta.

---

## Target: dim_tanggal   (SCD: tipe 0)
Sumber utama: Script Date Generator Standard

| Kolom target | Tipe | Tabel.kolom sumber | Transformasi | Aturan NULL |
|--------------|------|--------------------|--------------|-------------|
| tanggal_key | INT | - | Ekstrak tanggal ke format YYYYMMDD | -1 |
| tanggal | DATE | - | Ekstrak tanggal `YYYY-MM-DD` | '1900-01-01' |
| tahun | INT | - | `YEAR(tanggal)` | 0 |
| semester | INT | - | `CASE WHEN MONTH(tanggal) <= 6 THEN 1 ELSE 2 END` | 0 |
| kuartal | INT | - | `QUARTER(tanggal)` | 0 |
| bulan | INT | - | `MONTH(tanggal)` | 0 |
| nama_bulan | VARCHAR(15) | - | Nama bulan Indonesia (misal: 'Januari') | 'Tidak diketahui' |
| minggu_dalam_tahun | INT | - | `WEEKOFYEAR(tanggal)` | 0 |
| tanggal_dalam_bulan | INT | - | `DAYOFMONTH(tanggal)` | 0 |
| hari_dalam_minggu | INT | - | `DAYOFWEEK(tanggal)` | 0 |
| nama_hari | VARCHAR(15) | - | Nama hari Indonesia (misal: 'Senin') | 'Tidak diketahui' |
| is_akhir_pekan | TINYINT(1) | - | `CASE WHEN hari_dalam_minggu IN (6,7) THEN 1 ELSE 0 END` | 0 |

---

## Target: dim_kategori   (SCD: tipe 1)
Sumber utama: `Production.ProductCategory`, `Production.ProductSubcategory`

| Kolom target | Tipe | Tabel.kolom sumber | Transformasi | Aturan NULL |
|--------------|------|--------------------|--------------|-------------|
| kategori_key | INT | - | surrogate key dari DW (Auto Increment) | - |
| subkategori_id | INT | `Production.ProductSubcategory.ProductSubcategoryID` | langsung (Natural Key) | -1 |
| nama_kategori | VARCHAR(100) | `Production.ProductCategory.Name` | langsung (via JOIN ke `ProductSubcategory`) | 'Tanpa Kategori' |
| nama_subkategori | VARCHAR(100) | `Production.ProductSubcategory.Name` | langsung | 'Tanpa Subkategori' |

---

## Target: dim_lokasi   (SCD: tipe 1)
Sumber utama: `Production.Location`

| Kolom target | Tipe | Tabel.kolom sumber | Transformasi | Aturan NULL |
|--------------|------|--------------------|--------------|-------------|
| lokasi_key | INT | - | surrogate key dari DW (Auto Increment) | - |
| lokasi_id | INT | `Production.Location.LocationID` | langsung (Natural Key) | -1 |
| nama_lokasi | VARCHAR(100) | `Production.Location.Name` | langsung | 'Tidak Diketahui' |
| cost_rate | DECIMAL(10,2) | `Production.Location.CostRate` | langsung | 0.00 |
| availability | DECIMAL(10,2) | `Production.Location.Availability` | langsung | 0.00 |

---

## Target: dim_rak   (SCD: tipe 1)
Sumber utama: `Production.ProductInventory`

| Kolom target | Tipe | Tabel.kolom sumber | Transformasi | Aturan NULL |
|--------------|------|--------------------|--------------|-------------|
| rak_key | INT | - | surrogate key dari DW (Generate unik kombinasi `Shelf` & `Bin`) | - |
| shelf | VARCHAR(10) | `Production.ProductInventory.Shelf` | langsung (`SELECT DISTINCT Shelf, Bin`) | 'N/A' |
| bin | INT | `Production.ProductInventory.Bin` | langsung (`SELECT DISTINCT Shelf, Bin`) | 0 |

---

## Target: dim_produk   (SCD: tipe 2)
Sumber utama: `Production.Product`

| Kolom target | Tipe | Tabel.kolom sumber | Transformasi | Aturan NULL |
|--------------|------|--------------------|--------------|-------------|
| produk_key | INT | - | surrogate key dari DW (Auto Increment SCD2) | - |
| produk_id | INT | `Production.Product.ProductID` | langsung (Natural Key) | -1 |
| nama_produk | VARCHAR(100) | `Production.Product.Name` | langsung | 'Tidak Diketahui' |
| nomor_produk | VARCHAR(25) | `Production.Product.ProductNumber` | langsung | '-' |
| standard_cost | DECIMAL(19,4) | `Production.Product.StandardCost` | langsung | 0.0000 |
| reorder_point | INT | `Production.Product.ReorderPoint` | langsung | 0 |
| date_from | DATETIME | - | Tanggal awal record aktif | '1900-01-01 00:00:00' |
| date_to | DATETIME | - | Tanggal akhir record aktif (NULL jika aktif) | NULL |
| is_current | TINYINT(1) | - | 1 jika record versi aktif, 0 jika rilis lama | 1 |

---

## Target: fact_inventory   (grain: Satu baris per kombinasi produk, lokasi, dan rak pada tanggal pencatatan inventaris)
| Kolom target | Tipe | Tabel.kolom sumber | Transformasi | Aturan NULL |
|--------------|------|--------------------|--------------|-------------|
| tanggal_key | INT | `Production.ProductInventory.ModifiedDate` | tanggal ke YYYYMMDD (Lookup `dim_tanggal`) | -1 |
| produk_key | INT | `Production.ProductInventory.ProductID` | Lookup `dim_produk.produk_key` (di mana `is_current = 1`) | -1 |
| kategori_key | INT | `Production.Product.ProductSubcategoryID` | Lookup `dim_kategori.kategori_key` via `ProductSubcategoryID` | 0 |
| lokasi_key | INT | `Production.ProductInventory.LocationID` | Lookup `dim_lokasi.lokasi_key` via `LocationID` | -1 |
| rak_key | INT | `Production.ProductInventory.Shelf`, `Bin` | Lookup `dim_rak.rak_key` via kombinasi (`Shelf`, `Bin`) | -1 |
| quantity | INT | `Production.ProductInventory.Quantity` | langsung | 0 |

---

## Urutan Load
Pemuatan data dari staging hingga ke tabel fakta dilakukan secara bertahap berdasarkan dependensi relasi:

1. **Pemuatan Staging (Tahap Ekstraksi Raw Data):**
   * `stg_product_category` & `stg_product_subcategory`
   * `stg_location`
   * `stg_product`
   * `stg_product_inventory`

2. **Pemuatan Dimensi Statis & Utama (Level 1 - Tanpa Dependensi):**
   * `dim_tanggal` (Di-generate awal sebagai kalender statis).
   * `dim_lokasi` (Dimuat langsung dari `stg_location`).
   * `dim_rak` (Dimuat dari kombinasi unik `Shelf` dan `Bin`).

3. **Pemuatan Dimensi Hirarki & SCD 2 (Level 2 - Dengan Dependensi/Histori):**
   * `dim_kategori` (Join antara `stg_product_category` dan `stg_product_subcategory`).
   * `dim_produk` (SCD Tipe 2 dimuat dengan mencocokkan `kategori_key` serta membuat versi record baru jika ada perubahan `standard_cost` / `reorder_point`).

4. **Pemuatan Tabel Fakta (Level 3 - Akhir):**
   * `fact_inventory` (Dimuat paling akhir setelah melakukan *lookup* ke seluruh *surrogate key* dari `dim_tanggal`, `dim_produk`, `dim_kategori`, `dim_lokasi`, dan `dim_rak`).
