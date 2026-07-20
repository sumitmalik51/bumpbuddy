import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../ai/ai_config.dart';
import '../ai/chat_service.dart';
import '../ai/scan_reader.dart';
import '../models.dart';
import '../store.dart';
import 'ai_settings_screen.dart';
import 'faq_screen.dart';
import 'saved_answers_screen.dart';

/// "Ask BumpBuddy" — questions answered from the user's own pregnancy data.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _thinking = false;
  AiConfig? _config;
  bool _configLoaded = false;

  @override
  void initState() {
    super.initState();
    AiConfigStore.load().then((c) {
      if (mounted) {
        setState(() {
          _config = c;
          _configLoaded = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String question) async {
    final store = context.read<AppStore>();
    final messenger = ScaffoldMessenger.of(context);
    final q = question.trim();
    if (q.isEmpty || _thinking) return;
    _input.clear();
    await store.addChatMessage(ChatMessage(
        id: store.newId(), role: 'user', text: q, time: DateTime.now()));
    setState(() => _thinking = true);
    _scrollDown();
    try {
      final answer = await ChatService.ask(
        config: _config!,
        store: store,
        history: store.chatMessages,
        question: q,
      );
      await store.addChatMessage(ChatMessage(
          id: store.newId(),
          role: 'assistant',
          text: answer,
          time: DateTime.now()));
    } on ScanReaderException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _thinking = false);
      _scrollDown();
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final p = store.profile!;
    final scheme = Theme.of(context).colorScheme;
    final configured = _config?.isComplete ?? false;

    final suggestions = <String>[
      if (p.isTwins) 'How are ${p.babies.map((b) => b.displayName).join(' and ')} growing?',
      'What does my latest scan mean in simple words?',
      if (p.isTwins) 'Explain my twins\' weight difference',
      'What should I watch for this week?',
      ChatService.appointmentPrepQuestion(store),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask BumpBuddy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.quiz_outlined),
            tooltip: 'Common questions',
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const FaqScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_border),
            tooltip: 'Saved answers',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const SavedAnswersScreen())),
          ),
          if (store.chatMessages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear conversation',
              onPressed: () => store.clearChat(),
            ),
        ],
      ),
      body: !_configLoaded
          ? const Center(child: CircularProgressIndicator())
          : !configured
              ? _setupNudge(context)
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      color: scheme.secondaryContainer,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Text(
                        'Answers use your own tracked data. Educational only — your doctor\'s advice always comes first.',
                        style: TextStyle(
                            fontSize: 11.5,
                            color: scheme.onSecondaryContainer),
                      ),
                    ),
                    Expanded(
                      child: store.chatMessages.isEmpty
                          ? _emptyState(context, suggestions)
                          : ListView.builder(
                              controller: _scroll,
                              padding: const EdgeInsets.all(16),
                              itemCount: store.chatMessages.length +
                                  (_thinking ? 1 : 0),
                              itemBuilder: (context, i) {
                                if (i == store.chatMessages.length) {
                                  return _bubble(context,
                                      role: 'assistant',
                                      text: 'Thinking…',
                                      pending: true);
                                }
                                final m = store.chatMessages[i];
                                if (m.role != 'assistant') {
                                  return _bubble(context,
                                      role: m.role, text: m.text);
                                }
                                // Find the question this answer responded to.
                                var question = '';
                                for (var k = i - 1; k >= 0; k--) {
                                  if (store.chatMessages[k].role == 'user') {
                                    question = store.chatMessages[k].text;
                                    break;
                                  }
                                }
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _bubble(context,
                                        role: m.role, text: m.text),
                                    _answerActions(context, store, question,
                                        m.text),
                                  ],
                                );
                              },
                            ),
                    ),
                    if (store.chatMessages.isNotEmpty && !_thinking)
                      SizedBox(
                        height: 44,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          children: [
                            for (final s in suggestions.take(3))
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ActionChip(
                                  label: Text(
                                      s.length > 34
                                          ? '${s.substring(0, 32)}…'
                                          : s,
                                      style:
                                          const TextStyle(fontSize: 12)),
                                  onPressed: () => _send(s),
                                ),
                              ),
                          ],
                        ),
                      ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _input,
                                minLines: 1,
                                maxLines: 4,
                                textInputAction: TextInputAction.send,
                                onSubmitted: _send,
                                decoration: InputDecoration(
                                  hintText: p.isTwins
                                      ? 'Ask about your twins…'
                                      : 'Ask about your pregnancy…',
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: _thinking
                                  ? null
                                  : () => _send(_input.text),
                              icon: _thinking
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.send),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  /// Bookmark + share row shown under each assistant answer.
  Widget _answerActions(
      BuildContext context, AppStore store, String question, String answer) {
    final scheme = Theme.of(context).colorScheme;
    final saved = store.isAnswerSaved(answer);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => store.toggleSavedAnswer(question, answer),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(saved ? Icons.bookmark : Icons.bookmark_border,
                  size: 18,
                  color: saved ? scheme.primary : scheme.onSurfaceVariant),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => SharePlus.instance.share(ShareParams(
                text:
                    '${question.isNotEmpty ? '$question\n\n' : ''}$answer\n\n— via BumpBuddy')),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.ios_share,
                  size: 17, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context, List<String> suggestions) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 16),
        Icon(Icons.chat_bubble_outline, size: 56, color: scheme.primary),
        const SizedBox(height: 12),
        Text(
          'Ask anything — I know your scans, weights, BP and meds.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 24),
        for (final s in suggestions)
          Card(
            color: scheme.surfaceContainerHigh,
            child: ListTile(
              leading: Icon(Icons.auto_awesome,
                  size: 18, color: scheme.primary),
              title: Text(s, style: const TextStyle(fontSize: 14)),
              onTap: () => _send(s),
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const FaqScreen())),
          icon: const Icon(Icons.quiz_outlined),
          label: const Text('Browse common questions'),
        ),
      ],
    );
  }

  Widget _bubble(BuildContext context,
      {required String role, required String text, bool pending = false}) {
    final scheme = Theme.of(context).colorScheme;
    final isUser = role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: isUser ? scheme.primary : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: pending
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: scheme.primary)),
                  const SizedBox(width: 10),
                  Text(text,
                      style:
                          TextStyle(color: scheme.onSurfaceVariant)),
                ],
              )
            : SelectableText(
                text,
                style: TextStyle(
                  color: isUser ? scheme.onPrimary : scheme.onSurface,
                  height: 1.4,
                ),
              ),
      ),
    );
  }

  Widget _setupNudge(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 56, color: scheme.primary),
            const SizedBox(height: 16),
            const Text(
              'Connect your Azure AI once, and BumpBuddy can answer questions about YOUR pregnancy data.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const AiSettingsScreen()));
                final c = await AiConfigStore.load();
                if (mounted) setState(() => _config = c);
              },
              child: const Text('Set up AI'),
            ),
          ],
        ),
      ),
    );
  }
}
