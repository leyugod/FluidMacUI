# FluidMacUI v1.0 Component Gap Audit & Codebase Polish Report

> **Audit Scope**: Full read-only inspection of `Sources/FluidMacUI/` (all 10 modules, 59 Swift files), `Examples/FluidMacShowcase/` (7 files), and `Tests/FluidMacUITests/` (6 test suites).  
> **Target Platform**: Swift 6.2 (`.defaultIsolation(MainActor.self)`), `macOS 26.0+`, native Liquid Glass + iOS fluid spring physics + Apple first-party macOS layout parity.  
> **In-Flight Note**: `Sources/FluidMacUI/02_Controls/FMDateAndColorPickers.swift` and `Tests/FluidMacUITests/PickersLogicTests.swift` are currently being upgraded by `pickers` to 100% pure SwiftUI (`FMCalendarView`, `FMDatePicker`, `FMDateRangePicker`, `FMColorSwatches`, `FMColorPicker`, `FMCalendarMath`, `FMColorMath`) and are excluded from all proposed batches below to prevent collisions.

---

## 1. Current Inventory Summary

FluidMacUI currently ships **59 source files** across 10 modules, **6 Showcase demo pages**, and **6 unit test suites**:

| Module | Files | Public Components / Engines | Showcase Coverage | Unit Test Coverage |
| :--- | :---: | :--- | :--- | :--- |
| **Root** | 1 | `FluidMacUI.version` | `ShowcaseApp` | `SmokeTests` |
| **`00_PlatformBridge`** | 3 | `FMHaptics`, `FMTrackpadSwipeBridge`, `FMWindowAccessor`, `FMWindowState`, `FMTitleBarDragArea` | Indirect via `FMWindowContainer` & `FMNavigationStack` | — |
| **`01_Foundation`** | 8 | `FMTheme`, `FMColor`, `FMTypography`, `FMSpacing`, `FMDensity`, `FMSpring`, `FMMaterialEngine` (`FMGlassSurfaceModifier`), `FMInteractionEngine` (`FMFocusRingModifier`, `FMHoverLiftModifier`), `FMIconBadge`, `FMGlassCard` | `FoundationPage` + `LabInspectorPanel` | `ThemeAndDensityTests` |
| **`02_Controls`** | 11 | `FMButtonStyle`, `FMToggleStyle`, `FMCheckboxStyle`, `FMSegmentedPicker`, `FMSlider`, `FMStepper`, `FMTextField`, `FMSecureField`, `FMTextEditor`, `FMSearchBar`, `FMDropdownPicker`, `FMDatePicker` / `FMColorSwatches` *(upgrading in-flight)* | `ControlsPage` + `ProductivityPage` | `ControlLogicTests` + `PickersLogicTests` *(in-flight)* |
| **`03_Containers`** | 4 | `FMInsetGroup`, `FMRow`, `FMExpandableGroup`, `FMGridCard` | `ContainersAndNavPage` + `ControlsPage` | — |
| **`04_Navigation`** | 6 | `FMWindowContainer`, `FMDynamicHUDHostView`, `FMNavigationStack`, `FMNavigationController`, `FMSidebarSplitView`, `FMSidebarSearchField`, `FMSidebarAccountFooter`, `FMTabBar`, `FMToolbarButton`, `FMToolbarGroup`, `FMFloatingHeaderBar`, `FMInspectorSplitView` | All 6 pages + `ShowcaseApp` | `NavigationStackStateTests` |
| **`05_Feedback`** | 7 | `FMOverlayCoordinator`, `FMBottomSheet`, `FMAlert`, `FMActionPopover`, `FMConfirmPopover`, `FMInlineBanner`, `FMLightbox` | `FeedbackAndDataPage`, `AppStoreDemoPage`, `ProductivityPage` | `OverlayCoordinatorTests` |
| **`06_DataDisplay`** | 4 | `FMProgressRing`, `FMProgressBar`, `FMBadge` / `FMTag`, `FMEmptyStateView`, `FMSkeletonModifier` | `FeedbackAndDataPage` | — |
| **`07_DesktopExtras`** | 2 | `FMTooltip`, `FMKeycap`, `FMMenuBarPanel` | `ShowcaseApp` (`MenuBarExtra`) + tooltips | — |
| **`08_Editorial`** | 7 | `FMHeroHeader`, `FMMetricStrip`, `FMSectionHeader`, `FMHairlineDivider`, `FMExpandableText`, `FMHorizontalCarousel`, `FMRatingView`, `FMAvatar`, `FMAvatarGroup` | `AppStoreDemoPage` + `FoundationPage` | — |
| **`09_Productivity`** | 6 | `FMCommandPalette`, `FMDataTable`, `FMBreadcrumbBar`, `FMFilterChips`, `FMTokenField`, `FMFileDropZone`, `FMSelectionActionBar` | `ProductivityPage` + `ShowcaseApp` | `ProductivityTests` |

### High-Level Assessment
- **Strengths**: Clean module layering, strong Apple macOS 26 aesthetic parity (`AppStoreDemoPage`), genuine window-scoped `FMOverlayCoordinator`, smooth `FMNavigationStack` parallax, and Swift 6.2 MainActor isolation.
- **Key v1.0 Gaps**:
  1. **Missing 12 foundational desktop/iOS SwiftUI components** required by real macOS apps (Finder/Xcode outline trees, general split panes, shortcut recorders, bottom status bars, searchable multi-select comboboxes, radio groups, numeric/OTP inputs, gauges & sparklines, multi-step wizards, pill page controls, code/log viewers, and a pure-SwiftUI spinner).
  2. **Residual AppKit & quality defects** across existing modules: 2 remaining AppKit `ProgressView` leaks (`FMButtonStyle`, `FMDynamicHUDCapsule`), a broken `.fmSwipeBackDisabled()` data flow in `FMHorizontalCarousel`, a critical `FMSkeletonModifier` VoiceOver label wipe bug, a Light Mode + Reduce Transparency invisible-text contrast bug in `FMLightbox`, an unbalanced `NSCursor.push/pop` in `FMInspectorSplitView`, dead `.controlSize(.small)` modifiers, `FMNavigationStack` shared `scrollOffset` + sudden layout jump at offset 42, widespread missing keyboard focus rings/accessibility labels, and inconsistent hardcoded Chinese vs. English UI strings.

