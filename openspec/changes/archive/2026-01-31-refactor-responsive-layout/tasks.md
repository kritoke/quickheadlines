## 1. Create Responsive Module

- [x] 1.1 Create ui/src/Responsive.elm module file
- [x] 1.2 Define Breakpoint union type (VeryNarrow | Mobile | Tablet | Desktop)
- [x] 1.3 Implement breakpointFromWidth function with tier logic (<480, 480-767, 768-1023, >=1024)
- [x] 1.4 Implement horizontalPadding function returning 8/16/32/40 for each breakpoint
- [x] 1.5 Implement verticalPadding function returning 8/16/32/60 for each breakpoint
- [x] 1.6 Implement uniformPadding function returning 8/16/32/96 for each breakpoint
- [x] 1.7 Implement containerMaxWidth function returning fill/fill/max1024/max1200
- [x] 1.8 Implement isMobile helper returning true for Mobile/VeryNarrow
- [x] 1.9 Implement isVeryNarrow helper returning true only for VeryNarrow
- [x] 1.10 Implement timelineTimeColumnWidth returning 60 for VeryNarrow, 85 otherwise
- [x] 1.11 Implement timelineClusterPadding returning 70 for VeryNarrow, 105 otherwise
- [x] 1.12 Test Responsive module compilation with elm make

## 2. Refactor Timeline Page

- [x] 2.1 Import Responsive module in ui/src/Pages/Timeline.elm
- [x] 2.2 Remove isMobile and isVeryNarrow local variables from view function
- [x] 2.3 Add breakpoint calculation: breakpoint = Responsive.breakpointFromWidth shared.windowWidth
- [x] 2.4 Replace horizontalPadding with Responsive.horizontalPadding breakpoint
- [x] 2.5 Replace verticalPadding with Responsive.verticalPadding breakpoint
- [x] 2.6 Replace paddingEach with paddingXY horizontalPadding verticalPadding
- [x] 2.7 Update dayClusterSection function signature to accept Breakpoint instead of Bool
- [x] 2.8 Update clusterItem function signature to accept Breakpoint instead of Bool
- [x] 2.9 Update dayClusterSection to pass breakpoint to clusterItem calls
- [x] 2.10 Update time column width to use Responsive.timelineTimeColumnWidth breakpoint
- [x] 2.11 Update cluster left padding to use Responsive.timelineClusterPadding breakpoint
- [x] 2.12 Test Timeline.elm compilation

## 3. Refactor Home Page

- [x] 3.1 Import Responsive module in ui/src/Pages/Home_.elm
- [x] 3.2 Remove isMobile local variable from view function
- [x] 3.3 Add breakpoint calculation: breakpoint = Responsive.breakpointFromWidth shared.windowWidth
- [x] 3.4 Replace paddingValue with Responsive.uniformPadding breakpoint
- [x] 3.5 Add max-width constraint: width (fill |> Responsive.containerMaxWidth breakpoint)
- [x] 3.6 Update columnCount calculation to use case breakpoint of (VeryNarrow->1, Mobile->1, Tablet->2, Desktop->3)
- [x] 3.7 Update gapValue calculation to use case breakpoint of (VeryNarrow->16, Mobile->16, Tablet->20, Desktop->24)
- [x] 3.8 Update feedCard function signature to accept Breakpoint instead of Int windowWidth
- [x] 3.9 Replace windowWidth >= 1024 checks with case breakpoint of Desktop
- [x] 3.10 Test Home_.elm compilation