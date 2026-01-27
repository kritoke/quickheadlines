---
description: "WP02: Elm Land & Theme Oracle"
lane: "planned"
---

# WP02: Elm Land & Theme Oracle

## Constitutional Requirements
> **Reference:** QuickHeadlines Constitution v1.1.0
> - **Environment:** All commands MUST use `nix develop --command <command>`
> - **Styling:** ALL Elm Land UI MUST use `elm-ui` (`mdgriffith/elm-ui`). **Strictly Forbidden:** `Html`, `Html.Attributes`, `class` tags, and Tailwind/CSS frameworks.

## Goal
Replace the existing Slang views with an Elm Land project and establish the theme system.

## Actions

### 1. Initialize Elm Land
Create a `ui/` folder and run `nix develop --command elm-land init .`.

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
- Run `nix develop --command elm-land init .` to scaffold the project
- Review generated files structure

### Step 2: Create Theme.elm
- Create `ui/src/Theme.elm`
- **Strictly use `elm-ui` (`mdgriffith/elm-ui`)** - NO `Html`, NO Tailwind, NO CSS frameworks
- Define color palette using `Element.rgb255`:
  - darkBg: `Element.rgb255 18 18 18`
  - lumeOrange: `Element.rgb255 255 165 0`
  - textColor: `Element.rgb255 255 255 255`
- Create helper functions using `Element` primitives only
- Define metadataStyle for source count and time display using `Element.text`

### Step 3: Simplify index.slang
- Keep only basic HTML structure
- Remove any Slang-specific layout logic
- Ensure it loads the Elm app.js properly
- Add meta tags for responsive viewport

### Step 4: Create Shared Layout
- Create `ui/src/Layouts/Shared.elm`
- **Use `Element.layout` with Theme styles** - NO `Html.div`, NO `Html.node`
- Add header and footer placeholders using `Element.row` and `Element.column`
- Set up main content area using `Element.el`
