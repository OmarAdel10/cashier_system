# Product Requirement Document (PRD)
## Project: Premium Stationery POS System (المكتبة) - MVP

### 1. Overview & Objectives
The objective is to build a premium, highly responsive, offline-first Desktop Point of Sale (POS) application tailored for Egyptian stationery and school supply stores ("مكتبة"). The system must run smoothly on low-resource legacy hardware running Windows 10, replacing traditional outdated software with a modern, fluid user experience.

### 2. Target Hardware & Constraints
* **Operating System:** Windows 10 Desktop (64-bit).
* **Hardware Baseline:** Low-end Intel Core i3/Celeron processors, 4GB RAM, integrated graphics.
* **Performance Requirement:** Constant 60 FPS UI rendering; minimal memory footprint; absolute zero lag during checkout scanning operations.

### 3. Core Feature Scope (MVP)

#### Module A: Cashier Checkout Hub (Home Screen)
* **Headless Barcode Scanning Interceptor:** A global keyboard event listener must process input from a hardware barcode scanner automatically, regardless of which UI element currently holds focus.
* **Unified SKU Registry Tracking:** Identical items share the same barcode. Modifying the item quantity increments or decrements that unified record. Distinct packaging levels (e.g., a single pen vs. an entire box of pens) are treated as separate products with distinct barcodes.
* **Dynamic Quick Actions Grid:** A dedicated panel housing large, color-coded interactive tiles for barcode-less sales (e.g., photocopying services, custom gift wrapping, loose colored paper sheets).
* **Interactive Cash Drawer Assistant:** Quick-select monetary buttons for Egyptian currency notes (10, 20, 50, 100, 200 EGP) to instantly calculate accurate customer change calculations.

#### Module B: Product Management & Barcode Studio
* **Inventory Ingestion Interface:** Fast forms to input Item Name, Cost Price, Retail Price, Stock Count, and Barcode.
* **Quick Grid Configuration Switch:** A checkbox allowing the user to flag any product as a "Quick-Tile" item, instantly generating a button on the Checkout Hub with a customizable color theme.
* **Live Barcode Generator Preview:** A rendering container that displays a vector layout of a retail sticker (38mm x 25mm) updated in real-time as the SKU string is modified.

#### Module C: Shift & Sales History Ledger
* **Immutable Sales Log:** A secure local timeline capturing every successful transaction. Once recorded, the historical price, timestamp, and sold items remain unalterable, ensuring consistent accounting records if base product costs change in the future.

#### Module D: Store Settings & Localization Profile
* **Dynamic RTL Localization Toggle:** A master system switch changing the user interface between Arabic (العربية) and English instantly, triggering full structural layout direction flipping (`TextDirection.rtl`).
* **Store Identity Configurator:** Configurable textual parameters (Store Name, Receipt Footnote Message) that feed directly into the digital checkout layout and physical transaction receipts.
* **Theme Preference Selector:** Toggle state between Light Mode and High-Contrast Dark Mode to alleviate eye-strain during extended retail night shifts.

---