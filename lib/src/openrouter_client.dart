import 'dart:convert';
import 'package:a2ui_agent/a2ui_agent.dart';
import 'package:a2ui_core/a2ui_core.dart';
import 'package:genai_primitives/genai_primitives.dart'
    show ChatMessage, ChatMessageRole;
import 'package:http/http.dart' as http;
import 'openrouter_config.dart';

/// An A2UI client for OpenRouter.
///
/// This client handles streaming responses, model fallbacks, and
/// advanced parameter configuration. Its system prompt teaches the model
/// an A2UI catalog, and [requestProcessor] reads the model's replies back
/// into A2UI messages for a renderer.
class GenUIOpenRouterClient {
  final OpenRouterConfig config;

  /// Prompts the model for the catalog and parses its replies.
  ///
  /// For each reply, open a stream with
  /// `requestProcessor.openContinuingStream()`, feed it the chunks of
  /// [generateStream], and pass the A2UI messages it returns to an A2UI
  /// `MessageProcessor`. Each reply creates new surfaces, so it is checked on
  /// its own.
  final A2uiRequestProcessor requestProcessor;

  final http.Client _httpClient;
  final List<String> _systemPromptFragments;

  /// Creates a new [GenUIOpenRouterClient].
  ///
  /// [catalog] is the A2UI catalog the model builds UI from, such as
  /// `a2ui_flutter`'s `v0_9.basicCatalog()`. Replies use the A2UI protocol
  /// version the catalog targets, or v0.9 if it targets none.
  /// [systemPromptFragments] defines the assistant's persona.
  GenUIOpenRouterClient({
    required this.config,
    required CatalogApi catalog,
    List<String> systemPromptFragments = const [],
    http.Client? httpClient,
  })  : _httpClient = httpClient ?? http.Client(),
        _systemPromptFragments = systemPromptFragments,
        requestProcessor = A2uiGenerator(
          catalogs: [CatalogConfig(catalog)],
          inferenceFormatFactory: const DirectJsonFormatFactory(
            allowedMessages: ['createSurface', 'updateComponents'],
            bufferIncompleteComponents: true,
          ),
        ).createProcessor(
          A2uiRendererCapabilities.forCatalogIds(
            [catalog.id],
            version: catalog.protocolVersion ?? A2uiProtocolVersion.v0_9,
          ),
        );

  late final String _systemPrompt = [
    ..._systemPromptFragments,
    'IMPORTANT: DO NOT update or modify surfaces created in previous turns. '
        'If the UI needs to change, you MUST create a NEW surface with a new '
        'unique `surfaceId`. You may only use `updateComponents` to populate '
        'the components of a freshly created surface.',
    requestProcessor.promptSnippet,
  ].map((fragment) => fragment.trim()).join('\n\n');

  /// Maps chat message roles to OpenRouter roles.
  String _mapRole(ChatMessageRole role) {
    return switch (role) {
      ChatMessageRole.system => 'system',
      ChatMessageRole.user => 'user',
      ChatMessageRole.model => 'assistant',
    };
  }

  /// Builds the message payload for the OpenRouter API.
  List<Map<String, dynamic>> _buildMessages(
    ChatMessage newMessage,
    List<ChatMessage> history,
  ) {
    final messages = <Map<String, dynamic>>[];

    // System prompt with the A2UI instructions
    messages.add({
      'role': 'system',
      'content': _systemPrompt,
    });

    // History
    for (final msg in history) {
      messages.add({
        'role': _mapRole(msg.role),
        'content': msg.text,
      });
    }

    // New message
    messages.add({
      'role': _mapRole(newMessage.role),
      'content': newMessage.text,
    });

    return messages;
  }

  /// Generates a stream of text chunks from OpenRouter.
  ///
  /// The chunks are the model's reply as written, A2UI blocks included. Read
  /// them into text and A2UI messages with a stream from [requestProcessor].
  ///
  /// [models] overrides the default models in [config].
  /// [params] allows fine-tuning the LLM output.
  Stream<String> generateStream(
    ChatMessage newMessage, {
    List<ChatMessage> history = const [],
    List<String>? models,
    OpenRouterParameters? params,
  }) async* {
    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

    final headers = {
      'Authorization': 'Bearer ${config.apiKey}',
      'Content-Type': 'application/json',
      if (config.siteUrl != null) 'HTTP-Referer': config.siteUrl!,
      if (config.siteName != null) 'X-Title': config.siteName!,
    };

    final body = {
      'models': models ?? config.defaultModels,
      'messages': _buildMessages(newMessage, history),
      'stream': true,
      if (!config.allowFallbacks)
        'route':
            'fallback', // OpenRouter default is 'fallback' if multiple models
      ...?params?.toJson(),
    };

    final request = http.Request('POST', url)
      ..headers.addAll(headers)
      ..body = jsonEncode(body);

    try {
      final response = await _httpClient.send(request);

      if (response.statusCode != 200) {
        final errorBody = await response.stream.transform(utf8.decoder).join();
        throw OpenRouterException(
          message: 'OpenRouter API Error',
          statusCode: response.statusCode,
          body: errorBody,
        );
      }

      final stream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in stream) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6).trim();
          if (data == '[DONE]') break;
          if (data.isEmpty) continue;

          try {
            final json = jsonDecode(data);
            final content = json['choices']?[0]?['delta']?['content'];
            if (content != null) {
              yield content;
            }
          } catch (_) {
            // Ignore malformed chunks
          }
        }
      }
    } catch (e) {
      if (e is OpenRouterException) rethrow;
      throw OpenRouterException(message: e.toString());
    }
  }

  /// Closes the underlying HTTP client.
  void dispose() {
    _httpClient.close();
  }
}

/// Specialized exception for OpenRouter-related errors.
class OpenRouterException implements Exception {
  final String message;
  final int? statusCode;
  final String? body;

  OpenRouterException({required this.message, this.statusCode, this.body});

  @override
  String toString() {
    return 'OpenRouterException: $message (Status: $statusCode, Body: $body)';
  }
}