---

## 2. Prioritized Missing Components for v1.0 (12 Components in 3 Disjoint Author Batches)

Filtered ruthlessly against Apple's first-party macOS apps (Finder, Xcode, System Settings, Activity Monitor, Mail, Notes, Photos, App Store) and modern iOS/macOS SwiftUI workflows, the **12 highest-value missing components** are grouped into **3 strictly non-overlapping file batches** for parallel implementation.

> **Collision Guarantee**: Batches A, B, C, `pickers`, and Batch D (Polish) touch **zero overlapping files**. Every new component must follow FluidMacUI conventions (`FMTheme`, `FMDensity`, `FMSpring` respecting `reduceMotion`, `FMColor.adaptiveAccent`, `accessibilityReduceTransparency`, keyboard navigation + `.fmFocusRing`, full DocC comments, English default labels with customizable strings, and pure testable `*Math` / model structs).

---

### Batch A — Form, Input & Shortcut Controls (`controls-v1`)
**Owned files (5 new source files + 1 test file)**:
- `Sources/FluidMacUI/06_DataDisplay/FMSpinner.swift`
- `Sources/FluidMacUI/02_Controls/FMRadioGroup.swift`
- `Sources/FluidMacUI/02_Controls/FMComboBox.swift`
- `Sources/FluidMacUI/02_Controls/FMFormattedFields.swift`
- `Sources/FluidMacUI/02_Controls/FMShortcutRecorder.swift`
- `Tests/FluidMacUITests/ControlsV1Tests.swift`

#### A1. `FMSpinner` — Pure-SwiftUI Activity Indicator (`06_DataDisplay/FMSpinner.swift`)
- **Why v1.0 needs it**: Replaces AppKit's dated `NSProgressIndicator` (`ProgressView().controlSize(.small)`) currently leaking inside `FMButtonStyle` and `FMDynamicHUDCapsule`, and gives apps a crisp fluid spinner.
- **Proposed API**:
  ```swift
  public enum FMSpinnerStyle: Sendable, Hashable { case ring, petals }
  public enum FMSpinnerSize: Sendable, Hashable { case small, regular, large } // 14pt, 20pt, 32pt
  public struct FMSpinner: View {
      public init(style: FMSpinnerStyle = .ring, size: FMSpinnerSize = .regular, tint: Color? = nil)
  }
  ```
- **Key behavior**: Pure SwiftUI `TimelineView` / continuous stroke or 8-petal fade; automatically freezes to calm static state when `accessibilityReduceMotion` is true or `controlActiveState == .inactive` (0% inactive GPU).

#### A2. `FMRadioGroup` — Inline & Card Exclusive Choice Control (`02_Controls/FMRadioGroup.swift`)
- **Why v1.0 needs it**: `FMSegmentedPicker` breaks past 3–4 items or when options require descriptions/icons; System Settings, installers, and export dialogs rely heavily on inline & selectable-card radio groups.
- **Proposed API**:
  ```swift
  public enum FMRadioGroupStyle: Sendable, Hashable { case inline, card }
  public struct FMRadioOption<Value: Hashable>: Identifiable {
      public let id: Value
      public let title: String
      public let subtitle: String?
      public let icon: String?
  }
  public struct FMRadioGroup<Value: Hashable>: View {
      public init(
          selection: Binding<Value>,
          options: [FMRadioOption<Value>],
          style: FMRadioGroupStyle = .inline,
          axis: Axis = .vertical
      )
  }
  ```
- **Key behavior**: Spring concentric radio dot pop (`FMSpring.micro`), continuous-curvature card highlight with accent border in `.card` mode, `↑`/`↓` (or `←`/`→`) keyboard navigation, `.fmFocusRing`, `FMHaptics.perform(.alignment)`, VoiceOver `isSelected` trait.

#### A3. `FMComboBox` — Searchable Single & Multi-Select Autocomplete Picker (`02_Controls/FMComboBox.swift`)
- **Why v1.0 needs it**: Bridges the gap between static `FMDropdownPicker` (no search, single select only) and freeform `FMTokenField` (no constrained options). Essential for timezones, git branches, assignees, models, and tags.
- **Proposed API**:
  ```swift
  public enum FMComboBoxMath {
      /// Prefix matches first, then case-insensitive substring matches.
      public static func filter<T>(_ items: [T], query: String, label: (T) -> String) -> [T]
      public static func toggleSelection<T: Hashable>(_ item: T, in current: Set<T>, allowsMultiple: Bool) -> Set<T>
  }
  public struct FMComboBox<Option: Hashable>: View {
      // Single-select initializer
      public init(
          selection: Binding<Option?>,
          options: [Option],
          placeholder: String = "Select...",
          searchPlaceholder: String = "Filter options...",
          title: @escaping (Option) -> String,
          icon: ((Option) -> String?)? = nil
      )
      // Multi-select initializer
      public init(
          selection: Binding<Set<Option>>,
          options: [Option],
          placeholder: String = "Select items...",
          searchPlaceholder: String = "Filter options...",
          title: @escaping (Option) -> String,
          icon: ((Option) -> String?)? = nil
      )
  }
  ```
- **Key behavior**: Popover with embedded search bar, `ScrollView` capped at `maxHeight: 260`, `ScrollViewReader` + `↑`/`↓`/`↵`/`Esc` keyboard navigation, capsule chips inside trigger for multi-select, optional "Clear all".

