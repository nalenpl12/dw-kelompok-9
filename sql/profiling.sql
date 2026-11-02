-- 00. IDENTITAS PELAKSANAAN PROFILING ----------------------------------------
SELECT
    NOW() AS waktu_profiling_server,
    VERSION() AS versi_mysql,
    DATABASE() AS database_aktif;

-- 01. VERIFIKASI TABEL DAN STRUKTUR KOLOM ------------------------------------
-- Periksa bahwa kelima tabel sumber tersedia.
SELECT
    t.table_name,
    t.table_type
FROM information_schema.tables AS t
WHERE t.table_schema = 'dwo'
  AND t.table_name IN (
      'production_productinventory',
      'production_product',
      'production_productsubcategory',
      'production_productcategory',
      'production_location'
  )
ORDER BY t.table_name;

-- Periksa kolom, tipe data, dan collation (jika kolom bertipe teks).
SELECT
    c.table_name,
    c.column_name,
    c.data_type,
    c.is_nullable,
    c.collation_name
FROM information_schema.columns AS c
WHERE c.table_schema = 'dwo'
  AND c.table_name IN (
      'production_productinventory',
      'production_product',
      'production_productsubcategory',
      'production_productcategory',
      'production_location'
  )
ORDER BY c.table_name, c.ordinal_position;

-- 02. JUMLAH BARIS LIMA TABEL -------------------------------------------------
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

-- 03. RENTANG TANGGAL MODIFIKASI ----------------------------------------------
-- modifieddate adalah waktu perubahan RECORD, bukan tanggal snapshot bersama.
SELECT
    COUNT(*) AS jumlah_baris,
    MIN(modifieddate) AS modifieddate_terawal,
    MAX(modifieddate) AS modifieddate_terakhir,
    SUM(CASE WHEN modifieddate IS NULL THEN 1 ELSE 0 END) AS null_modifieddate
FROM dwo.production_productinventory;

-- 04. NILAI NULL DI TABEL SUMBER ----------------------------------------------
-- 04a: Tabel fakta sumber (ProductInventory)
SELECT
    COUNT(*) AS total_baris,
    SUM(CASE WHEN productid IS NULL THEN 1 ELSE 0 END) AS null_productid,
    SUM(CASE WHEN locationid IS NULL THEN 1 ELSE 0 END) AS null_locationid,
    SUM(CASE WHEN quantity IS NULL THEN 1 ELSE 0 END) AS null_quantity,
    SUM(CASE WHEN modifieddate IS NULL THEN 1 ELSE 0 END) AS null_modifieddate
FROM dwo.production_productinventory;

-- 04b: Atribut produk untuk Q1, Q2, Q4, dan Q5
SELECT
    COUNT(*) AS total_baris,
    SUM(CASE WHEN productid IS NULL THEN 1 ELSE 0 END) AS null_productid,
    SUM(CASE WHEN name IS NULL THEN 1 ELSE 0 END) AS null_nama_produk,
    SUM(CASE WHEN productsubcategoryid IS NULL THEN 1 ELSE 0 END) AS null_subcategoryid,
    SUM(CASE WHEN reorderpoint IS NULL THEN 1 ELSE 0 END) AS null_reorderpoint,
    SUM(CASE WHEN standardcost IS NULL THEN 1 ELSE 0 END) AS null_standardcost
FROM dwo.production_product;

-- 04c: Subkategori dan kategori
SELECT
    COUNT(*) AS total_baris,
    SUM(CASE WHEN productsubcategoryid IS NULL THEN 1 ELSE 0 END) AS null_subcategoryid,
    SUM(CASE WHEN productcategoryid IS NULL THEN 1 ELSE 0 END) AS null_categoryid,
    SUM(CASE WHEN name IS NULL THEN 1 ELSE 0 END) AS null_nama_subkategori
FROM dwo.production_productsubcategory;

SELECT
    COUNT(*) AS total_baris,
    SUM(CASE WHEN productcategoryid IS NULL THEN 1 ELSE 0 END) AS null_categoryid,
    SUM(CASE WHEN name IS NULL THEN 1 ELSE 0 END) AS null_nama_kategori
