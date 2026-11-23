-- ============================================================================
-- SKRIP REKONSILIASI DATA: SUMBER (dwo) VS DATA WAREHOUSE (dwo_fakta)
-- Proyek: dw-kelompok-9 (Inventory Management)
-- ============================================================================

-- 1. Rekonsiliasi Jumlah Baris: Sumber vs Staging
SELECT '1. Category' AS entitas,
       (SELECT COUNT(*) FROM dwo.production_productcategory) AS jumlah_sumber,
       (SELECT COUNT(*) FROM dwo_fakta.stg_product_category) AS jumlah_staging,
       (SELECT COUNT(*) FROM dwo.production_productcategory) - (SELECT COUNT(*) FROM dwo_fakta.stg_product_category) AS selisih
UNION ALL
SELECT '2. Subcategory',
       (SELECT COUNT(*) FROM dwo.production_productsubcategory),
       (SELECT COUNT(*) FROM dwo_fakta.stg_product_subcategory),
       (SELECT COUNT(*) FROM dwo.production_productsubcategory) - (SELECT COUNT(*) FROM dwo_fakta.stg_product_subcategory)
UNION ALL
SELECT '3. Location',
       (SELECT COUNT(*) FROM dwo.production_location),
       (SELECT COUNT(*) FROM dwo_fakta.stg_location),
       (SELECT COUNT(*) FROM dwo.production_location) - (SELECT COUNT(*) FROM dwo_fakta.stg_location)
UNION ALL
SELECT '4. Product',
       (SELECT COUNT(*) FROM dwo.production_product),
       (SELECT COUNT(*) FROM dwo_fakta.stg_product),
       (SELECT COUNT(*) FROM dwo.production_product) - (SELECT COUNT(*) FROM dwo_fakta.stg_product)
UNION ALL
SELECT '5. Product Cost History',
       (SELECT COUNT(*) FROM dwo.production_productcosthistory),
       (SELECT COUNT(*) FROM dwo_fakta.stg_product_cost_history),
       (SELECT COUNT(*) FROM dwo.production_productcosthistory) - (SELECT COUNT(*) FROM dwo_fakta.stg_product_cost_history)
UNION ALL
SELECT '6. Product Inventory (Fact)',
       (SELECT COUNT(*) FROM dwo.production_productinventory),
       (SELECT COUNT(*) FROM dwo_fakta.fact_inventory),
       (SELECT COUNT(*) FROM dwo.production_productinventory) - (SELECT COUNT(*) FROM dwo_fakta.fact_inventory);

-- 2. Rekonsiliasi Total Metrik Stok (Kuantitas & Nilai Inventori)
SELECT
    'Sumber (dwo)' AS sumber_data,
    COUNT(*) AS total_transaksi,
    SUM(pi.quantity) AS total_quantity_stok
FROM dwo.production_productinventory pi
UNION ALL
SELECT
    'Data Warehouse (fact_inventory)' AS sumber_data,
    COUNT(*) AS total_transaksi,
    SUM(f.quantity_stok) AS total_quantity_stok
FROM dwo_fakta.fact_inventory f;

-- 3. Ringkasan Jumlah Baris Seluruh Tabel Dimensi & Fakta (Setelah 2x Eksekusi Job)
SELECT 'dim_lokasi' AS nama_tabel, COUNT(*) AS total_baris, SUM(CASE WHEN lokasi_key = -1 THEN 1 ELSE 0 END) AS baris_unknown FROM dwo_fakta.dim_lokasi
UNION ALL
SELECT 'dim_kategori', COUNT(*), SUM(CASE WHEN kategori_key = -1 THEN 1 ELSE 0 END) FROM dwo_fakta.dim_kategori
UNION ALL
SELECT 'dim_rak', COUNT(*), SUM(CASE WHEN rak_key = -1 THEN 1 ELSE 0 END) FROM dwo_fakta.dim_rak
UNION ALL
SELECT 'dim_produk', COUNT(*), SUM(CASE WHEN produk_key = -1 THEN 1 ELSE 0 END) FROM dwo_fakta.dim_produk
UNION ALL
SELECT 'dim_tanggal', COUNT(*), SUM(CASE WHEN tanggal_key = -1 THEN 1 ELSE 0 END) FROM dwo_fakta.dim_tanggal
UNION ALL
SELECT 'fact_inventory', COUNT(*), 0 FROM dwo_fakta.fact_inventory;

-- 4. Validasi Integritas Referensial pada Tabel Fakta (Memastikan 0 Key Bernilai -1)
SELECT
    COUNT(*) AS total_baris_fakta,
    SUM(CASE WHEN tanggal_key = -1 THEN 1 ELSE 0 END) AS gagal_lookup_tanggal,
    SUM(CASE WHEN produk_key = -1 THEN 1 ELSE 0 END) AS gagal_lookup_produk,
    SUM(CASE WHEN kategori_key = -1 THEN 1 ELSE 0 END) AS gagal_lookup_kategori,
    SUM(CASE WHEN lokasi_key = -1 THEN 1 ELSE 0 END) AS gagal_lookup_lokasi,
    SUM(CASE WHEN rak_key = -1 THEN 1 ELSE 0 END) AS gagal_lookup_rak,
    SUM(quantity_stok) AS total_stok,
    SUM(nilai_stok) AS total_nilai_stok
FROM dwo_fakta.fact_inventory;

-- 5. Pembuktian Mekanisme SCD Tipe 2 pada dim_produk (Produk dengan >1 Riwayat Harga)
SELECT
    produk_key,
    produk_id,
    nama_produk,
    standard_cost,
    date_from,
    date_to,
    is_current
FROM dwo_fakta.dim_produk
WHERE produk_id IN (
    SELECT produk_id
    FROM dwo_fakta.dim_produk
    WHERE produk_id > 0
    GROUP BY produk_id
    HAVING COUNT(*) > 1
)
ORDER BY produk_id ASC, date_from ASC
LIMIT 15;