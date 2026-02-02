## 5. Semantic Metadata Standard
* **No Class Overrides:** Do not attempt to override generated `elm-ui` classes.
* **Semantic Hooks:** Every major layout component MUST have a `Theme.semantic` attribute.
* **Testing IDs:** Use `data-name` attributes for elements that require automated tracking or agent interaction.
* **Aria/Region:** Use `Element.Region` primitives (heading, navigation, mainContent) instead of generic `el` for top-level structures.
