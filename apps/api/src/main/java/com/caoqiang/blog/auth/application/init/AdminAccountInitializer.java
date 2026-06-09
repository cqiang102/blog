package com.caoqiang.blog.auth.application.init;

import com.caoqiang.blog.auth.application.service.EmailNormalizer;

import com.caoqiang.blog.config.BlogProperties;
import com.caoqiang.blog.user.domain.model.User;
import com.caoqiang.blog.user.domain.repository.UserRepository;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

/**
 * 管理员账户初始化器
 * 在应用启动时自动创建或更新管理员账户，确保系统至少有一个管理员。
 * 位于博客系统的认证模块，是系统初始化的核心组件。
 *
 * <p>关键特性：</p>
 * <ul>
 *   <li>自动初始化 - 在应用启动时自动执行</li>
 *   <li>配置驱动 - 从配置文件读取管理员账户信息</li>
 *   <li>幂等操作 - 如果管理员已存在则更新，否则创建</li>
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
 *   <li>查找或创建管理员账户</li>
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

    /** 博客配置属性，包含管理员账户配置 */
    private final BlogProperties blogProperties;
    /** 用户仓库，用于访问用户数据 */
    private final UserRepository userRepository;
    /** 密码编码器，用于密码加密 */
    private final PasswordEncoder passwordEncoder;

    /**
     * 构造函数，注入依赖
     *
     * @param blogProperties  博客配置属性
     * @param userRepository  用户仓库
     * @param passwordEncoder 密码编码器
     */
    public AdminAccountInitializer(
            BlogProperties blogProperties,
            UserRepository userRepository,
            PasswordEncoder passwordEncoder
    ) {
        this.blogProperties = blogProperties;
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
    }

    /**
     * 应用启动时执行
     * 检查配置并创建或更新管理员账户。
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
        // 确定昵称，如果未配置则使用默认值"站长"
        String nickname = StringUtils.hasText(bootstrap.getNickname()) ? bootstrap.getNickname().trim() : "站长";
        // 加密密码
        String passwordHash = passwordEncoder.encode(bootstrap.getPassword());

        // 查找或创建管理员账户
        userRepository.findByEmail(email)
                .ifPresentOrElse(
                        // 如果用户已存在，启用管理员权限
                        user -> user.enableAdmin(passwordHash, nickname),
                        // 如果用户不存在，创建新的管理员用户
                        () -> userRepository.save(User.admin(email, passwordHash, nickname))
                );
    }
}
