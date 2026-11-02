| Kode | Pertanyaan untuk manajemen | Measure (fakta/ukuran) | Dimensi | Sumber primer | Visualisasi usulan |
|---|---|---|---|---|---|
| Q1 | Berapa jumlah stok per kategori produk? | `SUM(quantity)` | Produk → subkategori → kategori | ProductInventory + Product + ProductSubcategory + ProductCategory | Bar kategori |
| Q2 | Produk apa yang stoknya tertinggi/rendah? | `SUM(quantity)` per `productid` | Produk | ProductInventory + Product | Top/bottom 10 |
| Q3 | Lokasi mana yang menyimpan stok terbesar? | `SUM(quantity)` per lokasi | Lokasi | ProductInventory + Location | Bar lokasi |
| Q4 | Produk apa yang total stoknya kurang dari reorder point? | `SUM(quantity)` per produk, dibanding `MAX(reorderpoint)` **setelah agregasi** | Produk | ProductInventory + Product | Tabel alert |
| Q5 | Berapa estimasi nilai stok menurut kategori/lokasi? | `SUM(quantity * standardcost)` | Produk/kategori, Lokasi | ProductInventory + Product (+kategori) + Location | Matriks/bar |