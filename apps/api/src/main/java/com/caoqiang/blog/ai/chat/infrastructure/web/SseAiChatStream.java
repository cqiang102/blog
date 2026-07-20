package com.caoqiang.blog.ai.chat.infrastructure.web;

import com.caoqiang.blog.ai.chat.application.dto.AiChatResponse;
import com.caoqiang.blog.ai.chat.application.port.AiChatStreamSink;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicReference;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

/** Maps transport-neutral chat stream events onto Spring MVC SSE. */
final class SseAiChatStream implements AiChatStreamSink {

    private static final long TIMEOUT_MILLIS = 600_000L;

    private final SseEmitter emitter = new SseEmitter(TIMEOUT_MILLIS);
    private final AtomicBoolean terminal = new AtomicBoolean();
    private final AtomicBoolean cancelled = new AtomicBoolean();
    private final AtomicReference<Runnable> cancellation = new AtomicReference<>();

    SseAiChatStream() {
        emitter.onCompletion(this::notifyCancellation);
        emitter.onTimeout(() -> {
            notifyCancellation();
            emitter.complete();
        });
        emitter.onError(error -> notifyCancellation());
    }

    SseEmitter emitter() {
        return emitter;
    }

    @Override
    public boolean emitToken(String token) {
        if (terminal.get() || cancelled.get()) {
            return false;
        }
        try {
            emitter.send(SseEmitter.event().name("token").data(token));
            return true;
        } catch (Exception exception) {
            notifyCancellation();
            return false;
        }
    }

    @Override
    public void complete(AiChatResponse response) {
        if (!terminal.compareAndSet(false, true)) {
            return;
        }
        try {
            emitter.send(SseEmitter.event().name("done").data(response));
        } catch (Exception exception) {
            notifyCancellation();
        } finally {
            emitter.complete();
        }
    }

    @Override
    public void fail(String message) {
        if (!terminal.compareAndSet(false, true)) {
            return;
        }
        try {
            emitter.send(SseEmitter.event().name("error").data(message));
        } catch (Exception exception) {
            notifyCancellation();
        } finally {
            emitter.complete();
        }
    }

    @Override
    public void registerCancellation(Runnable callback) {
        if (!cancellation.compareAndSet(null, callback)) {
            throw new IllegalStateException("A cancellation callback is already registered");
        }
        if (cancelled.get()) {
            callback.run();
        }
    }

    private void notifyCancellation() {
        terminal.set(true);
        if (!cancelled.compareAndSet(false, true)) {
            return;
        }
        Runnable callback = cancellation.get();
        if (callback != null) {
            callback.run();
        }
    }
}
