# Responsive Testing Guide

This document provides a comprehensive testing guide for the responsive design implementation in STW Neo.

## Quick Test Checklist

### Browser Testing

#### Desktop Browsers
- [ ] Chrome (Windows/Mac/Linux) - 1920x1080, 1366x768, 2560x1440
- [ ] Firefox (Windows/Mac/Linux) - 1920x1080, 1366x768
- [ ] Safari (Mac) - 1920x1080, 1440x900
- [ ] Edge (Windows) - 1920x1080, 1366x768

#### Mobile Browsers
- [ ] Chrome Mobile (Android) - Various devices
- [ ] Safari Mobile (iOS) - iPhone SE, iPhone 12/13/14, iPad
- [ ] Firefox Mobile (Android)
- [ ] Samsung Internet (Android)

### Device Testing

#### Mobile Phones (Portrait & Landscape)
- [ ] iPhone SE (375x667) - Smallest common iOS device
- [ ] iPhone 12/13/14 (390x844)
- [ ] iPhone 14 Pro Max (430x932)
- [ ] Samsung Galaxy S20/S21 (360x800, 412x915)
- [ ] Google Pixel 5/6 (393x851, 412x915)

#### Tablets (Portrait & Landscape)
- [ ] iPad Mini (768x1024)
- [ ] iPad Air (820x1180)
- [ ] iPad Pro 11" (834x1194)
- [ ] iPad Pro 12.9" (1024x1366)
- [ ] Samsung Galaxy Tab (800x1280)

#### Desktop/Laptop
- [ ] 1366x768 (Common laptop)
- [ ] 1440x900 (MacBook)
- [ ] 1920x1080 (Full HD)
- [ ] 2560x1440 (2K)
- [ ] 3840x2160 (4K)

### Screen Orientation
- [ ] Portrait mode on all devices
- [ ] Landscape mode on all devices
- [ ] Rotation handling (no layout breaks)

## Detailed Testing Scenarios

### 1. Landing Screen (`/`)

#### Mobile (320px - 768px)
- [ ] Logo and branding render correctly
- [ ] Partner logos are visible and properly sized
- [ ] Text is readable without zooming
- [ ] "Continue" button is easily tappable (48x48 dp minimum)
- [ ] No horizontal scrolling
- [ ] Content fits within viewport
- [ ] Safe area insets respected (notches, home indicators)

#### Tablet (768px - 1200px)
- [ ] Centered layout with appropriate margins
- [ ] Logos scale appropriately
- [ ] Text remains comfortable to read
- [ ] Button maintains proper sizing

#### Desktop (1200px+)
- [ ] Content centered with max-width constraint (1024px)
- [ ] Background styling visible on sides
- [ ] All elements properly aligned

### 2. Home Screen (`/home`)

#### Mobile
- [ ] Hero section with image displays correctly
- [ ] Text overlays are readable
- [ ] Module cards stack vertically
- [ ] "Get Started" buttons are easily tappable
- [ ] Footer links are accessible
- [ ] Feature row adapts or hides on small screens

#### Tablet
- [ ] Hero image scales appropriately
- [ ] Cards have adequate spacing
- [ ] Feature row displays if space allows
- [ ] Two-column layouts where appropriate

#### Desktop
- [ ] Maximum width constraint applied
- [ ] Hero section balanced
- [ ] Feature row displays prominently
- [ ] Hover states work on interactive elements

### 3. Condition Selection (`/conditions`)

#### Mobile
- [ ] Available conditions display as list
- [ ] Checkboxes are easily selectable (48x48 dp)
- [ ] Pending conditions show in 2-column grid
- [ ] Bottom action bar is fixed and accessible
- [ ] Scrolling works smoothly

#### Tablet
- [ ] Pending conditions show in 3-column grid
- [ ] More whitespace and padding
- [ ] Action bar centered with max-width

#### Desktop
- [ ] Content constrained to 820px
- [ ] 3+ column grid for pending conditions
- [ ] Hover states on condition tiles

### 4. Clinical Workflow (`/workflow`)

#### Mobile
- [ ] Questions display in single column
- [ ] Input fields are appropriately sized
- [ ] Progress bar is visible
- [ ] "Back" and "Continue" buttons accessible
- [ ] Findings sheet opens as bottom sheet
- [ ] Summary is scrollable

#### Tablet
- [ ] Form fields have comfortable width
- [ ] Multi-column layouts for options where appropriate
- [ ] Better use of horizontal space

#### Desktop
- [ ] Split-screen: form on left, results on right (if implemented)
- [ ] Or single column with comfortable max-width
- [ ] Keyboard navigation works smoothly

### 5. RD/ROP Screens

#### Mobile
- [ ] SAS calculator images render correctly
- [ ] Grading controls are usable
- [ ] Results cards are readable
- [ ] Action buttons accessible

#### Tablet
- [ ] Better spacing for clinical inputs
- [ ] Images display larger if appropriate
- [ ] Results have more breathing room

#### Desktop
- [ ] Content appropriately sized
- [ ] No wasted whitespace
- [ ] Images and diagrams clear

### 6. PDF Viewer

#### All Devices
- [ ] PDF loads and renders
- [ ] Zoom controls work
- [ ] Scrolling is smooth
- [ ] Navigation buttons accessible
- [ ] Full-screen mode available (if applicable)

### 7. References Screen

#### Mobile
- [ ] Cards stack vertically
- [ ] Links are easily tappable
- [ ] Icons and text aligned properly

