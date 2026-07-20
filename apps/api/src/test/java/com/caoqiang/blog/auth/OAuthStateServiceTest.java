package com.caoqiang.blog.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.auth.application.service.OAuthStateService;
import com.caoqiang.blog.shared.exception.BusinessException;
import java.time.Duration;
import java.util.Base64;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.ArgumentMatchers;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.data.redis.core.script.RedisScript;
import org.springframework.http.HttpStatus;

@ExtendWith(MockitoExtension.class)
class OAuthStateServiceTest {

    private static final String BROWSER_ID = token((byte) 1);

    @Mock
    private StringRedisTemplate redisTemplate;

    @Mock
    private ValueOperations<String, String> valueOperations;

    private OAuthStateService service;

    @BeforeEach
    void setUp() {
        lenient().when(redisTemplate.opsForValue()).thenReturn(valueOperations);
        service = new OAuthStateService(redisTemplate);
    }

    @Test
    void loginStateIsOpaqueBrowserBoundAndSingleUse() {
        String state = service.createLoginState(BROWSER_ID);
        StoredState stored = captureStoredState();
        when(redisTemplate.execute(ArgumentMatchers.<RedisScript<String>>any(), anyList()))
                .thenReturn(stored.payload(), (String) null);

        OAuthStateService.ConsumedState consumed = service.consume(state, BROWSER_ID);

        assertThat(state).matches("[A-Za-z0-9_-]{43}");
        assertThat(consumed.bindingUserId()).isNull();
        assertInvalidState(() -> service.consume(state, BROWSER_ID));
    }

    @Test
    void mismatchedBrowserBurnsTheState() {
        String state = service.createLoginState(BROWSER_ID);
        StoredState stored = captureStoredState();
        when(redisTemplate.execute(ArgumentMatchers.<RedisScript<String>>any(), anyList()))
                .thenReturn(stored.payload(), (String) null);

        assertInvalidState(() -> service.consume(state, token((byte) 2)));
        assertInvalidState(() -> service.consume(state, BROWSER_ID));
    }

    @Test
    void bindingStateCarriesTheInitiatingUserOnlyAfterSuccessfulConsumption() {
        UUID userId = UUID.randomUUID();
        String state = service.createBindingState(userId, BROWSER_ID);
        StoredState stored = captureStoredState();
        when(redisTemplate.execute(ArgumentMatchers.<RedisScript<String>>any(), anyList()))
                .thenReturn(stored.payload());

        OAuthStateService.ConsumedState consumed = service.consume(state, BROWSER_ID);

        assertThat(consumed.bindingUserId()).isEqualTo(userId);
    }

    @Test
    void missingOrExpiredStateIsRejected() {
        when(redisTemplate.execute(ArgumentMatchers.<RedisScript<String>>any(), anyList()))
                .thenReturn((String) null);

        assertInvalidState(() -> service.consume(token((byte) 3), BROWSER_ID));
        assertInvalidState(() -> service.consume("not-a-token", BROWSER_ID));
    }

    private StoredState captureStoredState() {
        ArgumentCaptor<String> key = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<String> payload = ArgumentCaptor.forClass(String.class);
        verify(valueOperations).set(key.capture(), payload.capture(), eq(Duration.ofMinutes(5)));
        assertThat(key.getValue()).startsWith("auth:oauth-state:").doesNotContain(payload.getValue());
        return new StoredState(key.getValue(), payload.getValue());
    }

    private void assertInvalidState(org.assertj.core.api.ThrowableAssert.ThrowingCallable operation) {
        assertThatThrownBy(operation).isInstanceOfSatisfying(BusinessException.class, error -> {
            assertThat(error.status()).isEqualTo(HttpStatus.BAD_REQUEST);
            assertThat(error.getMessage()).isEqualTo("OAuth state 无效或已过期");
        });
    }

    private static String token(byte value) {
        byte[] bytes = new byte[32];
        java.util.Arrays.fill(bytes, value);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    private record StoredState(String key, String payload) {}
}