#### A4. `FMNumberField` & `FMOTPField` — Formatted Numeric & Segmented Code Inputs (`02_Controls/FMFormattedFields.swift`)
- **Why v1.0 needs it**: Forms in macOS settings/finance/dev tools constantly need validated numeric/currency/port inputs with prefix/suffix and `↑`/`↓` stepping, plus modern 4–8 digit 2FA / license / PIN boxes.
- **Proposed API**:
  ```swift
  public enum FMFormattedFieldMath {
      public static func sanitizeNumeric(_ raw: String, allowsDecimal: Bool, allowsNegative: Bool) -> String
      public static func clamp(_ value: Double, to range: ClosedRange<Double>?) -> Double
      public static func distributeOTP(_ pasted: String, length: Int, alphanumeric: Bool) -> [String]
  }
  public struct FMNumberField: View {
      public init(
          _ placeholder: String = "0",
          value: Binding<Double>,
          range: ClosedRange<Double>? = nil,
          step: Double = 1,
          precision: Int = 0,
          prefix: String? = nil,
          suffix: String? = nil,
          showsStepperArrows: Bool = true
      )
  }
  public struct FMOTPField: View {
      public init(
          code: Binding<String>,
          length: Int = 6,
          alphanumeric: Bool = false,
          isError: Bool = false,
          onComplete: ((String) -> Void)? = nil
      )
  }
  ```
- **Key behavior**: `FMNumberField` supports `↑`/`↓` increment/decrement with `Shift` 10× multiplier, monospaced digits, live clamping on submit/blur; `FMOTPField` auto-advances across continuous-curvature boxes, supports `⌘V` full-code paste distribution, backspace retreat, and `Reduce Motion`-safe error shake.

#### A5. `FMShortcutRecorder` — Native macOS Keyboard Shortcut Capture (`02_Controls/FMShortcutRecorder.swift`)
- **Why v1.0 needs it**: Signature macOS utility control (System Settings, Raycast, Cleanshot, Xcode Key Bindings) that pairs directly with `FMKeycap` and `FMCommandPalette`.
- **Proposed API**:
  ```swift
  public struct FMKeyShortcut: Hashable, Sendable, Codable {
      public var key: String
      public var modifiers: FMKeyModifiers // OptionSet: command, option, control, shift
      public var keycapTokens: [String] // Canonical Apple order: ⌃ ⌥ ⇧ ⌘ + Key
      public var isValid: Bool // Requires ⌘/⌃/⌥ or function key (F1–F12)
      public init(key: String, modifiers: FMKeyModifiers)
  }
  public struct FMShortcutRecorder: View {
      public init(
          shortcut: Binding<FMKeyShortcut?>,
          placeholder: String = "Record Shortcut",
          validator: ((FMKeyShortcut) -> String?)? = nil
      )
  }
  ```
- **Key behavior**: Click to enter recording mode (pulsing accent border, local `NSEvent` `.keyDown` monitor cleanly installed/removed in `NSViewRepresentable` coordinator with `isolated deinit`), displays recorded combo using `FMKeycap`, `Esc` cancels recording, `Delete`/`⌫` clears shortcut, optional conflict message banner.

---

### Batch B — Desktop Layout, Hierarchy & Navigation Chrome (`layout-v1`)
**Owned files (4 new source files + 1 test file)**:
- `Sources/FluidMacUI/04_Navigation/FMSplitPane.swift`
- `Sources/FluidMacUI/09_Productivity/FMOutlineTree.swift`
- `Sources/FluidMacUI/07_DesktopExtras/FMStatusBar.swift`
- `Sources/FluidMacUI/08_Editorial/FMPageControl.swift`
- `Tests/FluidMacUITests/LayoutV1Tests.swift`

#### B1. `FMSplitPane` — General Resizable Horizontal & Vertical Split View (`04_Navigation/FMSplitPane.swift`)
- **Why v1.0 needs it**: `FMSidebarSplitView` and `FMInspectorSplitView` cover outer chrome, but apps need arbitrary horizontal/vertical resizable splits (Mail list + reader, Xcode editor + bottom console, Markdown editor + live preview).
- **Proposed API**:
  ```swift
  public enum FMSplitPaneMath {
      public static func clampPrimarySize(_ proposed: CGFloat, total: CGFloat, minPrimary: CGFloat, minSecondary: CGFloat) -> CGFloat
      public static func ratio(for primarySize: CGFloat, total: CGFloat) -> CGFloat
  }
  public struct FMSplitPane<Primary: View, Secondary: View>: View {
      public init(
          axis: Axis = .horizontal,
          fraction: Binding<CGFloat>? = nil,
          initialFraction: CGFloat = 0.5,
          minPrimary: CGFloat = 180,
          minSecondary: CGFloat = 180,
          resetFractionOnDoubleClick: CGFloat? = 0.5,
          @ViewBuilder primary: () -> Primary,
          @ViewBuilder secondary: () -> Secondary
      )
  }
  ```
- **Key behavior**: Crisp `0.5pt` hairline divider expanding subtly to accent highlight on hover/drag, `NSCursor.resizeLeftRight` / `.resizeUpDown` with leak-proof tracked push/pop + `.onDisappear` cleanup, double-click divider snaps smoothly to reset fraction with `FMHaptics.perform(.alignment)`.

#### B2. `FMOutlineTree` — Finder / Xcode Hierarchical Outline Browser (`09_Productivity/FMOutlineTree.swift`)
- **Why v1.0 needs it**: One of the single most ubiquitous macOS UI patterns (Finder List View, Xcode Project Navigator, Notes Folders, JSON/DOM Inspectors) and completely missing today.
- **Proposed API**:
  ```swift
  public struct FMOutlineNode<ID: Hashable & Sendable>: Identifiable {
      public let id: ID
      public let title: String
      public let subtitle: String?
      public let icon: String?
      public let iconColor: Color?
      public let badge: String?
      public let children: [FMOutlineNode<ID>]? // nil = leaf, [] = empty folder
  }
  public struct FMFlattenedOutlineRow<ID: Hashable & Sendable>: Identifiable {
      public let id: ID
      public let node: FMOutlineNode<ID>
      public let depth: Int
      public let isExpandable: Bool
      public let isExpanded: Bool
      public let parentID: ID?
  }
  public enum FMOutlineTreeMath {
      public static func flatten<ID>(_ roots: [FMOutlineNode<ID>], expanded: Set<ID>) -> [FMFlattenedOutlineRow<ID>]
      public static func nextSelection<ID>(from current: ID?, in rows: [FMFlattenedOutlineRow<ID>], delta: Int) -> ID?
  }
  public struct FMOutlineTree<ID: Hashable & Sendable>: View {
      public init(
          roots: [FMOutlineNode<ID>],
          selection: Binding<ID?>,
          expandedIDs: Binding<Set<ID>>,
          showsIndentGuides: Bool = true,
          onDoubleClick: ((FMOutlineNode<ID>) -> Void)? = nil
      )
  }
  ```
