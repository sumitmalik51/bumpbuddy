import 'package:flutter/material.dart';

import '../ai/ai_config.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  final _endpoint = TextEditingController();
  final _deployment = TextEditingController();
  final _apiKey = TextEditingController();
  bool _loaded = false;
  bool _hideKey = true;
  String? _status;

  @override
  void initState() {
    super.initState();
    AiConfigStore.load().then((c) {
      if (!mounted) return;
      setState(() {
        _endpoint.text = c.endpoint;
        _deployment.text = c.deployment;
        _apiKey.text = c.apiKey;
        _loaded = true;
      });
    });
  }

  @override
  void dispose() {
    _endpoint.dispose();
    _deployment.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final config = AiConfig(
      endpoint: _endpoint.text,
      deployment: _deployment.text,
      apiKey: _apiKey.text,
    );
    await AiConfigStore.save(config);
    if (mounted) {
      setState(() => _status = config.isComplete
          ? 'Saved. "Read with AI" is now available on ultrasound records.'
          : 'Saved, but some fields are empty — AI reading stays off until all three are set.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('AI scan reading')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: scheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Connect your own Azure AI Foundry deployment. Your key is stored '
                      'encrypted on this phone only, and report photos are sent directly '
                      'to YOUR Azure endpoint — nowhere else.\n\n'
                      'AI reading extracts what is printed on the report. It never '
                      'diagnoses — always review results with your doctor.',
                      style: TextStyle(
                          fontSize: 13, color: scheme.onSecondaryContainer),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _endpoint,
                  decoration: const InputDecoration(
                    labelText: 'Azure endpoint',
                    hintText: 'https://yourresource.services.ai.azure.com',
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _deployment,
                  decoration: const InputDecoration(
                    labelText: 'Deployment name',
                    hintText: 'e.g. gpt-5 or gpt-4o (must be vision-capable)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _apiKey,
                  obscureText: _hideKey,
                  decoration: InputDecoration(
                    labelText: 'API key',
                    suffixIcon: IconButton(
                      icon: Icon(
                          _hideKey ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _hideKey = !_hideKey),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _save,
                  child: const Text('Save'),
                ),
                if (_status != null) ...[
                  const SizedBox(height: 12),
                  Text(_status!,
                      style: TextStyle(color: scheme.primary, fontSize: 13)),
                ],
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () async {
                    await AiConfigStore.clear();
                    if (context.mounted) {
                      setState(() {
                        _endpoint.clear();
                        _deployment.clear();
                        _apiKey.clear();
                        _status = 'Cleared.';
                      });
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remove stored credentials'),
                ),
              ],
            ),
    );
  }
}
