# Laporan Progres Pekan ke-12 (Pelaporan Tugas Pekan 11) — Data Warehouse Inventory Snapshot

## 1. Identitas kegiatan

| Elemen | Keterangan |
|---|---|
| Nama proyek | Data Warehouse Pengelolaan Persediaan AdventureWorks |
| Pekan | 12 (Steering Review Implementasi Fisik DDL & Kamus Data Pekan 11) |
| Pembimbing/dosen | Mohamad Irwan Afandi, ST, M.Sc. |
| Database sumber | MySQL `dwo` |
| Database tujuan | MySQL `dwo_fakta` |
| Repositori | `dw-kelompok-9` |

---

## 2. Ringkasan kegiatan

Pada pekan ini, fokus kegiatan proyek bergeser dari tahap perancangan konseptual (Star Schema v2) menuju **implementasi fisik struktur database Data Warehouse** pada skema MySQL `dwo_fakta`. Seluruh rancangan tabel dimensi dan tabel fakta yang telah disetujui sponsor direalisasikan dalam bentuk skrip DDL terstandar (`sql/ddl.sql`) yang bersifat *idempotent* (dapat dijalankan berulang kali tanpa error).

Kegiatan utama mencakup pemasangan tabel kalender standar `dim_tanggal` versi 1.0, penyisipan baris *Unknown Member* (`-1`) pada seluruh dimensi, pembuatan indeks dan *foreign key* pada tabel fakta `fact_inventory`, pengujian integritas data melalui tiga skenario pelanggaran *constraint*, verifikasi struktur fisik menggunakan *reverse engineering* ERD di DBeaver, serta penyusunan kamus data (`docs/kamus-data.md`) dan pembaruan daftar tabel staging pada dokumen pemetaan (`docs/mapping.md`).

---

## 3. Target dan luaran pekan ke-11 (Dilaporkan Pekan 12)

| No. | Target/aktivitas | Luaran yang ditargetkan | Status aktual |
|---|---|---|---|
| 1 | Pemasangan `dim_tanggal` standar v1.0 | Tabel `dim_tanggal` terpasang beserta hasil query pemeriksaan | selesai |
| 2 | Penulisan skrip DDL DW idempotent | [`sql/ddl.sql`](../sql/ddl.sql) berisi seluruh dimensi, fakta, baris `-1`, FK, dan index | selesai |
| 3 | Pengujian eksekusi DDL berulang | Bukti eksekusi `sql/ddl.sql` 2x berturut-turut tanpa error | selesai |
| 4 | Pengujian tiga skenario constraint | 3 tangkapan layar pesan error pelanggaran PK, FK, dan NOT NULL | selesai |
| 5 | Penyusunan Kamus Data lengkap | [`docs/kamus-data.md`](../docs/kamus-data.md) mencakup seluruh tabel DW & penjelasan `dim_tanggal` | selesai |
| 6 | Verifikasi ERD via Reverse Engineering | Diagram ERD hasil reverse engineering DBeaver identik dengan Star Schema v2 | selesai |
| 7 | Penambahan daftar tabel staging di mapping | [`docs/mapping.md`](../docs/mapping.md) diperbarui dengan tabel staging & kolom fakta aktual | selesai |
| 8 | Penyusunan laporan progres pekan 12 | [`laporan/pekan-12.md`](pekan-12.md) | selesai |

---

## 4. Hasil implementasi fisik & pengujian database

### 4.1 Pemasangan dan Pemeriksaan `dim_tanggal` Standar v1.0

Skrip `dim_tanggal` standar versi 1.0 telah dijalankan pada database `dwo_fakta`. Query pemeriksaan dijalankan untuk memverifikasi total baris kalender, rentang tanggal awal hingga akhir, serta keberadaan baris *unknown* (`tanggal_key = -1`).

```sql
SELECT COUNT(*) AS total_baris, MIN(tanggal) AS tanggal_awal, MAX(tanggal) AS tanggal_akhir FROM dwo_fakta.dim_tanggal;
SELECT * FROM dwo_fakta.dim_tanggal WHERE tanggal_key = -1;
