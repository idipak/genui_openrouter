# GenUI OpenRouter

A powerful, streaming-first OpenRouter client for the [GenUI](https://pub.dev/packages/genui) ecosystem.

## Features

- **Streaming Support**: Native SSE streaming integration with GenUI Transport.
- **Model Fallbacks**: Easily configure multiple models to ensure high availability.
- **GenUI Component Aware**: Automatically handles system prompts based on your `Catalog`.
- **Advanced LLM Parameters**: Full support for temperature, top_p, frequency penalty, etc.
- **Compliance**: Built-in support for OpenRouter's recommended headers (`HTTP-Referer`, `X-Title`).

## Getting Started

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  genui_openrouter: ^0.1.0
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

### 2. Connect to GenUI Transport

```dart
final transport = A2uiTransportAdapter(
  onSend: (message) async {
    final stream = client.generateStream(
      message,
      params: OpenRouterParameters(temperature: 0.7),
    );
    
    await for (final chunk in stream) {
      transport.addChunk(chunk);
    }
  },
);
```

### 3. Dispose

Remember to dispose of the client when no longer needed:

```dart
@override
void dispose() {
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
