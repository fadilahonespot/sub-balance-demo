# TPS Test Script Guide

Panduan lengkap untuk menjalankan test TPS dengan satu script yang sudah digabungkan.

## 🚀 **Script Utama**

**Hanya satu script:** `scripts/test-tps-complete.sh`

## 📋 **Cara Menggunakan**

### **1. Test (Otomatis Reset Balance)**
```bash
# Jalankan test (otomatis reset balance)
make test

# Atau manual
./scripts/test-tps-complete.sh --reset
```

### **2. Test dengan Custom Settings**
```bash
# Custom account
./scripts/test-tps-complete.sh -a ACC002

# Custom duration
./scripts/test-tps-complete.sh -d 15

# Custom server URL
./scripts/test-tps-complete.sh -u http://localhost:8081/api/v1

# Reset balance untuk account tertentu
./scripts/test-tps-complete.sh --reset -a ACC002
```

## 🎯 **Command Makefile**

| Command | Fungsi |
|---------|--------|
| `make test` | Jalankan test TPS (otomatis reset balance) |
| `make test-setup` | Setup test data (opsional) |
| `make test-status` | Cek status account |
| `make balance` | Cek balance account |
| `make pending` | Cek pending transactions |

## 🔧 **Opsi Script**

| Opsi | Fungsi |
|------|--------|
| `-h, --help` | Tampilkan help |
| `-a, --account` | Account ID (default: ACC001) |
| `-d, --duration` | Durasi test per skenario (default: 10s) |
| `-u, --url` | Base URL server |
| `-r, --reset` | Reset balance sebelum test |
| `--reset-balance` | Reset balance sebelum test |

## 📊 **Skenario Test**

- ✅ **TPS 10** - 10 detik
- ✅ **TPS 30** - 10 detik  
- ✅ **TPS 50** - 10 detik
- ✅ **TPS 100** - 10 detik
- ✅ **Jeda 5 detik** antar skenario

## 🔄 **Reset Mode**

Ketika menggunakan `--reset`, script akan:

1. ✅ Cek pending transactions
2. ✅ Tunggu settlement
3. ✅ Hitung balance yang dibutuhkan
4. ✅ Tambah credit jika kurang
5. ✅ Jalankan test dengan balance fresh

## 📁 **Output**

- **Console** - Progress dan summary
- **`reports/tps_complete_report_*.md`** - Laporan lengkap
- **`reports/tps_test_*.log`** - Log detail

## ⚡ **Quick Start**

```bash
# Test (otomatis reset balance)
make test

# Test dengan custom
./scripts/test-tps-complete.sh --reset -a ACC002
```

## 🎉 **Keunggulan**

- ✅ **Satu script** - Tidak bingung dengan banyak file
- ✅ **Otomatis** - Handle account dan balance
- ✅ **Flexible** - Banyak opsi custom
- ✅ **Smart** - Reset mode untuk test berulang
- ✅ **Complete** - Monitoring, reporting, validation

**Sekarang hanya perlu ingat satu script: `test-tps-complete.sh`!** 🚀
