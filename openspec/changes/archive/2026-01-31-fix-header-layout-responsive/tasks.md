## 1. Import Responsive Module

- [x] 1.1 Add import Responsive exposing (Breakpoint(..), breakpointFromWidth, uniformPadding) to ui/src/Layouts/Shared.elm

## 2. Update Layout Function Signature

- [x] 2.1 Change layout record type to include model parameter
- [x] 2.2 Update layout function to pass model to headerView

## 3. Update headerView Function

- [x] 3.1 Update headerView function signature to accept Theme and Int instead of just Theme
- [x] 3.2 Calculate breakpoint from shared.windowWidth
- [x] 3.3 Update horizontal padding to use Responsive.uniformPadding breakpoint

## 4. Build Verification

- [x] 4.1 Compile Elm application to verify no syntax errors
- [x] 4.2 Added inline SVG icons for sun and moon theme toggle
- [x] 4.3 Added routes for sun-icon.svg and moon-icon.svg in api_controller.cr
- [x] 4.4 Made theme toggle padding responsive (4px very narrow, 6px mobile, 10px tablet/desktop)
- [x] 4.5 Created SVG icons for theme toggle (sun and moon)
- [ ] 4.6 Test on very narrow viewport (<480px) to verify 8px header padding
- [ ] 4.7 Test on mobile viewport (480-767px) to verify 16px header padding
- [ ] 4.8 Test on tablet viewport (768-1023px) to verify 32px header padding
- [ ] 4.9 Test on desktop viewport (>=1024px) to verify 96px header padding
- [ ] 4.10 Verify navigation buttons remain fully visible on all viewport sizes

## 5. Testing

- [ ] 5.1 Verify header vertical padding remains consistent at 16px across all breakpoints
- [ ] 5.2 Test window resize triggers responsive header updates in real-time
- [ ] 5.3 Test navigation links/tabs don't overflow or wrap awkwardly on narrow screens