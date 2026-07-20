package com.caoqiang.blog.audit.infrastructure;

import com.caoqiang.blog.audit.application.service.AuditLogService;
import com.caoqiang.blog.audit.domain.model.AuditAction;
import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.shared.response.ApiResponse;
import java.lang.reflect.RecordComponent;
import java.util.Set;
import java.util.UUID;
import org.aspectj.lang.JoinPoint;
import org.aspectj.lang.annotation.AfterReturning;
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.reflect.MethodSignature;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;

/** Records successful management operations without coupling controllers to the audit service. */
@Aspect
@Component
public class AuditLogAspect {

    private static final Logger log = LoggerFactory.getLogger(AuditLogAspect.class);
    private static final Set<String> EXCLUDED_QUERIES = Set.of("dashboard", "modules", "logs");

    private final AuditLogService auditLogService;

    public AuditLogAspect(AuditLogService auditLogService) {
        this.auditLogService = auditLogService;
    }

    @AfterReturning(
            pointcut = "execution(* com.caoqiang.blog..infrastructure.web.Admin*Controller.*(..))",
            returning = "returnValue")
    public void logAdminAction(JoinPoint joinPoint, Object returnValue) {
        MethodSignature signature = (MethodSignature) joinPoint.getSignature();
        String methodName = signature.getName();
        if (EXCLUDED_QUERIES.contains(methodName)) {
            return;
        }

        try {
            AuthenticatedUser currentUser = findCurrentUser(joinPoint);
            if (currentUser == null) {
                log.warn("Skipped audit event because no authenticated administrator was available");
                return;
            }
            String resourceType = signature
                    .getDeclaringType()
                    .getSimpleName()
                    .replace("Admin", "")
                    .replace("Controller", "")
                    .toUpperCase();
            auditLogService.log(
                    currentUser.id(),
                    AuditAction.fromMethodName(methodName).name(),
                    resourceType,
                    extractResourceId(joinPoint, returnValue));
        } catch (RuntimeException exception) {
            // Audit persistence is intentionally best-effort and must not change the business response.
            log.error("Failed to record an administrator audit event", exception);
        }
    }

    private AuthenticatedUser findCurrentUser(JoinPoint joinPoint) {
        for (Object argument : joinPoint.getArgs()) {
            if (argument instanceof AuthenticatedUser currentUser) {
                return currentUser;
            }
        }

        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication != null && authentication.getPrincipal() instanceof AuthenticatedUser currentUser) {
            return currentUser;
        }
        return null;
    }

    private UUID extractResourceId(JoinPoint joinPoint, Object returnValue) {
        for (Object argument : joinPoint.getArgs()) {
            if (argument instanceof UUID id) {
                return id;
            }
            if (argument instanceof String value) {
                try {
                    return UUID.fromString(value);
                } catch (IllegalArgumentException ignored) {
                    // Continue looking for another resource identifier.
                }
            }
        }
        return extractReturnedResourceId(returnValue);
    }

    private UUID extractReturnedResourceId(Object returnValue) {
        if (returnValue instanceof ApiResponse<?> response) {
            return extractReturnedResourceId(response.data());
        }
        if (returnValue instanceof UUID id) {
            return id;
        }
        if (returnValue == null || !returnValue.getClass().isRecord()) {
            return null;
        }

        for (RecordComponent component : returnValue.getClass().getRecordComponents()) {
            if (!component.getName().equals("id") || component.getType() != UUID.class) {
                continue;
            }
            try {
                return (UUID) component.getAccessor().invoke(returnValue);
            } catch (ReflectiveOperationException exception) {
                log.debug("Could not read resource id from audit response type {}", returnValue.getClass(), exception);
                return null;
            }
        }
        return null;
    }
}
