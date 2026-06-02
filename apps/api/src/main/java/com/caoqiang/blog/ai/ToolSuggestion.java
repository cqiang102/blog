package com.caoqiang.blog.ai;

import java.util.Map;

public record ToolSuggestion(String name, String description, Map<String, Object> arguments) {
}
