## Context

The QuickHeadlines application currently uses custom dropdown and expansion components (LayoutPicker, ThemePicker, ClusterExpansion) that:
- Have inconsistent accessibility implementation across components
- Lack proper keyboard navigation in some scenarios
- Create maintenance overhead with custom implementations
- Have TypeScript type issues with the existing BitsThemePicker

The Bits UI library provides well-tested, accessible components that integrate with Svelte 5's reactivity system.

## Goals / Non-Goals

**Goals:**
- Replace custom dropdown implementations with Bits UI Select for LayoutPicker
- Implement Toast notification system for error handling feedback
- Add Command component for advanced search functionality
- Convert ClusterExpansion to Bits UI Accordion component
- Fix TypeScript type issues in BitsThemePicker
- Ensure all components meet WCAG 2.1 AA accessibility standards

**Non-Goals:**
- Rewrite the entire UI - only modify specific components listed
- Change backend API structure
- Add authentication or user accounts
- Implement full offline support

## Decisions

### 1. Bits UI Library Selection

**Decision:** Use Bits UI (bits-ui) for Svelte component replacements.

**Rationale:**
- Bits UI provides well-tested, accessible components
- Strong TypeScript support
- Compatible with Svelte 5's reactivity model
- Active maintenance and community support

**Alternatives Considered:**
- `bits-ui` - Selected (best Svelte 5 support)
- `shadcn-vue` - Would require significant adaptation
- `kobalte` - Good but less Svelte-specific

### 2. Toast Notification Strategy

**Decision:** Implement toast notifications at the application root level with a centralized store.

**Rationale:**
- Single toast instance at root avoids z-index conflicts
- Centralized store allows any component to trigger notifications
- Supports multiple toast types (error, success, warning, info)

**Toast Types:**
- Error: Red accent, for failures and errors
- Success: Green accent, for successful operations
- Warning: Yellow accent, for warnings
- Info: Blue accent, for informational messages

### 3. Command Palette Implementation

**Decision:** Implement command palette as a global shortcut-activated component (Cmd/Ctrl + K).

**Rationale:**
- Familiar UX pattern for power users
- Enables quick feed search and navigation
- Can be extended for future commands (settings, actions)

**Features:**
- Fuzzy search for feed names
- Recent searches history
- Keyboard navigation (arrow keys, enter to select)
- Escape to close

### 4. ClusterExpansion to Accordion Migration

**Decision:** Replace custom ClusterExpansion with Bits UI Accordion.

**Rationale:**
- Accordion provides proper ARIA attributes out of the box
- Supports keyboard navigation (Enter/Space to toggle)
- Consistent behavior across the application
- Reduces custom code maintenance

### 5. Type Safety for ThemePicker

**Decision:** Define proper TypeScript types for theme values using const assertions.

**Rationale:**
- Eliminates type casting (`as typeof themeState.theme`)
- Provides autocomplete for theme values
- Catches invalid theme values at compile time

## Risks / Trade-offs

| Risk | Impact | Mitigation |
|------|--------|------------|
| Bits UI Svelte adapter API changes | Medium | Pin to specific version, write abstraction layer |
| Toast stacking with existing modals | Low | Use portal positioning, configurable z-index |
| Command palette keyboard conflicts | Medium | Check for input focus before activating |
| Performance with large feed lists | Low | Implement virtual scrolling if needed |

### Trade-offs

1. **Custom Styling vs. Native Look**: Bits UI provides base styles but may need customization to match application theme. This is a trade-off between full control and reduced maintenance.

2. **Bundle Size**: Adding Bits UI components increases bundle size. The trade-off is justified by improved reliability and accessibility.

3. **Migration Effort**: Converting existing components requires testing. The benefit is long-term maintainability.

## Migration Plan

### Phase 1: Infrastructure (Week 1)
1. Add Bits UI dependency
2. Create toast store and notification system
3. Create CommandPalette component

### Phase 2: Component Migration (Week 2)
1. Create new LayoutPicker with Bits UI Select
2. Fix type issues in BitsThemePicker
3. Test theme switching functionality

### Phase 3: Expansion Components (Week 3)
1. Convert ClusterExpansion to Bits UI Accordion
2. Integrate toast notifications throughout app
3. Add command palette to header

### Phase 4: Cleanup (Week 4)
1. Remove old custom components
2. Run accessibility audit
3. Update tests and snapshots

## Open Questions

1. **Toast Positioning**: Should toasts appear top-right or bottom-right? User feedback will determine final placement.

2. **Command Palette Scope**: Should it search only feeds, or also include actions and settings? Start with feeds, extend later.

3. **Accordion Animation**: Bits UI Accordion may have different animation behavior than current implementation. Need to verify it matches expectations.

4. **Theme Persistence**: Confirm current localStorage approach still works after Select component migration.
