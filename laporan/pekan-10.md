# Laporan Progres Pekan ke-10 — Data Warehouse Inventory Snapshot

## 1. Identitas kegiatan

| Elemen | Keterangan |
|---|---|
| Nama proyek | Data Warehouse Pengelolaan Persediaan AdventureWorks |
| Pekan | 10 |
| Pembimbing/dosen | Mohamad Irwan Afandi, ST, M.Sc. |
| Database sumber | MySQL `dwo` |
| Database tujuan | MySQL `dwo_fakta` |

## 2. Ringkasan kegiatan

Pada pekan ke-10, kegiatan proyek difokuskan pada penyelarasan kebutuhan bisnis, pemeriksaan karakteristik data sumber, dan dokumentasi rancangan dimensional untuk proses Inventory Snapshot. Cakupan analisis adalah kondisi persediaan produk pada satu snapshot yang sama, bukan transaksi keluar-masuk barang. Lima pertanyaan bisnis digunakan sebagai dasar penentuan ukuran dan dimensi, yakni stok per kategori, stok tertinggi/terendah per produk, stok per lokasi, produk di bawah *reorder point*, dan estimasi nilai stok berdasarkan kategori dan lokasi.

Rancangan menggunakan **satu tabel fakta** `fact_inventory_snapshot` serta **tiga dimensi** `dim_waktu`, `dim_produk`, dan `dim_lokasi`. Sumber utama adalah `dwo.production_productinventory` yang diperkaya dengan data produk, subkategori, kategori, dan lokasi. Tahap profiling menggunakan query MySQL yang terdokumentasi pada [`profiling.sql`](profiling.sql); hasil aktualnya dicatat pada [`profiling.md`](profiling.md).

> **Penting:** dokumen ini merupakan draf laporan progres. Status pekerjaan dan bukti eksekusi harus diperbarui sesuai pekerjaan kelompok yang benar-benar telah dilakukan. Tidak ada angka profiling yang diasumsikan.

## 3. Target dan luaran pekan ke-10

| No. | Target/aktivitas | Luaran yang ditargetkan | Status aktual |
|---|---|---|---|
| 1 | Finalisasi 5 pertanyaan bisnis terukur | [`pertanyaan-bisnis.md`](pertanyaan-bisnis.md) | selesai |
| 2 | Profiling data sumber MySQL | [`profiling.sql`](profiling.sql) dan tabel hasil pada [`profiling.md`](profiling.md) | selesai |
| 3 | Menetapkan grain tabel fakta | [`grain.md`](grain.md) | selesai |
| 4 | Menyusun Star Schema v1 (1 fakta + 3 dimensi) | Gambar Star Schema dan penjelasannya | selesai |
| 5 | Menentukan Bus Matrix dan calon conformed dimensions | [`bus-matrix.md`](bus-matrix.md) | selesai |
| 6 | Menyusun risiko awal dan mitigasinya | [`risiko.md`](risiko.md) | selesai |
| 7 | Memastikan struktur tabel di database target selaras dengan dokumen | Pemeriksaan `SHOW TABLES FROM dwo_fakta` dan struktur kolom | selesai |

## 4. Hasil perancangan

### 4.1 Proses bisnis dan grain

Proses yang dimodelkan adalah posisi stok persediaan dalam satu snapshot. Grain statement: satu baris pada `fact_inventory_snapshot` merepresentasikan stok **satu produk pada satu lokasi dalam satu tanggal snapshot**. Kunci logis grain: `(date_key, product_key, location_key)`.

### 4.2 Struktur Star Schema v1

- **Fakta:** `fact_inventory_snapshot`, dengan ukuran utama `quantity` dan `stock_value = quantity × standard_cost`.
- **Dimensi waktu:** `dim_waktu`, berfungsi memilih tanggal snapshot yang sama untuk semua pertanyaan.
- **Dimensi produk:** `dim_produk`, memuat identitas produk, kategori, subkategori, `reorder_point`, dan `standard_cost`.
- **Dimensi lokasi:** `dim_lokasi`, memuat identitas dan nama lokasi penyimpanan.

**Gambar Star Schema v1:** **[Sisipkan gambar diagram kelompok di sini atau tautan file gambar pada repository.]**

### 4.3 Bus Matrix

| Proses bisnis / tabel fakta | `dim_waktu` | `dim_produk` | `dim_lokasi` |
|---|:---:|:---:|:---:|
| Inventory Snapshot / `fact_inventory_snapshot` | ✓ | ✓ | ✓ |

Ketiga dimensi merupakan **calon conformed dimensions** karena rancangan saat ini baru mengimplementasikan satu proses bisnis/tabel fakta; penggunaan lintas proses belum dibuktikan.

## 5. Ringkasan Data Profiling

