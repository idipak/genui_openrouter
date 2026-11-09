# GenUI OpenRouter

A powerful, streaming-first OpenRouter client for [A2UI](https://a2ui.org) generative UI.

## Features

- **Streaming Support**: Native SSE streaming that [`a2ui_agent`](https://pub.dev/packages/a2ui_agent) reads into A2UI messages as it arrives.
- **Model Fallbacks**: Easily configure multiple models to ensure high availability.
- **A2UI Component Aware**: Automatically handles system prompts based on your A2UI catalog.
- **Advanced LLM Parameters**: Full support for temperature, top_p, frequency penalty, etc.
- **Compliance**: Built-in support for OpenRouter's recommended headers (`HTTP-Referer`, `X-Title`).

## Getting Started

Add the package to your `pubspec.yaml`, together with the A2UI packages that read the replies ([`a2ui_agent`](https://pub.dev/packages/a2ui_agent)) and render them in Flutter ([`a2ui_core`](https://pub.dev/packages/a2ui_core) and [`a2ui_flutter`](https://pub.dev/packages/a2ui_flutter)):

```yaml
dependencies:
  genui_openrouter: ^0.1.0
  a2ui_agent: ^0.1.0
  a2ui_core: ^0.5.0
  a2ui_flutter: ^0.1.0
```

## Usage

### 1. Initialize the Client

```dart
final config = OpenRouterConfig(
  apiKey: 'YOUR_API_KEY',
  siteUrl: 'https://myapp.com',
  siteName: 'My App',
  defaultModels: ['openai/gpt-3.5-turbo', 'google/palm-2-chat-bison'],
);

final client = GenUIOpenRouterClient(
  config: config,
  catalog: myCatalog,
  systemPromptFragments: ['You are a helpful assistant.'],
);
```

`myCatalog` is an A2UI catalog, such as `basicCatalog()` from `package:a2ui_flutter/v0_9/basic_catalog.dart`. The model writes A2UI v0.9 unless the catalog targets another protocol version.

### 2. Read the Reply

`generateStream` yields the model's reply as written. Read it into text and A2UI messages with a stream from `client.requestProcessor`, and pass the messages to a `MessageProcessor`:

```dart
import 'package:a2ui_agent/a2ui_agent.dart';
import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:genui_openrouter/genui_openrouter.dart';

final processor = MessageProcessor<ComponentImplementation>(
  catalogs: [myCatalog],
  validationConfig: ValidationConfig.relaxed,
  reportErrorsOnly: true,
);

Future<void> send(String message) async {
  final reply = client.requestProcessor.openContinuingStream();
  void deliver(List<StreamPart> parts) {
    for (final part in parts) {
      switch (part) {
        case TextPart(:final text):
          print(text); // Show the text in your chat UI.
        case A2uiPart(:final a2ui):
          processor.processMessages(AgentToRendererMessagePayload(a2ui));
        case ErrorPart(:final error):
          print('A2UI block rejected: ${error.message}');
      }
    }
  }

  final stream = client.generateStream(
    ChatMessage.user(message),
    params: OpenRouterParameters(temperature: 0.7),
  );
  try {
    await for (final chunk in stream) {
      deliver(reply.feed(chunk));
    }
    deliver(reply.close());
  } on A2uiError catch (error) {
    // The reply cannot be read further.
    deliver(error.partialResults);
  }
}
```

Each reply creates new surfaces. Render each surface that `processor.model.onSurfaceCreated` reports with `A2uiSurface(key: ObjectKey(surface), surface: surface)` from `a2ui_flutter`.

### 3. Dispose

Remember to dispose of the client when no longer needed:

```dart
@override
void dispose() {
  processor.dispose();
  client.dispose();
  super.dispose();
}
```

## Advanced Parameters

The `OpenRouterParameters` class allows you to control the LLM's behavior:

- `temperature`: Controls randomness (0.0 to 2.0).
- `maxTokens`: Maximum length of the generated response.
- `seed`: For deterministic outputs.
- `stop`: List of sequences that stop generation.

## License

MIT
