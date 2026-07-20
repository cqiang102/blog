package com.caoqiang.blog.audit;

import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.audit.application.service.AuditLogService;
import com.caoqiang.blog.audit.infrastructure.AuditLogAspect;
import com.caoqiang.blog.content.application.dto.TagResponse;
import com.caoqiang.blog.content.infrastructure.web.AdminTagController;
import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.shared.model.Role;
import com.caoqiang.blog.shared.response.ApiResponse;
import java.time.Instant;
import java.util.UUID;
import org.aspectj.lang.JoinPoint;
import org.aspectj.lang.reflect.MethodSignature;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class AuditLogAspectTest {

    @Mock
    private AuditLogService auditLogService;

    @Mock
    private JoinPoint joinPoint;

    @Mock
    private MethodSignature signature;

    @Test
    void createAuditUsesIdFromReturnedResponse() {
        UUID actorId = UUID.randomUUID();
        UUID resourceId = UUID.randomUUID();
        AuthenticatedUser actor = new AuthenticatedUser(actorId, "admin@example.com", "Admin", Role.ADMIN);
        when(joinPoint.getSignature()).thenReturn(signature);
        when(joinPoint.getArgs()).thenReturn(new Object[] {actor});
        when(signature.getName()).thenReturn("create");
        when(signature.getDeclaringType()).thenReturn(AdminTagController.class);
        AuditLogAspect aspect = new AuditLogAspect(auditLogService);

        aspect.logAdminAction(
                joinPoint,
                ApiResponse.ok(new TagResponse(resourceId, "Java", "java", null, Instant.EPOCH, Instant.EPOCH)));

        verify(auditLogService).log(actorId, "CREATE", "TAG", resourceId);
    }
}
