## 1. Lazy Loading Implementation

- [x] 1.1 Convert TimelineView to support dynamic imports
- [x] 1.2 Update timeline route to use lazy loading for TimelineView
- [x] 1.3 Implement lazy loading for SearchModal component
- [x] 1.4 Update main page to use dynamic import for SearchModal

## 2. Theme CSS Splitting

- [ ] 2.1 Extract base styles from app.css into separate theme-base.css
- [ ] 2.2 Create theme-light.css with light theme specific styles
- [ ] 2.3 Create theme-dark.css with dark theme specific styles  
- [ ] 2.4 Create theme-custom.css with all custom theme styles (matrix, retro80s, ocean, etc.)
- [ ] 2.5 Update theme store to load CSS conditionally based on active theme
- [ ] 2.6 Implement dynamic CSS loading mechanism

## 3. Vite Code Splitting Configuration

- [ ] 3.1 Add manualChunks configuration to vite.config.ts
- [ ] 3.2 Configure vendor-svelte chunk for Svelte core runtime
- [ ] 3.3 Configure vendor-utils chunk for utility libraries (clsx, tailwind-merge, tailwind-variants)
- [ ] 3.4 Configure vendor-bits-ui chunk for Bits-UI components
- [ ] 3.5 Configure vendor-tailwind chunk for Tailwind CSS processing
- [ ] 3.6 Test build output to verify proper chunking

## 4. Testing and Validation

- [ ] 4.1 Verify bundle size reduction (20-30% target)
- [ ] 4.2 Test lazy loading functionality for TimelineView and SearchModal
- [ ] 4.3 Test all theme switching functionality
- [ ] 4.4 Verify all UI components work correctly with Bits-UI maintained
- [ ] 4.5 Run Lighthouse performance tests
- [ ] 4.6 Ensure all existing tests pass

## 5. Documentation and Font Subsetting

- [ ] 5.1 Create font subsetting documentation for future use
- [ ] 5.2 Add vite-plugin-fontsubset configuration example
- [ ] 5.3 Document subsetting to Latin characters only