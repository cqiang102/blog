package com.caoqiang.blog.content.application.dto;

import java.util.UUID;

/** Lightweight content option used by remote selectors in the management UI. */
public record AdminContentOptionResponse(UUID id, String title) {}
