import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Azure AI Foundry connection settings.
/// Stored in the platform secure store (Android Keystore) — NEVER in the APK,
/// never in shared_preferences, never sent anywhere except the user's own
/// Azure endpoint.
class AiConfig {
  final String endpoint; // e.g. https://myresource.services.ai.azure.com
  final String deployment; // e.g. gpt-5 / gpt-4o
  final String apiKey;

  const AiConfig({
    required this.endpoint,
    required this.deployment,
    required this.apiKey,
  });

  bool get isComplete =>
      endpoint.trim().isNotEmpty &&
      deployment.trim().isNotEmpty &&
      apiKey.trim().isNotEmpty;

  /// Users often paste the Foundry *project* endpoint
  /// (…/api/projects/xyz) — inference lives on the resource root.
  String get normalizedEndpoint {
    var e = endpoint.trim();
    if (e.endsWith('/')) e = e.substring(0, e.length - 1);
    final projectIdx = e.indexOf('/api/projects');
    if (projectIdx > 0) e = e.substring(0, projectIdx);
    return e;
  }
}

class AiConfigStore {
  static const _storage = FlutterSecureStorage();
  static const _kEndpoint = 'ai_endpoint';
  static const _kDeployment = 'ai_deployment';
  static const _kApiKey = 'ai_api_key';

  static Future<AiConfig> load() async {
    return AiConfig(
      endpoint: await _storage.read(key: _kEndpoint) ?? '',
      deployment: await _storage.read(key: _kDeployment) ?? '',
      apiKey: await _storage.read(key: _kApiKey) ?? '',
    );
  }

  static Future<void> save(AiConfig c) async {
    await _storage.write(key: _kEndpoint, value: c.endpoint.trim());
    await _storage.write(key: _kDeployment, value: c.deployment.trim());
    await _storage.write(key: _kApiKey, value: c.apiKey.trim());
  }

  static Future<void> clear() async {
    await _storage.delete(key: _kEndpoint);
    await _storage.delete(key: _kDeployment);
    await _storage.delete(key: _kApiKey);
  }
}
