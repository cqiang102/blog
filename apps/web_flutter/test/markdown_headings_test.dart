import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/core/markdown_headings.dart';

void main() {
  test('extracts ATX headings and skips code fences', () {
    const markdown = '''
# 标题一

普通段落，包含 # 但不是标题

```dart
# 代码里的标题不应解析
void main() {}
```

## 标题二 **加粗** [链接](https://example.com)

### 标题三

    # 缩进代码块也不解析
''';
    final headings = extractMarkdownHeadings(markdown);
    expect(headings.map((h) => h.text), [
      '标题一',
      '标题二 加粗 链接',
      '标题三',
    ]);
    expect(headings.map((h) => h.level), [1, 2, 3]);
  });

  test('deduplicates repeated heading text with stable slugs', () {
    final headings = extractMarkdownHeadings('''
# 常见问题
## 安装
## 安装
### 配置
## 安装
''');
    expect(headings.map((h) => h.slug), [
      '常见问题',
      '安装',
      '安装-2',
      '配置',
      '安装-3',
    ]);
  });

  test('cleans inline formatting and keeps Chinese slugs', () {
    final headings = extractMarkdownHeadings('''
# **Flutter** 与 `Dart`
## [部署](https://example.com) 指南
### 纯中文标题！
''');
    expect(headings[0].text, 'Flutter 与 Dart');
    expect(headings[0].slug, 'flutter-与-dart');
    expect(headings[1].text, '部署 指南');
    expect(headings[2].slug, '纯中文标题');
  });
}
