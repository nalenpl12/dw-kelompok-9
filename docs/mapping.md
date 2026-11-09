# Pemetaan Data Warehouse (Data Warehouse Mapping)

Dokumen ini berisi spesifikasi pemetaan (mapping) data dari sumber OLTP (*AdventureWorks*) ke tabel dimensi dan fakta pada Data Warehouse. 

---

## Target: dim_kategori (SCD: Tipe 1)

**Sumber Utama:** `Production.ProductCategory`, `Production.ProductSubcategory`

| Kolom Target | Tipe | Tabel.Kolom Sumber | Transformasi | Aturan NULL |
| :--- | :--- | :--- | :--- | :--- |
| `kategori_key` | INT | - | Surrogate key dari DW (Auto Increment / Lookup Key) | - |
| `nama_kategori` | VARCHAR(100) | `Production.ProductCategory.Name` | Langsung (via JOIN ke `ProductSubcategory`) | 'Tanpa Kategori' |
| `nama_subkategori` | VARCHAR(100) | `Production.ProductSubcategory.Name` | Langsung | 'Tanpa Subkategori' |

---

## Target: dim_lokasi (SCD: Tipe 1)

**Sumber Utama:** `Production.Location`

| Kolom Target | Tipe | Tabel.Kolom Sumber | Transformasi | Aturan NULL |
| :--- | :--- | :--- | :--- | :--- |
| `lokasi_key` | INT | `Production.Location.LocationID` | Surrogate key dari DW (peta dari LocationID OLTP) | - |
| `nama_lokasi` | VARCHAR(100) | `Production.Location.Name` | Langsung | 'Tidak Diketahui' |
| `cost_rate` | DECIMAL(10,2) | `Production.Location.CostRate` | Langsung | 0.00 |
| `availability` | DECIMAL(10,2) | `Production.Location.Availability` | Langsung | 0.00 |

---

## Target: dim_produk (SCD: Tipe 1)

**Sumber Utama:** `Production.Product`

| Kolom Target | Tipe | Tabel.Kolom Sumber | Transformasi | Aturan NULL |
| :--- | :--- | :--- | :--- | :--- |
| `produk_key` | INT | `Production.Product.ProductID` | Surrogate key dari DW (peta dari ProductID OLTP) | - |
| `nama_produk` | VARCHAR(100) | `Production.Product.Name` | Langsung | 'Tidak Diketahui' |
| `nomor_produk` | VARCHAR(25) | `Production.Product.ProductNumber` | Langsung | '-' |
| `standard_cost` | DECIMAL(19,4) | `Production.Product.StandardCost` | Langsung | 0.0000 |
| `reorder_point` | INT | `Production.Product.ReorderPoint` | Langsung | 0 |

---

## Target: dim_rak (SCD: Tipe 1)

**Sumber Utama:** `Production.ProductInventory`

| Kolom Target | Tipe | Tabel.Kolom Sumber | Transformasi | Aturan NULL |
| :--- | :--- | :--- | :--- | :--- |
| `rak_key` | INT | - | Surrogate key dari DW (Generate urutan unik dari kombinasi `Shelf` & `Bin`) | - |
| `shelf` | VARCHAR(10) | `Production.ProductInventory.Shelf` | Langsung (`SELECT DISTINCT Shelf, Bin`) | 'N/A' |
| `bin` | INT | `Production.ProductInventory.Bin` | Langsung (`SELECT DISTINCT Shelf, Bin`) | 0 |

---

## Target: dim_tanggal (SCD: Tipe 0 / Statis)

**Sumber Utama:** Date Generator / Script ETL Tanggal Standar

| Kolom Target | Tipe | Tabel.Kolom Sumber | Transformasi | Aturan NULL |
| :--- | :--- | :--- | :--- | :--- |
| `tanggal_key` | INT | - | Tanggal ke format YYYYMMDD | -1 |
| `tanggal` | DATE | - | Ekstrak tanggal `YYYY-MM-DD` | '1900-01-01' |
| `tahun` | INT | - | `YEAR(tanggal)` | 0 |
| `semester` | INT | - | `CASE WHEN MONTH(tanggal) <= 6 THEN 1 ELSE 2 END` | 0 |
| `kuartal` | INT | - | `QUARTER(tanggal)` | 0 |
| `bulan` | INT | - | `MONTH(tanggal)` | 0 |
| `nama_bulan` | VARCHAR(15) | - | Nama bulan Indonesia (misal: 'Januari') | 'Tidak diketahui' |
| `minggu_dalam_tahun` | INT | - | `WEEKOFYEAR(tanggal)` | 0 |
| `tanggal_dalam_bulan` | INT | - | `DAYOFMONTH(tanggal)` | 0 |
| `hari_dalam_minggu` | INT | - | `DAYOFWEEK(tanggal)` | 0 |
| `nama_hari` | VARCHAR(15) | - | Nama hari Indonesia (misal: 'Senin') | 'Tidak diketahui' |
| `is_akhir_pekan` | TINYINT(1) | - | `CASE WHEN hari_dalam_minggu IN (6,7) THEN 1 ELSE 0 END` | 0 |

---

## Target: fact_inventory

**Grain:** Satu baris per kombinasi produk, lokasi, dan rak pada tanggal pencatatan inventaris.

| Kolom Target | Tipe | Tabel.Kolom Sumber | Transformasi | Aturan NULL |
| :--- | :--- | :--- | :--- | :--- |
| `tanggal_key` | INT | `Production.ProductInventory.ModifiedDate` | Tanggal ke YYYYMMDD (Lookup `dim_tanggal`) | -1 |
| `produk_key` | INT | `Production.ProductInventory.ProductID` | Lookup `dim_produk.produk_key` via `ProductID` | -1 |
| `kategori_key` | INT | `Production.Product.ProductSubcategoryID` | Lookup `dim_kategori.kategori_key` via `ProductSubcategoryID` | 0 |
| `lokasi_key` | INT | `Production.ProductInventory.LocationID` | Lookup `dim_lokasi.lokasi_key` via `LocationID` | -1 |
| `rak_key` | INT | `Production.ProductInventory.Shelf`, `Bin` | Lookup `dim_rak.rak_key` via kombinasi (`Shelf`, `Bin`) | -1 |
| `quantity` | INT | `Production.ProductInventory.Quantity` | Langsung | 0 |

---

## Urutan Execution / Load ETL

1. `dim_tanggal` (Di-populate pertama kali sebagai dimensi statis independen).
2. `dim_kategori` (Loaded dari join `ProductCategory` dan `ProductSubcategory`).
3. `dim_lokasi` (Loaded dari tabel `Location`).
4. `dim_produk` (Loaded dari tabel `Product`, butuh `dim_kategori` untuk pemetaan key).
5. `dim_rak` (Loaded dari kombinasi unik `Shelf` dan `Bin` pada `ProductInventory`).
6. `fact_inventory` (Loaded paling akhir setelah seluruh surrogate key dimensi tersedia untuk proses lookup).