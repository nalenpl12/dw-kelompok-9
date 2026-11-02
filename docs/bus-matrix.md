# Bus Matrix — Inventory Snapshot AdventureWorks

## 1. Tujuan

*Bus Matrix* memetakan proses bisnis yang dianalisis terhadap dimensi yang digunakan dalam Data Warehouse. Model yang dirancang adalah **Star Schema v1** dengan satu proses bisnis, satu tabel fakta (`fact_inventory_snapshot`), dan tiga dimensi.

## 2. Bus Matrix proses bisnis

| Proses bisnis / tabel fakta | `dim_waktu` | `dim_produk` | `dim_lokasi` |
|---|:---:|:---:|:---:|
| **Inventory Snapshot / `fact_inventory_snapshot`** | ✓ | ✓ | ✓ |

Keterangan:
- ✓ = dimensi yang digunakan oleh proses bisnis.
- `dim_waktu`: tanggal snapshot persediaan.
- `dim_produk`: identitas produk, subkategori, kategori, reorder point, standard cost.
- `dim_lokasi`: lokasi penyimpanan produk.

## 3. Matriks pendukung: pertanyaan bisnis dan dimensi

Matriks berikut merupakan **pemetaan kebutuhan analisis**, bukan pengganti Bus Matrix proses bisnis di atas.

| Pertanyaan | `dim_waktu` | `dim_produk` | `dim_lokasi` | Ukuran |
|---|:---:|:---:|:---:|---|
| **Q1** — Total stok per kategori | ✓* | ✓ | — | `SUM(quantity)` |
| **Q2** — Produk dengan stok tertinggi/terendah | ✓* | ✓ | — | `SUM(quantity)` per produk |
| **Q3** — Lokasi dengan stok terbesar | ✓* | — | ✓ | `SUM(quantity)` per lokasi |
| **Q4** — Stok produk di bawah reorder point | ✓* | ✓ | — | `SUM(quantity)` dibanding `MAX(reorder_point)` setelah agregasi |
| **Q5** — Estimasi nilai stok kategori × lokasi | ✓* | ✓ | ✓ | `SUM(stock_value)` |

**✓*** berarti dimensi waktu dipakai untuk **memilih tanggal snapshot yang sama** pada semua pertanyaan, bukan sebagai sumbu agregasi utama. **—** berarti tidak diperlukan langsung untuk menjawab pertanyaan.

## 4. Penandaan conformed dimension

*Conformed dimension* adalah dimensi dengan identitas dan makna yang konsisten ketika digunakan bersama oleh lebih dari satu proses bisnis/tabel fakta.

**Status rancangan saat ini:** baru **satu proses bisnis dan satu tabel fakta**. Karena itu, tidak ada penggunaan lintas proses yang telah terbukti. Ketiganya **calon conformed dimensions**, bukan dimensi yang sudah terverifikasi conformed.

| Dimensi | Status saat ini | Peluang penggunaan lintas proses |
|---|---|---|
| `dim_waktu` | **Calon conformed** | Dapat dipakai pada fakta penjualan atau pembelian dengan definisi kalender yang sama |
| `dim_produk` | **Calon conformed** | Dapat dipakai pada fakta penjualan atau pembelian dengan identitas produk dan kategori konsisten |
| `dim_lokasi` | **Calon conformed** | Dapat dipakai pada fakta lain yang memang menggunakan definisi lokasi penyimpanan yang sama |

**Aturan untuk menjadi conformed:** kode bisnis, definisi atribut, dan tingkat detailnya harus selaras pada lebih dari satu proses bisnis. Jangan menandai “sudah conformed” hanya karena dimensi digunakan pada beberapa pertanyaan dari proses yang sama.

## 5. Kesimpulan

Bus Matrix menunjukkan bahwa **Inventory Snapshot menggunakan ketiga dimensi**. Model ini memenuhi kebutuhan Q1–Q5 dengan satu tabel fakta, sedangkan status *conformed* masih bersifat **rencana pengembangan** sampai dimensi tersebut digunakan dan diverifikasi lintas proses.