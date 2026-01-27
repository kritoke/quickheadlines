---
description: "WP02: Elm Land & Theme Oracle"
lane: "planned"
---

# WP02: Elm Land & Theme Oracle

## Goal
Replace the existing Slang views with an Elm Land project and establish the theme system.

## Actions

### 1. Initialize Elm Land
Create a `ui/` folder and run `elm-land init .`.

### 2. Standard Theme
Create `ui/src/Theme.elm`. Use `darkBg (18,18,18)` and `lumeOrange (255,165,0)`.

### 3. Purge Slang logic
Modify `views/index.slang` to be a bare-bones HTML shell that only loads the Elm `app.js`.

### 4. Layout
Implement `ui/src/Layouts/Shared.elm` using `Element.layout`.

## Definition of Done
The project serves a dark-mode Elm shell instead of the old Slang dashboard.

## Implementation Steps

### Step 1: Initialize Elm Land project
- Create `ui/` directory
- Run `elm-land init .` to scaffold the project
- Review generated files structure

### Step 2: Create Theme.elm
- Create `ui/src/Theme.elm`
- Define color palette:
  - darkBg: Element.rgb255 18 18 18
  - lumeOrange: Element.rgb255 255 165 0
  - textColor: Element.rgb255 255 255 255
- Create helper functions for common styles
- Define metadataStyle for source count and time display

### Step 3: Simplify index.slang
- Keep only basic HTML structure
- Remove any Slang-specific layout logic
- Ensure it loads the Elm app.js properly
- Add meta tags for responsive viewport

### Step 4: Create Shared Layout
- Create `ui/src/Layouts/Shared.elm`
- Use `Element.layout` with Theme styles
- Add header and footer placeholders
- Set up main content area
