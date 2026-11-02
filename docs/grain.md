# Grain Statement dan Star Schema v1 — Inventory Snapshot

## 1. Proses bisnis dan sumber utama

Proses bisnis yang dimodelkan adalah **posisi persediaan pada satu waktu snapshot** (*inventory snapshot*), bukan pergerakan transaksi masuk/keluar. Tabel sumber utama ialah `dwo.production_productinventory`. Database sumber dan target sama-sama berada pada **MySQL**: `dwo` dan `dwo_fakta`.

## 2. Grain statement

> **Satu baris pada `dwo_fakta.fact_inventory_snapshot` merepresentasikan jumlah stok satu produk pada satu lokasi penyimpanan dalam satu tanggal snapshot tertentu.**

Kunci grain logis: `date_key + product_key + location_key`.

Konsekuensi desain:

- Satu produk yang tersimpan di dua lokasi akan menghasilkan **dua baris fakta** pada snapshot yang sama.
- Total stok per produk harus dihitung dengan menjumlahkan baris seluruh lokasi.
- Tanggal snapshot seluruh baris untuk satu proses ekstraksi harus **sama**.
- Desain saat ini merepresentasikan **maksimal satu snapshot per tanggal** (karena `date_key` berbasis hari). Jika perlu beberapa snapshot pada hari yang sama, grain dan kunci waktunya harus dikembangkan menjadi tingkat timestamp/batch.
- `modifieddate` dari tabel sumber **bukan** tanggal snapshot; kolom tersebut menunjukkan waktu perubahan record.

## 3. Star Schema v1

**Satu tabel fakta:** `fact_inventory_snapshot`.

| Kolom | Jenis | Makna |
|---|---|---|
| `inventory_snapshot_key` | PK, surrogate key | Identitas baris fakta |
| `date_key` | FK → `dim_waktu` | Tanggal snapshot |
| `product_key` | FK → `dim_produk` | Produk |
| `location_key` | FK → `dim_lokasi` | Lokasi penyimpanan |
| `quantity` | Measure aditif | Jumlah unit stok |
| `stock_value` | Measure aditif | Estimasi nilai stok saat snapshot |

**Tiga tabel dimensi:**

| Dimensi | Primary key | Atribut yang relevan |
|---|---|---|
| `dim_waktu` | `date_key` | `full_date`, `day`, `month`, `month_name`, `quarter`, `year` |
| `dim_produk` | `product_key` | `product_id`, `product_name`, `product_number`, `color`, `size`, `subcategory_name`, `category_name`, `reorder_point`, `standard_cost` |
| `dim_lokasi` | `location_key` | `location_id`, `location_name`, `availability`, `cost_rate` |

**Relasi:** ketiga dimensi berhubungan langsung ke `fact_inventory_snapshot` melalui foreign key; dimensi kategori dan subkategori **digabung** sebagai atribut `dim_produk`, bukan menjadi tabel dimensi terpisah.

### Tempat gambar Star Schema

**[Sisipkan gambar rancangan Star Schema v1 di sini]**

*Gambar 1. Star Schema v1 untuk Data Warehouse Inventory Snapshot AdventureWorks.*

## 4. Ukuran dan aturan agregasi

| Atribut | Perhitungan / penggunaan | Aturan |
|---|---|---|
| `quantity` | `SUM(quantity)` | Dapat dijumlahkan antarproduk dan antarlokasi dalam **satu** snapshot; jangan menjumlahkan beberapa snapshot sebagai stok pada satu waktu |
| `stock_value` | `quantity × standard_cost` saat ETL, lalu `SUM(stock_value)` | Nilai estimasi berdasarkan biaya standar, bukan nilai jual |
| `reorder_point` | Bandingkan `SUM(quantity)` per produk dengan `MAX(reorder_point)` setelah pengelompokan | Atribut produk, **tidak** dijumlahkan per lokasi |
| `standard_cost` | Biaya per unit untuk menghitung `stock_value` | **Tidak** dijumlahkan sebagai nilai stok |

`quantity` dan `stock_value` adalah ukuran *semi-additive terhadap waktu*: boleh dijumlahkan antarproduk/lokasi pada satu snapshot, tetapi jumlah antarsnapshot tidak mewakili stok aktual pada satu tanggal.

## 5. Penelusuran sumber (source-to-target)

| Sumber `dwo` | Kolom sumber | Target `dwo_fakta` |
|---|---|---|
| `production_productinventory` | `productid`, `locationid`, `quantity` | FK produk/lokasi dan `fact_inventory_snapshot.quantity` |
| `production_product` | `productid`, `name`, `productnumber`, `color`, `size`, `reorderpoint`, `standardcost` | Atribut `dim_produk`; `standardcost` dipakai saat menghitung `stock_value` |
| `production_productsubcategory` | `productsubcategoryid`, `name`, `productcategoryid` | `dim_produk.subcategory_name` dan jalur ke kategori |
| `production_productcategory` | `productcategoryid`, `name` | `dim_produk.category_name` |
| `production_location` | `locationid`, `name`, `availability`, `costrate` | Atribut `dim_lokasi` |
| Waktu ekstraksi | Tanggal snapshot disepakati sebelum ETL | `dim_waktu.date_key` dan FK fakta |

