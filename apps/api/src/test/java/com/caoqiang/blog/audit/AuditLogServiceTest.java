package com.caoqiang.blog.audit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.shared.response.PageResponse;
import com.caoqiang.blog.user.entity.User;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;

import java.util.List;

@ExtendWith(MockitoExtension.class)
class AuditLogServiceTest {

    @Mock
    private AuditLogRepository auditLogRepository;

    private AuditLogService auditLogService;

    private User testUser;

    @BeforeEach
    void setUp() {
        auditLogService = new AuditLogService(auditLogRepository);
        testUser = User.register("admin@example.com", "hash", "管理员");
    }

    @Test
    void logActionSuccessfully() {
        UUID resourceId = UUID.randomUUID();
        Map<String, Object> detail = Map.of("field", "value");

        auditLogService.log(testUser, "CREATE", "CONTENT", resourceId, detail);

        ArgumentCaptor<AuditLog> captor = ArgumentCaptor.forClass(AuditLog.class);
        verify(auditLogRepository).save(captor.capture());

        AuditLog savedLog = captor.getValue();
        assertThat(savedLog.getActor()).isEqualTo(testUser);
        assertThat(savedLog.getAction()).isEqualTo("CREATE");
        assertThat(savedLog.getResourceType()).isEqualTo("CONTENT");
        assertThat(savedLog.getResourceId()).isEqualTo(resourceId);
        assertThat(savedLog.getDetail()).contains("\"field\":\"value\"");
    }

    @Test
    void logActionWithoutDetail() {
        UUID resourceId = UUID.randomUUID();

        auditLogService.log(testUser, "DELETE", "COMMENT", resourceId);

        ArgumentCaptor<AuditLog> captor = ArgumentCaptor.forClass(AuditLog.class);
        verify(auditLogRepository).save(captor.capture());

        AuditLog savedLog = captor.getValue();
        assertThat(savedLog.getActor()).isEqualTo(testUser);
        assertThat(savedLog.getAction()).isEqualTo("DELETE");
        assertThat(savedLog.getResourceType()).isEqualTo("COMMENT");
        assertThat(savedLog.getResourceId()).isEqualTo(resourceId);
        assertThat(savedLog.getDetail()).isNull();
    }

    @Test
    @SuppressWarnings("unchecked")
    void listAuditLogs() {
        AuditLog log1 = new AuditLog(testUser, "CREATE", "CONTENT", UUID.randomUUID(), null);
        AuditLog log2 = new AuditLog(testUser, "UPDATE", "TAG", UUID.randomUUID(), null);

        Page<AuditLog> page = new PageImpl<>(List.of(log1, log2));
        when(auditLogRepository.findAll(any(Specification.class), any(Pageable.class))).thenReturn(page);

        PageResponse<AuditLogResponse> result = auditLogService.list(0, 10, null, null, null);

        assertThat(result.items()).hasSize(2);
        assertThat(result.items().get(0).action()).isEqualTo("CREATE");
        assertThat(result.items().get(1).action()).isEqualTo("UPDATE");
    }
}
