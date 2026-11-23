# Laporan Progres Data Warehouse — Pekan 12 & 13
**Kelompok:** 9 (`dw-kelompok-9`)  
**Studi Kasus:** Inventory Management (AdventureWorks)  
**Database Sumber & Target:** `dwo` $\rightarrow$ `dwo_fakta` (MariaDB / MySQL)  
**Tools ETL:** Pentaho Data Integration (Spoon & Kitchen) v9.4

---

## 1. Arsitektur & Alur Pipeline ETL (`etl/`)

Pipeline ETL dibangun secara modular di dalam folder `etl/` dengan alur bertahap dari ekstraksi sumber ke lapisan *staging*, pembaruan tabel dimensi (termasuk *Slowly Changing Dimension* Tipe 2), hingga pengisian tabel fakta:

1. **`t01_ekstrak.ktr`**: Mengekstrak 6 tabel operasional dari database `dwo` ke tabel *staging* (`stg_product_category`, `stg_product_subcategory`, `stg_location`, `stg_product`, `stg_product_cost_history`, dan `stg_product_inventory`) dengan opsi *Truncate table* aktif.
2. **Skrip Pembersih Idempoten (`SQL` Step pada Job)**: Menghapus baris data transaksi dan dimensi dengan `key > 0` (mempertahankan baris *unknown member* `-1`) serta mereset nilai `AUTO_INCREMENT` sebelum pemuatan ulang dimensi.
3. **`t02_dim_lokasi.ktr`**, **`t03_dim_kategori.ktr`**, **`t04_dim_rak.ktr`**: Membentuk data unik terstandarisasi ke masing-masing tabel dimensi.
4. **`t05_dim_produk.ktr` (SCD Tipe 2)**: Membangun riwayat perubahan harga pokok standar (`standard_cost`) per produk menggunakan fungsi analitik `ROW_NUMBER()` dan `LEAD()` untuk menentukan rentang tanggal berlaku (`date_from`, `date_to`) serta penanda versi aktif (`is_current`).
5. **`t10_fact_inventory.ktr`**: Melakukan *lookup* berantai terhadap `dim_tanggal`, `dim_produk` (berdasarkan kecocokan `produk_id` dan rentang `date_from <= tanggal_transaksi <= date_to`), `dim_kategori`, `dim_lokasi`, dan `dim_rak`, kemudian menghitung metrik `nilai_stok = quantity_stok * unit_cost` untuk dimuat ke `fact_inventory`.
6. **`job_utama.kjb`**: Mengorkestrasi seluruh transformasi di atas secara berurutan dari `START` hingga `Success`.

![Kanvas Job Utama Pentaho Spoon](docs/job_utama_spoon.png)

---

## 2. Pengujian Eksekusi Mandiri via `Kitchen.bat`

Pengujian dilakukan melalui Command Prompt tanpa antarmuka grafis Spoon menggunakan perintah:
```cmd
Kitchen.bat /file:"D:\Kuliah\Semester 7\Data Warehouse\dw-kelompok-9\etl\job_utama.kjb" /level:Basic
