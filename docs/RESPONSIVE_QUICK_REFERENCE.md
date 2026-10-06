# Responsive Design Quick Reference

Quick guide for developers working with responsive layouts in STW Neo.

## Import Statement

```dart
import 'package:neonatal_stw/core/widgets/responsive.dart';
import 'package:neonatal_stw/core/widgets/responsive_helpers.dart';
```

## Breakpoints (px)

| Name | Value | Use Case |
|------|-------|----------|
| `Breakpoints.mobile` | 320 | Base mobile |
| `Breakpoints.mobileLandscape` | 576 | Mobile landscape |
| `Breakpoints.tablet` | 768 | Tablet portrait |
| `Breakpoints.tabletLandscape` | 992 | Tablet landscape |
| `Breakpoints.desktop` | 1200 | Desktop |
| `Breakpoints.desktopLarge` | 1400 | Large desktop |

## Context Extensions

```dart
// Device type checks
context.isMobile          // < 768px
context.isTablet          // 768px - 1200px
context.isDesktop         // >= 1200px

// Get responsive values
context.responsivePadding // 16/24/32
context.responsiveSpacing // 12/16/20

// Screen dimensions
context.screenWidth
context.screenHeight

// Custom responsive values
final fontSize = context.responsiveValue(
  mobile: 14.0,
  tablet: 16.0,
  desktop: 18.0,
);
```

## Common Patterns

### 1. Responsive Padding

```dart
// Method 1: Using ResponsivePadding widget
ResponsivePadding(
  mobile: 16.0,
  tablet: 24.0,
  desktop: 32.0,
  child: MyContent(),
)

// Method 2: Using context extension
Padding(
  padding: EdgeInsets.all(context.responsivePadding),
  child: MyContent(),
)
```

### 2. Responsive Layout

```dart
// Switch between layouts
ResponsiveBuilder(
  mobile: (context) => SingleColumnLayout(),
  tablet: (context) => TwoColumnLayout(),
  desktop: (context) => ThreeColumnLayout(),
)
```

### 3. Responsive Grid

```dart
ResponsiveGrid(
  mobileColumns: 1,
  tabletColumns: 2,
  desktopColumns: 3,
  spacing: 16.0,
  children: items.map((item) => ItemCard(item)).toList(),
)
```

### 4. Row/Column Switch

```dart
ResponsiveRowColumn(
  breakpoint: Breakpoints.tablet,
  spacing: 16.0,
  children: [
    FilterButton(),
    SearchBar(),
    SortButton(),
  ],
)
```

### 5. Responsive Text

```dart
ResponsiveText(
  'Clinical Assessment',
  mobileFontSize: 20,
  tabletFontSize: 24,
  desktopFontSize: 28,
  style: TextStyle(fontWeight: FontWeight.bold),
)
```

### 6. Conditional Rendering

```dart
// Show/hide based on screen size
if (context.isDesktop) 
  SidePanel(),

// Different content for different sizes
context.isMobile
  ? MobileBottomSheet()
  : DesktopDialog(),
```

### 7. Phone-Proportioned Screen

```dart
// For landing/home screens
Scaffold(
  body: SafeArea(
    child: PhoneColumn(
      child: YourContent(),
    ),
  ),
)
```

### 8. Content Max Width

```dart
// For forms and lists
Align(
  alignment: Alignment.topCenter,
  child: ConstrainedBox(
    constraints: BoxConstraints(maxWidth: Breakpoints.contentMaxWidth),
    child: YourForm(),
  ),
)

// Or use MaxWidth widget
MaxWidth(
  maxWidth: Breakpoints.contentMaxWidth,
  child: YourForm(),
)
```

### 9. Responsive Card

```dart
ResponsiveCard(
  mobilePadding: EdgeInsets.all(12),
  tabletPadding: EdgeInsets.all(16),
  desktopPadding: EdgeInsets.all(20),
  child: CardContent(),
)
```

### 10. Layout Builder Pattern

```dart
LayoutBuilder(
  builder: (context, constraints) {
    final isMobile = constraints.maxWidth < Breakpoints.tablet;
    
    return Column(
      children: [
        if (isMobile)
          MobileHeader()
        else
          DesktopHeader(),
        // ...
      ],
    );
  },
)
```

## Button Sizing

```dart
// Minimum touch target: 48x48 dp
FilledButton(
  style: FilledButton.styleFrom(
    minimumSize: Size(64, 48), // Width, Height
  ),
  onPressed: () {},
  child: Text('Action'),
)
```

## Common Sizes

```dart
// Responsive padding
EdgeInsets.all(context.responsivePadding)

// Responsive spacing
SizedBox(height: context.responsiveSpacing)

// Card padding by device
context.isMobile ? 12.0 : 16.0

// Icon sizes
context.isMobile ? 20.0 : 24.0

// Border radius
context.isMobile ? 12.0 : 16.0
```

## Accessibility

```dart
// Always use semantic widgets
Semantics(
  button: true,
  label: 'Start Assessment',
  child: YourButton(),
)

// Minimum touch target
MaterialTapTargetSize.padded // 48x48 dp

// Text contrast
// Ensure >= 4.5:1 for normal text
// Ensure >= 3:1 for large text (18pt+)
```

## Testing

```dart
// Test responsive behavior
testWidgets('adapts to mobile', (tester) async {
  await tester.binding.setSurfaceSize(Size(375, 667));
  await tester.pumpWidget(MyApp());
  expect(find.byType(MobileLayout), findsOneWidget);
});

testWidgets('adapts to tablet', (tester) async {
  await tester.binding.setSurfaceSize(Size(768, 1024));
  await tester.pumpWidget(MyApp());
  expect(find.byType(TabletLayout), findsOneWidget);
});
```

## Common Mistakes to Avoid

❌ **DON'T** hardcode sizes everywhere
```dart
Container(
  width: 300,
  height: 200,
  // Fixed sizes don't adapt
)
```

✅ **DO** use responsive values
```dart
Container(
  width: context.screenWidth * 0.8,
  constraints: BoxConstraints(maxWidth: 400),
)
```

❌ **DON'T** ignore safe areas
```dart
Scaffold(
  body: Column(...) // May be hidden by notch
)
```

✅ **DO** wrap with SafeArea
```dart
Scaffold(
  body: SafeArea(
    child: Column(...) // Respects device notches
  ),
)
```

❌ **DON'T** make tiny touch targets
```dart
IconButton(
  iconSize: 16, // Too small!
  onPressed: () {},
)
```

✅ **DO** meet minimum 48x48 dp
```dart
IconButton(
  iconSize: 24,
  padding: EdgeInsets.all(12),
  constraints: BoxConstraints.tightFor(width: 48, height: 48),
  onPressed: () {},
)
```

## Performance Tips

1. **Use `const` constructors** where possible
2. **Avoid rebuilding** unnecessarily - use `LayoutBuilder` at the right level
3. **Cache expensive calculations** from MediaQuery
4. **Optimize images** for different screen densities
5. **Use `RepaintBoundary`** for complex animations

## Resources

- Full Guide: [RESPONSIVE_DESIGN.md](RESPONSIVE_DESIGN.md)
- Testing Guide: [RESPONSIVE_TESTING.md](RESPONSIVE_TESTING.md)
- Flutter Docs: https://docs.flutter.dev/ui/layout/responsive
- Material 3: https://m3.material.io/foundations/layout
