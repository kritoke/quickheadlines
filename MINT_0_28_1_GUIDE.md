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
  fun render : Html {
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

## Dynamic Text (CRITICAL - SYNTAX)

### ✅ CORRECT: Use { } for String Values
```mint
/* String values in HTML content */
<div>{ name }</div>

/* Dynamic style values */
<div style="color: {color}">Text</div>

/* Static string with quotes */
<div>{"QuickHeadlines"}</div>
```

### ❌ WRONG (causes HTML_ELEMENT_EXPECTED_CLOSING_TAG)
```mint
/* <{ }> syntax does NOT work */
<{ name }>
<{"Text"}>
```

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
  fun render : Html {
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

### Error: `HTML_ELEMENT_EXPECTED_CLOSING_TAG` with `<{ }>`

**Cause:** Using wrong syntax for dynamic text.

**Fix:** Use `{ }` instead of `<{ }>`:
```mint
/* CORRECT */
<div>{ name }</div>

/* WRONG - causes error */
<div><{ name }></div>
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
5. [ ] Component uses `fun render : Html { }`
6. [ ] Dynamic text uses `{ variable }` NOT `<{ variable }>`
7. [ ] State changes use `next` keyword
8. [ ] Deleted `.mint` and `mint-packages.json` after schema changes
9. [ ] Ran `mint install` after cache deletion

---

## Verified Working Patterns (QuickHeadlines Production Code)

### Component Structure
```mint
component Main {
  fun render : Html {
    <div>Content</div>
  }
}
```

### Properties
```mint
component FeedCard {
  property item : TimelineItem

  fun render : Html {
    <div>{ item.title }</div>
  }
}
```

### State
```mint
component Timeline {
  state items : Array(TimelineItem) = []
  state loading : Bool = False

  fun loadItems : Promise(Void) {
    next loading = True
    next items = []
  }
}
```

### Dynamic Text in HTML
```mint
/* String variable */
<div>{ item.title }</div>

/* Static string with quotes */
<div>{"QuickHeadlines"}</div>

/* Property access */
<div>{ source.name }</div>
```

### Dynamic Styles
```mint
/* Inline style with variable */
<div style="background-color: {item.headerColor}">
  Content
</div>

/* Multiple dynamic values */
<img src={item.favicon} alt={item.feedTitle}/>
```

### For Loops
```mint
/* Rendering array items */
for article of source.articles {
  <FeedCard item={article}/>
}
```

### Style Blocks
```mint
style base {
  background: #272729;
  border: 1px solid #343536;
  border-radius: 8px;
  display: flex;
  flex-direction: column;
  height: 500px;
  overflow: hidden;
}

/* Media queries */
@media (max-width: 1100px) {
  grid-template-columns: repeat(2, 1fr);
}
```

### CSS Classes with :: Syntax
```mint
<div::box data-name="feed-box">
  Content
</div>
```

---

## Verified Non-Working Patterns

### Dynamic Text
```mint
/* ❌ FAILS with HTML_ELEMENT_EXPECTED_CLOSING_TAG */
<{ name }>
<{"Text"}>
#{ name }
```

### Style Interpolation in CSS
```mint
/* ❌ FAILS */
color: #{variable};
background: #{if theme == Dark { "black" } else { "white" }};
```

### Render Function Shorthand
```mint
/* ❌ FAILS - requires fun return type */
render {
  <div>Content</div>
}
```

### Store Connection Syntax
```mint
/* ❌ FAILS - different pattern required */
connect FeedStore exposing { theme }
```

---

## QuickHeadlines Component Examples

### FeedCard Component (Working)
```mint
component FeedCard {
  property item : TimelineItem

  style base {
    display: flex;
    gap: 12px;
    padding: 16px;
    background: #ffffff;
    border-radius: 8px;
  }

  style favicon-container {
    flex-shrink: 0;
    width: 40px;
    height: 40px;
    border-radius: 6px;
  }

  style content {
    flex: 1;
    min-width: 0;
  }

  style title {
    font-size: 16px;
    font-weight: 600;
    color: #111827;
  }

  style meta {
    font-size: 12px;
    color: #9ca3af;
  }

  fun render : Html {
    <a href={item.link} target="_blank" rel="noopener noreferrer">
      <div::base>
        <div::favicon-container style="background-color: {item.headerColor}">
          <img::favicon src={item.favicon} alt={item.feedTitle}/>
        </div>
        <div::content>
          <h3::title>
            { item.title }
          </h3>
          <div::meta>
            { item.pubDate }
          </div>
        </div>
      </div>
    </a>
  }
}
```

### FeedBox Component (Working)
```mint
component FeedBox {
  property source : FeedSource

  style box {
    background: #272729;
    border: 1px solid #343536;
    border-radius: 8px;
    display: flex;
    flex-direction: column;
    height: 500px;
    overflow: hidden;
  }

  style header {
    padding: 12px;
    font-weight: bold;
    border-bottom: 1px solid #343536;
    background: #1a1a1b;
  }

  style itemsList {
    flex: 1;
    overflow-y: auto;
  }

  fun render : Html {
    <div::box data-name="feed-box">
      <div::header>
        { source.name }
      </div>
      <div::itemsList>
        for article of source.articles {
          <FeedCard item={article}/>
        }
      </div>
    </div>
  }
}
```

### FeedGrid with Responsive Layout (Working)
```mint
component FeedGrid {
  property feeds : Array(FeedSource)

  style gridContainer {
    display: grid;
    gap: 20px;
    padding: 20px;
    height: calc(100vh - 80px);
    overflow-y: auto;
    position: relative;
    grid-template-columns: repeat(3, 1fr);

    @media (max-width: 1100px) {
      grid-template-columns: repeat(2, 1fr);
    }

    @media (max-width: 700px) {
      grid-template-columns: 1fr;
    }
  }

  style bottomShadow {
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    height: 60px;
    pointer-events: none;
    z-index: 100;
    background: linear-gradient(transparent, rgba(0,0,0,0.8));
  }

  fun render : Html {
    <div::gridContainer data-name="feed-grid-root">
      for feed of feeds {
        <FeedBox source={feed}/>
      }
      <div::bottomShadow/>
    </div>
  }
}
```

---

## Syntax Summary Table

| What | Syntax | Example |
|------|--------|---------|
| Render function | `fun render : Html { }` | `fun render : Html { <div>Text</div> }` |
| String variable | `{ variable }` | `{ item.title }` |
| Static string | `{"text"}` | `{"QuickHeadlines"}` |
| Property access | `{ object.property }` | `{ source.name }` |
| Inline style | `style="prop: {val}"` | `style="color: {color}"` |
| Style reference | `::styleName` | `<div::base>` |
| For loop | `for item of array { }` | `for article of articles { }` |
| CSS block | `style name { }` | `style base { color: red; }` |
| Media query | `@media (max-width) { }` | `@media (max-width: 700px) { ... }` |
| State change | `next state = value` | `next loading = True` |

---

## Last Updated

February 10, 2026 - Mint 0.28.1

## Contributors

- QuickHeadlines Team
- Based on guidance from mint-lang/mint-website repository
- Verified with production QuickHeadlines code
