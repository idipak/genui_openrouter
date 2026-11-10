## Unreleased

* **Breaking:** move from `genui` to the A2UI Dart SDKs, since `genui` will
  be deprecated. The package now depends on `a2ui_core`, `a2ui_agent` and
  `genai_primitives` instead of `genui`, and no longer needs Flutter.
  * `GenUIOpenRouterClient` takes an `a2ui_core` `CatalogApi`, such as an
    `a2ui_flutter` `CatalogImplementation`, instead of a genui `Catalog`.
  * The system prompt comes from `a2ui_agent` instead of genui's
    `PromptBuilder.chat`, and asks for A2UI JSON in `<a2ui-json>` blocks
    instead of markdown fences. genui's `A2uiTransportAdapter` cannot read
    these replies: read the chunks of `generateStream` with a stream from the
    new `requestProcessor`, as the README shows.
  * `ChatMessage` and `ChatMessageRole` come from `genai_primitives`, and
    this package re-exports them.

## 0.1.0

* Initial release of the OpenRouter GenUI client.
* Added streaming support and GenUI catalog compatibility.