package com.caoqiang.blog.content.application.api;

import java.util.UUID;

public record ContentAccessSummary(UUID id, String title, String summary, String type) {}
