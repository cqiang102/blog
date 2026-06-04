package com.caoqiang.blog.auth;

import com.caoqiang.blog.common.BusinessException;
import java.time.Clock;
import java.time.Instant;
import java.util.Optional;
import java.util.Random;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 邮箱验证码业务服务
 * 处理验证码的生成、发送和验证逻辑。
 * 位于博客系统的认证模块，是邮箱验证流程的核心组件。
 *
 * <p>关键特性：</p>
 * <ul>
 *   <li>验证码生成 - 生成 6 位随机数字验证码</li>
 *   <li>发送频率限制 - 同一邮箱 60 秒内只能发送一次验证码</li>
 *   <li>过期管理 - 验证码有效期为 5 分钟</li>
 *   <li>使用状态 - 验证码使用后标记为已使用，防止重复使用</li>
 *   <li>事务管理 - 使用 Spring 事务保证数据一致性</li>
 * </ul>
 *
 * @author blog-mimo
 */
@Service
public class VerificationService {

    /** 验证码长度 */
    private static final int CODE_LENGTH = 6;

    /** 验证码有效期（分钟） */
    private static final int EXPIRE_MINUTES = 5;

    /** 重发冷却时间（秒） */
    private static final int RESEND_COOLDOWN_SECONDS = 60;

    /** 验证码数据访问层 */
    private final VerificationCodeRepository repository;

    /** 邮件发送服务 */
    private final EmailService emailService;

    /** 时钟，用于获取当前时间，便于测试 */
    private final Clock clock;

    /** 随机数生成器 */
    private final Random random = new Random();

    /**
     * 构造函数，注入依赖
     *
     * @param repository   验证码数据访问层
     * @param emailService 邮件发送服务
     * @param clock        时钟实例
     */
    public VerificationService(VerificationCodeRepository repository, EmailService emailService, Clock clock) {
        this.repository = repository;
        this.emailService = emailService;
        this.clock = clock;
    }

    /**
     * 发送验证码到指定邮箱
     * 生成验证码并通过邮件发送，同时检查发送频率限制。
     *
     * @param email 目标邮箱地址
     * @throws BusinessException 如果发送频率超过限制
     */
    @Transactional
    public void sendCode(String email) {
        Instant now = clock.instant();

        // 检查 60 秒冷却
        Optional<VerificationCode> last = repository.findFirstByEmailOrderByCreatedAtDesc(email);
        if (last.isPresent()) {
            Instant lastCreated = last.get().getCreatedAt();
            if (now.isBefore(lastCreated.plusSeconds(RESEND_COOLDOWN_SECONDS))) {
                throw new BusinessException(HttpStatus.TOO_MANY_REQUESTS, "请等待 60 秒后重试");
            }
        }

        // 生成验证码
        String code = generateCode();
        Instant expiresAt = now.plusSeconds(EXPIRE_MINUTES * 60L);
        VerificationCode verificationCode = new VerificationCode(email, code, expiresAt);
        repository.save(verificationCode);

        // 发送邮件
        emailService.sendVerificationCode(email, code);
    }

    /**
     * 验证邮箱验证码
     * 检查验证码的有效性，包括是否存在、是否过期、是否匹配。
     *
     * @param email 邮箱地址
     * @param code  用户输入的验证码
     * @throws BusinessException 如果验证码不存在、已过期或不匹配
     */
    @Transactional
    public void verify(String email, String code) {
        Instant now = clock.instant();

        VerificationCode vc = repository.findFirstByEmailAndUsedOrderByCreatedAtDesc(email, false)
                .orElseThrow(() -> new BusinessException(HttpStatus.BAD_REQUEST, "请先获取验证码"));

        if (vc.isExpired(now)) {
            throw new BusinessException(HttpStatus.BAD_REQUEST, "验证码已过期，请重新获取");
        }

        if (!vc.getCode().equals(code)) {
            throw new BusinessException(HttpStatus.BAD_REQUEST, "验证码错误");
        }

        vc.markUsed();
    }

    /**
     * 生成随机验证码
     * 生成指定长度的数字验证码，不足位数时前面补零。
     *
     * @return 验证码字符串
     */
    private String generateCode() {
        int bound = (int) Math.pow(10, CODE_LENGTH);
        int number = random.nextInt(bound);
        return String.format("%0" + CODE_LENGTH + "d", number);
    }
}
