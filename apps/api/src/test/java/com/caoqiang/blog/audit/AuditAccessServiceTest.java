package com.caoqiang.blog.audit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.audit.application.api.AuditAccessService;
import com.caoqiang.blog.audit.application.dto.AuditLogResponse;
import com.caoqiang.blog.audit.application.service.AuditLogService;
import com.caoqiang.blog.shared.response.PageResponse;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class AuditAccessServiceTest {

    @Mock
    private AuditLogService auditLogService;

    @Test
    void mapsInternalAuditResponsesToThePublicContract() {
        UUID id = UUID.randomUUID();
        UUID actorId = UUID.randomUUID();
        UUID resourceId = UUID.randomUUID();
        Instant createdAt = Instant.parse("2026-07-13T10:00:00Z");
        when(auditLogService.list(1, 20, "UPDATE", "CONTENT", actorId)).thenReturn(
                new PageResponse<>(List.of(new AuditLogResponse(
                        id,
                        actorId,
                        "admin",
                        "UPDATE",
                        "CONTENT",
                        resourceId,
                        "{}",
                        createdAt
                )), 1, 20, 21)
        );
        AuditAccessService service = new AuditAccessService(auditLogService);

        var result = service.list(1, 20, "UPDATE", "CONTENT", actorId);

        assertThat(result.page()).isEqualTo(1);
        assertThat(result.size()).isEqualTo(20);
        assertThat(result.total()).isEqualTo(21);
        assertThat(result.items()).singleElement().satisfies(item -> {
            assertThat(item.id()).isEqualTo(id);
            assertThat(item.actorUserId()).isEqualTo(actorId);
            assertThat(item.actorNickname()).isEqualTo("admin");
            assertThat(item.resourceId()).isEqualTo(resourceId);
            assertThat(item.createdAt()).isEqualTo(createdAt);
        });
        verify(auditLogService).list(1, 20, "UPDATE", "CONTENT", actorId);
    }
}
