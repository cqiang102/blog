import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(112),
          child: Column(
            children: [
              AppBar(title: const Text('个人中心')),
              const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.person), text: '资料'),
                  Tab(icon: Icon(Icons.comment), text: '评论'),
                  Tab(icon: Icon(Icons.favorite), text: '点赞'),
                  Tab(icon: Icon(Icons.history), text: '浏览'),
                ],
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ProfileForm(),
            _RecordList(type: '评论'),
            _RecordList(type: '点赞'),
            _RecordList(type: '浏览'),
          ],
        ),
      ),
    );
  }
}

class _ProfileForm extends StatelessWidget {
  const _ProfileForm();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const CircleAvatar(radius: 44, child: Icon(Icons.person, size: 44)),
        const SizedBox(height: 20),
        const TextField(decoration: InputDecoration(labelText: '昵称')),
        const SizedBox(height: 12),
        const TextField(decoration: InputDecoration(labelText: '简介'), maxLines: 3),
        const SizedBox(height: 12),
        const TextField(decoration: InputDecoration(labelText: '博客地址')),
        const SizedBox(height: 12),
        const TextField(decoration: InputDecoration(labelText: '邮箱')),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.save),
            label: const Text('保存'),
          ),
        ),
      ],
    );
  }
}

class _RecordList extends StatelessWidget {
  const _RecordList({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: 6,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) => Card(
        child: ListTile(
          leading: const Icon(Icons.article_outlined),
          title: Text('我的$type记录 ${index + 1}'),
          subtitle: const Text('关联内容标题和时间会从后端读取。'),
          trailing: IconButton(
            tooltip: '删除',
            onPressed: () {},
            icon: const Icon(Icons.delete_outline),
          ),
        ),
      ),
    );
  }
}
