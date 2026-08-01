package com.caoqiang.blog.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.ai.chat.application.dto.AiChatRequest;
import com.caoqiang.blog.ai.chat.application.dto.AiChatResponse;
import com.caoqiang.blog.ai.chat.application.port.AiChatStreamSink;
import com.caoqiang.blog.ai.chat.application.service.AiChatExchangeService;
import com.caoqiang.blog.ai.chat.application.service.AiChatModelService;
import com.caoqiang.blog.ai.chat.application.service.AiChatStreamingService;
import com.caoqiang.blog.ai.chat.application.service.AiQuotaService;
import com.caoqiang.blog.ai.chat.domain.model.AiChatSession;
import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.shared.model.Role;
import com.caoqiang.blog.user.application.api.IdentityUser;
import java.time.LocalDate;
import java.util.ArrayDeque;
import java.util.List;
import java.util.Queue;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executor;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import reactor.core.publisher.Flux;

@ExtendWith(MockitoExtension.class)
class AiChatStreamingServiceTest {

    @Mock
    private AiChatExchangeService exchangeService;

    @Mock
    private AiChatModelService modelService;

    private AuthenticatedUser principal;
    private AiChatRequest request;
    private AiChatExchangeService.PreparedExchange prepared;

    @BeforeEach
    void setUp() {
        UUID userId = UUID.randomUUID();
        principal = new AuthenticatedUser(userId, "reader@example.com", "读者", Role.USER);
        request = new AiChatRequest(null, "问题");
        IdentityUser identity = new IdentityUser(
                userId, principal.email(), principal.nickname(), null, null, null, "hash", Role.USER, true);
        AiChatSession session = new AiChatSession(userId, "会话");
        prepared = new AiChatExchangeService.PreparedExchange(
                identity,
                session,
                new AiQuotaService.Reservation(userId, LocalDate.of(2026, 6, 26), 1),
                10,
                "问题",
                List.of());
    }

    @Test
    void cancellationBeforeQueuedWorkStartsAvoidsQuotaAndModelCalls() {
        QueuedExecutor executor = new QueuedExecutor();
        TestSink sink = new TestSink();
        AiChatStreamingService service = new AiChatStreamingService(exchangeService, modelService, executor);

        service.start(principal, request, sink);
        sink.cancel();
        executor.runNext();

        verifyNoInteractions(exchangeService, modelService);
        assertThat(sink.response).isNull();
    }

    @Test
    void cancellationBeforeSubscriptionHandleAssignmentStillDisposesTheStream() throws Exception {
        TestSink sink = new TestSink();
        AtomicBoolean disposed = new AtomicBoolean();
        when(exchangeService.prepare(principal, request)).thenReturn(prepared);
        when(modelService.streamAnswer("问题", List.of(), principal))
                .thenReturn(Flux.<String>never()
                        .doOnSubscribe(subscription -> sink.cancel())
                        .doOnCancel(() -> disposed.set(true)));
        AiChatStreamingService service = new AiChatStreamingService(exchangeService, modelService, Runnable::run);

        service.start(principal, request, sink);

        assertThat(waitUntil(disposed)).isTrue();
        verify(exchangeService).release(prepared);
        verify(exchangeService, never()).complete(any(), any());
    }

    @Test
    void successfulStreamPersistsOnceAndReturnsCombinedAnswer() throws Exception {
        TestSink sink = new TestSink();
        AiChatResponse response = new AiChatResponse(prepared.session().getId(), "你好", 9, 38);
        when(exchangeService.prepare(principal, request)).thenReturn(prepared);
        when(modelService.streamAnswer("问题", List.of(), principal)).thenReturn(Flux.just("你", "好"));
        when(exchangeService.complete(prepared, "你好")).thenReturn(response);
        AiChatStreamingService service = new AiChatStreamingService(exchangeService, modelService, Runnable::run);

        service.start(principal, request, sink);

        assertThat(sink.finished.await(3, TimeUnit.SECONDS)).isTrue();
        assertThat(sink.tokens).containsExactly("你", "好");
        assertThat(sink.response).isEqualTo(response);
        verify(exchangeService).complete(prepared, "你好");
        verify(exchangeService, never()).release(prepared);
    }

    @Test
    void providerFailureReleasesQuotaAndSignalsAStableError() throws Exception {
        TestSink sink = new TestSink();
        when(exchangeService.prepare(principal, request)).thenReturn(prepared);
        when(modelService.streamAnswer("问题", List.of(), principal))
                .thenReturn(Flux.error(new IllegalStateException("provider detail")));
        AiChatStreamingService service = new AiChatStreamingService(exchangeService, modelService, Runnable::run);

        service.start(principal, request, sink);

        assertThat(sink.finished.await(3, TimeUnit.SECONDS)).isTrue();
        assertThat(sink.error).isEqualTo("AI 服务暂时不可用，请稍后重试");
        verify(exchangeService).release(prepared);
        verify(exchangeService, never()).complete(any(), any());
    }

    @Test
    void cancelsStreamWhenAnswerExceedsMaxLength() throws Exception {
        TestSink sink = new TestSink();
        String hugeToken = "x".repeat(60_000);
        when(exchangeService.prepare(principal, request)).thenReturn(prepared);
        when(modelService.streamAnswer("问题", List.of(), principal)).thenReturn(Flux.just(hugeToken));
        AiChatStreamingService service = new AiChatStreamingService(exchangeService, modelService, Runnable::run);

        service.start(principal, request, sink);

        // 流应被取消（cancel → release），不应调用 complete
        verify(exchangeService).release(prepared);
        verify(exchangeService, never()).complete(any(), any());
    }

    private boolean waitUntil(AtomicBoolean condition) throws InterruptedException {
        for (int attempt = 0; attempt < 100 && !condition.get(); attempt++) {
            Thread.sleep(10);
        }
        return condition.get();
    }

    private static final class QueuedExecutor implements Executor {
        private final Queue<Runnable> tasks = new ArrayDeque<>();

        @Override
        public void execute(Runnable command) {
            tasks.add(command);
        }

        void runNext() {
            tasks.remove().run();
        }
    }

    private static final class TestSink implements AiChatStreamSink {
        private final java.util.List<String> tokens = new java.util.ArrayList<>();
        private final CountDownLatch finished = new CountDownLatch(1);
        private Runnable cancellation;
        private AiChatResponse response;
        private String error;

        @Override
        public boolean emitToken(String token) {
            tokens.add(token);
            return true;
        }

        @Override
        public void complete(AiChatResponse response) {
            this.response = response;
            finished.countDown();
        }

        @Override
        public void fail(String message) {
            error = message;
            finished.countDown();
        }

        @Override
        public void registerCancellation(Runnable callback) {
            cancellation = callback;
        }

        void cancel() {
            cancellation.run();
        }
    }
}
