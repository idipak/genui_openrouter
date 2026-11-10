import 'dart:convert';

import 'package:a2ui_agent/a2ui_agent.dart';
import 'package:a2ui_core/a2ui_core.dart';
import 'package:genui_openrouter/genui_openrouter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// An HTTP client that answers every request with [chunks] as OpenRouter
/// stream events, and passes the decoded request body to [onRequest].
http.Client _replyWith(
  List<String> chunks, {
  void Function(Map<String, dynamic> body)? onRequest,
}) {
  return MockClient.streaming((request, bodyStream) async {
    onRequest?.call(
      jsonDecode(await bodyStream.bytesToString()) as Map<String, dynamic>,
    );
    final events = [
      for (final chunk in chunks)
        'data: ${jsonEncode({
              'choices': [
                {
                  'delta': {'content': chunk}
                }
              ]
            })}\n\n',
      'data: [DONE]\n\n',
    ];
    return http.StreamedResponse(
      Stream.fromIterable(events.map(utf8.encode)),
      200,
    );
  });
}

/// Reads [chunks] the way the README shows, with a stream from the client's
/// request processor.
List<StreamPart> _read(GenUIOpenRouterClient client, List<String> chunks) {
  final reply = client.requestProcessor.openContinuingStream();
  return [
    for (final chunk in chunks) ...reply.feed(chunk),
    ...reply.close(),
  ];
}

void main() {
  test('sends the A2UI system prompt before the conversation', () async {
    late Map<String, dynamic> body;
    final client = GenUIOpenRouterClient(
      config: const OpenRouterConfig(apiKey: 'key'),
      catalog: BasicCatalog.v0_9(),
      systemPromptFragments: ['You are a helpful assistant.'],
      httpClient: _replyWith(const [], onRequest: (b) => body = b),
    );
    addTearDown(client.dispose);

    await client.generateStream(
      ChatMessage.user('Show me a form.'),
      history: [ChatMessage.user('Hi'), ChatMessage.model('Hello!')],
    ).drain<void>();

    final messages = (body['messages'] as List).cast<Map<String, dynamic>>();
    expect(
      messages.map((m) => m['role']),
      ['system', 'user', 'assistant', 'user'],
    );
    final system = messages.first['content'] as String;
    expect(system, startsWith('You are a helpful assistant.'));
    expect(
      system,
      contains('DO NOT update or modify surfaces created in previous turns'),
    );
    expect(system, contains(client.requestProcessor.promptSnippet));
    expect(system, contains('<a2ui-json>'));
    expect(system, contains(BasicCatalog.v0_9Id));
  });

  test('streams a reply that the request processor reads into A2UI messages',
      () async {
    final catalog = BasicCatalog.v0_9();
    final reply = 'Here is your card.\n<a2ui-json>${jsonEncode([
          {
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'card',
              'catalogId': BasicCatalog.v0_9Id,
            },
          },
          {
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'card',
              'components': [
                {'id': 'root', 'component': 'Text', 'text': 'Hello'},
              ],
            },
          },
        ])}</a2ui-json>';
    final client = GenUIOpenRouterClient(
      config: const OpenRouterConfig(apiKey: 'key'),
      catalog: catalog,
      httpClient: _replyWith([
        for (var i = 0; i < reply.length; i += 16)
          reply.substring(i, i + 16 > reply.length ? reply.length : i + 16),
      ]),
    );
    addTearDown(client.dispose);

    final chunks =
        await client.generateStream(ChatMessage.user('Show a card.')).toList();
    expect(chunks.join(), reply);

    final parts = _read(client, chunks);
    expect(
      parts.whereType<TextPart>().map((part) => part.text).join(),
      contains('Here is your card.'),
    );
    expect(parts.whereType<ErrorPart>(), isEmpty);
    final messages = [
      for (final part in parts.whereType<A2uiPart>()) ...part.a2ui,
    ];
    expect(messages, [
      isA<CreateSurfaceMessage>(),
      isA<UpdateComponentsMessage>(),
    ]);

    final processor = MessageProcessor<ComponentApi>(catalogs: [catalog]);
    addTearDown(processor.dispose);
    processor.processMessages(AgentToRendererMessagePayload(messages));
    expect(processor.model.getSurface('card'), isNotNull);
  });

  test('rejects a reply that updates a surface of an earlier turn', () {
    final client = GenUIOpenRouterClient(
      config: const OpenRouterConfig(apiKey: 'key'),
      catalog: BasicCatalog.v0_9(),
      httpClient: _replyWith(const []),
    );
    addTearDown(client.dispose);

    final parts = _read(client, [
      '<a2ui-json>${jsonEncode([
            {
              'version': 'v0.9',
              'updateComponents': {
                'surfaceId': 'earlier',
                'components': [
                  {'id': 'root', 'component': 'Text', 'text': 'Changed'},
                ],
              },
            },
          ])}</a2ui-json>',
    ]);

    expect(parts.whereType<A2uiPart>(), isEmpty);
    expect(
      parts.whereType<ErrorPart>().single.error,
      isA<A2uiIntegrityError>(),
    );
  });
}
