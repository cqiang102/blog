package com.caoqiang.blog.auth;

import com.caoqiang.blog.user.User;
import com.caoqiang.blog.user.UserRepository;
import java.util.Map;
import java.util.Optional;
import org.springframework.security.oauth2.client.userinfo.DefaultOAuth2UserService;
import org.springframework.security.oauth2.client.userinfo.OAuth2UserRequest;
import org.springframework.security.oauth2.core.OAuth2AuthenticationException;
import org.springframework.security.oauth2.core.user.OAuth2User;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * GitHub OAuth2 用户服务
 * 处理 GitHub OAuth2 登录的用户信息加载和账户关联逻辑。
 * 位于博客系统的认证模块，是 OAuth2 认证流程的核心组件。
 *
 * <p>关键特性：</p>
 * <ul>
 *   <li>用户加载 - 从 GitHub API 加载用户信息</li>
 *   <li>账户关联 - 将 GitHub 账户与本地用户关联</li>
 *   <li>用户创建 - 为新 GitHub 用户创建本地用户账户</li>
 *   <li>信息同步 - 同步 GitHub 用户的头像和昵称</li>
 * </ul>
 *
 * <p>处理流程：</p>
 * <ol>
 *   <li>从 GitHub API 加载用户属性</li>
 *   <li>提取用户信息（登录名、邮箱、昵称、头像等）</li>
 *   <li>查找是否已关联的 OAuth 账户</li>
 *   <li>如果已关联，更新用户信息</li>
 *   <li>如果未关联，查找或创建本地用户，并创建关联</li>
 *   <li>返回 GithubOAuth2User 对象</li>
 * </ol>
 *
 * <p>事务管理：整个加载过程在事务中执行，确保数据一致性。</p>
 *
 * @author blog-mimo
 */
@Service
public class GithubOAuth2UserService extends DefaultOAuth2UserService {

    /** 用户仓库，用于访问用户数据 */
    private final UserRepository userRepository;
    /** OAuth 账户仓库，用于访问 OAuth 账户关联数据 */
    private final OAuthAccountRepository oauthAccountRepository;

    /**
     * 构造函数，注入依赖
     *
     * @param userRepository         用户仓库
     * @param oauthAccountRepository OAuth 账户仓库
     */
    public GithubOAuth2UserService(UserRepository userRepository, OAuthAccountRepository oauthAccountRepository) {
        this.userRepository = userRepository;
        this.oauthAccountRepository = oauthAccountRepository;
    }

    /**
     * 加载 GitHub 用户信息
     * 从 GitHub API 加载用户信息，处理账户关联和用户创建。
     *
     * @param userRequest OAuth2 用户请求
     * @return GithubOAuth2User 对象
     * @throws OAuth2AuthenticationException 如果认证失败
     */
    @Override
    @Transactional
    public OAuth2User loadUser(OAuth2UserRequest userRequest) throws OAuth2AuthenticationException {
        // 调用父类方法从 GitHub API 加载用户信息
        OAuth2User oauth2User = super.loadUser(userRequest);

        // 提取 GitHub 用户 ID
        String providerUserId = oauth2User.getName();
        // 获取用户属性
        Map<String, Object> attributes = oauth2User.getAttributes();

        // 提取用户信息
        String login = (String) attributes.get("login");
        String email = (String) attributes.get("email");
        String name = (String) attributes.get("name");
        String avatarUrl = (String) attributes.get("avatar_url");
        String bio = (String) attributes.get("bio");
        String blogUrl = (String) attributes.get("blog");

        // 如果邮箱为空，使用生成的占位邮箱
        if (email == null || email.isBlank()) {
            email = login + "@github.local";
        }

        // 确定昵称：优先使用真实姓名，其次使用登录名
        String nickname = (name != null && !name.isBlank()) ? name : login;

        // 查找是否已关联的 OAuth 账户
        Optional<OAuthAccount> existingAccount = oauthAccountRepository
                .findByProviderAndProviderUserId(OAuthProvider.GITHUB, providerUserId);

        User user;
        if (existingAccount.isPresent()) {
            // 如果已关联，更新用户信息
            user = existingAccount.get().getUser();
            user.setAvatarUrl(avatarUrl);
            user.setNickname(nickname);
        } else {
            // 如果未关联，查找或创建本地用户
            Optional<User> existingUser = userRepository.findByEmail(email);
            if (existingUser.isPresent()) {
                // 如果邮箱已存在，使用现有用户
                user = existingUser.get();
            } else {
                // 创建新用户（密码为空，因为是 OAuth 用户）
                user = User.register(email, null, nickname);
                user.setAvatarUrl(avatarUrl);
                user.setBio(bio);
                user.setBlogUrl(blogUrl);
                user = userRepository.save(user);
            }

            // 创建 OAuth 账户关联
            OAuthAccount oauthAccount = new OAuthAccount(user, OAuthProvider.GITHUB, providerUserId, login);
            oauthAccountRepository.save(oauthAccount);
        }

        // 返回 GithubOAuth2User 对象
        return new GithubOAuth2User(oauth2User, user);
    }
}
