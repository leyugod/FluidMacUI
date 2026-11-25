# Changelog

All notable changes to **FluidMacUI** are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] — 2026-11-25

Initial public release of **FluidMacUI** (`Swift 6.2`, `macOS 26.0+`, `.defaultIsolation(MainActor.self)`), shipping **71 source files** across **10 modules**, an interactive **FluidMacShowcase** desktop app, and **63 Swift Testing unit tests** across **11 suites** with **0 compiler warnings**.

### Highlights & Architecture
- **Native macOS 26 Liquid Glass & Concentric Curvature**: Adaptive `FMGlassSurfaceModifier` (`.fmGlassSurface`) powered by macOS 26 `.glassEffect()`, `GlassEffectContainer`, and `ConcentricRectangle`, with seamless switching to classic `.frosted` vibrancy and automatic opaque fallbacks under `accessibilityReduceTransparency`.
- **100% Pure-SwiftUI Controls (Zero Legacy AppKit Visual Chrome)**: Replaced all remaining native AppKit visual chrome (`NSDatePicker`, `NSColorWell`, `NSProgressIndicator`, harsh system focus rectangles) with pure-SwiftUI FluidMacUI implementations across every module.
- **Four-Tier Spring Choreography & Trackpad Haptics**: Calibrated `FMSpringLevel` presets (`.interactive`, `.micro`, `.navigation`, `.modal`) honoring `accessibilityReduceMotion` and `FMTheme.animationSpeed`, paired with Force Touch `FMHaptics`.
- **Window-Scoped Overlay Isolation**: Per-window `FMOverlayCoordinator` guarantees HUD capsules, Bottom Sheets, Alerts, and Lightboxes stay isolated across multiple macOS windows (`⌘N`).
- **Swift 6.2 Strict Concurrency & 0% Inactive-Window GPU**: Explicit `nonisolated` `Shape` geometry, `isolated deinit` AppKit monitor cleanup, balanced `NSCursor.push()`/`pop()` tracking, and automatic animation pausing via `TimelineView(.animation(paused:))` when `controlActiveState == .inactive` or Reduce Motion is enabled.

### Full Module Inventory
- **`PlatformBridge`**: `FMHaptics`, `FMHapticPattern`, `FMTrackpadSwipeBridge`, `FMWindowAccessor`, `FMWindowState`, `FMTitleBarDragArea`.
- **`Foundation`**: `FMTheme`, `FMColor`, `FMSurfaceStyle`, `FMCornerStyle`, `FMSpacing`, `FMDensity`, `Font` semantic typography tokens (`FMTypography.swift`), `FMSpring`, `FMSpringLevel`, `FMCornerRadius`, `FMGlassRole`, `FMGlassSurfaceModifier`, `FMFocusRingModifier`, `FMHoverLiftModifier`, `FMGlassCard`, `FMCardSurface`, `FMIconBadge`.
- **`Controls`**:
  - Core controls: `FMButtonStyle` (with `.controlSize` scaling and pure-SwiftUI `FMSpinner` loading state), `FMToggleStyle`, `FMCheckboxStyle`, `FMSegmentedPicker`, `FMDropdownPicker`, `FMSlider`, `FMStepper`, `FMTextField`, `FMSecureField`, `FMTextEditor`, `FMSearchBar`.
  - Pure-SwiftUI Date & Color Pickers: `FMCalendarView`, `FMDatePicker`, `FMDateRangePicker`, `FMCalendarDay`, `FMCalendarMath`, `FMColorPicker`, `FMColorPickerTriggerStyle` (`.pill` / `.orb`), `FMColorSwatches` (exact-diameter rainbow orb + Color Studio popover with 2D S/B canvas, Hue & Opacity sliders, live `#RRGGBB` input + copy, presets & recent colors), `FMRGBA`, `FMHSBA`, `FMColorMath`.
  - New v1.0 Form & Shortcut Controls: `FMRadioGroup` (`.inline` / `.card`, `FMRadioOption`, `FMRadioGroupMath`), `FMComboBox` (single & multi-select searchable autocomplete with capsule chips and `FMComboBoxMath`), `FMNumberField` (prefix/suffix, `Shift` 10× arrow stepping), `FMOTPField` (segmented verification boxes with `⌘V` paste distribution & Reduce-Motion-safe error shake, `FMFormattedFieldMath`), and `FMShortcutRecorder` (`FMKeyShortcut`, `FMKeyModifiers`, `FMShortcutMath`, leak-proof `NSEvent` local monitor).
