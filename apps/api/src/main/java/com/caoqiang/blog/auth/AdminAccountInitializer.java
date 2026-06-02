package com.caoqiang.blog.auth;

import com.caoqiang.blog.config.BlogProperties;
import com.caoqiang.blog.user.User;
import com.caoqiang.blog.user.UserRepository;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

@Component
public class AdminAccountInitializer implements ApplicationRunner {

    private final BlogProperties blogProperties;
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    public AdminAccountInitializer(
            BlogProperties blogProperties,
            UserRepository userRepository,
            PasswordEncoder passwordEncoder
    ) {
        this.blogProperties = blogProperties;
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
    }

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        BlogProperties.Admin.Bootstrap bootstrap = blogProperties.getAdmin().getBootstrap();
        if (!bootstrap.isEnabled()) {
            return;
        }
        if (!StringUtils.hasText(bootstrap.getEmail()) || !StringUtils.hasText(bootstrap.getPassword())) {
            return;
        }

        String email = EmailNormalizer.normalize(bootstrap.getEmail());
        String nickname = StringUtils.hasText(bootstrap.getNickname()) ? bootstrap.getNickname().trim() : "站长";
        String passwordHash = passwordEncoder.encode(bootstrap.getPassword());

        userRepository.findByEmail(email)
                .ifPresentOrElse(
                        user -> user.enableAdmin(passwordHash, nickname),
                        () -> userRepository.save(User.admin(email, passwordHash, nickname))
                );
    }
}
