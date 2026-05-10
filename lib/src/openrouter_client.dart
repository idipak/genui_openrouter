import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:genui/genui.dart';
import 'openrouter_config.dart';

/// A GenUI-compatible client for OpenRouter.
///
/// This client handles streaming responses, model fallbacks, and
/// advanced parameter configuration while integrating seamlessly with
/// GenUI's PromptBuilder and Transport architecture.
class GenUIOpenRouterClient {
  final OpenRouterConfig config;
  final http.Client _httpClient;
  final PromptBuilder _promptBuilder;

  /// Creates a new [GenUIOpenRouterClient].
  ///
  /// [catalog] is required for GenUI component-aware prompting.
  /// [systemPromptFragments] defines the assistant's persona.
  GenUIOpenRouterClient({
    required this.config,
    required Catalog catalog,
    List<String> systemPromptFragments = const [],
    http.Client? httpClient,
  })  : _httpClient = httpClient ?? http.Client(),
        _promptBuilder = PromptBuilder.chat(
          catalog: catalog,
          systemPromptFragments: systemPromptFragments,
        );

  /// Maps GenUI roles to OpenRouter roles.
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

    // System prompt from GenUI
    messages.add({
      'role': 'system',
      'content': _promptBuilder.systemPromptJoined(),
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
