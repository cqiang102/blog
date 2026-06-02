package com.caoqiang.blog.audit;

import com.caoqiang.blog.auth.AuthenticatedUser;
import com.caoqiang.blog.user.User;
import com.caoqiang.blog.user.UserRepository;
import java.util.UUID;
import org.aspectj.lang.JoinPoint;
import org.aspectj.lang.annotation.AfterReturning;
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.reflect.MethodSignature;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.stereotype.Component;

@Aspect
@Component
public class AuditLogAspect {

    private final AuditLogService auditLogService;
    private final UserRepository userRepository;

    public AuditLogAspect(AuditLogService auditLogService, UserRepository userRepository) {
        this.auditLogService = auditLogService;
        this.userRepository = userRepository;
    }

    @AfterReturning(pointcut = "execution(* com.caoqiang.blog.admin.*Controller.*(..))", returning = "result")
    public void logAdminAction(JoinPoint joinPoint, Object result) {
        try {
            MethodSignature signature = (MethodSignature) joinPoint.getSignature();
            String methodName = signature.getName();

            if (methodName.equals("dashboard") || methodName.equals("modules") || methodName.equals("logs")) {
                return;
            }

            String className = signature.getDeclaringType().getSimpleName();
            String action = determineAction(methodName);
            String resourceType = determineResourceType(className);

            AuthenticatedUser currentUser = findCurrentUser(joinPoint);
            if (currentUser == null) return;

            User actor = userRepository.findById(currentUser.id()).orElse(null);

            UUID resourceId = extractResourceId(joinPoint);

            auditLogService.log(actor, action, resourceType, resourceId);
        } catch (Exception e) {
            // 日志记录失败不应影响正常业务
            System.err.println("Failed to log audit: " + e.getMessage());
        }
    }

    private String determineAction(String methodName) {
        if (methodName.startsWith("create") || methodName.startsWith("add")) return "CREATE";
        if (methodName.startsWith("update") || methodName.startsWith("edit")) return "UPDATE";
        if (methodName.startsWith("delete") || methodName.startsWith("remove")) return "DELETE";
        if (methodName.startsWith("get") || methodName.startsWith("list") || methodName.startsWith("detail")) return "READ";
        if (methodName.startsWith("set") || methodName.startsWith("change")) return "UPDATE";
        return methodName.toUpperCase();
    }

    private String determineResourceType(String className) {
        String name = className.replace("Admin", "").replace("Controller", "");
        return name.toUpperCase();
    }

    private AuthenticatedUser findCurrentUser(JoinPoint joinPoint) {
        Object[] args = joinPoint.getArgs();
        for (Object arg : args) {
            if (arg instanceof AuthenticatedUser) {
                return (AuthenticatedUser) arg;
            }
        }
        return null;
    }

    private UUID extractResourceId(JoinPoint joinPoint) {
        Object[] args = joinPoint.getArgs();
        for (Object arg : args) {
            if (arg instanceof UUID) {
                return (UUID) arg;
            }
            if (arg instanceof String) {
                try {
                    return UUID.fromString((String) arg);
                } catch (IllegalArgumentException ignored) {
                }
            }
        }
        return null;
    }
}