- **Key behavior**: `LazyVStack` over `FMOutlineTreeMath.flatten(...)` for O(visible) performance on large trees, subtle vertical indentation guide hairlines, spring-rotating `chevron.right`, keyboard `↑`/`↓` row stepping + `→` expand/descend + `←` collapse/ascend-to-parent, `FMColor.sidebarSelection` pill, `.fmFocusRing`.

#### B3. `FMStatusBar` — Native macOS Bottom Status & Telemetry Bar (`07_DesktopExtras/FMStatusBar.swift`)
- **Why v1.0 needs it**: Standard bottom chrome in Finder, Xcode, Pages, Mail, and dev tools for item counts, sync status, git branch, cursor position, and zoom controls.
- **Proposed API**:
  ```swift
  public struct FMStatusBarItem: View {
      public init(
          icon: String? = nil,
          text: String,
          statusColor: Color? = nil, // Optional leading pulse/status dot
          action: (() -> Void)? = nil
      )
  }
  public struct FMStatusBar<Leading: View, Center: View, Trailing: View>: View {
      public init(
          height: CGFloat = 28,
          @ViewBuilder leading: () -> Leading,
          @ViewBuilder center: () -> Center,
          @ViewBuilder trailing: () -> Trailing
      )
  }
  ```
- **Key behavior**: Crisp top `FMHairlineDivider()`, opaque/frosted surface respecting `accessibilityReduceTransparency`, tabular `.fmNumeric` / `11.5pt` typography, hover highlight on interactive items, automatic `.fmDensity(.compact)`.

#### B4. `FMPageControl` & `FMOnboardingPager` — Fluid Pill Page Indicator (`08_Editorial/FMPageControl.swift`)
- **Why v1.0 needs it**: Direct companion to `FMHorizontalCarousel` and macOS welcome/onboarding sheets (`FMBottomSheet` / `FMWindowContainer`).
- **Proposed API**:
  ```swift
  public struct FMPageControl: View {
      public init(
          currentPage: Binding<Int>,
          pageCount: Int,
          showsGlassBackdrop: Bool = false,
          tint: Color? = nil
      )
  }
  public struct FMOnboardingPage: Identifiable {
      public let id: String
      public let icon: String
      public let iconColor: Color
      public let title: String
      public let description: String
  }
  public struct FMOnboardingPager: View {
      public init(
          pages: [FMOnboardingPage],
          continueTitle: String = "Continue",
          doneTitle: String = "Get Started",
          onComplete: @escaping () -> Void
      )
  }
  ```
- **Key behavior**: Active indicator morphs smoothly from `6pt` circle to `20×6pt` capsule via `FMSpring.micro`, click any dot to jump, `←`/`→` keyboard support, `.accessibilityAdjustableAction` for VoiceOver.

---

### Batch C — Telemetry, Multi-Step Flows & Developer Data Display (`data-v1`)
**Owned files (3 new source files + 1 test file)**:
- `Sources/FluidMacUI/06_DataDisplay/FMCharts.swift`
- `Sources/FluidMacUI/06_DataDisplay/FMStepsIndicator.swift`
- `Sources/FluidMacUI/09_Productivity/FMCodeBlock.swift`
- `Tests/FluidMacUITests/DataV1Tests.swift`

#### C1. `FMGauge` & `FMSparkline` — Micro Telemetry Gauges & Sparklines (`06_DataDisplay/FMCharts.swift`)
- **Why v1.0 needs it**: SwiftUI `Gauge` on macOS renders flat legacy chrome; Activity Monitor, MenuBar panels, and Bento `FMGridCard` dashboards constantly need compact radial gauges and trend sparklines without pulling in heavy charting dependencies.
- **Proposed API**:
  ```swift
  public enum FMChartMath {
      public static func normalized(_ value: Double, in range: ClosedRange<Double>) -> Double
      public static func normalizedPoints(_ values: [Double]) -> [CGFloat] // 0...1, safe for flat/empty arrays
      public static func nearestIndex(forNormalizedX x: CGFloat, count: Int) -> Int?
  }
  public enum FMGaugeStyle: Sendable, Hashable { case arc, ring, linearCapacity }
  public struct FMGauge: View {
      public init(
          value: Double,
          in range: ClosedRange<Double> = 0...1,
          label: String? = nil,
          valueText: String? = nil,
          style: FMGaugeStyle = .arc,
          size: CGFloat = 84,
          gradient: [Color]? = nil
      )
  }
  public struct FMSparkline: View {
      public init(
          values: [Double],
          color: Color? = nil,
          lineWidth: CGFloat = 2,
          showsAreaFill: Bool = true,
          showsHoverScrub: Bool = true,
          valueFormatter: ((Double) -> String)? = nil
      )
  }
  ```
- **Key behavior**: `FMGauge` renders 240° speedometer arc, full ring, or segmented/gradient linear bar with spring value transitions and tabular numeric readout; `FMSparkline` draws smooth Catmull-Rom / quadratic curves with gradient area fill and interactive pointer hover scrub line + floating value pill.