## 6. Query Data Profiling (MySQL)

Jalankan pada koneksi MySQL yang dapat mengakses database `dwo`.

### A. Jumlah baris kelima tabel sumber

```sql
SELECT 'production_productinventory' AS nama_tabel, COUNT(*) AS jumlah_baris
FROM dwo.production_productinventory
UNION ALL
SELECT 'production_product', COUNT(*) FROM dwo.production_product
UNION ALL
SELECT 'production_productsubcategory', COUNT(*) FROM dwo.production_productsubcategory
UNION ALL
SELECT 'production_productcategory', COUNT(*) FROM dwo.production_productcategory
UNION ALL
SELECT 'production_location', COUNT(*) FROM dwo.production_location;
```

### B. Rentang tanggal perubahan record (bukan rentang snapshot)

```sql
SELECT
    MIN(modifieddate) AS modifieddate_terawal,
    MAX(modifieddate) AS modifieddate_terakhir
FROM dwo.production_productinventory;
```

### C. Pemeriksaan NULL pada kolom kritis

```sql
SELECT
    COUNT(*) AS total_baris,
    SUM(CASE WHEN productid IS NULL THEN 1 ELSE 0 END) AS null_productid,
    SUM(CASE WHEN locationid IS NULL THEN 1 ELSE 0 END) AS null_locationid,
    SUM(CASE WHEN quantity IS NULL THEN 1 ELSE 0 END) AS null_quantity
FROM dwo.production_productinventory;

SELECT
    COUNT(*) AS total_baris,
    SUM(CASE WHEN standardcost IS NULL THEN 1 ELSE 0 END) AS null_standardcost,
    SUM(CASE WHEN reorderpoint IS NULL THEN 1 ELSE 0 END) AS null_reorderpoint
FROM dwo.production_product;
```

### D. Pemeriksaan keunikan grain pada sumber

```sql
SELECT productid, locationid, COUNT(*) AS jumlah_baris
FROM dwo.production_productinventory
GROUP BY productid, locationid
HAVING COUNT(*) > 1;
```

### E. Pemeriksaan pasangan produk dan lokasi

```sql
SELECT pi.productid, pi.locationid, pi.quantity
FROM dwo.production_productinventory AS pi
LEFT JOIN dwo.production_product AS p ON p.productid = pi.productid
LEFT JOIN dwo.production_location AS l ON l.locationid = pi.locationid
WHERE p.productid IS NULL OR l.locationid IS NULL;
```

### Ringkasan hasil profiling

| Uji | Hasil aktual | Interpretasi |
|---|---|---|
| Jumlah baris tabel sumber | **[Isi dari MySQL]** | **[Interpretasi]** |
| `MIN(modifieddate)`–`MAX(modifieddate)` | **[Isi dari MySQL]** | Rentang perubahan record, bukan rentang snapshot |
| Jumlah NULL kritis | **[Isi dari MySQL]** | **[Interpretasi]** |
| Duplikasi produk–lokasi | **[Isi dari MySQL]** | **[Interpretasi]** |
| Baris tanpa pasangan produk/lokasi | **[Isi dari MySQL]** | **[Interpretasi]** |

## 7. Validasi setelah ETL

Untuk satu snapshot, jumlah baris fakta dan total kuantitas harus sama dengan cakupan sumber yang dimuat (kecuali pengecualian tercatat). Lakukan pengujian berikut dengan mengganti `[DATE_KEY]` menjadi nilai numerik yang benar, tanpa tanda kurung siku:

```sql
-- Pastikan nilai date_key snapshot yang ada terlebih dahulu
SELECT date_key, COUNT(*) AS jumlah_baris
FROM dwo_fakta.fact_inventory_snapshot
GROUP BY date_key
ORDER BY date_key DESC;

-- Perbandingan jumlah baris dan total stok untuk snapshot tertentu:
SET @snapshot_date_key := (
    SELECT MAX(date_key) FROM dwo_fakta.fact_inventory_snapshot
);

SELECT COUNT(*) AS baris_sumber, SUM(quantity) AS stok_sumber
FROM dwo.production_productinventory;

SELECT COUNT(*) AS baris_fakta, SUM(quantity) AS stok_fakta
FROM dwo_fakta.fact_inventory_snapshot
WHERE date_key = @snapshot_date_key;
```

> Perbandingan tersebut valid jika sumber `dwo` belum berubah sejak ekstraksi snapshot, atau jika sumber dibandingkan dengan **salinan ekstraksi yang sama**. Untuk data operasional yang berubah, simpan hasil ekstraksi atau bukti rekonsiliasi pada saat ETL; jangan membandingkan snapshot lama dengan stok sumber terkini.

## 8. Keputusan ruang lingkup histori

Versi 1 dianalisis pada **satu snapshot**. Jika dijadwalkan berkala, dimensi produk berpotensi membutuhkan *Slowly Changing Dimension* atau nilai `reorder_point` historis pada fakta agar Q4 untuk snapshot lama tidak berubah ketika atribut produk diperbarui. Nilai `stock_value` pada fakta sudah ditetapkan pada saat pemuatan.