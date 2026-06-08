// JSON 解析辅助函数
// 提供安全的类型转换和默认值处理

/// 安全转换为字符串，null 转为空字符串
String jsonString(Object? value) => value?.toString() ?? '';

/// 转换为可空字符串，空字符串转为 null
String? jsonNullableString(Object? value) {
  final text = jsonString(value);
  return text.isEmpty ? null : text;
}

/// 安全转换为 int，转换失败返回 0
int jsonInt(Object? value) =>
    value is num ? value.toInt() : int.tryParse(jsonString(value)) ?? 0;

/// 安全转换为 DateTime，转换失败返回 epoch 时间
DateTime jsonDate(Object? value) =>
    DateTime.tryParse(jsonString(value))?.toLocal() ??
    DateTime.fromMillisecondsSinceEpoch(0);

/// 从 JSON 列表解析字符串列表
List<String> jsonStringList(Object? value) {
  return (value as List? ?? const [])
      .map((item) => item.toString())
      .where((item) => item.isNotEmpty)
      .toList();
}
