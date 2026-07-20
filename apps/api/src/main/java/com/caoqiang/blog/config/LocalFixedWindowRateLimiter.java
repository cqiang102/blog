package com.caoqiang.blog.config;

import java.util.concurrent.atomic.AtomicReferenceArray;
import java.util.function.LongSupplier;

/**
 * Fixed-memory fallback rate limiter used only while Redis is unavailable.
 *
 * <p>Keys are mapped to a fixed number of concurrent slots. Hash collisions deliberately share a
 * counter, which can make the fallback stricter but cannot create an unbounded in-memory map or
 * let key churn evict another client's counter.</p>
 */
final class LocalFixedWindowRateLimiter {

    static final int DEFAULT_SLOT_COUNT = 16_384;

    private final AtomicReferenceArray<Window> windows;
    private final LongSupplier currentTimeMillis;

    LocalFixedWindowRateLimiter() {
        this(DEFAULT_SLOT_COUNT, System::currentTimeMillis);
    }

    LocalFixedWindowRateLimiter(int slotCount, LongSupplier currentTimeMillis) {
        if (slotCount <= 0) {
            throw new IllegalArgumentException("slotCount must be positive");
        }
        this.windows = new AtomicReferenceArray<>(slotCount);
        this.currentTimeMillis = currentTimeMillis;
    }

    long increment(String key, int windowSeconds) {
        int slot = Math.floorMod(key.hashCode(), windows.length());
        long now = currentTimeMillis.getAsLong();
        long durationMillis = Math.max(1, windowSeconds) * 1_000L;

        while (true) {
            Window current = windows.get(slot);
            Window next;
            if (current == null || current.expiresAtMillis() <= now) {
                next = new Window(1, now + durationMillis);
            } else {
                long nextCount = current.count() == Long.MAX_VALUE ? Long.MAX_VALUE : current.count() + 1;
                next = new Window(nextCount, current.expiresAtMillis());
            }
            if (windows.compareAndSet(slot, current, next)) {
                return next.count();
            }
        }
    }

    int capacity() {
        return windows.length();
    }

    private record Window(long count, long expiresAtMillis) {}
}
