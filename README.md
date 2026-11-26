# DukaanMate (दुकान मेट) 📱🛒

**DukaanMate** is a modern, high-performance offline-first billing, inventory, ledger (Khata), and smart retail management system built with Flutter & Dart for small-to-medium retail businesses, grocery stores, and local merchants.

---

## 🌟 Key Features

- **⚡ Fast Offline Billing & Invoicing**: Generate itemized invoices with real-time tax calculation, discounts, and print/share receipts as PDF.
- **⚖️ Smart & Weight Calculator**: Quick price-by-weight calculator (grams/kg) and integrated shop calculator for fast counter calculations.
- **👥 Customer Ledger (Udhaar / Khata)**: Maintain individual customer debit/credit transactions, payment history, and pending balances.
- **📦 Inventory & Product Catalog**: Track stock counts, barcode lookup, cost prices, selling prices, and profit margins.
- **📊 Business Analytics & Reports**: Daily, weekly, and monthly sales summaries, revenue breakdowns, and top-selling item insights.
- **💳 UPI & QR Code Integration**: Seamless customer payments via pre-configured UPI QR codes on invoices.
- **🛡️ 100% Offline & Secure Local Database**: Powered by [Drift](https://drift.simonbinder.eu/) (SQLite) with encrypted backups and local data persistence.

---

## 🏛️ Architecture Overview

The project adheres to **Clean Architecture** and **Feature-First modular structure**:

```text
lib/
├── core/                   # Core application configuration, base utilities
│   ├── constants/          # App constants, styling & dimensions
│   ├── database/           # Drift SQLite database, DAOs, and schema tables
│   ├── errors/             # Custom exception handling & failure models
│   ├── providers/          # Riverpod state management providers
│   ├── routes/             # App routing and navigation handling
│   ├── theme/              # Dark/light theme definitions & typography
│   └── utils/              # Formatting helpers (Currency, Date, Text)
├── features/               # Feature-based modular structure
│   ├── backup/             # Local database export, import & vacuuming
│   ├── billing/            # Invoice generation, cart, and PDF printing
│   ├── calculator/         # Smart calculator & weight-based pricing
│   ├── customers/          # Ledger (Khata), customer directory & statements
│   ├── dashboard/          # Metric counters, quick actions & daily summary
│   ├── products/           # Product catalogue, pricing & stock tracking
│   ├── reports/            # Sales reporting, charts & profit metrics
│   └── settings/           # Business profile, UPI QR setup & preferences
├── shared/                 # Shared widgets, services, and domain models
└── main.dart               # Application entry point & provider scope initialization
```

---

## 🛠️ Tech Stack & Dependencies

- **Framework**: [Flutter](https://flutter.dev/) (Channel stable)
- **Language**: [Dart](https://dart.dev/)
- **State Management**: [Riverpod / Flutter Riverpod](https://riverpod.dev/)
- **Local Database**: [Drift](https://drift.simonbinder.eu/) + `sqlite3_flutter_libs`
- **PDF Generation**: `pdf` & `printing`
- **Routing**: `go_router`
- **File Management & Sharing**: `share_plus`, `path_provider`, `archive`

---

## 🚀 Getting Started & Setup

### Prerequisites

- Flutter SDK `^3.19.0` or higher
- Android Studio / VS Code with Flutter extension
- Android SDK (API Level 21+) or iOS toolchain (Xcode 14+)

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/yuchandewar/DukaanMate.git
   cd DukaanMate
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Generate Drift Database Code**:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Run the Application**:
   ```bash
   flutter run
   ```

---

## 🔒 Security & Privacy

- **Offline-First**: All data is stored locally on the merchant's device using SQLite.
- **Zero Cloud Exposure**: Sensitive customer records, ledgers, and transactions stay on the device unless explicitly exported as an encrypted backup.
- **Android Release Signing**: Signing keys and `key.properties` are kept out of version control.

---

## 🤝 Contributing

Contributions, bug reports, and feature requests are welcome! Feel free to check the [issues page](https://github.com/yuchandewar/DukaanMate/issues).

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
