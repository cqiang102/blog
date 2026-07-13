package com.caoqiang.blog.auth;

import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.auth.application.init.AdminAccountInitializer;
import com.caoqiang.blog.config.BlogProperties;
import com.caoqiang.blog.shared.model.Role;
import com.caoqiang.blog.user.application.api.IdentityUser;
import com.caoqiang.blog.user.application.api.UserAccountService;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.boot.ApplicationArguments;
import org.springframework.security.crypto.password.PasswordEncoder;

@ExtendWith(MockitoExtension.class)
class AdminAccountInitializerTest {

    @Mock
    private UserAccountService userAccountService;
    @Mock
    private PasswordEncoder passwordEncoder;
    @Mock
    private ApplicationArguments applicationArguments;

    @Test
    void doesNotResetOrElevateAnExistingAccount() {
        BlogProperties properties = enabledProperties();
        IdentityUser existing = new IdentityUser(
                UUID.randomUUID(),
                "admin@example.com",
                "原昵称",
                null,
                null,
                null,
                "existing-hash",
                Role.USER,
                true
        );
        when(userAccountService.findByEmail("admin@example.com")).thenReturn(Optional.of(existing));
        AdminAccountInitializer initializer = new AdminAccountInitializer(
                properties,
                userAccountService,
                passwordEncoder
        );

        initializer.run(applicationArguments);

        verifyNoInteractions(passwordEncoder);
        verify(userAccountService, never()).createAdmin(
                org.mockito.ArgumentMatchers.anyString(),
                org.mockito.ArgumentMatchers.anyString(),
                org.mockito.ArgumentMatchers.anyString()
        );
    }

    @Test
    void createsAdminWhenAccountDoesNotExist() {
        BlogProperties properties = enabledProperties();
        when(userAccountService.findByEmail("admin@example.com")).thenReturn(Optional.empty());
        when(passwordEncoder.encode("strong-password")).thenReturn("encoded");
        AdminAccountInitializer initializer = new AdminAccountInitializer(
                properties,
                userAccountService,
                passwordEncoder
        );

        initializer.run(applicationArguments);

        verify(userAccountService).createAdmin("admin@example.com", "encoded", "站长");
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
