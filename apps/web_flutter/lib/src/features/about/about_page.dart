import 'package:flutter/material.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final _controller = TextEditingController();
  final _messages = <_ChatMessage>[
    const _ChatMessage(false, '你好，我是这个博客的 AI 助手。登录后每天可以问我 10 个问题。'),
  ];
  int _remaining = 10;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty || _remaining <= 0) return;

    setState(() {
      _messages.add(_ChatMessage(true, text));
      _messages.add(const _ChatMessage(false, '已收到。真实实现会从个人知识库和博客内容里检索，再调用模型回答。'));
      _remaining -= 1;
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverAppBar(title: Text('关于我')),
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverList.list(
            children: [
              Text('写代码，也记录生活。', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('这里会放个人介绍、项目经历、常用技术栈和联系方式。'),
              const SizedBox(height: 24),
              Card(
                child: SizedBox(
                  height: 520,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.smart_toy),
                        title: const Text('AI 助手'),
                        subtitle: Text('今日剩余 $_remaining 次'),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) => _ChatBubble(message: _messages[index]),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                onSubmitted: (_) => _send(),
                                decoration: const InputDecoration(hintText: '问问我的经历、文章或项目'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              tooltip: '发送',
                              onPressed: _send,
                              icon: const Icon(Icons.send),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: message.mine ? Theme.of(context).colorScheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: message.mine ? null : Border.all(color: const Color(0xFFE0E7E3)),
        ),
        child: Text(
          message.text,
          style: TextStyle(color: message.mine ? Colors.white : Theme.of(context).colorScheme.onSurface),
        ),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage(this.mine, this.text);

  final bool mine;
  final String text;
}
