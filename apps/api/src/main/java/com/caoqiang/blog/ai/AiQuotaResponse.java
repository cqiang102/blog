package com.caoqiang.blog.ai;

import java.time.LocalDate;

public record AiQuotaResponse(LocalDate date, int dailyLimit, int used) {
}
