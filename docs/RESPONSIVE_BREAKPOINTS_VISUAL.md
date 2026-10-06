# Responsive Breakpoints Visual Guide

This document provides a visual reference for the responsive breakpoints used in STW Neo.

## Breakpoint Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          RESPONSIVE BREAKPOINTS                         │
└─────────────────────────────────────────────────────────────────────────┘

320px         576px        768px         992px        1200px       1400px
  │             │            │             │            │             │
  │   MOBILE    │  MOBILE    │   TABLET    │  TABLET    │  DESKTOP    │  DESKTOP
  │             │ LANDSCAPE  │  PORTRAIT   │ LANDSCAPE  │             │   LARGE
  │             │            │             │            │             │
  └─────────────┴────────────┴─────────────┴────────────┴─────────────┴──────────>
  
  iPhone SE     Landscape    iPad Mini     iPad Pro     MacBook       27" iMac
  Small Android Small Tablet Small Desktop  Desktop      Desktop       4K Display
```

## Device Categories

### 📱 Mobile (320px - 767px)

**Characteristics:**
- Single column layouts
- Full-width cards
- Stacked navigation
- Large touch targets (48x48 dp minimum)
- Minimal padding (16px)
- Font size: 14-15px base

**Common Devices:**
- iPhone SE (375x667)
- iPhone 12/13/14 (390x844)
- iPhone 14 Pro Max (430x932)
- Samsung Galaxy S10/S20 (360x800, 412x915)
- Google Pixel 5/6 (393x851)

**Layout Example:**
```
┌──────────────────┐
│     Header       │ <- Full width
├──────────────────┤
│                  │
│   Card 1         │ <- Stack vertically
│                  │
├──────────────────┤
│                  │
│   Card 2         │
│                  │
├──────────────────┤
│                  │
│   Card 3         │
│                  │
├──────────────────┤
│     Footer       │
└──────────────────┘
```

### 📱🔄 Mobile Landscape (576px - 767px)

**Characteristics:**
- Slightly wider layout
- 2-column grids where appropriate
- Reduced vertical spacing
- Horizontal navigation possible

**Common Scenarios:**
- Phones in landscape mode
- Small tablets in portrait
- Compact browser windows

**Layout Example:**
```
┌───────────────────────────────┐
│         Header                │
├───────────────────────────────┤
│           │                   │
│  Card 1   │      Card 2       │ <- 2 columns
│           │                   │
├───────────────────────────────┤
│         Footer                │
└───────────────────────────────┘
```

### 📲 Tablet Portrait (768px - 991px)

**Characteristics:**
- 2-3 column layouts
- More whitespace
- Side-by-side elements
- Medium padding (24px)
- Enhanced typography (16px base)

**Common Devices:**
- iPad Mini (768x1024)
- iPad Air (820x1180)
- iPad 10.2" (810x1080)
- Small tablets

**Layout Example:**
```
┌──────────────────────────────────┐
│          Header                  │
├──────────────────────────────────┤
│                                  │
│  ┌─────────┐    ┌─────────┐    │
│  │ Card 1  │    │ Card 2  │    │ <- 2-3 columns
│  └─────────┘    └─────────┘    │
│                                  │
│  ┌─────────┐    ┌─────────┐    │
│  │ Card 3  │    │ Card 4  │    │
│  └─────────┘    └─────────┘    │
│                                  │
├──────────────────────────────────┤
│          Footer                  │
└──────────────────────────────────┘
```

### 📲🔄 Tablet Landscape (992px - 1199px)

**Characteristics:**
- 3+ column layouts
- Split-screen possible
- Sidebar navigation
- Desktop-like features

**Common Devices:**
- iPad Pro 11" (834x1194)
- iPad landscape
- Small desktop windows

**Layout Example:**
```
┌────────────────────────────────────────────┐
│              Header                        │
├──────────┬─────────────────────────────────┤
│          │                                 │
│  Side    │  ┌────┐  ┌────┐  ┌────┐       │
│  Nav     │  │ C1 │  │ C2 │  │ C3 │       │ <- 3 columns
│          │  └────┘  └────┘  └────┘       │
│          │                                 │
├──────────┴─────────────────────────────────┤
│              Footer                        │
└────────────────────────────────────────────┘
```

### 💻 Desktop (1200px - 1399px)

**Characteristics:**
- Multi-column layouts
- Rich typography (17-18px base)
- Hover interactions
- Large padding (32px)
- Maximum content width (1024px)
- Centered with background

**Common Devices:**
- MacBook Pro 13" (1440x900)
- MacBook Pro 16" (1728x1117)
- Full HD displays (1920x1080)
- Desktop monitors

**Layout Example:**
```
┌─────┬───────────────────────────────────────────┬─────┐
│     │              Header                       │     │
│     ├───────────────────────────────────────────┤     │
│     │                                           │     │
│ BG  │  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐ │ BG  │
│     │  │  C1  │  │  C2  │  │  C3  │  │  C4  │ │     │ <- 4 columns
│     │  └──────┘  └──────┘  └──────┘  └──────┘ │     │
│     │                                           │     │
│     │           Max Width: 1024px               │     │
│     │                                           │     │
│     ├───────────────────────────────────────────┤     │
│     │              Footer                       │     │
└─────┴───────────────────────────────────────────┴─────┘
```

### 🖥️ Desktop Large (1400px+)

**Characteristics:**
- Maximum design width maintained
- Extra wide margins
- Enhanced visual hierarchy
- Large type (18px+ base)
- Same max-width as desktop (1024px)

**Common Devices:**
- 27" iMac (2560x1440)
- 4K displays (3840x2160)
- Ultra-wide monitors

**Layout Example:**
```
┌────────┬───────────────────────────────────┬────────┐
│        │          Header                   │        │
│        ├───────────────────────────────────┤        │
│        │                                   │        │
│   BG   │  ┌────┐  ┌────┐  ┌────┐  ┌────┐ │   BG   │
│        │  │ C1 │  │ C2 │  │ C3 │  │ C4 │ │        │
│        │  └────┘  └────┘  └────┘  └────┘ │        │
│        │                                   │        │
│  Wide  │      Max Width: 1024px           │  Wide  │
│ Margin │                                   │ Margin │
│        │                                   │        │
│        ├───────────────────────────────────┤        │
│        │          Footer                   │        │
└────────┴───────────────────────────────────┴────────┘
```

## Responsive Patterns

### Pattern 1: Stack to Row

Mobile → Desktop transition:

```
MOBILE (< 768px)          DESKTOP (≥ 768px)
┌──────────┐              ┌──────────────────────┐
│  Item 1  │              │ Item 1 | Item 2 | 3 │
├──────────┤      →       └──────────────────────┘
│  Item 2  │
├──────────┤
│  Item 3  │
└──────────┘
```

### Pattern 2: Grid Adaptation

```
MOBILE          TABLET           DESKTOP
1 column        2 columns        3-4 columns

