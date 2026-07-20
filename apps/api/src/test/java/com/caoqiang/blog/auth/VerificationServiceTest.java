package com.caoqiang.blog.auth;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.auth.application.service.EmailService;
import com.caoqiang.blog.auth.application.service.VerificationService;
import com.caoqiang.blog.auth.domain.model.VerificationCode;
import com.caoqiang.blog.auth.domain.repository.VerificationCodeRepository;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

@ExtendWith(MockitoExtension.class)
class VerificationServiceTest {

    @Mock
    private VerificationCodeRepository repository;

    @Mock
    private EmailService emailService;

    private VerificationService service;

    @BeforeEach
    void setUp() {
        service = new VerificationService(
                repository, emailService, Clock.fixed(Instant.parse("2026-07-16T08:00:00Z"), ZoneOffset.UTC));
    }

    @AfterEach
    void clearTransactionSynchronization() {
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.clearSynchronization();
        }
    }

    @Test
    void sendsOnlyAfterTheVerificationCodeTransactionCommits() {
        String email = "user@example.com";
        when(repository.findFirstByEmailOrderByCreatedAtDesc(email)).thenReturn(Optional.empty());
        TransactionSynchronizationManager.initSynchronization();

        service.sendCode(email);

        ArgumentCaptor<VerificationCode> code = ArgumentCaptor.forClass(VerificationCode.class);
        verify(repository).save(code.capture());
        verify(emailService, never()).sendVerificationCode(any(), any());

        TransactionSynchronizationManager.getSynchronizations().getFirst().afterCommit();

        verify(emailService).sendVerificationCode(email, code.getValue().getCode());
    }

    @Test
    void doesNotSendWhenTheVerificationCodeTransactionRollsBack() {
        String email = "user@example.com";
        when(repository.findFirstByEmailOrderByCreatedAtDesc(email)).thenReturn(Optional.empty());
        TransactionSynchronizationManager.initSynchronization();

        service.sendCode(email);
        TransactionSynchronizationManager.getSynchronizations()
                .getFirst()
                .afterCompletion(TransactionSynchronization.STATUS_ROLLED_BACK);

        verify(emailService, never()).sendVerificationCode(any(), any());
    }
}
