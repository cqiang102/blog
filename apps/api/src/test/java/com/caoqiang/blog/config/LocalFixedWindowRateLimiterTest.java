package com.caoqiang.blog.config;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.concurrent.atomic.AtomicLong;
import org.junit.jupiter.api.Test;

class LocalFixedWindowRateLimiterTest {

    @Test
    void incrementsWithinAWindowAndResetsAfterExpiry() {
        AtomicLong now = new AtomicLong(1_000L);
        LocalFixedWindowRateLimiter limiter = new LocalFixedWindowRateLimiter(16, now::get);

        assertThat(limiter.increment("client", 10)).isEqualTo(1);
        assertThat(limiter.increment("client", 10)).isEqualTo(2);

        now.set(11_000L);

        assertThat(limiter.increment("client", 10)).isEqualTo(1);
    }

    @Test
    void usesFixedMemoryRegardlessOfKeyCardinality() {
        LocalFixedWindowRateLimiter limiter = new LocalFixedWindowRateLimiter(32, () -> 1_000L);

        for (int index = 0; index < 100_000; index++) {
            limiter.increment("client-" + index, 60);
        }

        assertThat(limiter.capacity()).isEqualTo(32);
    }
}