#### Tablet/Desktop
- [ ] Cards display in grid if appropriate
- [ ] Better use of space
- [ ] Hover states on interactive elements

## Text Scaling Tests

Test with system text scaling at:
- [ ] 100% (default)
- [ ] 125%
- [ ] 150%
- [ ] 175%
- [ ] 200%

Verify:
- [ ] No text overflow or truncation
- [ ] Buttons remain usable
- [ ] Layouts adapt gracefully
- [ ] Touch targets remain adequate

## Browser Zoom Tests

Test at zoom levels:
- [ ] 50%
- [ ] 75%
- [ ] 100%
- [ ] 125%
- [ ] 150%
- [ ] 200%

Verify:
- [ ] Layout remains functional
- [ ] No horizontal scrolling at 100%
- [ ] Text remains readable
- [ ] Interactive elements accessible

## Touch & Interaction Tests

### Mobile/Tablet
- [ ] All buttons meet 48x48 dp minimum
- [ ] Touch targets have adequate spacing (8dp minimum)
- [ ] Swipe gestures work where implemented
- [ ] Pull-to-refresh disabled where inappropriate
- [ ] Long-press actions work if implemented
- [ ] Multi-touch zoom disabled on form inputs

### Desktop
- [ ] Hover states work on interactive elements
- [ ] Click targets are appropriate
- [ ] Keyboard navigation works
- [ ] Tab order is logical
- [ ] Enter key submits forms
- [ ] Escape key closes modals

## Accessibility Tests

### Keyboard Navigation
- [ ] Tab through all interactive elements
- [ ] Visible focus indicators
- [ ] Logical tab order
- [ ] Skip links available
- [ ] Modal traps focus correctly

### Screen Readers
- [ ] VoiceOver (iOS/Mac) compatibility
- [ ] TalkBack (Android) compatibility
- [ ] NVDA (Windows) compatibility
- [ ] Proper ARIA labels
- [ ] Semantic HTML structure
- [ ] Alt text for images

### Color & Contrast
- [ ] WCAG AA compliance (4.5:1 for text)
- [ ] High contrast mode support
- [ ] Color not sole indicator of meaning

### Motion & Animation
- [ ] Respects prefers-reduced-motion
- [ ] Animations can be disabled
- [ ] No autoplay videos
- [ ] No flashing content

## Performance Tests

### Mobile Networks
- [ ] 4G connection
- [ ] 3G connection
- [ ] Slow 3G connection
- [ ] Offline mode (if applicable)

### Metrics
- [ ] Time to First Contentful Paint < 2s
- [ ] Time to Interactive < 3.5s
- [ ] Total page weight < 2MB
- [ ] Images optimized
- [ ] Fonts load efficiently

## Edge Cases

### Extreme Dimensions
- [ ] Very narrow (320px width)
- [ ] Very wide (3840px width)
- [ ] Very short (480px height)
- [ ] Very tall (2000px+ height)

### Content
- [ ] Long text entries (wrapping, overflow)
- [ ] Empty states display correctly
- [ ] Error states are clear
- [ ] Loading states are visible

### Browser Features
- [ ] JavaScript disabled (graceful degradation)
- [ ] Cookies disabled
- [ ] Local storage unavailable
- [ ] Ad blockers active

## Automated Testing

### Visual Regression
```bash
# Run visual regression tests (if implemented)
flutter test --update-goldens
flutter test
```

### Layout Overflow
```bash
# Run layout overflow tests
flutter test test/layout_overflow_test.dart
```

### Widget Tests
```bash
# Run all widget tests
flutter test test/landing_page_test.dart
flutter test test/widget_smoke_test.dart
```

## Testing Tools

### Browser DevTools
- Chrome DevTools Device Mode
- Firefox Responsive Design Mode
- Safari Web Inspector

### Online Tools
- [BrowserStack](https://www.browserstack.com/) - Real device testing
- [Responsinator](http://www.responsinator.com/) - Quick responsive preview
- [Am I Responsive](https://ui.dev/amiresponsive) - Screenshot generator
- [Mobile-Friendly Test](https://search.google.com/test/mobile-friendly) - Google's tool

### Desktop Tools
- [Responsively App](https://responsively.app/) - Multi-device preview
- [Polypane](https://polypane.app/) - Professional testing browser

### Flutter Tools
```bash
# Run on specific device
flutter run -d chrome
flutter run -d edge
flutter run -d web-server

# Run with custom viewport
flutter run -d chrome --web-browser-flag="--window-size=375,667"
```

## Issue Reporting Template

When reporting responsive issues:

```markdown
**Device/Browser:** iPhone 12, Safari 15
**Screen Size:** 390x844, Portrait
**Breakpoint:** Mobile (< 768px)
**Location:** Home Screen, Hero Section

**Issue:**
Text overlaps image on iPhone 12 in portrait mode.

**Steps to Reproduce:**
1. Open app on iPhone 12
2. Navigate to Home screen
3. Observe hero section

**Expected:**
Text should be readable with proper contrast

**Actual:**
Text overlaps image and is hard to read

**Screenshot:** [attached]
```

## Continuous Testing

### During Development
- Test on at least 3 sizes: mobile, tablet, desktop
- Check both orientations
- Verify touch targets meet 48x48 dp minimum
- Test text scaling at 150%

### Before Release
- Complete full checklist
- Test on real devices
- Run automated tests
- Get user feedback
- Document any known issues

### After Release
- Monitor user reports
- Track analytics for device/browser usage
- Update tests for new devices
- Regular accessibility audits
