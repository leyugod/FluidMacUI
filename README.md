# FluidMacUI

> **A modern macOS 26+ SwiftUI design system and fluid interaction engine that unites Apple first-party macOS layout parity and native Liquid Glass optics with iOS physical spring choreography and full desktop productivity — with zero legacy AppKit visual chrome leaks.**

**Version:** `1.0.0` · **Platform:** `macOS 26.0+` · **Toolchain:** `Swift 6.2` (`.defaultIsolation(MainActor.self)`) · **Tests:** `63 tests` across `11 Swift Testing suites`

---

## Highlights

- **Apple First-Party macOS 26 Layout Parity**
  - Full-height sidebar (`FMSidebarSplitView`) naturally integrated with window traffic lights, built-in capsule search (`FMSidebarSearchField`), restrained SF Symbols styling, neutral selection pills, and pinned account footer (`FMSidebarAccountFooter`).
  - Floating circular Liquid Glass toolbar (`FMToolbarButton`, `FMToolbarGroup`, `FMFloatingHeaderBar`) aligned cleanly to the window chrome, paired with `.scrollEdgeEffectStyle(.soft, for: .top)` and editorial native canvas surfaces (`.nativeCanvas`) free of "card-inside-card" clutter.
  - Full desktop workspace primitives: resizable horizontal/vertical `FMSplitPane`, collapsible `FMInspectorSplitView`, Finder/Xcode-grade `FMOutlineTree`, bottom `FMStatusBar`, `⌘K` command palette (`.fmCommandPalette(...)`), multi-column sortable `FMDataTable`, and `FMCodeBlock`.
- **100% Pure-SwiftUI Controls — Zero Legacy AppKit Chrome**
  - Every control is built in pure SwiftUI with consistent tokens, hover depth, and continuous curvature: pure-SwiftUI `FMCalendarView`, `FMDatePicker`, `FMDateRangePicker`, `FMColorSwatches`, `FMColorPicker` (2D S/B canvas, Hue & Opacity sliders, live `#RRGGBB` input + copy), and `FMSpinner` — zero `NSDatePicker`, `NSColorWell`, `NSProgressIndicator`, or harsh default focus rectangles anywhere.
- **Native Liquid Glass & Concentric Curvature Engine**
  - Built for macOS 26 `.glassEffect()`, `GlassEffectContainer`, and `ConcentricRectangle`, with runtime switching to classic `.frosted` vibrancy and automatic opaque fallbacks under **Reduce Transparency**.
- **Four-Tier Physical Springs & Force Touch Haptics**
  - Calibrated `FMSpringLevel` choreography (`interactive`, `micro`, `navigation`, `modal`) honoring `accessibilityReduceMotion` and `FMTheme.animationSpeed`, paired with trackpad detents via `FMHaptics`.
- **Accessibility, Multi-Window Isolation & 0% Inactive-Window GPU**
  - Window-scoped `FMOverlayCoordinator` keeps Dynamic HUDs, Bottom Sheets, and Alerts strictly isolated per macOS window (`⌘N`).
  - Unified `.focusable()` → `.focused()` → `.focusEffectDisabled()` → `.fmFocusRing(...)` keyboard focus pipeline, complete VoiceOver labels/traits/adjustable actions, Reduce Motion & Reduce Transparency compliance, and `TimelineView(.animation(paused:))` pausing to guarantee **0% inactive-window GPU wakeups**.
- **Swift 6.2 Strict Concurrency**
  - Built with `swift-tools-version: 6.2`, `.defaultIsolation(MainActor.self)`, explicit `nonisolated` `Shape` geometry, and `isolated deinit` AppKit monitor cleanup — compiling with **0 warnings and 0 errors**.

---

## Quick Start

### Swift Package Manager

Add `FluidMacUI` to your `Package.swift`:

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MyMacApp",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/leyugod/FluidMacUI.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "MyMacApp",
            dependencies: ["FluidMacUI"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        )
    ]
)
```

### Minimal Example

```swift
import SwiftUI
import FluidMacUI

