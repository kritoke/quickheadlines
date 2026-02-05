## 1. Import Responsive Module

- [x] 1.1 Add import Responsive exposing (Breakpoint(..), breakpointFromWidth, uniformPadding) to ui/src/Layouts/Shared.elm

## 2. Add Responsive Helpers to headerView

- [x] 2.1 Update headerView function signature to accept Shared.Model instead of Theme
- [x] 2.2 Calculate breakpoint from shared.windowWidth in headerView
- [x] 2.3 Update horizontal padding to use Responsive.uniformPadding breakpoint instead of fixed 16px

## 3. Update Layout Function Call

- [x] 3.1 Update layout function call to headerView to pass shared.model instead of just theme

## 4. Build Verification

- [x] 4.1 Compile Elm application to verify no syntax errors
- [x] 4.2 Test on very narrow viewport (<480px) to verify 8px header padding
- [x] 4.3 Test on mobile viewport (480-767px) to verify 16px header padding
- [x] 4.4 Test on tablet viewport (768-1023px) to verify 32px header padding
- [x] 4.5 Test on desktop viewport (>=1024px) to verify 96px header padding
- [x] 4.6 Verify navigation buttons remain fully visible on all viewport sizes

## 5. Testing

- [x] 5.1 Verify header vertical padding remains consistent at 16px across all breakpoints
- [x] 5.2 Test window resize triggers responsive header updates in real-time
- [x] 5.3 Test navigation links/tabs don't overflow or wrap awkwardly on narrow screens

## 6. Icon Button Responsive Padding (Completed 2026-02-05)

- [x] 6.1 Add responsive padding to homeIconView (4px very narrow, 6px mobile, 10px tablet+)
- [x] 6.2 Add responsive padding to timelineIconView (same as homeIconView)
- [x] 6.3 Matches pattern already used in themeToggle
- [x] 6.4 Compile verification successful

## Implementation Notes

The header icon buttons (home, timeline, theme toggle) now use responsive padding:
- VeryNarrowBreakpoint (<480px): 4px
- MobileBreakpoint (480-767px): 6px
- TabletBreakpoint+ (768px+): 10px