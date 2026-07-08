# System Architecture & Technical Specification
## Project: Premium Stationery POS System (المكتبة) - MVP

### 1. Architectural Framework
The system implements **Clean Architecture** organized around a **Feature-First** structural paradigm. Each system module (`checkout`, `inventory`, `sales_history`) must be strictly segregated into independent computational layers to satisfy SOLID design principles.

```
lib/ 
└── features/
└── [feature_name]/
├── data/ # Data Transfer Objects (DTOs), Hive Adapters, Repo Impl
├── domain/ # Pure Business Entities, Abstract Contracts, Use Cases
└── presentation/ # HydratedBLoC/Cubit state logic, UI Layout Widgets
```

### 2. Concrete Technology Stack 
* **UI Framework:** Flutter Desktop (Native Windows Compilation targeting C++ engine binary).
* **State Management & Local Cache Engine:** HydratedBLoC running on top of a pure Dart Hive key-value storage layout. State modifications automatically serialize asynchronously directly to the local disk in JSON formats.
* **Barcode Layout Engine:** `barcode_widget` package using native vector rendering mechanics.
* **Localization Implementation Engine:** Built-in lightweight $O(1)$ local `Map<String, Map<String, String>>` structural dictionary within the `SettingsBloc` (Bypassing `intl` code-generation to keep memory profiles minimal and enable future client-side translation overrides).

### 3. Data Structures & Performance Optimization Rules 

#### Rule 1: O(1) Fast Inventory Lookup Map
To ensure lightning-fast item ingestion during high-volume cashier rushes on poor hardware, the central application state must store products inside an optimized **Hash Map** layout rather than a linear array list.
* **Data Layout:** `Map<String, ProductEntity>` where the **Key is the Barcode String**.
* **Performance Baseline:** Search evaluation runs at constant $O(1)$ time complexity, ensuring instant item retrieval whether the database contains 100 entries or 30,000 stationery products.
#### Rule 2: Segmented State Memory Allocation
To optimize execution memory profiles on 4GB RAM machines, the application state splits indexation upon boot:
1. `inventoryMap`: Core key-value matrix mapping barcodes directly to entities for backend business calculations.
2. `quickTileList`: A pre-filtered sub-array tracking exclusively entries tagged with `isQuickTile == true` to allow instant, calculation-free UI drawing loops on the Checkout Dashboard.

#### Rule 3: Fixed-Point Financial Precision Math
To completely eradicate binary floating-point computation rounding anomalies (`double` precision leakage), the system enforces strict integer manipulation tracking the lowest Egyptian monetary subdivision (Piastres / قروش).
* **Formula:** Internal Value = EGP String Value * 100 *
* *Example:* A notebook retailing at `15.75 EGP` evaluates internally as the absolute integer `1575`. A single photocopy service costing `0.50 EGP` evaluates as the integer `50`. Division operations or decimal formatting maps occur exclusively at the visual presentation layer border (`displayString = value / 100`).

#### Rule 4: Constant Localization & Application Properties Registry 
* The active local dictionary utilizes nested key lookup strings: `translationMap[currentLanguageCode][uiLabelKey]`.
* Because execution passes directly through standard Dart Map pointers, language switches alter the state immediately with zero layout recalculation overhead.

### 4. Design Patterns Mandate
* **Repository Pattern:** Structural separation decoupled via abstract contracts. The presentation layer state engines are explicitly blind to Hive configurations, communicating only via `IProductRepository` interfaces.
* **Command Pattern:** Cart transactional events (addition, adjustments, deductions) are processed as individual event requests sent to the Checkout BLoC, allowing decoupled calculation testing.

---