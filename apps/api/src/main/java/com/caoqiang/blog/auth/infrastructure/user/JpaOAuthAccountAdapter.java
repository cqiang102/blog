package com.caoqiang.blog.auth.infrastructure.user;

import com.caoqiang.blog.auth.domain.model.OAuthAccount;
import com.caoqiang.blog.auth.domain.model.OAuthProvider;
import com.caoqiang.blog.auth.domain.repository.OAuthAccountRepository;
import com.caoqiang.blog.user.application.port.OAuthAccountPort;
import java.util.List;
import java.util.Locale;
import java.util.UUID;
import org.springframework.stereotype.Component;

/**
 * Auth-owned persistence adapter exposed to the user module through a narrow port.
 */
@Component
public class JpaOAuthAccountAdapter implements OAuthAccountPort {

    private final OAuthAccountRepository oauthAccountRepository;

    public JpaOAuthAccountAdapter(OAuthAccountRepository oauthAccountRepository) {
        this.oauthAccountRepository = oauthAccountRepository;
    }

    @Override
    public List<LinkedOAuthAccount> findByUserId(UUID userId) {
        return oauthAccountRepository.findByUserId(userId).stream()
                .map(this::toLinkedAccount)
                .toList();
    }

    @Override
    public boolean remove(UUID userId, String provider) {
        OAuthProvider oauthProvider;
        try {
            oauthProvider = OAuthProvider.valueOf(provider.trim().toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException exception) {
            return false;
        }

        return oauthAccountRepository.findByUserIdAndProvider(userId, oauthProvider)
                .map(account -> {
                    oauthAccountRepository.delete(account);
                    return true;
                })
                .orElse(false);
    }

    private LinkedOAuthAccount toLinkedAccount(OAuthAccount account) {
        return new LinkedOAuthAccount(
                account.getProvider().name(),
                account.getProviderUsername(),
                account.getCreatedAt()
        );
    }
}