FROM dwo.production_productcategory;

-- 04d: Lokasi
SELECT
    COUNT(*) AS total_baris,
    SUM(CASE WHEN locationid IS NULL THEN 1 ELSE 0 END) AS null_locationid,
    SUM(CASE WHEN name IS NULL THEN 1 ELSE 0 END) AS null_nama_lokasi
FROM dwo.production_location;

-- 05. DISTRIBUSI DAN NILAI TIDAK WAJAR ---------------------------------------
SELECT
    COUNT(DISTINCT productid) AS jumlah_produk_dengan_stok,
    COUNT(DISTINCT locationid) AS jumlah_lokasi_tercatat,
    SUM(quantity) AS total_quantity,
    MIN(quantity) AS minimum_quantity,
    MAX(quantity) AS maksimum_quantity,
    SUM(CASE WHEN quantity < 0 THEN 1 ELSE 0 END) AS baris_quantity_negatif,
    SUM(CASE WHEN quantity = 0 THEN 1 ELSE 0 END) AS baris_quantity_nol
FROM dwo.production_productinventory;

SELECT
    SUM(CASE WHEN standardcost < 0 THEN 1 ELSE 0 END) AS produk_standardcost_negatif,
    SUM(CASE WHEN standardcost = 0 THEN 1 ELSE 0 END) AS produk_standardcost_nol,
    SUM(CASE WHEN reorderpoint < 0 THEN 1 ELSE 0 END) AS produk_reorderpoint_negatif
FROM dwo.production_product;

-- 06. KEUNIKAN GRAIN PRODUK × LOKASI ------------------------------------------
-- Jika ada hasil, jangan langsung INSERT ke fakta dengan UNIQUE
-- (date_key, product_key, location_key); cek kebutuhan agregasi dari sumber.
SELECT
    productid,
    locationid,
    COUNT(*) AS jumlah_record,
    SUM(quantity) AS quantity_gabungan
FROM dwo.production_productinventory
GROUP BY productid, locationid
HAVING COUNT(*) > 1
ORDER BY jumlah_record DESC, productid, locationid;

-- Ringkasan kuantitas kombinasi yang berulang (nol = tidak terdeteksi).
SELECT
    COUNT(*) AS jumlah_kombinasi_duplikat,
    COALESCE(SUM(jumlah_record - 1), 0) AS kelebihan_baris
FROM (
    SELECT productid, locationid, COUNT(*) AS jumlah_record
    FROM dwo.production_productinventory
    GROUP BY productid, locationid
    HAVING COUNT(*) > 1
) AS duplikat;

-- 07. INTEGRITAS REFERENSI / ORPHAN ------------------------------------------
-- Semua JOIN menggunakan kolom ID numerik (menghindari mismatch collation).
SELECT
    COUNT(*) AS jumlah_baris_inventory,
    SUM(CASE WHEN p.productid IS NULL THEN 1 ELSE 0 END) AS inventory_tanpa_produk,
    SUM(CASE WHEN l.locationid IS NULL THEN 1 ELSE 0 END) AS inventory_tanpa_lokasi
FROM dwo.production_productinventory AS pi
LEFT JOIN dwo.production_product AS p
    ON pi.productid = p.productid
LEFT JOIN dwo.production_location AS l
    ON pi.locationid = l.locationid;

-- Contoh record tanpa pasangan untuk tindakan korektif (maks. 100 record).
SELECT
    pi.productid,
    pi.locationid,
    pi.quantity,
    CASE WHEN p.productid IS NULL THEN 'PRODUK_TIDAK_ADA' ELSE 'OK' END AS status_produk,
    CASE WHEN l.locationid IS NULL THEN 'LOKASI_TIDAK_ADA' ELSE 'OK' END AS status_lokasi
FROM dwo.production_productinventory AS pi
LEFT JOIN dwo.production_product AS p
    ON pi.productid = p.productid
LEFT JOIN dwo.production_location AS l
    ON pi.locationid = l.locationid