#### C2. `FMStepsIndicator` — Multi-Step Wizard Progress Bar (`06_DataDisplay/FMStepsIndicator.swift`)
- **Why v1.0 needs it**: Setup assistants, multi-step creation drawers, deployment/migration flows, and onboarding wizards need structured step status visualization.
- **Proposed API**:
  ```swift
  public enum FMStepState: Sendable, Hashable { case completed, active, pending, error }
  public struct FMStepItem: Identifiable, Hashable, Sendable {
      public let id: String
      public let title: String
      public let subtitle: String?
      public let icon: String?
  }
  public enum FMStepsMath {
      public static func state(for index: Int, currentStep: Int, errorSteps: Set<Int>) -> FMStepState
      public static func completionRatio(currentStep: Int, totalSteps: Int) -> Double
  }
  public struct FMStepsIndicator: View {
      public init(
          steps: [FMStepItem],
          currentStep: Binding<Int>,
          errorSteps: Set<Int> = [],
          axis: Axis = .horizontal,
          allowsStepSelection: Bool = false
      )
  }
  ```
- **Key behavior**: Animated connector fill line, spring-popping checkmark badge on completed steps, pulsing/elevated active badge, error badge in `FMColor.red`, optional click-to-jump on completed steps with `FMHaptics`.

#### C3. `FMCodeBlock` — Monospaced Code & Streaming Log Viewer (`09_Productivity/FMCodeBlock.swift`)
- **Why v1.0 needs it**: Essential for developer tools, AI assistants, diagnostic panels, API clients, and configuration viewers on macOS.
- **Proposed API**:
  ```swift
  public enum FMCodeLanguage: String, Sendable, Hashable, CaseIterable {
      case plain, swift, json, shell
  }
  public enum FMCodeTokenKind: Sendable, Hashable {
      case plain, keyword, string, number, comment, property
  }
  public struct FMCodeToken: Sendable, Hashable {
      public let text: String
      public let kind: FMCodeTokenKind
  }
  public enum FMCodeTokenizer {
      public static func tokenizeLine(_ line: String, language: FMCodeLanguage) -> [FMCodeToken]
  }
  public struct FMCodeBlock: View {
      public init(
          _ code: String,
          language: FMCodeLanguage = .plain,
          title: String? = nil,
          showsLineNumbers: Bool = true,
          showsCopyButton: Bool = true,
          maxHeight: CGFloat? = 320
      )
  }
  ```
- **Key behavior**: Continuous-curvature surface with header bar (language pill/title + soft-wrap toggle + Copy button that copies to `NSPasteboard.general` and morphs icon to green checkmark for 1.6s with `FMHaptics`), selectable text or horizontal/vertical scroll, adaptive Dark/Light syntax palette, crisp right-aligned tabular line numbers.

---

## 3. Existing Component Polish & Legacy AppKit Leak Checklist (Batch D — `polish-v1`)

All findings below were verified directly against line numbers in `Sources/FluidMacUI/` (excluding `FMDateAndColorPickers.swift`, owned by `pickers`).

### P0 — Critical Bugs, AppKit Leaks & Severe Accessibility / Contrast Glitches

| # | File & Line | Issue | Concrete Fix |
| :---: | :--- | :--- | :--- |
| **P0-1** | `Sources/FluidMacUI/06_DataDisplay/FMSkeletonModifier.swift:61` | `.accessibilityLabel(isLoading ? "Loading content" : "")` **wipes out the wrapped view's real VoiceOver label** whenever `isLoading == false`. | Replace with `.accessibilityHidden(isLoading)` on content + an overlay accessibility label only when `isLoading` is true (or conditional modifier that does not set `""` when loaded). |
| **P0-2** | `Sources/FluidMacUI/05_Feedback/FMLightbox.swift:48-54` | Counter badge uses hardcoded `.foregroundStyle(.white)` inside `.fmGlassSurface(.regular, ...)`. In **Light Mode with Reduce Transparency enabled**, `elevatedOpaqueSurface(.light)` is near-white (`#F9F9FB`), making the counter **completely invisible**. Also close/prev/next buttons (`:56`, `:67`, `:75`) lack `.accessibilityLabel`. | Use `.foregroundStyle(.primary)` (or dark translucent pill `Color.black.opacity(0.65)` unaffected by light opaque fallback) and add `.accessibilityLabel("Close")`, `"Previous"`, `"Next"`. |
| **P0-3** | `Sources/FluidMacUI/08_Editorial/FMHorizontalCarousel.swift:45` & `Sources/FluidMacUI/04_Navigation/FMNavigationStack.swift:155,267` | **Broken upward environment propagation**: `FMHorizontalCarousel` sets `.fmSwipeBackDisabled(true)` on a child, expecting parent `FMNavigationStack` (`@Environment(\.fmSwipeBackDisabled)`) to disable trackpad swipe-back. SwiftUI `EnvironmentValues` flow downward only, so this modifier has **zero effect**. | Either propagate via a `PreferenceKey` (`FMSwipeBackDisabledPreferenceKey`) up to `FMNavigationStack`, or have `FMTrackpadSwipeBridge` inspect the hit-tested `NSView` hierarchy for an enclosing horizontal `NSScrollView` that can scroll left before intercepting. |
| **P0-4** | `Sources/FluidMacUI/04_Navigation/FMNavigationStack.swift:170,408-427` | Two layout bugs: (1) single `@State private var scrollOffset` is shared across root and all pushed pages—scrolling a pushed page and popping back leaves root's large title hidden; (2) `if isRoot && headerStyle == .large && scrollOffset < 42` abruptly removes the large title from the `VStack` at `42pt`, causing a **layout jump / scroll oscillation**. | Track scroll offset per page ID (dictionary `[UUID: CGFloat]` + root offset), and place the large title inside the scrollable layout or smoothly interpolate opacity/offset without abruptly removing vertical layout height mid-scroll. |
| **P0-5** | `Sources/FluidMacUI/02_Controls/FMButtonStyle.swift:98-101` & `Sources/FluidMacUI/04_Navigation/FMWindowContainer.swift:183-185` | **Remaining AppKit `ProgressView` visual leaks**: both use SwiftUI `ProgressView().controlSize(.small)` which renders AppKit's `NSProgressIndicator` spinning ticks. | Replace both with pure-SwiftUI `FMSpinner(style: .ring, size: .small, tint: ...)` once Batch A lands (or a lightweight private ring until merged). In `FMButtonStyle:137`, also guard keyboard activation when `isLoading` is true (`.disabled(isLoading)` or no-op guard). |
| **P0-6** | `Sources/FluidMacUI/04_Navigation/FMInspectorSplitView.swift:66-72` | **Unbalanced `NSCursor.push()` / `NSCursor.pop()`**: if the inspector closes while the cursor hovers over the splitter, `onHover(false)` may not fire, leaving the resize cursor stuck globally or popping another view's cursor. | Track `@State private var isCursorPushed = false`; only `push()` when `!isCursorPushed`, only `pop()` when `isCursorPushed`, and always clean up in `.onDisappear`. |
| **P0-7** | `Sources/FluidMacUI/02_Controls/FMButtonStyle.swift:54-109`, `04_Navigation/FMWindowContainer.swift:215`, `05_Feedback/FMInlineBanner.swift:85`, `Examples/FluidMacShowcase/Pages/AppStoreDemoPage.swift:110` | **Dead `.controlSize(.small)` API**: `FMButtonStyle` ignores `@Environment(\.controlSize)`, yet 3 call sites (`FMDynamicHUDCapsule`, `FMInlineBanner`, `AppStoreDemoPage`) apply `.controlSize(.small)` expecting compact pill buttons. | Read `@Environment(\.controlSize) private var controlSize` inside `FMButtonBody` and scale `minHeight`, horizontal padding, and font size for `.mini` / `.small` / `.regular` / `.large`. |
| **P0-8** | `Sources/FluidMacUI/04_Navigation/FMWindowContainer.swift:235` | `.accessibilityElement(children: .combine)` on `FMDynamicHUDCapsule` merges the interactive `action` button and `xmark` dismiss button into a single non-interactive element for VoiceOver users. | Change to `.accessibilityElement(children: .contain)` so VoiceOver announces the HUD and still lets users reach the action and dismiss buttons. |

