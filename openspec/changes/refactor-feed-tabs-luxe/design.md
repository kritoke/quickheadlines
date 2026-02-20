## Design: Luxe FeedTabs & CursorTrail Components

### 1. Component Architecture

#### FeedTabs.svelte

**Props:**
```typescript
interface Props {
  tabs: TabResponse[];          // From API: [{name: "Tech"}, {name: "News"}]
  activeTab: string;            // Bindable: "all" | "Tech" | "News"
  onTabChange: (tab: string) => void;
}

let { tabs, activeTab = $bindable(), onTabChange }: Props = $props();
```

Uses Bits UI primitives:
- `Tabs.Root` - Root context with `bind:value`
- `Tabs.List` - Container with luxe glass styling
- `Tabs.Trigger` - Individual tab buttons with `data-[state=active]`

The FeedTabs component does NOT render content panels. Content is handled by the existing `{#key activeTab}` block in `+page.svelte`.

#### CursorTrail.svelte

**State:**
```typescript
// Svelte 5 Spring class for physics-based animation
const primarySpring = new Spring({ x: 0, y: 0 }, {
  stiffness: 0.15,
  damping: 0.8
});

const auraSpring = new Spring({ x: 0, y: 0 }, {
  stiffness: 0.08,  // Slower = more lag for trailing effect
  damping: 0.7
});
```

**Visual layers:**
1. Primary dot: 8px radius, solid accent color, follows closely
2. Aura dot: 40px radius, blurred (12px), 30% opacity, trails behind

### 2. Styling Strategy

**Container (Tabs.List):**
```
bg-white/50 dark:bg-zinc-950/50 backdrop-blur-2xl
rounded-2xl border border-zinc-200/50 dark:border-zinc-800/50
shadow-[inset_0_1px_2px_rgba(0,0,0,0.05)]
dark:shadow-[inset_0_1px_0_rgba(255,255,255,0.05)]
```

**Active Pill:**
```
absolute inset-0 rounded-xl -z-10
bg-white dark:bg-zinc-800
border border-zinc-200 dark:border-zinc-700/50
shadow-sm
```

**Cursor Trail Glow (when cursorTrail enabled):**
```
shadow-[0_0_15px_-3px_rgba(150,173,141,0.4)]
border-accent/40
```

**Cursor Trail Container:**
```
fixed inset-0 pointer-events-none z-[9999]
```

### 3. Animation Strategy

**Sliding Pill:**
- Use `in:fly={{ x: 5, duration: 300, easing: cubicOut }}`
- Add `style="view-transition-name: tab-pill"` for View Transitions API

**View Transition CSS:**
```css
::view-transition-old(tab-pill),
::view-transition-new(tab-pill) {
  animation-duration: 0.35s;
  animation-timing-function: cubic-bezier(0.4, 0, 0.2, 1);
}
```

**Cursor Trail:**
- Svelte 5 `Spring` class provides physics-based interpolation
- Different stiffness/damping for primary vs aura creates natural trailing effect
- Updates on `mousemove` event

### 4. Integration with +page.svelte

Replace:
```svelte
<TabBar {tabs} {activeTab} onTabChange={handleTabChange} />
```

With:
```svelte
<FeedTabs {tabs} bind:activeTab={activeTab} onTabChange={handleTabChange} />
```

Add cursor trail at top of main content:
```svelte
<CursorTrail />
```

Update header toggle button from polka dots to cursor icon.

### 5. Tailwind Config Additions

```js
colors: {
  luxe: {
    light: "#fcfcfd",
    dark: "#09090b",
    border: "rgba(0, 0, 0, 0.08)",
    'border-dark': "rgba(255, 255, 255, 0.1)",
  },
  accent: {
    DEFAULT: "#96ad8d", // Wasabi Green
    glow: "rgba(150, 173, 141, 0.3)",
  }
},
boxShadow: {
  'inner-light': 'inset 0 1px 2px 0 rgba(0, 0, 0, 0.05)',
  'inner-dark': 'inset 0 1px 0 0 rgba(255, 255, 255, 0.05)',
  'luxe-glow': '0 0 20px -5px rgba(150, 173, 141, 0.4)',
}
```

### 6. CSS Utilities (app.css)

```css
@layer base {
  .luxe-glass {
    @apply bg-white/70 dark:bg-zinc-950/70 backdrop-blur-xl
           border border-luxe-border dark:border-luxe-border-dark;
  }
}

::view-transition-old(tab-pill),
::view-transition-new(tab-pill) {
  animation-duration: 0.35s;
  animation-timing-function: cubic-bezier(0.4, 0, 0.2, 1);
}
```

### 7. Theme State Changes

Rename `coolMode` to `cursorTrail` in `theme.svelte.ts`:
- State property: `cursorTrail: boolean`
- localStorage key: `quickheadlines-cursortrail`
- Toggle function: `toggleCursorTrail()`

This provides a cleaner semantic naming since the polka dot particles are being replaced.
