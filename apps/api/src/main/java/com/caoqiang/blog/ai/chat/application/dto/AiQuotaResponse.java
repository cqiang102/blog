package com.caoqiang.blog.ai.chat.application.dto;

import java.time.LocalDate;

/**
 * AI 配额响应 DTO。
 *
 * @param date       配额日期（UTC）
 * @param dailyLimit 每日提问次数上限
 * @param used       当日已使用次数
 */
public record AiQuotaResponse(LocalDate date, int dailyLimit, int used) {
}
