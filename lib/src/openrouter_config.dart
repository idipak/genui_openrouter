/// Configuration for the OpenRouter client.
class OpenRouterConfig {
  /// Your OpenRouter API key.
  final String apiKey;

  /// Optional: URL of your site for OpenRouter rankings.
  final String? siteUrl;

  /// Optional: Name of your site for OpenRouter rankings.
  final String? siteName;

  /// Default models to use if none are specified in the request.
  final List<String> defaultModels;

  /// Whether to allow fallbacks to other models.
  final bool allowFallbacks;

  const OpenRouterConfig({
    required this.apiKey,
    this.siteUrl,
    this.siteName,
    this.defaultModels = const ['openai/gpt-3.5-turbo'],
    this.allowFallbacks = true,
  });
}

/// Parameters for fine-tuning the LLM response.
class OpenRouterParameters {
  final double? temperature;
  final int? maxTokens;
  final double? topP;
  final int? topK;
  final double? frequencyPenalty;
  final double? presencePenalty;
  final double? repetitionPenalty;
  final int? seed;
  final List<String>? stop;

  const OpenRouterParameters({
    this.temperature,
    this.maxTokens,
    this.topP,
    this.topK,
    this.frequencyPenalty,
    this.presencePenalty,
    this.repetitionPenalty,
    this.seed,
    this.stop,
  });

  Map<String, dynamic> toJson() {
    return {
      if (temperature != null) 'temperature': temperature,
      if (maxTokens != null) 'max_tokens': maxTokens,
      if (topP != null) 'top_p': topP,
      if (topK != null) 'top_k': topK,
      if (frequencyPenalty != null) 'frequency_penalty': frequencyPenalty,
      if (presencePenalty != null) 'presence_penalty': presencePenalty,
      if (repetitionPenalty != null) 'repetition_penalty': repetitionPenalty,
      if (seed != null) 'seed': seed,
      if (stop != null) 'stop': stop,
    };
  }
}
