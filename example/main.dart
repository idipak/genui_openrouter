import 'package:genui/genui.dart';
import 'package:genui_openrouter/genui_openrouter.dart';

void main() async {
  // 1. Define your GenUI Catalog
  final catalog = BasicCatalogItems.asCatalog();

  // 2. Configure the OpenRouter Client
  final config = OpenRouterConfig(
    apiKey: 'YOUR_OPENROUTER_API_KEY',
    siteUrl: 'https://yourportfolio.com',
    siteName: 'My Portfolio',
    defaultModels: ['openai/gpt-3.5-turbo', 'anthropic/claude-2'],
  );

  final client = GenUIOpenRouterClient(
    config: config,
    catalog: catalog,
    systemPromptFragments: ['You are a helpful portfolio assistant.'],
  );

  // 3. Set up GenUI Transport
  final transport = A2uiTransportAdapter(
    onSend: (message) async {
      final stream = client.generateStream(message);
      await for (final chunk in stream) {
        // In a real Flutter app, you'd use transport.addChunk(chunk)
        print('Chunk received: $chunk');
      }
    },
  );

  // 4. Start a Conversation
  final conversation = Conversation(
    controller: SurfaceController(catalogs: [catalog]),
    transport: transport,
  );

  // 5. Send a message
  conversation
      .sendRequest(ChatMessage.user('Tell me about your Flutter skills.'));
}
