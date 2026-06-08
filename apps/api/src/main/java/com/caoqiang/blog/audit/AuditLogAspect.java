package com.caoqiang.blog.audit;

import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.user.entity.User;
import com.caoqiang.blog.user.repository.UserRepository;
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

/**
 * 审计日志 AOP 切面
 * <p>
 * 拦截管理端控制器的所有方法调用，自动记录审计日志。
 * <p>
 * 主要职责：
 * <ul>
 *   <li>拦截 admin 包下所有控制器的方法执行</li>
 *   <li>根据方法名自动识别操作类型（CREATE/UPDATE/DELETE/READ）</li>
 *   <li>根据控制器类名自动识别资源类型</li>
 *   <li>提取操作者信息和资源 ID</li>
 *   <li>异步记录审计日志，不影响正常业务流程</li>
 * </ul>
 * <p>
 * 排除 dashboard、modules、logs 等查询方法，避免日志冗余。
 */
@Aspect
@Component
public class AuditLogAspect {

    private static final Logger log = LoggerFactory.getLogger(AuditLogAspect.class);

    /** 审计日志服务 */
    private final AuditLogService auditLogService;
    /** 用户数据访问层，用于获取操作者信息 */
    private final UserRepository userRepository;

    public AuditLogAspect(AuditLogService auditLogService, UserRepository userRepository) {
        this.auditLogService = auditLogService;
        this.userRepository = userRepository;
    }

    /**
     * 记录管理端操作审计日志
     * <p>
     * 在管理端控制器方法成功返回后执行，记录操作信息。
     *
     * @param joinPoint 方法连接点
     * @param result    方法返回结果
     */
    @AfterReturning(pointcut = "execution(* com.caoqiang.blog.admin.*Controller.*(..))", returning = "result")
    public void logAdminAction(JoinPoint joinPoint, Object result) {
        try {
            MethodSignature signature = (MethodSignature) joinPoint.getSignature();
            String methodName = signature.getName();

            log.info("审计日志切面触发: 方法={}.{}", signature.getDeclaringType().getSimpleName(), methodName);

            // 排除查询类方法，避免日志冗余
            if (methodName.equals("dashboard") || methodName.equals("modules") || methodName.equals("logs")) {
                log.info("排除查询类方法: {}", methodName);
                return;
            }

            // 获取类名、操作类型和资源类型
            String className = signature.getDeclaringType().getSimpleName();
            String action = determineAction(methodName);
            String resourceType = determineResourceType(className);

            // 获取当前操作用户
            AuthenticatedUser currentUser = findCurrentUser(joinPoint);
            if (currentUser == null) {
                log.warn("无法获取当前用户，跳过审计日志记录。方法: {}.{}", 
                        signature.getDeclaringType().getSimpleName(), methodName);
                return;
            }

            log.info("获取到当前用户: id={}, nickname={}", currentUser.id(), currentUser.nickname());

            // 获取用户实体
            User actor = userRepository.findById(currentUser.id()).orElse(null);
            if (actor == null) {
                log.warn("未找到用户实体: id={}", currentUser.id());
            }

            // 提取资源 ID
            UUID resourceId = extractResourceId(joinPoint);

            log.info("记录审计日志: actor={}, action={}, resourceType={}, resourceId={}", 
                    actor != null ? actor.getNickname() : "null", action, resourceType, resourceId);

            // 记录审计日志
            auditLogService.log(actor, action, resourceType, resourceId);
            log.info("审计日志记录成功");
        } catch (Exception e) {
            // 日志记录失败不应影响正常业务
            log.error("Failed to log audit: {}", e.getMessage(), e);
        }
    }

    /**
     * 根据方法名确定操作类型
     * <p>
     * 根据方法名前缀自动识别操作类型：
     * <ul>
     *   <li>create/add -> CREATE</li>
     *   <li>update/edit/set/change -> UPDATE</li>
     *   <li>delete/remove -> DELETE</li>
     *   <li>get/list/detail -> READ</li>
     *   <li>其他 -> 方法名大写</li>
     * </ul>
     *
     * @param methodName 方法名
     * @return 操作类型字符串
     */
    private String determineAction(String methodName) {
        if (methodName.startsWith("create") || methodName.startsWith("add")) return "CREATE";
        if (methodName.startsWith("update") || methodName.startsWith("edit")) return "UPDATE";
        if (methodName.startsWith("delete") || methodName.startsWith("remove")) return "DELETE";
        if (methodName.startsWith("get") || methodName.startsWith("list") || methodName.startsWith("detail")) return "READ";
        if (methodName.startsWith("set") || methodName.startsWith("change")) return "UPDATE";
        return methodName.toUpperCase();
    }

    /**
     * 根据控制器类名确定资源类型
     * <p>
     * 移除 "Admin" 和 "Controller" 后缀，转换为大写。
     * 例如：AdminContentController -> CONTENT
     *
     * @param className 控制器类名
     * @return 资源类型字符串
     */
    private String determineResourceType(String className) {
        String name = className.replace("Admin", "").replace("Controller", "");
        return name.toUpperCase();
    }

    /**
     * 获取当前认证用户
     * <p>
     * 首先从方法参数中查找，如果没有则从 SecurityContextHolder 中获取。
     *
     * @param joinPoint 方法连接点
     * @return 当前认证用户，如果未找到返回 null
     */
    private AuthenticatedUser findCurrentUser(JoinPoint joinPoint) {
        // 首先从方法参数中查找
        Object[] args = joinPoint.getArgs();
        for (Object arg : args) {
            if (arg instanceof AuthenticatedUser) {
                return (AuthenticatedUser) arg;
            }
        }

        // 如果方法参数中没有，从 SecurityContextHolder 中获取
        try {
            Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
            if (authentication != null && authentication.getPrincipal() instanceof AuthenticatedUser) {
                return (AuthenticatedUser) authentication.getPrincipal();
            }
        } catch (Exception e) {
            log.debug("从 SecurityContextHolder 获取用户失败: {}", e.getMessage());
        }

        return null;
    }

    /**
     * 从方法参数中提取资源 ID
     * <p>
     * 查找 UUID 类型参数或可解析为 UUID 的字符串参数。
     *
     * @param joinPoint 方法连接点
     * @return 资源 ID，如果未找到返回 null
     */
    private UUID extractResourceId(JoinPoint joinPoint) {
        Object[] args = joinPoint.getArgs();
        for (Object arg : args) {
            // 直接查找 UUID 类型参数
            if (arg instanceof UUID) {
                return (UUID) arg;
            }
            // 尝试将字符串解析为 UUID
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
