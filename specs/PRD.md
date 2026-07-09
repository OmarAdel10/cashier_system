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
* **Unknown Barcode Feedback:** When the scanner interceptor produces a barcode that does not exist in the `inventoryMap`, the system must surface a localized, dismissible error affordance (see `DESIGN.md` Section 6.4) — the cashier must never see a silent no-op on a missed scan, and the focus must remain on the scanner input so the next scan is captured immediately.
* **Empty Cart First-Launch State:** A new install with no inventory must present a localized empty state (see `DESIGN.md` Section 6.3) directing the cashier to the Product Management module rather than a blank canvas.
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
* **Dynamic RTL Localization Toggle:** A master system switch changing the user interface between Arabic (العربية) and English instantly, triggering full structural layout direction flipping (`TextDirection.rtl`). Implemented as a `SegmentedButton` with per-tab auto-save.
* **Store Identity Configurator:** Configurable textual parameters `storeName` (String) and `receiptFootnote` (String) stored as fields on `AppSettingsEntity` with `copyWith()` immutability. Values feed directly into the digital checkout layout and physical transaction receipts.
* **Theme Preference Selector:** Toggle state between Light Mode (warm beige palette: `#F5F0EB`/`#FFFDF5`) and High-Contrast Dark Mode (charcoal: `#0F172A`/`#1E293B`) to alleviate eye-strain during extended retail night shifts. Implemented as a `Switch` with real-time status indicator.
* **Persistence Model:** All settings persisted automatically via `HydratedBloc` + Hive local key-value storage. No explicit "Save" or "Apply" button required — each interaction commits immediately. A failure to persist (disk full, corrupted box) must surface the localized error state from `DESIGN.md` Section 6.4, with a retry action that re-issues the original bloc event against the same payload.
* **Localization Engine:** Dedicated `LocalizationService` class with O(1) `Map<String, Map<String, String>>` translation dictionary supporting Arabic and English. Accessed via `translate(key)` method. No `intl` package dependency.

---