struct ContentView: View {
    @State private var selectedDate = Date()
    @State private var accent = FMColor.blue
    @State private var shortcut: FMKeyShortcut? = FMKeyShortcut(key: "K", modifiers: [.command])

    var body: some View {
        FMWindowContainer(backdrop: .nativeCanvas) {
            VStack(alignment: .leading, spacing: FMSpacing.md) {
                FMSectionHeader("Workspace Preferences")

                FMInsetGroup {
                    FMRow("Schedule", icon: "calendar") {
                        FMDatePicker(selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                    }
                    FMRow("Accent Color", icon: "paintpalette") {
                        FMColorSwatches(selection: $accent)
                    }
                    FMRow("Quick Open", icon: "command") {
                        FMShortcutRecorder(shortcut: $shortcut)
                    }
                }
            }
            .padding(FMSpacing.lg)
        }
        .fmTheme(FMTheme(accentColor: accent, surfaceStyle: .liquidGlass, cornerStyle: .concentric))
    }
}
```

---

## Complete v1.0.0 Component Catalog (10 Modules · 71 Source Files)

### `00_PlatformBridge` — AppKit & Trackpad Bridges
| File | Public Symbols |
| :--- | :--- |
| `FMHaptics.swift` | `FMHaptics`, `FMHapticPattern` |
| `FMTrackpadSwipeBridge.swift` | `FMTrackpadSwipeBridge` |
| `FMWindowAccessor.swift` | `FMWindowAccessor`, `FMWindowState`, `FMTitleBarDragArea` |

### `01_Foundation` — Theme, Material, Motion & Layout Tokens
| File | Public Symbols |
| :--- | :--- |
| `FMTheme.swift` | `FMTheme`, `FMColor`, `FMSurfaceStyle`, `FMCornerStyle`, `.fmTheme(_:)` |
| `FMSpacing.swift` | `FMSpacing`, `FMDensity`, `.fmDensity(_:)` |
| `FMTypography.swift` | `Font.fmLargeTitle`, `.fmTitle`, `.fmTitle2`, `.fmHeadline`, `.fmBody`, `.fmControl`, `.fmSubheadline`, `.fmFootnote`, `.fmCaption`, `.fmMono`, `.fmNumeric(size:weight:)` |
| `FMSpring.swift` | `FMSpring`, `FMSpringLevel`, `.fmAnimation(_:value:)` |
| `FMMaterialEngine.swift` | `FMCornerRadius`, `FMGlassRole`, `FMGlassSurfaceModifier`, `.fmGlassSurface(...)`, `.fmClipCorner(...)` |
| `FMInteractionEngine.swift` | `FMFocusRingModifier`, `FMHoverLiftModifier`, `.fmFocusRing(...)`, `.fmFocusClean()`, `.fmHoverLift(...)` |
| `FMGlassCard.swift` | `FMGlassCard`, `FMCardSurface` |
| `FMIconBadge.swift` | `FMIconBadge` |

### `02_Controls` — Pure-SwiftUI Interactive Controls
| File | Public Symbols |
| :--- | :--- |
| `FMButtonStyle.swift` | `FMButtonStyle`, `FMButtonVariant`, `FMButtonMetrics`, `.buttonStyle(.fm(...))` |
| `FMToggleStyle.swift` | `FMToggleStyle`, `.toggleStyle(.fm)` |
| `FMCheckboxStyle.swift` | `FMCheckboxStyle`, `.toggleStyle(.fmCheckbox)` |
| `FMSegmentedPicker.swift` | `FMSegmentedPicker` |
| `FMRadioGroup.swift` | `FMRadioGroup`, `FMRadioGroupStyle`, `FMRadioOption`, `FMRadioGroupMath` |
| `FMDropdownPicker.swift` | `FMDropdownPicker` |
| `FMComboBox.swift` | `FMComboBox`, `FMComboBoxMath` |
| `FMDateAndColorPickers.swift` | `FMCalendarView`, `FMDatePicker`, `FMDateRangePicker`, `FMCalendarDay`, `FMCalendarMath`, `FMColorPicker`, `FMColorPickerTriggerStyle`, `FMColorSwatches`, `FMRGBA`, `FMHSBA`, `FMColorMath` |
| `FMSlider.swift` | `FMSlider`, `FMSliderStyle`, `FMSliderMath` |
| `FMStepper.swift` | `FMStepper`, `FMStepperMath` |
| `FMTextField.swift` | `FMTextField`, `FMSecureField` |
| `FMFormattedFields.swift` | `FMNumberField`, `FMOTPField`, `FMFormattedFieldMath` |
| `FMTextEditor.swift` | `FMTextEditor` |
| `FMSearchBar.swift` | `FMSearchBar` |
| `FMShortcutRecorder.swift` | `FMShortcutRecorder`, `FMKeyShortcut`, `FMKeyModifiers`, `FMShortcutMath` |

### `03_Containers` — Structured Grouping & Surfaces
| File | Public Symbols |
| :--- | :--- |
| `FMInsetGroup.swift` | `FMInsetGroup` |
| `FMRow.swift` | `FMRow` |
| `FMExpandableGroup.swift` | `FMExpandableGroup` |
| `FMGridCard.swift` | `FMGridCard` |

### `04_Navigation` — Window, Sidebar, Stack, Split & Toolbar Chrome
| File | Public Symbols |
| :--- | :--- |
| `FMWindowContainer.swift` | `FMWindowContainer`, `FMWindowBackdrop`, `FMDynamicHUDHostView` |
| `FMNavigationStack.swift` | `FMNavigationStack`, `FMNavigationController`, `FMNavigationEntry`, `FMNavigationHeaderStyle`, `FMSwipeBackDisabledPreferenceKey` |
| `FMSidebarSplitView.swift` | `FMSidebarSplitView`, `FMSidebarSection`, `FMSidebarItem`, `FMSidebarIconStyle`, `FMSidebarSearchField`, `FMSidebarAccountFooter` |
| `FMSplitPane.swift` | `FMSplitPane`, `FMSplitPaneMath` |
| `FMInspectorSplitView.swift` | `FMInspectorSplitView` |
| `FMToolbar.swift` | `FMToolbarButton`, `FMToolbarGroup`, `FMFloatingHeaderBar` |
| `FMTabBar.swift` | `FMTabBar`, `FMTabItem` |

### `05_Feedback` — Window-Scoped Overlays, Popovers & Media Previews
| File | Public Symbols |
| :--- | :--- |
| `FMOverlayCoordinator.swift` | `FMOverlayCoordinator`, `FMHUDItem`, `FMHUDStyle`, `FMHUDAction`, `@Environment(\.fmHUD)` |
| `FMBottomSheet.swift` | `FMBottomSheetModifier`, `.fmBottomSheet(...)` |
| `FMAlert.swift` | `FMAlertModifier`, `FMAlertButton`, `FMAlertButtonRole`, `FMAlertShortcutResolver`, `.fmAlert(...)` |
| `FMActionPopover.swift` | `FMActionPopoverModifier`, `FMActionMenuItem`, `.fmActionPopover(...)` |
| `FMConfirmPopover.swift` | `FMConfirmPopoverModifier`, `.fmConfirmPopover(...)` |
| `FMInlineBanner.swift` | `FMInlineBanner`, `FMBannerTone` |
| `FMLightbox.swift` | `FMLightboxModifier`, `.fmLightbox(...)` |

### `06_DataDisplay` — Telemetry, Progress, Status & Loading States
| File | Public Symbols |
| :--- | :--- |
| `FMSpinner.swift` | `FMSpinner`, `FMSpinnerStyle`, `FMSpinnerSize` |
| `FMProgress.swift` | `FMProgressRing`, `FMProgressBar` |
| `FMCharts.swift` | `FMGauge`, `FMGaugeStyle`, `FMSparkline`, `FMChartMath` |
| `FMStepsIndicator.swift` | `FMStepsIndicator`, `FMStepItem`, `FMStepState`, `FMStepsMath` |
| `FMBadge.swift` | `FMBadge`, `FMBadgeStyle`, `FMTag` |
| `FMEmptyStateView.swift` | `FMEmptyStateView` |
| `FMSkeletonModifier.swift` | `FMSkeletonModifier`, `.fmSkeleton(...)` |

### `07_DesktopExtras` — Native macOS Status, Keycaps, Tooltips & Menu Bar
| File | Public Symbols |
| :--- | :--- |
| `FMStatusBar.swift` | `FMStatusBar`, `FMStatusBarItem`, `FMStatusBarDivider` |
| `FMTooltip.swift` | `FMKeycap`, `FMTooltipModifier`, `.fmTooltip(...)` |
| `FMMenuBarPanel.swift` | `FMMenuBarPanel` |

### `08_Editorial` — App Store & Editorial Layout Primitives
| File | Public Symbols |
| :--- | :--- |
| `FMHeroHeader.swift` | `FMHeroHeader` |
| `FMMetricStrip.swift` | `FMMetricStrip`, `FMMetricItem`, `FMMetricValue` |
| `FMSectionHeader.swift` | `FMSectionHeader`, `FMHairlineDivider` |
| `FMExpandableText.swift` | `FMExpandableText` |
| `FMHorizontalCarousel.swift` | `FMHorizontalCarousel` |
| `FMPageControl.swift` | `FMPageControl`, `FMOnboardingPager`, `FMOnboardingPage`, `FMPageControlMath` |
| `FMRatingView.swift` | `FMRatingView` |
| `FMAvatar.swift` | `FMAvatar`, `FMAvatarGroup` |

### `09_Productivity` — Power-User Desktop Workflows
| File | Public Symbols |
| :--- | :--- |
| `FMCommandPalette.swift` | `FMCommandPaletteModifier`, `FMCommandItem`, `FMCommandGroup`, `FMCommandMatcher`, `.fmCommandPalette(...)` |
| `FMOutlineTree.swift` | `FMOutlineTree`, `FMOutlineNode`, `FMFlattenedOutlineRow`, `FMOutlineTreeMath` |
| `FMDataTable.swift` | `FMDataTable`, `FMTableColumn`, `FMColumnWidth`, `FMSortDirection`, `FMTableSelectionMath` |
| `FMCodeBlock.swift` | `FMCodeBlock`, `FMCodeLanguage`, `FMCodeToken`, `FMCodeTokenKind`, `FMCodeTokenizer` |
| `FMBreadcrumbBar.swift` | `FMBreadcrumbBar`, `FMBreadcrumbItem` |
| `FMFilterChips.swift` | `FMFilterChips`, `FMTokenField`, `FMTokenMath` |
| `FMFileDropZone.swift` | `FMFileDropZone`, `FMFileDropValidator` |
| `FMSelectionActionBar.swift` | `FMSelectionActionBar` |

---

## Building, Testing & Running the Showcase

**Requirements:** macOS 26.0+ and Xcode / Swift 6.2+.

```bash
# Build library and FluidMacShowcase executable
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build

# Run all 63 Swift Testing unit tests across 11 suites
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test

# Launch the interactive FluidMacShowcase desktop app
# (App Store parity demo, Controls, Navigation, Feedback & Data, Productivity, ⌘K palette, ⌘N multi-window, live Lab Inspector)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run FluidMacShowcase
```

---

## Documentation & Release Notes

- Release Changelog: [CHANGELOG.md](CHANGELOG.md)
- Architecture & Design Blueprint: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- Native macOS Visual Parity Audit: [docs/NATIVE_PARITY_AUDIT.md](docs/NATIVE_PARITY_AUDIT.md)
- v1.0 Component Gap & Polish Audit: [docs/V1_GAP_AUDIT.md](docs/V1_GAP_AUDIT.md)
