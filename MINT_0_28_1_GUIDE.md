# Mint 0.28.1 Configuration Guide

> **Warning:** AI models default to older Mint schemas (0.10.0 - 0.21.0) from training data. Mint 0.28.1 has significant breaking changes that are not well-documented online.

This guide provides the correct Mint 0.28.1 patterns for QuickHeadlines.

---

## Table of Contents

1. [mint.json Schema](#mintjson-schema)
2. [Component Structure](#component-structure)
3. [State Management](#state-management)
4. [Lifecycle Hooks](#lifecycle-hooks)
5. [Mint UI Integration](#mint-ui-integration)
6. [Common Errors](#common-errors)
7. [Reference Projects](#reference-projects)

---

## mint.json Schema

### ❌ WRONG (Deprecated Schema)
```json
{
  "name": "quickheadlines",
  "application": {
    "start": "Main"
  },
  "source": "source"
}
```

### ✅ CORRECT (Mint 0.28.1 Schema)
```json
{
  "name": "quickheadlines",
  "source-directories": ["source"],
  "dependencies": {
    "mint-ui": {
      "repository": "https://github.com/mint-lang/mint-ui",
      "constraint": "1.0.0 <= v < 2.0.0"
    }
  }
}
```

### Key Changes

| Old Key | New Key | Notes |
|---------|----------|-------|
| `application.start` | **REMOVED** | Entry point is now implicit |
| `source` | `source-directories` | Must be an array |
| `dependencies.version` | `dependencies.repository` + `dependencies.constraint` | New format |

---

## Component Structure

### ❌ WRONG
```mint
component Main {
  store FeedStore
  fun init : Void {
    this.store.init()
  }
  fun render : Html {
    <div>Hello</div>
  }
}
```

### ✅ CORRECT (Minimal Main.mint)
```mint
component Main {
  render {
    <div>QuickHeadlines</div>
  }
}
```

### Key Rules

1. **No explicit store declaration** - stores are connected differently
2. **No init function needed** - render is auto-called
3. **No lifecycle hooks required** for basic components
4. **Entry point is implicit** - component named `Main` in `source-directories`

---

## Dynamic Text (CRITICAL - SYNTAX ISSUES)

### ⚠️ KNOWN ISSUE: <{ }> and #{ } Do Not Work
In this Mint 0.28.1 build, the documented dynamic text syntax fails:

```mint
/* FAILS with "HTML_ELEMENT_EXPECTED_CLOSING_TAG" */
<{ name }>
#{color}

/* WORKS */
<div>Text</div>
```

**Current Workaround:** Use plain text only in components.

### State Management

### ❌ WRONG (Mutation)
```mint
this.loading = True
this.items = newItems
```

### ✅ CORRECT (Use `next` keyword)
```mint
next loading = True
next items = newItems
```

### Store Pattern (Mint 0.28.1)
```mint
store FeedStore {
  state items : Array(Item) = []
  state loading : Bool = False

  fun loadItems : Void {
    next loading = True
    # ... API call ...
    next loading = False
    next items = response.items
  }
}
```

---

## Lifecycle Hooks

### ❌ WRONG
```mint
Browser.Dom.onReady { || doSomething() }
```

### ✅ CORRECT

For Mint 0.28.1, use **minimal component structure**:
```mint
component Main {
  render {
    <div>Content</div>
  }
}
```

No lifecycle hooks are needed for basic rendering. The `render` function is automatically called.

---

## Mint UI Integration

### ❌ WRONG
```mint
<div style="font-family: sans-serif;">
  <Ui.Button>Click</Ui.Button>
</div>
```

### ✅ CORRECT
```mint
component Main {
  style base {
    font-family: "Inter var", sans-serif;
    padding: 20px;
  }

  render {
    <div::base>
      <Ui.Theme.Root theme={Ui.Themes:Light}>
        <Ui.Typography.Heading size={1}>
          "QuickHeadlines"
        </Ui.Typography.Heading>

        <Ui.Button
          label="Test"
          onClick={fun (event : Html.Event) { Debug.log("Clicked!") }}
        />
      </Ui.Theme.Root>
    </div>
  }
}
```

### Key Patterns

1. **Use `::base` syntax** for style references
2. **Use `Ui.Theme.Root`** for theming
3. **Use `Ui.Typography.*** for typography
4. **Use `Ui.Button`** with `label` and `onClick` props
5. **Callback format:** `fun (event : Html.Event) { ... }`

---

## Common Errors

### Error: `HTML_ELEMENT_EXPECTED_CLOSING_TAG` with <{ }>

**Cause:** Dynamic text syntax not working in this Mint 0.28.1 build.

**Workaround:** Use plain text only. Do not use:
- `<{ variable }>` for dynamic text
- `#{ variable }` for style interpolation

```mint
/* WORKS */
<div>Feed</div>

/* FAILS */
<div><{ name }></div>
<div style="color: #{color}">Text</div>
```

### Error: `APPLICATION_INVALID_KEY: start`

**Cause:** Using deprecated `application.start` key.

**Fix:**
```bash
# Delete cached files
cd frontend
rm -rf .mint mint-packages.json

# Recreate mint.json (flat structure only)
{
  "name": "quickheadlines",
  "source-directories": ["source"],
  "dependencies": { ... }
}

mint install
```

### Error: `CONSTANT_EXPECTED_EXPRESSION: {`

**Cause:** Using old JSON or Mint syntax.

**Fix:** Ensure `mint.json` has no nested `application` block with `start` key.

### Error: `FUNCTION_EXPECTED_CLOSING_BRACKET`

**Cause:** Incorrect callback or closure syntax.

**Fix:** Use minimal component structure first:
```mint
component Main {
  fun render : Html {
    <div>Hello</div>
  }
}
```

---

## Reference Projects

### Primary Reference (Ground Truth)
- **mint-lang/mint-website** - Official website, always uses latest patterns
- URL: https://github.com/mint-lang/mint-website

### Example Projects
- **mint-lang/mint-realworld** - Conduit clone implementation
- URL: https://github.com/mint-lang/mint-realworld

### Quick Reference: mint.json
```json
{
  "name": "project-name",
  "source-directories": ["source"],
  "dependencies": {
    "mint-ui": {
      "repository": "https://github.com/mint-lang/mint-ui",
      "constraint": "1.0.0 <= v < 2.0.0"
    }
  }
}
```

---

## Guardrail for AI Agents

> Copy this into OpenSpec prompts to prevent schema errors:

```
Guardrail: Mint 0.28.1 Configuration
- NO NESTING: mint.json must remain "flat"
- FORBIDDEN KEYS: Never use "application.start", "source" (singular)
- USE: "source-directories" (plural array), "dependencies" with "repository" and "constraint"
- FILE DELETION: If compiler mentions "invalid key: start", delete frontend/.mint and frontend/mint-packages.json before retrying
- ENTRY POINT: Implicit - component named "Main" in source-directories
- STATE: Use "next" keyword for state changes, not mutation
- REFERENCE: Use github.com/mint-lang/mint-website as absolute template
```

---

## Commands Reference

### Clean Cache and Rebuild
```bash
cd frontend
rm -rf .mint mint-packages.json
mint install
mint build --optimize
```

### Development Mode
```bash
cd frontend
mint serve
```

### Format Code
```bash
cd frontend
mint format source/
```

---

## Troubleshooting Checklist

1. [ ] `mint.json` uses flat structure (no `application.start`)
2. [ ] `source-directories` is plural and an array
3. [ ] Dependencies use `repository` + `constraint` format
4. [ ] Component is named `Main` in `source-directories`
5. [ ] Component uses `render` function (not `init`)
6. [ ] State changes use `next` keyword
7. [ ] Deleted `.mint` and `mint-packages.json` after schema changes
8. [ ] Ran `mint install` after cache deletion

---

## Last Updated

February 10, 2026 - Mint 0.28.1

## Contributors

- QuickHeadlines Team
- Based on guidance from mint-lang/mint-website repository