WHERE p.productid IS NULL OR l.locationid IS NULL
LIMIT 100;

-- 08. KELENGKAPAN KLASIFIKASI KATEGORI ---------------------------------------
SELECT
    COUNT(*) AS jumlah_baris_inventory,
    SUM(CASE WHEN p.productid IS NULL THEN 1 ELSE 0 END) AS tanpa_produk,
    SUM(CASE WHEN p.productid IS NOT NULL
                  AND p.productsubcategoryid IS NULL THEN 1 ELSE 0 END) AS produk_tanpa_subkategori,
    SUM(CASE WHEN p.productsubcategoryid IS NOT NULL
                  AND ps.productsubcategoryid IS NULL THEN 1 ELSE 0 END) AS subkategori_tidak_ditemukan,
    SUM(CASE WHEN ps.productsubcategoryid IS NOT NULL
                  AND pc.productcategoryid IS NULL THEN 1 ELSE 0 END) AS kategori_tidak_ditemukan
FROM dwo.production_productinventory AS pi
LEFT JOIN dwo.production_product AS p ON p.productid = pi.productid
LEFT JOIN dwo.production_productsubcategory AS ps
    ON ps.productsubcategoryid = p.productsubcategoryid
LEFT JOIN dwo.production_productcategory AS pc
    ON pc.productcategoryid = ps.productcategoryid;

-- 09. BASELINE REKONSILIASI UNTUK 5 PERTANYAAN -------------------------------
-- Baseline ini dihitung dari keadaan sumber saat profiling.
-- Untuk perbandingan terhadap Data Warehouse, gunakan ekstraksi yang SAMA.
-- COUNT(*) pada join diasumsikan unik pada master productid; validasi di seksi 07.
SELECT
    COUNT(*) AS baris_inventory_sumber,
    COUNT(DISTINCT pi.productid) AS jumlah_produk,
    COUNT(DISTINCT pi.locationid) AS jumlah_lokasi,
    SUM(pi.quantity) AS total_quantity_sumber,
    SUM(pi.quantity * p.standardcost) AS total_estimasi_nilai_sumber,
    SUM(CASE WHEN p.standardcost IS NULL THEN 1 ELSE 0 END)
        AS baris_tidak_dapat_dinilai
FROM dwo.production_productinventory AS pi
LEFT JOIN dwo.production_product AS p
    ON p.productid = pi.productid;

-- Q4 baseline: daftar produk dengan total stok di bawah reorder point.
-- Stok dijumlahkan ke tingkat produk terlebih dahulu (lintas lokasi).
SELECT
    p.productid,
    p.name AS nama_produk,
    SUM(pi.quantity) AS total_stok,
    MAX(p.reorderpoint) AS reorder_point,
    MAX(p.reorderpoint) - SUM(pi.quantity) AS kekurangan_stok
FROM dwo.production_productinventory AS pi
JOIN dwo.production_product AS p
    ON p.productid = pi.productid
GROUP BY p.productid, p.name
HAVING SUM(pi.quantity) < MAX(p.reorderpoint)
ORDER BY kekurangan_stok DESC, p.productid;

-- Q5 baseline: total estimasi nilai stok per kategori dan lokasi.
SELECT
    COALESCE(pc.name, 'Belum dikategorikan') AS kategori,
    l.name AS lokasi,
    SUM(pi.quantity) AS total_stok,
    SUM(pi.quantity * p.standardcost) AS estimasi_nilai_stok
FROM dwo.production_productinventory AS pi
JOIN dwo.production_product AS p ON p.productid = pi.productid
LEFT JOIN dwo.production_productsubcategory AS ps
    ON ps.productsubcategoryid = p.productsubcategoryid
LEFT JOIN dwo.production_productcategory AS pc
    ON pc.productcategoryid = ps.productcategoryid
JOIN dwo.production_location AS l
    ON l.locationid = pi.locationid
GROUP BY COALESCE(pc.name, 'Belum dikategorikan'), l.name
ORDER BY kategori, lokasi;
