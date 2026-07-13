package com.caoqiang.blog.auth.application.init;

import com.caoqiang.blog.shared.util.EmailNormalizer;
import com.caoqiang.blog.shared.util.PasswordPolicy;

import com.caoqiang.blog.config.BlogProperties;
import com.caoqiang.blog.user.application.api.UserAccountService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

/**
 * 管理员账户初始化器
 * 在应用首次启动时按配置创建管理员账户。
 * 位于博客系统的认证模块，是系统初始化的核心组件。
 *
 * <p>关键特性：</p>
 * <ul>
 *   <li>自动初始化 - 在应用启动时自动执行</li>
 *   <li>配置驱动 - 从配置文件读取管理员账户信息</li>
 *   <li>幂等操作 - 如果同邮箱账户已存在则跳过，绝不覆盖现有凭据或权限</li>
 *   <li>安全存储 - 密码使用 BCrypt 加密存储</li>
 * </ul>
 *
 * <p>处理流程：</p>
 * <ol>
 *   <li>检查管理员引导配置是否启用</li>
 *   <li>验证邮箱和密码配置是否有效</li>
 *   <li>规范化邮箱地址</li>
 *   <li>确定昵称（默认为"站长"）</li>
 *   <li>加密密码</li>
 *   <li>确认账户不存在后创建管理员账户</li>
 * </ol>
 *
 * <p>配置示例：</p>
 * <pre>
 * blog:
 *   admin:
 *     bootstrap:
 *       enabled: true
 *       email: admin@example.com
 *       password: your-password
 *       nickname: 站长
 * </pre>
 *
 * @author blog-mimo
 */
@Component
public class AdminAccountInitializer implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(AdminAccountInitializer.class);

    /** 博客配置属性，包含管理员账户配置 */
    private final BlogProperties blogProperties;
    /** 用户仓库，用于访问用户数据 */
    private final UserAccountService userAccountService;
    /** 密码编码器，用于密码加密 */
    private final PasswordEncoder passwordEncoder;

    /**
     * 构造函数，注入依赖
     *
     * @param blogProperties  博客配置属性
     * @param userAccountService 用户模块公开账户服务
     * @param passwordEncoder 密码编码器
     */
    public AdminAccountInitializer(
            BlogProperties blogProperties,
            UserAccountService userAccountService,
            PasswordEncoder passwordEncoder
    ) {
        this.blogProperties = blogProperties;
        this.userAccountService = userAccountService;
        this.passwordEncoder = passwordEncoder;
    }

    /**
     * 应用启动时执行
     * 检查配置并在账户不存在时创建管理员账户。
     *
     * @param args 应用启动参数
     */
    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        // 获取管理员引导配置
        BlogProperties.Admin.Bootstrap bootstrap = blogProperties.getAdmin().getBootstrap();
        // 检查是否启用管理员引导
        if (!bootstrap.isEnabled()) {
            return;
        }
        // 验证邮箱和密码配置是否有效
        if (!StringUtils.hasText(bootstrap.getEmail()) || !StringUtils.hasText(bootstrap.getPassword())) {
            return;
        }

        // 规范化邮箱地址
        String email = EmailNormalizer.normalize(bootstrap.getEmail());
        if (userAccountService.findByEmail(email).isPresent()) {
            log.info("Admin bootstrap skipped because account already exists: {}", email);
            return;
        }

        String nickname = StringUtils.hasText(bootstrap.getNickname()) ? bootstrap.getNickname().trim() : "站长";
        try {
            PasswordPolicy.validate(bootstrap.getPassword());
        } catch (RuntimeException exception) {
            throw new IllegalStateException("Admin bootstrap password does not satisfy the password policy", exception);
        }
        String passwordHash = passwordEncoder.encode(bootstrap.getPassword());
        userAccountService.createAdmin(email, passwordHash, nickname);
    }
}
