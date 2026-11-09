# Desain Cube

| Elemen | Desain Cube | Asal di DW |
| :--- | :--- | :--- |
| **Nama cube** | Inventaris | `fact_inventory` |
| **Dimensi Waktu** | Tahun > Semester > Kuartal > Bulan > Tanggal | `dim_tanggal` via `tanggal_key` |
| **Dimensi Kategori** | Nama Kategori > Nama Subkategori | `dim_kategori` via `kategori_key` |
| **Dimensi Produk** | Nama Produk (`nama_produk`) | `dim_produk` via `produk_key` |
| **Dimensi Lokasi** | Nama Lokasi (`nama_lokasi`) | `dim_lokasi` via `lokasi_key` |
| **Dimensi Rak** | Shelf > Bin | `dim_rak` via `rak_key` |
| **Measure** | Total Kuantitas (`sum`), Jumlah Catatan Inventaris (`count`) | Kolom `quantity` pada `fact_inventory` |
| **Calculated Member** | Rata-rata Stok per Catatan = `[Measures].[Total Kuantitas]` / `[Measures].[Jumlah Catatan Inventaris]` | Dihitung otomatis di level cube |