┌────┐          ┌────┬────┐      ┌───┬───┬───┐
│ C1 │          │ C1 │ C2 │      │C1 │C2 │C3 │
├────┤          ├────┼────┤      ├───┼───┼───┤
│ C2 │    →    │ C3 │ C4 │  →  │C4 │C5 │C6 │
├────┤          └────┴────┘      └───┴───┴───┘
│ C3 │
└────┘
```

### Pattern 3: Navigation Adaptation

```
MOBILE              TABLET              DESKTOP
Hamburger Menu      Tabs                Full Nav

┌──────────┐        ┌──────────────┐    ┌──────────────────┐
│ ☰  Logo  │        │ Logo [T1][T2]│    │ Logo [L1][L2][L3]│
└──────────┘        └──────────────┘    └──────────────────┘
```

### Pattern 4: Content Density

```
MOBILE              TABLET              DESKTOP
Compact             Comfortable         Spacious

Padding: 16px       Padding: 24px       Padding: 32px
Font: 14px          Font: 16px          Font: 17-18px
Line Height: 1.5    Line Height: 1.5    Line Height: 1.5
```

## Typography Scale

```
Mobile (< 768px)     Tablet (768-1199px)   Desktop (≥ 1200px)
─────────────────    ───────────────────   ──────────────────
H1: 24-28px          H1: 28-32px           H1: 32-36px
H2: 20-24px          H2: 24-28px           H2: 28-32px
H3: 18-20px          H3: 20-22px           H3: 22-24px
Body: 14-15px        Body: 15-16px         Body: 16-18px
Small: 12-13px       Small: 13-14px        Small: 14-15px
```

## Spacing Scale

```
                Mobile    Tablet    Desktop
                ──────    ──────    ───────
Small Spacing:    8px      12px      16px
Medium Spacing:   12px     16px      20px
Large Spacing:    16px     24px      32px
XL Spacing:       24px     32px      48px
Padding:          16px     24px      32px
Margin:           16px     24px      32px
```

## Common Responsive Patterns in Code

### 1. Responsive Padding
```dart
context.isMobile   → 16px padding
context.isTablet   → 24px padding
context.isDesktop  → 32px padding
```

### 2. Responsive Columns
```dart
context.isMobile   → 1 column
context.isTablet   → 2 columns
context.isDesktop  → 3-4 columns
```

### 3. Responsive Font Size
```dart
context.isMobile   → fontSize * 0.9
context.isTablet   → fontSize * 1.0
context.isDesktop  → fontSize * 1.1
```

## Touch Target Guidelines

```
Minimum Touch Target: 48x48 dp
Recommended: 56x56 dp or larger

┌────────────┐
│            │  48dp minimum
│   Button   │  56dp recommended
│            │
└────────────┘
    48-56dp

Spacing between targets: 8dp minimum
```

## Maximum Width Constraints

```
phoneMaxWidth:    560px   (Landing, Home screens)
contentMaxWidth:  820px   (Forms, lists, summaries)
shellMaxWidth:    1024px  (Entire app on wide screens)

┌─────────────────────────────────────────────┐
│                                             │
│   ┌───────────────────────────────┐        │
│   │     Max 1024px                │        │ Wide Screen
│   │   (Centered with margins)     │        │
│   └───────────────────────────────┘        │
│                                             │
└─────────────────────────────────────────────┘
```

## Quick Reference Table

| Screen Size | Width Range | Columns | Padding | Font Base | Use Case |
|-------------|-------------|---------|---------|-----------|----------|
| Mobile | 320-767px | 1 | 16px | 14-15px | Phones portrait |
| Mobile L | 576-767px | 1-2 | 16px | 15px | Phones landscape |
| Tablet | 768-991px | 2-3 | 24px | 16px | Tablets portrait |
| Tablet L | 992-1199px | 3 | 24px | 16-17px | Tablets landscape |
| Desktop | 1200-1399px | 3-4 | 32px | 17-18px | Laptops, desktops |
| Desktop L | 1400px+ | 3-4 | 32px | 18px | Large displays |

---

## Visual Testing

Use browser DevTools to test these breakpoints:

**Chrome DevTools:**
1. Press F12 or Cmd+Option+I
2. Click "Toggle Device Toolbar" (Cmd+Shift+M)
3. Select device or enter custom dimensions
4. Test each breakpoint

**Recommended Test Widths:**
- 375px (iPhone)
- 768px (iPad Portrait)
- 1024px (iPad Landscape)
- 1440px (Laptop)
- 1920px (Desktop)

---

*Last Updated: January 2025*
