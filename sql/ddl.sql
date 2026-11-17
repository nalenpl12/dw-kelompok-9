USE dwo_fakta;

-- Matikan pengecekan FK sementara agar tabel bisa di-drop ulang tanpa error urutan
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS fact_inventory;
DROP TABLE IF EXISTS dim_produk;
DROP TABLE IF EXISTS dim_kategori;
DROP TABLE IF EXISTS dim_lokasi;
DROP TABLE IF EXISTS dim_rak;
-- Catatan: dim_tanggal tidak di-drop agar data dim_tanggal standar v1.0 tetap aman

SET FOREIGN_KEY_CHECKS = 1;

-- 1. Tabel Dimensi Lokasi (SCD Tipe 1)
CREATE TABLE dim_lokasi (
    lokasi_key INT(11) NOT NULL AUTO_INCREMENT,
    nama_lokasi VARCHAR(100) NOT NULL DEFAULT 'Tidak Diketahui',
    cost_rate DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    availability DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    PRIMARY KEY (lokasi_key)
) ENGINE=InnoDB;

INSERT INTO dim_lokasi (lokasi_key, nama_lokasi, cost_rate, availability)
VALUES (-1, 'Tidak Diketahui', 0.00, 0.00);

-- 2. Tabel Dimensi Kategori (SCD Tipe 1)
CREATE TABLE dim_kategori (
    kategori_key INT(11) NOT NULL AUTO_INCREMENT,
    nama_kategori VARCHAR(100) NOT NULL DEFAULT 'Tanpa Kategori',
    nama_subkategori VARCHAR(100) NOT NULL DEFAULT 'Tanpa Subkategori',
    PRIMARY KEY (kategori_key)
) ENGINE=InnoDB;

INSERT INTO dim_kategori (kategori_key, nama_kategori, nama_subkategori)
VALUES (-1, 'Tidak Diketahui', 'Tidak Diketahui');

-- 3. Tabel Dimensi Produk (Sesuaikan dengan Star Schema v2 jika memakai kolom SCD Tipe 2)
CREATE TABLE dim_produk (
    produk_key INT(11) NOT NULL AUTO_INCREMENT,
    nama_produk VARCHAR(100) NOT NULL DEFAULT 'Tidak Diketahui',
    nomor_produk VARCHAR(25) NOT NULL DEFAULT '-',
    standard_cost DECIMAL(19,4) NOT NULL DEFAULT 0.0000,
    reorder_point INT(11) NOT NULL DEFAULT 0,
    PRIMARY KEY (produk_key)
) ENGINE=InnoDB;

INSERT INTO dim_produk (produk_key, nama_produk, nomor_produk, standard_cost, reorder_point)
VALUES (-1, 'Tidak Diketahui', '-', 0.0000, 0);

-- 4. Tabel Dimensi Rak (SCD Tipe 1)
CREATE TABLE dim_rak (
    rak_key INT(11) NOT NULL AUTO_INCREMENT,
    shelf VARCHAR(10) NOT NULL DEFAULT 'N/A',
    bin INT(11) NOT NULL DEFAULT 0,
    PRIMARY KEY (rak_key)
) ENGINE=InnoDB;

INSERT INTO dim_rak (rak_key, shelf, bin)
VALUES (-1, 'N/A', 0);

-- 5. Tabel Fakta Inventory
CREATE TABLE fact_inventory (
    inventory_key BIGINT(20) NOT NULL AUTO_INCREMENT,
    tanggal_key INT(11) NOT NULL,
    produk_key INT(11) NOT NULL,
    kategori_key INT(11) NOT NULL,
    lokasi_key INT(11) NOT NULL,
    rak_key INT(11) NOT NULL,
    quantity_stok INT(11) NOT NULL DEFAULT 0,
    unit_cost DECIMAL(19,4) NOT NULL DEFAULT 0.0000,
    nilai_stok DECIMAL(19,4) NOT NULL DEFAULT 0.0000,
    PRIMARY KEY (inventory_key),
    INDEX idx_fact_tanggal (tanggal_key),
    INDEX idx_fact_produk (produk_key),
    INDEX idx_fact_kategori (kategori_key),
    INDEX idx_fact_lokasi (lokasi_key),
    INDEX idx_fact_rak (rak_key),
    CONSTRAINT fk_fact_tanggal FOREIGN KEY (tanggal_key) REFERENCES dim_tanggal(tanggal_key),
    CONSTRAINT fk_fact_produk FOREIGN KEY (produk_key) REFERENCES dim_produk(produk_key),
    CONSTRAINT fk_fact_kategori FOREIGN KEY (kategori_key) REFERENCES dim_kategori(kategori_key),
    CONSTRAINT fk_fact_lokasi FOREIGN KEY (lokasi_key) REFERENCES dim_lokasi(lokasi_key),
    CONSTRAINT fk_fact_rak FOREIGN KEY (rak_key) REFERENCES dim_rak(rak_key)
) ENGINE=InnoDB;