---

### P1 — Interaction, Accessibility, Reduce Motion & Reduce Transparency Gaps

| # | File & Line | Issue | Concrete Fix |
| :---: | :--- | :--- | :--- |
| **P1-1** | `Sources/FluidMacUI/01_Foundation/FMMaterialEngine.swift:138-147` | `opaqueFallback` passes `tint: nil`, causing `.tinted` and `.interactiveTinted` glass buttons/cards to lose all tint color when **Reduce Transparency** is enabled. | Pass a subtle opaque-blended tint (`tintColor`) or accent border in `opaqueFallback` so tinted active states (e.g. active `FMToolbarButton`) remain visually distinct. |
| **P1-2** | `Sources/FluidMacUI/04_Navigation/FMNavigationStack.swift:339-344` & `FMSidebarSplitView.swift:348-352` | Both render `.ultraThinMaterial` without checking `@Environment(\.accessibilityReduceTransparency)`. | When `reduceTransparency == true`, skip `.ultraThinMaterial` and render solid `FMColor.canvasBackground(colorScheme)` / `FMColor.sidebarBackground(colorScheme)`. |
| **P1-3** | `Sources/FluidMacUI/04_Navigation/FMNavigationStack.swift:285,291,311,355`, `05_Feedback/FMBottomSheet.swift:79`, `08_Editorial/FMHorizontalCarousel.swift:89`, `02_Controls/FMTextField.swift:125-136` | Hardcoded `withAnimation(FMSpring.*)` and `triggerShake()` bypass `@Environment(\.accessibilityReduceMotion)` and `theme.animationSpeed`. Also `FMTextField.triggerShake()` spawns untracked overlapping `Task`s. | Use `FMSpring.animation(..., reduceMotion: reduceMotion, speed: theme.animationSpeed)`. Skip horizontal shake in `FMTextField` when `reduceMotion` is true and cancel any prior `shakeTask` before starting a new one (plus cancel in `.onDisappear`). |
| **P1-4** | `Sources/FluidMacUI/06_DataDisplay/FMProgress.swift:75-80,146-151` & `FMSkeletonModifier.swift:46-51` | Indeterminate `repeatForever` animations do **not pause when `controlActiveState == .inactive`** (violates NFR: 0% inactive GPU) and do not react if `reduceMotion` toggles at runtime. | Gate animations on `let active = !reduceMotion && activeState != .inactive` and sync via `.onChange(of: active, initial: true)`. |
| **P1-5** | `Sources/FluidMacUI/02_Controls/FMSlider.swift:100,158` | (1) `standardTrack` drag calculation `gesture.location.x / width` ignores half-thumb inset (`thumbDiameter * 0.5`), shifting the thumb slightly on click; (2) `capsuleTrack` computes `fillWidth = max(activeHeight * 0.65, width * progress)`, rendering a ~17pt filled pill even at `progress == 0`; (3) missing `.accessibilityValue` & `.accessibilityAdjustableAction`. | Compute standard ratio over `(thumbDiameter * 0.5)...(width - thumbDiameter * 0.5)`; allow `fillWidth = progress == 0 ? 0 : max(activeHeight * 0.65, width * progress)`; add full VoiceOver value & adjustable action. |
| **P1-6** | `Sources/FluidMacUI/02_Controls/FMCheckboxStyle.swift:84-105` | (1) `DragGesture` toggles on `onEnded` even if the pointer dragged far outside the checkbox; (2) missing `.onKeyPress(.return)`; (3) missing `.accessibilityElement(children: .combine)` + `.accessibilityValue` + `.accessibilityAddTraits(.isButton)`. | Check `abs(value.translation.width) < 24 && abs(value.translation.height) < 24` (or hit bounds) before toggling, handle `.return`, and add VoiceOver traits/value. |
| **P1-7** | `Sources/FluidMacUI/02_Controls/FMStepper.swift:96-148` | Completely lacks keyboard focus (`Tab` / `↑` / `↓` / `←` / `→`), `.fmFocusRing`, and VoiceOver `.accessibilityAdjustableAction`. Also `startRepeating` keeps looping `Task.sleep` after reaching `range.lowerBound` / `range.upperBound`. | Add `.focusable(isEnabled)` + `.focused($isFocused)` + `.fmFocusRing(..., isCapsule: true)` + arrow keys + `.accessibilityAdjustableAction`; break the repeat loop once `next == value`. |
| **P1-8** | `Sources/FluidMacUI/02_Controls/FMDropdownPicker.swift:83-131` | No `ScrollView` wrapper (long option lists overflow screen vertically) and no keyboard `↑`/`↓`/`↵`/`Esc` navigation inside the menu. | Wrap options in `ScrollView` with `.frame(maxHeight: 280)` and wire arrow/Enter/Escape key handling. |
| **P1-9** | `Sources/FluidMacUI/03_Containers/FMRow.swift:112-135` & `FMGridCard.swift:82-106` | Interactive rows/cards (`action != nil`) use `DragGesture` only—unreachable via `Tab` keyboard navigation, missing `.fmFocusRing`, `.onKeyPress(.return/.space)`, and `.accessibilityAddTraits(.isButton)`. | Add `.focusable()` + `.focused` + `.fmFocusRing` + `.onKeyPress(.return/.space)` + `.accessibilityAddTraits(.isButton)` when `action != nil`. |
| **P1-10** | `Sources/FluidMacUI/04_Navigation/FMSidebarSplitView.swift:332,441` | Tooltip advertises shortcut `["⌘", "S"]`, which (a) is not wired inside `FMSidebarSplitView` itself (only in `ShowcaseApp`), and (b) conflicts with macOS standard **Save (`⌘S`)**. Apple HIG uses **`⌥⌘S`** (Finder/App Store) or **`⌃⌘S`**. | Change default tooltip shortcut hint to `["⌥", "⌘", "S"]` (or make configurable) and remove hardcoded Chinese tooltip text. |
| **P1-11** | `Sources/FluidMacUI/05_Feedback/FMBottomSheet.swift:69-84` | `DragGesture()` attached to the entire sheet body steals horizontal/vertical drags from embedded `FMSlider` or `ScrollView` controls. | Restrict drag-to-dismiss to the top grabber/header region or require downward vertical dominance (`abs(y) > abs(x) * 1.5`) via `simultaneousGesture`. |
| **P1-12** | `Sources/FluidMacUI/05_Feedback/FMAlert.swift:133-136` | Hidden `.keyboardShortcut(.return)` triggers the first non-cancel button **even if its role is `.destructive`**—violating macOS HIG safety against accidental destructive confirmation on Enter. | Only bind `.return` to `.default` role buttons (never `.destructive`). |
| **P1-13** | `Sources/FluidMacUI/09_Productivity/FMFileDropZone.swift:123,128-146` | (1) Uses synchronous blocking `panel.runModal()` instead of async `panel.begin { ... }`; (2) `handleDrop` accepts **any** dropped file without validating `url` against `allowedContentTypes`. | Switch to `panel.begin { response in ... }` and filter dropped URLs via `try? url.resourceValues(forKeys: [.contentTypeKey]).contentType?.conforms(to:)` against `allowedContentTypes`. |
| **P1-14** | `Sources/FluidMacUI/09_Productivity/FMCommandPalette.swift:123-186` | `FMCommandItem.group` is ignored during rendering (flat list despite DocC promising grouped suggestions), and `↑`/`↓` arrow navigation does not auto-scroll (`ScrollViewReader`) to keep `selectedIndex` visible. | Wrap list in `ScrollViewReader` calling `proxy.scrollTo(filtered[selectedIndex].id)` on `selectedIndex` changes, and render group headers when `query.isEmpty` (or preserve grouped sections). |
| **P1-15** | `Sources/FluidMacUI/09_Productivity/FMDataTable.swift:131-136,199-213` | (1) `.onTapGesture(count: 2)` alongside `.onTapGesture` introduces a ~300ms SwiftUI delay on every single click; (2) missing `⇧`-click range selection and keyboard `↑`/`↓` row navigation. | Handle double-click via `NSApp.currentEvent?.clickCount == 2` inside a single tap handler (zero 300ms lag), add `⇧`-click range selection using `lastSelectedRowID`, and wire `↑`/`↓` keys. |
| **P1-16** | `Sources/FluidMacUI/08_Editorial/FMExpandableText.swift:36-46` | Always displays the `"more"` button even when the text fits within `collapsedLineLimit` without truncation. Also uses `theme.accentColor` without `FMColor.adaptiveAccent`. | Measure intrinsic vs. clamped text height (using `ViewThatFits` or background hidden full-text `GeometryReader`) to show the button only when truncated, and apply `FMColor.adaptiveAccent`. |
| **P1-17** | `Sources/FluidMacUI/08_Editorial/FMSectionHeader.swift:105` | Convenience action link button hardcodes `.foregroundStyle(FMColor.blue)` instead of `@Environment(\.fmTheme).accentColor`, breaking custom accent themes. | Replace the `AnyView` closure with a small private `FMSectionActionLink` view that reads `@Environment(\.fmTheme)` + `FMColor.adaptiveAccent`. |
| **P1-18** | `Sources/FluidMacUI/07_DesktopExtras/FMTooltip.swift:124-131` | Fixed offsets (`-12`/`+12` for `.leading`/`.trailing`, `-36`/`+36` for `.top`/`.bottom`) cause tooltips to overlap directly on top of the target view for `.leading`/`.trailing` or tall targets. | Use `.overlay` + `alignmentGuide` (or `.popover`-free measured offset based on target/tooltip size via `GeometryReader` / `visualEffect`) so tooltips always sit `8pt` outside the target edge. |
| **P1-19** | `Sources/FluidMacUI/08_Editorial/FMAvatar.swift:22-56` | `FMAvatar` lacks a `SwiftUI.Image` (or custom artwork) initializer—only supports initials and SF Symbols. Also status cutout stroke hardcodes `FMColor.canvasBackground` (`:90`, `:131`). | Add `public init(image: Image, size: CGFloat = 34, status: FMAvatarStatus? = nil)` and an optional `cutoutColor: Color? = nil` parameter. |
| **P1-20** | `Sources/FluidMacUI/04_Navigation/FMToolbar.swift:60-66` | `FMToolbarButton` sets `isPressed = true` even when `!isEnabled` and suppresses focus ring without `.fmFocusRing`. | Guard `DragGesture` with `guard isEnabled else { return }`, and add `@FocusState` + `.fmFocusRing(isFocused: isFocused, isCapsule: true)`. |

