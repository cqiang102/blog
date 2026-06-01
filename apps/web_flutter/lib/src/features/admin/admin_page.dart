import 'package:flutter/material.dart';

import '../../core/sample_data.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    final modules = [
      '标签管理',
      '媒体管理',
      '评论管理',
      '浏览记录',
      '点赞记录',
      '朋友管理',
      '用户管理',
      'AI 聊天记录',
      '个人知识库',
    ];

    return CustomScrollView(
      slivers: [
        const SliverAppBar(title: Text('管理员中心')),
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverList.list(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 960 ? 6 : constraints.maxWidth >= 640 ? 3 : 2;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: adminMetrics.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisExtent: 112,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemBuilder: (context, index) {
                      final metric = adminMetrics[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(metric.label),
                              const SizedBox(height: 8),
                              Text(
                                metric.value,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
              Text('管理模块', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final module in modules)
                    SizedBox(
                      width: 220,
                      child: Card(
                        child: ListTile(
                          leading: const Icon(Icons.tune),
                          title: Text(module),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {},
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.monitor_heart_outlined),
                  title: const Text('日志监控'),
                  subtitle: const Text('后续接入 actuator loggers、审计日志和运行事件。'),
                  trailing: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.refresh),
                    label: const Text('刷新'),
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
