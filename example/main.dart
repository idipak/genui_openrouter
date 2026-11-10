import 'package:a2ui_agent/a2ui_agent.dart';
import 'package:a2ui_core/a2ui_core.dart';
import 'package:genui_openrouter/genui_openrouter.dart';

void main() async {
  // 1. Define your A2UI Catalog
  // In a Flutter app, you'd use a2ui_flutter's v0_9.basicCatalog()
  final catalog = BasicCatalog.v0_9();

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

  // 3. Set up an A2UI MessageProcessor
  // In a real Flutter app, you'd render each surface with A2uiSurface
  final processor = MessageProcessor<ComponentApi>(
    catalogs: [catalog],
    validationConfig: ValidationConfig.relaxed,
    reportErrorsOnly: true,
  );
  processor.model.onSurfaceCreated.subscribe((surface) {
    print('Surface created: ${surface.id}');
  });

  // 4. Read the reply into text and A2UI messages
  final reply = client.requestProcessor.openContinuingStream();
  void deliver(List<StreamPart> parts) {
    for (final part in parts) {
      switch (part) {
        case TextPart(:final text):
          print('Text received: $text');
        case A2uiPart(:final a2ui):
          processor.processMessages(AgentToRendererMessagePayload(a2ui));
        case ErrorPart(:final error):
          print('A2UI block rejected: ${error.message}');
      }
    }
  }

  // 5. Send a message
  final stream = client
      .generateStream(ChatMessage.user('Tell me about your Flutter skills.'));
  try {
    await for (final chunk in stream) {
      deliver(reply.feed(chunk));
    }
    deliver(reply.close());
  } on A2uiError catch (error) {
    // The reply was rejected and has ended
    deliver(error.partialResults);
    print('Reply rejected: ${error.message}');
  }
}
