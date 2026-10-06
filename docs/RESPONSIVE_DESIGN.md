# Responsive Design Guide

This document outlines the responsive design system implemented in the STW Neo application.

## Breakpoints

The application uses the following breakpoints defined in `lib/core/widgets/responsive.dart`:

| Breakpoint | Value | Description |
|------------|-------|-------------|
| `mobile` | 320px | Mobile portrait (phones) |
| `mobileLandscape` | 576px | Mobile landscape / small tablets |
| `tablet` | 768px | Tablets portrait |
| `tabletLandscape` | 992px | Tablets landscape / small desktop |
| `desktop` | 1200px | Desktop |
| `desktopLarge` | 1400px | Large desktop |
| `phoneMaxWidth` | 560px | Max width for phone-proportioned screens |
| `contentMaxWidth` | 820px | Max width for forms and content |
| `shellMaxWidth` | 1024px | Max width for the entire app |

## Responsive Components

### 1. AppShell
Centres the app in a maximum-width column on wide screens (>1104px), preventing the UI from stretching too wide on large monitors.

```dart
MaterialApp.router(
  builder: (context, child) => AppShell(child: child!),
)
```

### 2. PhoneColumn
Creates a phone-proportioned layout that:
- Limits width to `phoneMaxWidth` (default 560px)
- Centres content vertically and horizontally
- Enables scrolling when viewport height is less than `minHeight`

```dart
PhoneColumn(
  child: YourContent(),
)
```

### 3. MaxWidth
Constrains child width for consistent alignment:

```dart
MaxWidth(
  maxWidth: Breakpoints.contentMaxWidth,
  child: YourWidget(),
)
```

### 4. ResponsivePadding
Automatically adjusts padding based on screen size:

```dart
ResponsivePadding(
  mobile: 16.0,
  tablet: 24.0,
  desktop: 32.0,
  child: YourContent(),
)
```

### 5. ResponsiveGrid
Creates a responsive grid that adapts columns:

```dart
ResponsiveGrid(
  mobileColumns: 1,
  tabletColumns: 2,
  desktopColumns: 3,
  spacing: 16.0,
  children: [
    Card1(),
    Card2(),
    Card3(),
  ],
)
```

### 6. ResponsiveRowColumn
Switches between Row and Column layouts:

```dart
ResponsiveRowColumn(
  breakpoint: Breakpoints.tablet,
  spacing: 16.0,
  children: [
    Widget1(),
    Widget2(),
  ],
)
```

## Responsive Helpers

The `responsive_helpers.dart` file provides extension methods and utility widgets:

### Context Extensions

```dart
// Check device type
if (context.isMobile) { /* mobile-specific code */ }
if (context.isTablet) { /* tablet-specific code */ }
if (context.isDesktop) { /* desktop-specific code */ }

// Get responsive values
final padding = context.responsivePadding; // 16, 24, or 32
final spacing = context.responsiveSpacing; // 12, 16, or 20

// Get screen dimensions
final width = context.screenWidth;
final height = context.screenHeight;

// Get responsive value
final columns = context.responsiveValue(
  mobile: 1,
  tablet: 2,
  desktop: 3,
);
```

### Responsive Widgets

#### ResponsiveText
```dart
ResponsiveText(
  'Hello World',
  mobileFontSize: 14,
  tabletFontSize: 16,
  desktopFontSize: 18,
  style: TextStyle(fontWeight: FontWeight.bold),
)
```

#### ResponsiveBuilder
```dart
ResponsiveBuilder(
  mobile: (context) => MobileLayout(),
  tablet: (context) => TabletLayout(),
  desktop: (context) => DesktopLayout(),
)
```

#### ResponsiveCard
```dart
ResponsiveCard(
  mobilePadding: EdgeInsets.all(12),
  tabletPadding: EdgeInsets.all(16),
  desktopPadding: EdgeInsets.all(20),
  child: YourContent(),
)
```

## Typography

The theme uses responsive typography with improved line heights:

- **Headlines**: Poppins font, sizes 22-28px, line height 1.2
- **Titles**: Poppins font, sizes 14-22px, line height 1.2-1.3
- **Body**: Inter font, sizes 12-15px, line height 1.5
- **Labels**: Inter/Poppins font, sizes 11-15px, line height 1.2

All text automatically scales based on the device's text scaling settings.

## Touch Targets

All interactive elements meet WCAG AA guidelines:

- **Minimum touch target**: 48x48 dp (increased from 44x44)
- **Button minimum size**: 64x48 dp
- **Icon buttons**: 48x48 dp with adequate padding
- **Tap target padding**: MaterialTapTargetSize.padded

## Web-Specific Optimizations

### Viewport Configuration
```html
<meta name="viewport" content="width=device-width, initial-scale=1.0, 
      minimum-scale=1.0, maximum-scale=5.0, viewport-fit=cover, user-scalable=yes">
```

### CSS Improvements
- Responsive font sizing with `clamp()`
- Smooth scrolling (respects reduced motion)
- Better tap highlight colors
- Prevent text size adjustment on orientation change
- Accessible focus styles

### Loading Screen
The splash screen is fully responsive using CSS:

```css
#splash img { 
  width: clamp(72px, 15vw, 96px); 
  height: clamp(72px, 15vw, 96px); 
}

#splash .name { 
  font-size: clamp(16px, 4vw, 20px); 
}
```

## Layout Patterns

### 1. Single Column (Mobile)
Used for phones and narrow screens:
- Stack all content vertically
- Full-width cards and buttons
- Adequate spacing between elements

### 2. Two Column (Tablet)
Used for tablets (768px - 1200px):
- Side-by-side layouts where appropriate
- Forms on left, results on right
- Grid layouts with 2 columns

### 3. Three Column (Desktop)
Used for desktop (1200px+):
- Maximum content area utilization
- Grid layouts with 3+ columns
- Centered content with max-width constraints

## Best Practices

1. **Always use LayoutBuilder** when making layout decisions based on available space
2. **Test on actual devices** - emulators don't always reflect real-world behavior
3. **Consider landscape orientation** - especially for tablets
4. **Use context extensions** instead of checking MediaQuery directly
5. **Maintain readability** - limit line length to ~70 characters
6. **Ensure touch targets** are at least 48x48 dp
7. **Test text scaling** - users may have large text settings
8. **Progressive enhancement** - mobile first, then enhance for larger screens

## Testing Checklist

- [ ] Mobile portrait (320px - 428px)
- [ ] Mobile landscape (568px - 896px)
- [ ] Tablet portrait (768px - 834px)
- [ ] Tablet landscape (1024px - 1366px)
- [ ] Desktop (1440px, 1920px, 2560px)
- [ ] Text scaling (100%, 150%, 200%)
- [ ] Browser zoom (100%, 150%, 200%)
- [ ] Touch interactions on mobile
- [ ] Keyboard navigation on desktop
- [ ] Screen readers (accessibility)

## Resources

- [Flutter Responsive Design](https://docs.flutter.dev/ui/layout/responsive)
- [Material Design Layout](https://m3.material.io/foundations/layout/understanding-layout/overview)
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [Web Content Accessibility](https://web.dev/accessible/)
