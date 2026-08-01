package com.caoqiang.blog.ai.chat.application.service;

import com.caoqiang.blog.ai.chat.application.dto.AiChatRequest;
import com.caoqiang.blog.ai.chat.application.dto.AiChatResponse;
import com.caoqiang.blog.ai.chat.application.port.AiChatStreamSink;
import com.caoqiang.blog.shared.exception.BusinessException;
import com.caoqiang.blog.shared.model.AuthenticatedUser;
import java.time.Duration;
import java.util.concurrent.Executor;
import java.util.concurrent.RejectedExecutionException;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicReference;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Service;
import reactor.core.Disposable;
import reactor.core.scheduler.Scheduler;
import reactor.core.scheduler.Schedulers;

/** Owns the cancellation-safe lifecycle of a streaming AI exchange. */
@Service
public class AiChatStreamingService {

    private static final Logger log = LoggerFactory.getLogger(AiChatStreamingService.class);

    /**
     * SSE 发送专用有界调度器。
     * <p>
     * emitter.send() 是同步阻塞写，慢客户端会长时间占用线程。使用独立的有界调度器
     * 与全局共享的 {@code Schedulers.boundedElastic()} 隔离，避免少量挂起连接拖垮
     * 应用内其它依赖该调度器的响应式操作。
     */
    private static final Scheduler SSE_SEND_SCHEDULER = Schedulers.newBoundedElastic(20, 100, "ai-sse-send", 60);

    /** 模型流无响应的上限，远小于 SSE emitter 超时，及时释放被占用的资源。 */
    private static final Duration MODEL_STREAM_TIMEOUT = Duration.ofSeconds(120);

    private final AiChatExchangeService exchangeService;
    private final AiChatModelService modelService;
    private final Executor streamExecutor;

    public AiChatStreamingService(
            AiChatExchangeService exchangeService,
            AiChatModelService modelService,
            @Qualifier("aiStreamExecutor") Executor streamExecutor) {
        this.exchangeService = exchangeService;
        this.modelService = modelService;
        this.streamExecutor = streamExecutor;
    }

    public void start(AuthenticatedUser currentUser, AiChatRequest request, AiChatStreamSink sink) {
        StreamExecution execution = new StreamExecution(currentUser, request, sink);
        sink.registerCancellation(execution::cancel);
        if (execution.isCancelled()) {
            return;
        }
        try {
            streamExecutor.execute(execution::run);
        } catch (RejectedExecutionException exception) {
            log.warn("AI stream executor is saturated");
            execution.failWithoutExchange("AI 服务繁忙，请稍后重试");
        }
    }

    private final class StreamExecution {

        private final AuthenticatedUser currentUser;
        private final AiChatRequest request;
        private final AiChatStreamSink sink;
        private final AtomicBoolean cancelled = new AtomicBoolean();
        private final AtomicBoolean finalized = new AtomicBoolean();
        private final AtomicReference<AiChatExchangeService.PreparedExchange> exchange = new AtomicReference<>();
        private final AtomicReference<Disposable> subscription = new AtomicReference<>();
        private final StringBuilder answer = new StringBuilder();

        private StreamExecution(AuthenticatedUser currentUser, AiChatRequest request, AiChatStreamSink sink) {
            this.currentUser = currentUser;
            this.request = request;
            this.sink = sink;
        }

        private boolean isCancelled() {
            return cancelled.get();
        }

        private void run() {
            if (cancelled.get()) {
                return;
            }

            AiChatExchangeService.PreparedExchange prepared;
            try {
                prepared = exchangeService.prepare(currentUser, request);
            } catch (BusinessException exception) {
                failWithoutExchange(exception.getMessage());
                return;
            } catch (RuntimeException exception) {
                log.error("Failed to prepare AI stream", exception);
                failWithoutExchange("AI 服务暂时不可用，请稍后重试");
                return;
            }

            exchange.set(prepared);
            if (cancelled.get()) {
                cancel();
                return;
            }

            try {
                Disposable handle = modelService
                        .streamAnswer(prepared.userMessage(), prepared.history(), currentUser)
                        .timeout(MODEL_STREAM_TIMEOUT)
                        .publishOn(SSE_SEND_SCHEDULER)
                        .subscribe(this::onToken, error -> failPrepared(prepared), () -> complete(prepared));
                subscription.set(handle);
                if (cancelled.get()) {
                    dispose(handle);
                }
            } catch (RuntimeException exception) {
                log.error("Failed to start AI stream", exception);
                failPrepared(prepared);
            }
        }

        private void onToken(String token) {
            if (cancelled.get() || finalized.get()) {
                return;
            }
            answer.append(token);
            if (!sink.emitToken(token)) {
                cancel();
            }
        }

        private void complete(AiChatExchangeService.PreparedExchange prepared) {
            if (cancelled.get()) {
                cancel();
                return;
            }
            if (!finalized.compareAndSet(false, true)) {
                return;
            }
            try {
                AiChatResponse response = exchangeService.complete(prepared, answer.toString());
                sink.complete(response);
            } catch (RuntimeException exception) {
                exchangeService.release(prepared);
                log.error("Failed to persist AI stream result", exception);
                sink.fail("保存对话失败，请稍后重试");
            }
        }

        private void failPrepared(AiChatExchangeService.PreparedExchange prepared) {
            if (finalized.compareAndSet(false, true)) {
                exchangeService.release(prepared);
                sink.fail("AI 服务暂时不可用，请稍后重试");
            }
        }

        private void failWithoutExchange(String message) {
            if (!cancelled.get() && finalized.compareAndSet(false, true)) {
                sink.fail(message);
            }
        }

        private void cancel() {
            cancelled.set(true);
            Disposable handle = subscription.get();
            if (handle != null) {
                dispose(handle);
            }
            AiChatExchangeService.PreparedExchange prepared = exchange.get();
            if (prepared != null && finalized.compareAndSet(false, true)) {
                exchangeService.release(prepared);
            }
        }

        private void dispose(Disposable handle) {
            if (!handle.isDisposed()) {
                handle.dispose();
            }
        }
    }
}
