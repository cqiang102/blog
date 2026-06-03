package com.caoqiang.blog.ai;

import java.util.Map;

/**
 * 工具建议 DTO。
 * <p>
 * 表示 AI 建议调用的工具信息，用于在 UI 中展示可执行的操作建议。
 *
 * @param name        工具名称
 * @param description 工具描述
 * @param arguments   工具调用参数
 */
public record ToolSuggestion(String name, String description, Map<String, Object> arguments) {
}
