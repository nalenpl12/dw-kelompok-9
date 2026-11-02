# Piagam Proyek Data Warehouse
Kelompok      : Kelompok 9
Proses bisnis : Pergerakan Persediaan
Sponsor       : Mohamad Irwan Afandi, ST, M.Sc.

## 1. Latar belakang
AdventureWorks memiliki data persediaan produk yang berkaitan dengan kategori barang, lokasi penyimpanan, titik pemesanan ulang (*reorder point*), dan biaya standar produk. Agar informasi tersebut dapat digunakan untuk pengambilan keputusan, manajemen membutuhkan ringkasan stok yang konsisten dan terukur pada satu waktu pengambilan data (*inventory snapshot*).

Proyek ini mengintegrasikan data operasional AdventureWorks ke dalam Data Warehouse dengan struktur Star Schema. Analisis berfokus pada total stok per kategori, produk dengan stok tertinggi dan terendah, lokasi dengan stok terbesar, produk di bawah reorder point, serta estimasi nilai persediaan. Permasalahan ini dirumuskan sebagai kebutuhan analitis proyek, bukan sebagai klaim bahwa manajemen AdventureWorks telah mengalami kegagalan operasional tertentu.

## 2. Tujuan dan pertanyaan bisnis
Tujuan: Membangun Data Warehouse berbasis snapshot persediaan yang menyediakan informasi stok menurut produk, kategori, dan lokasi untuk mendukung analisis manajemen.

1. Q1: Berapa total jumlah stok yang tersedia pada setiap kategori produk?
2. Q2: Produk apa yang memiliki jumlah stok tertinggi dan terendah?
3. Q3: Lokasi penyimpanan mana yang memiliki jumlah stok terbesar?
4. Q4: Produk apa saja yang total stoknya lebih rendah daripada *reorder point*?
5. Q5: Berapa estimasi nilai persediaan pada setiap kategori produk dan lokasi penyimpanan?

## 3. Ruang lingkup
Luar lingkup:
- Proses bisnis: kondisi persediaan pada **satu snapshot yang sama**.
- Data sumber: `dwo.production_productinventory`, `dwo.production_product`, `dwo.production_productsubcategory`, `dwo.production_productcategory`, dan `dwo.production_location`.
- Waktu data: snapshot tanggal [YYYY-MM-DD], diambil pada [jam dan zona waktu pengambilan]; bukan rentang histori transaksi. Rentang `modifieddate` dicatat dalam profiling hanya sebagai informasi perubahan record.
- Grain: satu baris per kombinasi tanggal snapshot × produk × lokasi.
- Satu tabel fakta: `fact_inventory_snapshot`.
- Tiga dimensi: `dim_waktu`, `dim_produk`, `dim_lokasi`.
- Ukuran: `quantity` dan `stock_value = quantity × standard_cost`.
- Proses: pemeriksaan sumber, transformasi dan pemuatan (ETL), validasi, analisis OLAP, serta dashboard untuk Q1–Q5.

Di luar lingkup:
- Analisis transaksi barang masuk/keluar dari `production_transactionhistory`.
- Tren historis stok **sebelum** snapshot yang tersedia; histori baru dapat dianalisis jika snapshot berkala benar-benar disimpan.
- Peramalan permintaan, optimasi pemesanan, kapasitas gudang, profit, atau harga jual.
- Klaim nilai persediaan akuntansi resmi; `stock_value` hanya estimasi berbasis standard cost.

## 4. Tim dan peran
| Nama | NPM | Peran utama |
| Nalendra Pradipta Loka | 23082010196 | Project Manager |
| Muqammad Saifuddin Ramadhan | 23082010217 | Data Modeler |
| Muhammad Achsani | 23082010174 | ETL Developer |
| Ricky Widyadhana | 23082010187 | OLAP Developer|
| Ahmad Haris Insanul Kamil | 23082010186 | Dashboard Developer |

## 5. Lingkungan teknis
| Komponen | Teknologi / keterangan |
|---|---|
| Sumber | MySQL — database `dwo` |
| Target | MySQL — database `dwo_fakta` |
| ETL | Pentaho Data Integration CE (atau SQL MySQL pada tahap prototipe) |
| OLAP | Mondrian |
| Dashboard | Chart.js |
| Pemodelan | Star Schema v1, satu fakta dan tiga dimensi |

Jika kedua database berada di server MySQL yang sama, sumber dapat diakses dengan penamaan `dwo.nama_tabel`. Tidak diperlukan `postgres_fdw` karena DBMS yang digunakan adalah MySQL.

## 6. Risiko awal
| Risiko | Dampak | Rencana penanganan |
|---|---|---|
| Ekstraksi tidak mewakili satu kondisi waktu yang konsisten | Hasil total stok antarproduk/lokasi tidak sebanding | Gunakan satu batas pengambilan data yang konsisten dan catat waktu snapshot |
| Duplikasi baris produk–lokasi | Stok dan nilai persediaan terhitung ganda | Validasi grain dan batasi keunikan `date_key, product_key, location_key` |
| Nilai kosong atau relasi dimensi tidak lengkap | Ada baris yang hilang atau nilai stok tidak terhitung | Data profiling, pengujian relasi, dan rekonsiliasi sebelum publikasi |
| Perubahan `standard_cost` atau `reorder_point` | Interpretasi histori tidak konsisten | Pertahankan nilai saat snapshot atau gunakan histori dimensi jika diperlukan |

## 7. Kriteria sukses
1. Database `dwo_fakta` berisi satu tabel fakta yang digunakan proyek (`fact_inventory_snapshot`) dan tiga dimensi (`dim_waktu`, `dim_produk`, `dim_lokasi`). Jika tabel eksperimen lama masih ada, bedakan/arsipkan secara aman sebelum menyatakan struktur final hanya mempunyai satu fakta.
2. Setiap baris fakta merepresentasikan satu kombinasi unik tanggal snapshot × produk × lokasi dan memiliki pasangan dimensi yang valid.
3. Semua baris dalam analisis Q1–Q5 mengacu pada `date_key` snapshot yang sama.
4. Jumlah baris dan `SUM(quantity)` pada fakta untuk snapshot terpilih sesuai dengan data sumber yang diekstraksi setelah memperhitungkan aturan pembersihan data yang didokumentasikan.
5. `SUM(stock_value)` sesuai dengan hasil `SUM(quantity × standardcost)` pada sumber untuk snapshot yang sama.
6. Kelima pertanyaan bisnis dapat dijawab melalui query, OLAP, atau dashboard dengan hasil yang konsisten.
7. Hasil profiling, desain grain, Star Schema v1, Bus Matrix, dan penanganan risiko terdokumentasi di repository.