| Pemeriksaan | Hasil / bukti |
|---|---|
| Jumlah baris lima tabel sumber | **[Isi berdasarkan output query]** |
| Rentang `modifieddate` inventory | **[Isi tanggal terawal–terakhir]** |
| NULL pada kolom utama (`productid`, `locationid`, `quantity`, `standardcost`, `reorderpoint`) | **[Isi hasil]** |
| Duplikasi kombinasi produk–lokasi | **[Isi jumlah kombinasi duplikat]** |
| Inventory tanpa pasangan produk/lokasi | **[Isi hasil]** |
| Baseline `SUM(quantity)` dan `SUM(quantity × standardcost)` | **[Isi hasil]** |

`modifieddate` hanya menjelaskan waktu perubahan masing-masing baris. **Tanggal snapshot bersama harus ditentukan saat ekstraksi** dan dipakai untuk seluruh baris dalam satu proses pemuatan. Bila ditemukan lebih dari satu baris sumber per kombinasi produk–lokasi, perlu dipastikan apakah data harus diagregasikan ke tingkat grain sebelum load fakta.

## 6. Kendala teknis dan langkah penanganan

| Potensi kendala / yang pernah dibahas | Penanganan |
|---|---|
| Tabel dimensi dicari dari database yang salah (`dwo.dim_produk`) | Gunakan nama database lengkap, misalnya `dwo_fakta.dim_produk`, ketika menjalankan SQL lintas database pada server MySQL yang sama. |
| Perbedaan *collation* pada perbandingan teks | Utamakan JOIN melalui ID numerik; jika diperlukan JOIN teks, cocokkan character set/collation terlebih dahulu. |
| Perbedaan detail data sumber dengan grain produk–lokasi | Uji duplikasi kombinasi `productid, locationid`; agregasikan bila memang terdapat detail berulang yang sah. |
| Snapshot tidak konsisten bila sumber berubah selama ekstraksi | Gunakan ekstraksi satu cut-off yang konsisten atau tabel staging hasil pembekuan data. |

**Kendala yang benar-benar dialami pada pekan ke-10 dan penyelesaiannya:** **[Isi sesuai log/screenshot pengujian kelompok.]**

## 7. Risiko prioritas

1. **Ketidakkonsistenan snapshot:** atur satu waktu/cut-off ekstraksi dan identitas snapshot untuk seluruh fakta.
2. **Duplikasi produk–lokasi:** profil kombinasi kunci bisnis dan lakukan agregasi sesuai grain jika diperlukan.
3. **NULL atau referensi tidak lengkap:** lakukan validasi `quantity`, `standardcost`, `reorderpoint`, dan pasangan produk/lokasi sebelum load.
4. **Perubahan standard cost dan reorder point:** pertahankan `stock_value` hasil perhitungan snapshot dan rencanakan histori ambang jika diperlukan.

Risiko lengkap serta rencana mitigasinya ada pada [`risiko.md`](risiko.md).

## 8. Rencana tindak lanjut

1. Lengkapi `profiling.md` dengan output aktual dan bukti screenshot/ekspor query.
2. Putuskan aturan ETL jika ditemukan NULL, data tanpa pasangan, atau beberapa baris produk–lokasi.
3. Validasi struktur `dwo_fakta`: satu tabel fakta yang digunakan dan tiga dimensi; dokumentasikan tabel lama yang hanya bersifat eksperimen apabila masih ada.
4. Lakukan atau verifikasi proses pemuatan dimensi sebelum fakta, menggunakan tanggal snapshot yang sama.
5. Rekonsiliasi jumlah baris pada grain yang sama, `SUM(quantity)`, dan `SUM(stock_value)` terhadap ekstraksi sumber yang sama.
6. Siapkan OLAP Mondrian dan visualisasi dashboard untuk Q1–Q5 setelah validasi lolos.

## 9. Kriteria keberhasilan pekan ke-10

- Lima pertanyaan bisnis memiliki ukuran, dimensi, dan tabel sumber yang jelas.
- Data profiling terdokumentasi dengan hasil aktual, bukan hanya potongan SQL.
- Grain, gambar Star Schema v1, Bus Matrix, dan risiko awal selaras dengan database yang dibuat.
- Keputusan penanganan duplikasi, NULL, dan referensi hilang tercatat.
- Perbedaan antara data sumber dan tabel fakta dapat ditelusuri serta dijelaskan.

## 10. Bukti dan referensi dokumen

- [Piagam proyek](piagam-proyek.md)
- [Pertanyaan bisnis Q1–Q5](pertanyaan-bisnis.md)
- [Grain dan Star Schema](grain.md)
- [Bus Matrix](bus-matrix.md)
- [Risiko awal](risiko.md)
- [Query profiling MySQL](profiling.sql)
- [Hasil profiling](profiling.md)
