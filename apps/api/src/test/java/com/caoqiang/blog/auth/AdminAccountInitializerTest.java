package com.caoqiang.blog.auth;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.auth.application.init.AdminAccountInitializer;
import com.caoqiang.blog.config.BlogProperties;
import com.caoqiang.blog.user.domain.model.User;
import com.caoqiang.blog.user.domain.repository.UserRepository;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.boot.ApplicationArguments;
import org.springframework.security.crypto.password.PasswordEncoder;

@ExtendWith(MockitoExtension.class)
class AdminAccountInitializerTest {

    @Mock
    private UserRepository userRepository;
    @Mock
    private PasswordEncoder passwordEncoder;
    @Mock
    private ApplicationArguments applicationArguments;

    @Test
    void doesNotResetOrElevateAnExistingAccount() {
        BlogProperties properties = enabledProperties();
        User existing = User.register("admin@example.com", "existing-hash", "原昵称");
        when(userRepository.findByEmail("admin@example.com")).thenReturn(Optional.of(existing));
        AdminAccountInitializer initializer = new AdminAccountInitializer(
                properties,
                userRepository,
                passwordEncoder
        );

        initializer.run(applicationArguments);

        verifyNoInteractions(passwordEncoder);
        verify(userRepository, never()).save(any(User.class));
    }

    @Test
    void createsAdminWhenAccountDoesNotExist() {
        BlogProperties properties = enabledProperties();
        when(userRepository.findByEmail("admin@example.com")).thenReturn(Optional.empty());
        when(passwordEncoder.encode("strong-password")).thenReturn("encoded");
        AdminAccountInitializer initializer = new AdminAccountInitializer(
                properties,
                userRepository,
                passwordEncoder
        );

        initializer.run(applicationArguments);

        verify(userRepository).save(any(User.class));
    }

    private BlogProperties enabledProperties() {
        BlogProperties properties = new BlogProperties();
        BlogProperties.Admin.Bootstrap bootstrap = properties.getAdmin().getBootstrap();
        bootstrap.setEnabled(true);
        bootstrap.setEmail("Admin@Example.com");
        bootstrap.setPassword("strong-password");
        bootstrap.setNickname("站长");
        return properties;
    }
}
