USE dwo_fakta;

-- ============================================================================
-- UJI 1: PELANGGARAN FOREIGN KEY CONSTRAINT
-- Ekspektasi: Gagal dengan error "Cannot add or update a child row: a foreign key constraint fails"
-- ============================================================================
INSERT INTO fact_inventory (
    tanggal_key, produk_key, kategori_key, lokasi_key, rak_key,
    quantity_stok, unit_cost, nilai_stok
) VALUES (
    20130430, 999999, 1, 1, 1,
    10, 50.0000, 500.0000
);

-- ============================================================================
-- UJI 2: PELANGGARAN UNIQUE / PRIMARY KEY CONSTRAINT
-- Ekspektasi: Gagal dengan error "Duplicate entry '...' for key 'unique_inventory'"
-- ============================================================================
INSERT INTO fact_inventory (
    tanggal_key, produk_key, kategori_key, lokasi_key, rak_key,
    quantity_stok, unit_cost, nilai_stok
)
SELECT
    tanggal_key, produk_key, kategori_key, lokasi_key, rak_key,
    quantity_stok, unit_cost, nilai_stok
FROM fact_inventory
LIMIT 1;

-- ============================================================================
-- UJI 3: PELANGGARAN NOT NULL CONSTRAINT
-- Ekspektasi: Gagal dengan error "Column 'date_from' cannot be null"
-- ============================================================================
INSERT INTO dim_produk (
    produk_id, nama_produk, nomor_produk,
    standard_cost, reorder_point, date_from, date_to, is_current
) VALUES (
    99999, 'Produk Uji Null', 'TEST-001',
    100.0000, 5, NULL, '9999-12-31', 1
);