---

### P2 — Focus Ring Consistency, Localization Defaults, DocC & Swift 6.2 Hygiene

| # | File & Line | Issue | Concrete Fix |
| :---: | :--- | :--- | :--- |
| **P2-1** | 12 interactive components using `.focusEffectDisabled()` without `.fmFocusRing`: `FMExpandableGroup`, `FMToolbarButton`, `FMTabBar`, `FMSidebarSplitView` rows, `FMAlert` buttons, `FMFileDropZone`, `FMFilterChips`, `FMBreadcrumbBar`, `FMExpandableText`, `FMSectionHeader`, `FMActionPopover` | Violates `ARCHITECTURE.md` Principle 4 ("Never strip focus blindly; render FluidMacUI continuous focus rings for keyboard navigation"). | Add `@FocusState` + `.fmFocusRing(...)` consistently across interactive controls. |
| **P2-2** | Hardcoded Chinese strings mixed with English across library `Sources/`: `FMSpacing.swift:33-35`, `FMTheme.swift:16,32-33`, `FMSearchBar.swift:22-23`, `FMSidebarSplitView.swift:15-16,332,441`, `FMConfirmPopover.swift:20-21,76-77`, `FMCommandPalette.swift:19,65,116,241`, `FMDataTable.swift:107`, `FMFileDropZone.swift:24-25`, `FMFilterChips.swift:108,143`, `FMSelectionActionBar.swift:15,41` | Library defaults mix Chinese (`"搜索..."`, `"暂无数据"`, `"已选 N 项"`) with English (`"Search"`, `"Show Sidebar"`, `"Hide password"`, `"more"`/`"less"`). In `FMSelectionActionBar:41`, `"已选 \(selectedCount) \(unitLabel)"` cannot even be overridden to English! | Standardize public library defaults to clean English (matching Apple SwiftUI conventions) and expose customizable parameters (`emptyTitle`, `selectionLabel: (Int) -> String`) so Chinese/localized apps like `FluidMacShowcase` pass localized strings cleanly. |
| **P2-3** | `Sources/FluidMacUI/04_Navigation/FMSidebarSplitView.swift:146` | Uses legacy `DispatchQueue.main.async` inside `.onAppear` instead of Swift 6.2 structured concurrency (`.task`). | Replace with `.task { isFocused = false; didAppear = true }`. |
| **P2-4** | `Sources/FluidMacUI/02_Controls/FMSecureField` (`FMTextField.swift:140-222`) | Lacks `errorMessage` and `onSubmit` parity with `FMTextField`, and toggling `isRevealed` drops keyboard focus between `SecureField` and `TextField`. | Add optional `errorMessage` & `onSubmit`, and preserve focus across `isRevealed` toggle via a dual-case `@FocusState` enum. |
| **P2-5** | `Sources/FluidMacUI/07_DesktopExtras/FMMenuBarPanel.swift:68-71` | DocC promises a "scrollable body", but body is a plain `VStack` without a `ScrollView` or `maxHeight` parameter. | Add `maxBodyHeight: CGFloat? = nil` and wrap `content` in `ScrollView` when `maxBodyHeight` is provided. |
| **P2-6** | `Sources/FluidMacUI/08_Editorial/FMAvatar.swift:101` & missing `Sources/FluidMacUI/FluidMacUI.docc/` | `FMAvatarGroup.Member` is the only `public struct` missing a DocC header; `FluidMacUI.docc` catalog planned in `ARCHITECTURE.md` does not yet exist. | Add DocC comments to `FMAvatarGroup.Member` and public initializers, and add a top-level `FluidMacUI.docc/FluidMacUI.md` landing article before tagging `v1.0.0`. |
| **P2-7** | Missing accessibility labels on icon-only buttons: `FMTextField.swift:71`, `FMSearchBar.swift:64`, `FMSidebarSplitView.swift:120`, `FMInlineBanner.swift:89`, `FMFileDropZone.swift:96`, `FMFilterChips.swift:125`, `FMSelectionActionBar.swift:29`, `FMHorizontalCarousel.swift:50,59`, `FMLightbox.swift:56,67,75` | Icon-only `xmark` / `chevron` buttons announce only raw SF Symbol names or nothing to VoiceOver. | Add concise `.accessibilityLabel(...)` to every icon-only button. |