- **`Containers`**: `FMInsetGroup`, `FMRow`, `FMExpandableGroup`, `FMGridCard`.
- **`Navigation`**: `FMWindowContainer`, `FMWindowBackdrop`, `FMDynamicHUDHostView`, `FMNavigationStack` (per-level scroll offset tracking & `FMSwipeBackDisabledPreferenceKey`), `FMNavigationController`, `FMSidebarSplitView`, `FMSidebarSearchField`, `FMSidebarAccountFooter`, `FMSplitPane` (`FMSplitPaneMath`, balanced cursor push/pop, double-click reset), `FMInspectorSplitView`, `FMToolbarButton`, `FMToolbarGroup`, `FMFloatingHeaderBar`, `FMTabBar`.
- **`Feedback`**: `FMOverlayCoordinator`, `FMHUDItem`, `FMHUDStyle`, `FMHUDAction`, `FMBottomSheetModifier`, `FMAlertModifier` (`FMAlertShortcutResolver` preventing accidental destructive Enter submission), `FMActionPopoverModifier`, `FMConfirmPopoverModifier`, `FMInlineBanner`, `FMLightboxModifier` (Light/Dark + Reduce Transparency adaptive chrome).
- **`DataDisplay`**: `FMSpinner` (`.ring` / `.petals`, `.small` / `.regular` / `.large`), `FMProgressRing`, `FMProgressBar`, `FMGauge` (`.arc`, `.ring`, `.linearCapacity`), `FMSparkline` (smooth spline + hover scrub), `FMChartMath`, `FMStepsIndicator` (`FMStepItem`, `FMStepState`, `FMStepsMath`), `FMBadge`, `FMTag`, `FMEmptyStateView`, `FMSkeletonModifier` (VoiceOver-safe loading overlay).
- **`DesktopExtras`**: `FMStatusBar`, `FMStatusBarItem`, `FMStatusBarDivider`, `FMKeycap`, `FMTooltipModifier`, `FMMenuBarPanel`.
- **`Editorial`**: `FMHeroHeader`, `FMMetricStrip`, `FMSectionHeader`, `FMHairlineDivider`, `FMExpandableText`, `FMHorizontalCarousel`, `FMPageControl`, `FMOnboardingPager`, `FMOnboardingPage`, `FMPageControlMath`, `FMRatingView`, `FMAvatar`, `FMAvatarGroup`.
- **`Productivity`**: `FMCommandPaletteModifier` (grouped sections + `ScrollViewReader` keyboard tracking), `FMOutlineTree` (`FMOutlineNode`, `FMFlattenedOutlineRow`, `FMOutlineTreeMath`), `FMDataTable` (`FMTableSelectionMath`), `FMCodeBlock` (`FMCodeLanguage`, `FMCodeTokenizer`, one-click copy + syntax tinting), `FMBreadcrumbBar`, `FMFilterChips`, `FMTokenField`, `FMFileDropZone` (non-blocking `NSOpenPanel.begin` + `FMFileDropValidator` `UTType` filtering), `FMSelectionActionBar`.

### Accessibility, Performance & Quality Guarantees
- Consistent `.focusable()` → `.focused()` → `.focusEffectDisabled()` → `.fmFocusRing(...)` keyboard focus chain across interactive controls.
- Full VoiceOver labels, `.isSelected` traits, `.accessibilityAdjustableAction` support, and unobstructed action/dismiss controls in Dynamic HUD capsules.
- Reduce Motion disables spatial shake/slide/scale animations and pauses indeterminate progress/spinner/skeleton motion; Reduce Transparency switches translucent surfaces to high-contrast opaque fills.
- All indeterminate animations (`FMSpinner`, `FMProgressRing`, `FMProgressBar`, `FMSkeletonModifier`) pause cleanly when the window becomes inactive.

### Test Suite Coverage (`63 tests` across `11 suites`)
- `FluidMacUI Smoke Tests` (`SmokeTests.swift`)
- `Theme, Density & Spring Engine Tests` (`ThemeAndDensityTests.swift`)
- `Control Logic & Math Tests` (`ControlLogicTests.swift`)
- `Calendar & Color Picker Math Tests` (`PickersLogicTests.swift`)
- `Controls v1.0 Logic & Formatting Tests` (`ControlsV1Tests.swift`)
- `Layout & Navigation v1.0 Tests` (`LayoutV1Tests.swift`)
- `Data Display & Code v1.0 Logic Tests` (`DataV1Tests.swift`)
- `Navigation Stack State Machine Tests` (`NavigationStackStateTests.swift`)
- `Window-Scoped Overlay Coordinator Tests` (`OverlayCoordinatorTests.swift`)
- `Productivity & Editorial Logic Tests` (`ProductivityTests.swift`)
- `Batch D Polish Regression Tests` (`PolishRegressionTests.swift`)
