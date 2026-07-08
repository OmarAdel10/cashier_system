# Design System & UI/UX Specification
## Project: Premium Stationery POS System (المكتبة) - MVP

### 1. Visual Philosophy & Performance Constraints
To achieve a "premium" feel on potato desktop hardware (low-end CPUs, integrated graphics, 4GB RAM), the interface must abandon heavy GPU-intensive operations.
* **Banned Layout Properties:** Deep Gaussian blurs (`BackdropFilter`), nested overlapping opacity layers, heavy blurred drop shadows, and continuous loop decorative animations.
* **Design Aesthetic:** Flat, high-contrast, structural minimalism. Premium quality is achieved through **immaculate typography hierarchies, crisp sharp borders, perfect padding symmetry, and fast, snappy micro-interactions**.

### 2. Design Tokens (The Theme Matrix)

#### Color Palette
Designed for high legibility inside retail stores under harsh fluorescent lighting conditions:
* **Primary / Accent:** Deep Modern Blue (`#007ACC`) — for core action buttons and focus states.
* **Success / Cash:** Teal Green (`#10B981`) — exclusively for total amounts, payment triggers, and sales completions.
* **Background (Light Mode):** Clean Off-White (`#F8FAFC`) with card containers set to absolute white (`#FFFFFF`).
* **Background (Dark Mode):** Charcoal/Slate (`#0F172A`) with card containers set to (`#1E293B`).
* **Borders / Dividers:** Subtle Slate Grey (`#E2E8F0` for Light, `#334155` for Dark).

#### Typography & Localization Engine Rules (Dual Language RTL)
The system must render flawless Arabic (for store operations/items) and English text concurrently.
* **Directionality Rule:** When the active state sets language to Arabic, the root application wrapper executes a full layout inversion (`TextDirection.rtl`). The Side Nav Rail shifts cleanly to the right-hand window edge, and layout vectors mirror perfectly.
* **Primary Font Family:** `Cairo` (Google Fonts) — chosen for its geometric design rendering cleanly across both English labels and complex Arabic script.
* **Heading Hierarchy:**
	* `HeadlineLarge` (Totals/Change): Bold, 32pt.
	* `TitleMedium` (Product Names/Grid Tiles): SemiBold, 16pt.
	* `BodySmall` (Receipt details/Skus): Regular, 12pt.

### 3. Desktop Layout Geometry & Layout Grids

The application layout locks into a fixed, multi-pane structural layout to prevent excessive window resizing calculations.

```
┌─────────────────────────────────────────────────────────────┐
│  Side  │ Search Bar & Scanner Status Interceptor Indicator  │
│  Nav   ├──────────────────────────────┬──────────────────────┤
│  Rail  │                              │                      │
│        │                              │                      │
│  [🏠]  │                              │   Digital Receipt    │
│  [📦]  │    Dynamic Workspace View    │    Tower Panel       │
│  [📊]  │ (Switches between Checkout,  │                      │
│        │   Inventory, or Settings)    ├──────────────────────┤
│        │                              │  Interactive Cash    │
│  [⚙️]  │                              │  Drawer Assistant    │
│Settings│                              │  [10] [20] [50] [200]│
└────────┴──────────────────────────────┴──────────────────────┘
```

#### Split Pane Spatial Ratios
* **Left Sidebar Rail (Right-Aligned in RTL mode):** Fixed Width `72px`. Houses core navigation icons (Checkout, Ingestion, Logs, Settings).
* **Center Workspace (70% Remaining Width):** Renders the active layout depending on navigation choice (Checkout Hub Grid, Stock Ingestion Interface, or the Store Configuration View).
* **Side Tower Panel (30% Remaining Width):** Fixed min-width `360px`. Dedicated exclusively to the active cart receipt print-preview and cash drawer assistant.

### 4. Interactive Component Specifications

#### Component A: The Dynamic Quick-Tiles
* **Layout:** Grid system using `SliverGridWithFixedCrossAxisCount` tracking cross-axis size responsively based on available center width.
* **Visual Rules:** Container cards use solid backgrounds specified by the item's `tileColorHex`. Text must automatically compute contrast color (Absolute White vs. Dark Charcoal) depending on the background brightness value.
* **Interaction:** Tapping a tile invokes a `Material` ripple flash effect that triggers instantly, bypassing multi-frame bounce easing configurations.

#### Component B: Store Settings Workspace Components
* **Layout Blocks:** Form-factor lists separated by clean divider elements tracking localized properties. Text inputs utilize automatic validation blocks checking formatting constraints dynamically.

---