---

## 4. Recommended Parallel Execution Plan for v1.0 Release

All 4 workstreams below are **100% file-disjoint** and can run concurrently (with a single 2-file follow-up after Batch A merges to swap `ProgressView` → `FMSpinner` in `FMButtonStyle.swift` and `FMWindowContainer.swift`, plus a final `FluidMacShowcase` integration pass):

1. **`controls-v1` (Batch A)**: `FMSpinner`, `FMRadioGroup`, `FMComboBox`, `FMNumberField`/`FMOTPField`, `FMShortcutRecorder` + `ControlsV1Tests.swift`.
2. **`layout-v1` (Batch B)**: `FMSplitPane`, `FMOutlineTree`, `FMStatusBar`, `FMPageControl`/`FMOnboardingPager` + `LayoutV1Tests.swift`.
3. **`data-v1` (Batch C)**: `FMGauge`/`FMSparkline`, `FMStepsIndicator`, `FMCodeBlock` + `DataV1Tests.swift`.
4. **`polish-v1` (Batch D)**: Execute P0 & P1 fixes across existing `Sources/FluidMacUI/` files (excluding `FMDateAndColorPickers.swift`), expanding `Tests/FluidMacUITests/` to cover fixed behaviors.
5. **Final Showcase & Verification Pass**: Wire all 12 new v1.0 components + `pickers`'s new `FMCalendarView`/`FMDateRangePicker`/`FMColorPicker` into `Examples/FluidMacShowcase/`, add `FluidMacUI.docc/`, and verify `swift build && swift test` passes with **0 warnings, 0 errors**.
