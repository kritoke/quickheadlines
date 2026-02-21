## Design: FeedTabs Component

### Component Architecture

**FeedTabs.svelte** accepts:
- `tabs: TabResponse[]` - Array of tab objects with `name` property
- `activeTab: string` - Currently active tab
- `onTabChange: (tab: string) => void` - Callback when tab changes

Uses Bits UI primitives:
- `Tabs.Root` - Root context with `value` binding
- `Tabs.List` - Container with luxe glass styling
- `Tabs.Trigger` - Individual tab buttons with `data-[state=active]`

### Styling

**Container (Tabs.List):**
- bg-slate-100/80 dark:bg-slate-800/80
- backdrop-blur-xl
- rounded-xl border
- shadow-sm

**Active Pill:**
- bg-white dark:bg-slate-700
- border-slate-200 dark:border-slate-600
- shadow-sm
- Optional: shadow-luxe-glow border-accent/30 when coolMode enabled

### Animation

- Sliding pill uses `in:fly` with 300ms duration and cubicOut easing
- view-transition-name: tab-pill for View Transitions API support

### Integration

Replace in +page.svelte:
```svelte
<TabBar {tabs} {activeTab} onTabChange={handleTabChange} />
```
With:
```svelte
<FeedTabs {tabs} {activeTab} onTabChange={handleTabChange} />
```

### Tailwind Config Additions

```js
colors: {
  accent: {
    DEFAULT: '#96ad8d',
    glow: 'rgba(150, 173, 141, 0.3)'
  }
},
boxShadow: {
  'luxe-glow': '0 0 15px -3px rgba(150, 173, 141, 0.4)'
}
```
