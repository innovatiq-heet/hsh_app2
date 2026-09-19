# App Theme & Colors Documentation

Comprehensive documentation for the design system tokens, color palettes, typography, dimensions, and `ThemeData` configuration used across the application.

---

## 📁 Source Files

| Resource | File Location | Description |
| :--- | :--- | :--- |
| **Color Tokens** | [`lib/constants/app_colors.dart`](file:///e:/Flutter%20Projects/hsh_app2/lib/constants/app_colors.dart) | Core brand colors, status indicators, gradients, and shadows |
| **Theme Configuration** | [`lib/constants/app_theme.dart`](file:///e:/Flutter%20Projects/hsh_app2/lib/constants/app_theme.dart) | Global Material 3 `ThemeData` setup and component themes |
| **Typography** | [`lib/constants/app_text_styles.dart`](file:///e:/Flutter%20Projects/hsh_app2/lib/constants/app_text_styles.dart) | Plus Jakarta Sans font style definitions |
| **Dimensions & Spacing** | [`lib/constants/app_dimens.dart`](file:///e:/Flutter%20Projects/hsh_app2/lib/constants/app_dimens.dart) | Standard padding, margins, radii, and component heights |

---

## 🎨 Color Palette (`AppColors`)

### 1. Brand & Core Colors

| Swatch | Color Name | Hex Code | ARGB / Constant | Role & Usage |
| :---: | :--- | :--- | :--- | :--- |
| 🟦 | `headerBlue` | `#0F172A` | `0xFF0F172A` | Deep navy for primary titles, app bars, and high-emphasis headers |
| 🟦 | `primary` | `#1E3A8A` | `0xFF1E3A8A` | Main brand color (Deep Blue) for primary actions, buttons, and active states |
| 🟦 | `primaryLight` | `#3B82F6` | `0xFF3B82F6` | Vibrant light blue for gradients, focus borders, and highlights |
| 🟦 | `secondary` | `#0EA5E9` | `0xFF0EA5E9` | Sky blue secondary accent for gradients and complementary highlights |
| ⬜ | `mainBackground` | `#F8FAFC` | `0xFFF8FAFC` | App scaffold background, ultra-light slate gray |
| ⬜ | `surface` | `#FFFFFF` | `0xFFFFFFFF` | Pure white for cards, sheets, dialogs, and navigation surfaces |

### 2. Typography & Neutral Colors

| Swatch | Color Name | Hex Code | ARGB / Constant | Role & Usage |
| :---: | :--- | :--- | :--- | :--- |
| ⬛ | `textPrimary` | `#0F172A` | `0xFF0F172A` | High-contrast dark slate for main headings and primary body text |
| 🔘 | `textSecondary` | `#64748B` | `0xFF64748B` | Medium slate for secondary labels, descriptions, and subtitle text |
| 🔘 | `textMuted` | `#94A3B8` | `0xFF94A3B8` | Light slate for hints, placeholders, disabled states, and captions |

### 3. Status & Feedback Colors

| Swatch | Color Name | Hex Code | ARGB / Constant | Role & Usage |
| :---: | :--- | :--- | :--- | :--- |
| 🟩 | `successGreen` | `#10B981` | `0xFF10B981` | Completed, verified, success badges, and confirmation states |
| 🟧 | `warningOrange` | `#F59E0B` | `0xFFF59E0B` | In-progress, alert warnings, and cautionary items |
| 🟥 | `cancelledRed` | `#EF4444` | `0xFFEF4444` | Error states, validation failures, destructive actions, and cancelled badges |
| 🟦 | `pendingBlue` | `#3B82F6` | `0xFF3B82F6` | Informational notes, queued items, and pending review states |

### 4. Borders, Surfaces & Effects

| Swatch | Color Name | Hex Code | ARGB / Constant | Role & Usage |
| :---: | :--- | :--- | :--- | :--- |
| ⬜ | `border` | `#E2E8F0` | `0xFFE2E8F0` | Card borders, dividers, chip outlines, and field strokes |
| ⬜ | `surfaceMuted` | `#F1F5F9` | `0xFFF1F5F9` | Form input backgrounds, chip disabled state, and subtle chips |
| 🟦 | `primarySoft` | `#E8EEFB` | `0xFFE8EEFB` | Soft tinted blue for navigation selection pill and active tag backgrounds |
| ⬛ | `shadow` | `#0F172A` | `0xFF0F172A` | Base color for elevation shadows (rendered with 6% alpha) |

---

## 🌈 Gradients & Shadows

### Gradients

```dart
// Primary Gradient (Diagonal from Primary to Secondary)
static const LinearGradient primaryGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF1E3A8A), Color(0xFF0EA5E9)],
);

// Hero Header Gradient (Deep Navy -> Brand Blue -> Light Blue)
static const LinearGradient heroGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF3B82F6)],
  stops: [0.0, 0.55, 1.0],
);

// Button Gradient (Left-to-Right Primary to Light Blue)
static const LinearGradient buttonGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
);
```

### Soft Shadow Token

```dart
static final List<BoxShadow> softShadow = [
  BoxShadow(
    color: Color(0xFF0F172A).withValues(alpha: 0.06),
    blurRadius: 24,
    offset: const Offset(0, 8),
  ),
];
```

---

## 🔤 Typography (`AppTextStyles`)

The application uses **Plus Jakarta Sans** (`GoogleFonts.plusJakartaSans`) with `AppColors.textPrimary` default styling:

| Style Name | Font Size | Weight | Letter Spacing | Default Color | Intended Usage |
| :--- | :---: | :---: | :---: | :--- | :--- |
| `displayXl` | 34 pt | 800 (Bold) | -0.8 | `textPrimary` | Hero section numbers, big metrics |
| `displayLg` | 28 pt | 800 (Bold) | -0.6 | `textPrimary` | Splash headers, primary screens |
| `displayMd` | 24 pt | 700 (Bold) | -0.4 | `textPrimary` | Page title banners, modal headers |
| `headline` | 20 pt | 700 (Bold) | -0.2 | `textPrimary` | AppBar titles, card headers |
| `title` | 17 pt | 700 (Bold) | 0.0 | `textPrimary` | Section titles, list item headers |
| `subtitle` | 15 pt | 600 (SemiBold) | 0.0 | `textPrimary` | Tab labels, button alternatives |
| `bodyLg` | 15 pt | 500 (Medium) | 0.0 | `textPrimary` | Prominent body text, summaries |
| `bodyMd` | 14 pt | 500 (Medium) | 0.0 | `textPrimary` | Standard body copy, form fields |
| `bodySm` | 12 pt | 500 (Medium) | 0.0 | `textSecondary` | Sub-labels, secondary descriptions |
| `label` | 13 pt | 600 (SemiBold) | 0.0 | `textSecondary` | Input floating labels, chips |
| `caption` | 11 pt | 600 (SemiBold) | +0.2 | `textMuted` | Bottom navigation labels, time stamps |
| `overline` | 11 pt | 700 (Bold) | +1.1 | `textMuted` | Category eyebrow tags, uppercase titles |
| `button` | 15 pt | 700 (Bold) | 0.0 | `Colors.white` | Primary elevated action buttons |

---

## 📐 Dimensions & Layout (`AppDimens`)

```dart
// Padding & Spacing
screenPadding   = 20.0;   // Outer screen horizontal margin
cardPadding     = 18.0;   // Inner card content padding
gapXs           = 4.0;    // Extra small spacing
gapSm           = 8.0;    // Small spacing
gapMd           = 12.0;   // Medium spacing
gapLg           = 16.0;   // Large spacing
gapXl           = 24.0;   // Section spacing
gapXxl          = 32.0;   // Major container spacing

// Border Radii
radiusSm        = 10.0;   // Small components & badges
radiusMd        = 16.0;   // Cards, inputs, dialog buttons
radiusLg        = 20.0;   // Floating action buttons, hero cards
radiusXl        = 28.0;   // Bottom sheets, modal dialogs
radiusPill      = 999.0;  // Fully rounded stadium buttons & chips

// Component Heights & Sizes
buttonHeight    = 54.0;   // Standard touch target button height
inputHeight     = 56.0;   // Standard text field height
bottomNavHeight = 72.0;   // Custom navigation bar height
iconSm          = 16.0;   // Inline icons
iconMd          = 24.0;   // Standard action icons
iconLg          = 32.0;   // Featured card icons
```

---

## ⚙️ Material 3 Theme Specification (`AppTheme.light`)

The theme is configured using `Material 3` (`useMaterial3: true`).

### 1. Root & ColorScheme
- **Scaffold Background**: `AppColors.mainBackground` (`#F8FAFC`)
- **Splash Factory**: `InkSparkle.splashFactory`
- **ColorScheme**:
  - `seedColor`: `AppColors.primary` (`#1E3A8A`)
  - `primary`: `AppColors.primary` (`#1E3A8A`)
  - `secondary`: `AppColors.secondary` (`#0EA5E9`)
  - `surface`: `AppColors.surface` (`#FFFFFF`)
  - `error`: `AppColors.cancelledRed` (`#EF4444`)

### 2. AppBar (`AppBarTheme`)
- **Background**: `AppColors.mainBackground`
- **Foreground / Title**: `AppColors.headerBlue` with `AppTextStyles.headline`
- **Elevation**: `0` (flat)
- **Scrolled Under Elevation**: `0`
- **Status Bar Icons**: Dark icons (`SystemUiOverlayStyle.dark`)
- **Center Title**: `false`

### 3. Buttons
- **`ElevatedButtonTheme`**:
  - Background: `AppColors.primary`
  - Text: White, `AppTextStyles.button`
  - Height: `54.0` (`AppDimens.buttonHeight`)
  - Shape: Rounded rectangle with `16.0` radius (`AppDimens.radiusMd`)
  - Elevation: `0`
- **`FilledButtonTheme`**:
  - Background: `AppColors.primary`
  - Shape: Stadium border (`StadiumBorder`)
  - Padding: Horizontal `18`, Vertical `10`
  - Text: `AppTextStyles.subtitle`
- **`OutlinedButtonTheme`**:
  - Shape: Stadium border (`StadiumBorder`)
  - Padding: Horizontal `18`, Vertical `10`
  - Text: `AppTextStyles.subtitle`
- **`TextButtonTheme`**:
  - Foreground: `AppColors.primary`
  - Text: `AppTextStyles.subtitle`
- **`FloatingActionButtonTheme`**:
  - Background: `AppColors.primary`
  - Foreground: White
  - Elevation: `6` (Highlight: `8`)
  - Shape: Rounded rectangle with `20.0` radius (`AppDimens.radiusLg`)

### 4. Input Fields (`InputDecorationTheme`)
- **Filled**: `true`
- **Fill Color**: `AppColors.surfaceMuted` (`#F1F5F9`)
- **Padding**: Horizontal `18`, Vertical `18`
- **Default/Enabled/Disabled Border**: Borderless (`OutlineInputBorder` with `BorderSide.none`, radius `16.0`)
- **Focused Border**: `AppColors.primaryLight` with `1.6` width
- **Error / Focused Error Border**: `AppColors.cancelledRed`
- **Icon Color**: `AppColors.textMuted` (Prefix & Suffix)
- **Hint Style**: `AppTextStyles.bodyMd` with `AppColors.textMuted`
- **Label Style**: `AppTextStyles.bodyMd` with `AppColors.textSecondary`
- **Floating Label Style**: `AppTextStyles.label` with `AppColors.primary`

### 5. Navigation Bar (`NavigationBarThemeData`)
- **Height**: `72.0` (`AppDimens.bottomNavHeight`)
- **Background**: `AppColors.surface` (`#FFFFFF`)
- **Indicator Color**: `AppColors.primarySoft` (`#E8EEFB`)
- **Elevation**: `0`
- **Selected Icon**: `AppColors.primary`
- **Unselected Icon**: `AppColors.textMuted`
- **Selected Text**: `AppColors.primary` (Font size `12`, Bold `w700`)
- **Unselected Text**: `AppColors.textMuted` (Font size `12`, SemiBold `w600`)

### 6. Chips & Segmented Controls
- **`ChipThemeData`**:
  - Surface: `AppColors.surface`
  - Selected Fill: `AppColors.primary`
  - Outline: `AppColors.border` (`#E2E8F0`)
  - Shape: Stadium border (`StadiumBorder`)
  - Selected Label: White
  - Unselected Label: `AppColors.textSecondary`
- **`SegmentedButtonThemeData`**:
  - Selected Fill: `AppColors.primary` with White text
  - Unselected Fill: `AppColors.surface` with `AppColors.textSecondary` text
  - Border: `AppColors.border`
  - Padding: Vertical `14`

### 7. Overlays & Dialogs
- **`SnackBarThemeData`**:
  - Behavior: Floating (`SnackBarBehavior.floating`)
  - Background: `AppColors.headerBlue` (`#0F172A`)
  - Text: White (`AppTextStyles.bodyMd`)
  - Border Radius: `16.0` (`AppDimens.radiusMd`)
- **`BottomSheetThemeData`**:
  - Background: `AppColors.surface` (`#FFFFFF`)
  - Drag Handle: Visible (`showDragHandle: true`)
  - Top Corner Radius: `28.0` (`AppDimens.radiusXl`)
- **`DialogThemeData`**:
  - Background: `AppColors.surface`
  - Corner Radius: `28.0` (`AppDimens.radiusXl`)

### 8. Selection Controls & Miscellaneous
- **`CheckboxThemeData`**: Corner radius `6`, fills with `AppColors.primary` when checked.
- **`ProgressIndicatorThemeData`**: `AppColors.primary`.
- **`DividerThemeData`**: Color `AppColors.border`, thickness `1`, space `1`.
- **`TabBarThemeData`**: Primary indicator, starts alignment, label color `AppColors.primary`, unselected color `AppColors.textSecondary`.

---

## 💻 Flutter Usage Examples

### Applying the Theme in `main.dart`
```dart
import 'package:flutter/material.dart';
import 'constants/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HSH App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const HomeScreen(),
    );
  }
}
```

### Using Colors & Styles in Custom Widgets
```dart
import 'package:flutter/material.dart';
import 'constants/app_colors.dart';
import 'constants/app_dimens.dart';
import 'constants/app_text_styles.dart';

class StatusCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isCompleted;

  const StatusCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted ? AppColors.successGreen : AppColors.warningOrange,
            ),
          ),
          const SizedBox(width: AppDimens.gapMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.title),
                const SizedBox(height: AppDimens.gapXs),
                Text(subtitle, style: AppTextStyles.bodySm),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```
