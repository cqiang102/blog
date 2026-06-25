package com.caoqiang.blog.auth.infrastructure.web;

import com.caoqiang.blog.auth.application.dto.AuthTokenResponse;
import com.caoqiang.blog.auth.domain.model.OAuthAccount;
import com.caoqiang.blog.auth.domain.model.OAuthProvider;
import com.caoqiang.blog.auth.domain.repository.OAuthAccountRepository;
import com.caoqiang.blog.auth.application.service.JwtService;
import com.caoqiang.blog.auth.application.service.RefreshTokenService;
import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.shared.response.ApiResponse;
import com.caoqiang.blog.user.domain.model.User;
import com.caoqiang.blog.user.application.dto.UserProfileResponse;
import com.caoqiang.blog.user.domain.repository.UserRepository;
import java.util.Map;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestClient;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.util.UriComponentsBuilder;

/**
 * GitHub OAuth 控制器
 * 纯 API，返回 JSON，不重定向。
 * <p>
 * 绑定流程：前端调 /bind 获取绑定 URL → 跳 GitHub → 前端收到 code → 前端调 /callback 完成绑定
 * 登录流程：前端跳 GitHub → 前端收到 code 和签名 state → 前端调 /callback 完成登录
 */
@RestController
@RequestMapping("/api/v1/auth/github")
public class GithubBindController {

    private static final Logger log = LoggerFactory.getLogger(GithubBindController.class);

    private final JwtService jwtService;
    private final UserRepository userRepository;
    private final OAuthAccountRepository oauthAccountRepository;
    private final RefreshTokenService refreshTokenService;
    private final String clientId;
    private final String clientSecret;
    private final String frontendBaseUrl;

    public GithubBindController(
            JwtService jwtService,
            UserRepository userRepository,
            OAuthAccountRepository oauthAccountRepository,
            RefreshTokenService refreshTokenService,
            @Value("${blog.oauth.github.client-id:}") String clientId,
            @Value("${blog.oauth.github.client-secret:}") String clientSecret,
            @Value("${blog.frontend.base-url:http://localhost:3000}") String frontendBaseUrl) {
        this.jwtService = jwtService;
        this.userRepository = userRepository;
        this.oauthAccountRepository = oauthAccountRepository;
        this.refreshTokenService = refreshTokenService;
        this.clientId = clientId;
        this.clientSecret = clientSecret;
        this.frontendBaseUrl = frontendBaseUrl;
    }

    /**
     * 获取 GitHub 绑定授权 URL
     * 返回 GitHub 授权 URL，state 中携带签名绑定令牌（含用户 ID，5 分钟有效）。
     */
    @GetMapping("/bind")
    public ApiResponse<Map<String, String>> bind(@AuthenticationPrincipal AuthenticatedUser currentUser) {
        if (currentUser == null) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "请先登录");
        }
        String bindingToken = jwtService.createBindingToken(currentUser.id());
        String callbackUrl = frontendBaseUrl + "/login/oauth2/code/github";
        String githubUrl = UriComponentsBuilder
                .fromUriString("https://github.com/login/oauth/authorize")
                .queryParam("client_id", clientId)
                .queryParam("redirect_uri", callbackUrl)
                .queryParam("scope", "read:user,user:email")
                .queryParam("state", bindingToken)
                .build()
                .encode()
                .toUriString();
        return ApiResponse.ok(Map.of("url", githubUrl));
    }

    /**
     * 前端回调接口：交换 GitHub code 获取用户信息，完成登录或绑定。
     * 纯 API，返回 JSON（AuthTokenResponse）。
     *
     * @param code  GitHub 授权码
     * @param state 必填，登录或绑定流程的短期签名 state
     * @return 登录令牌
     */
    @PostMapping("/callback")
    @Transactional
    public ApiResponse<AuthTokenResponse> callback(
            @RequestParam String code,
            @RequestParam String state) {

        if (clientId == null || clientId.isBlank()) {
            log.error("GitHub client-id is not configured!");
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "GitHub OAuth 未配置");
        }

        UUID bindUserId = jwtService.parseBindingToken(state);
        if (bindUserId == null && !jwtService.isValidOAuthLoginState(state)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "OAuth state 无效或已过期");
        }

        String accessToken = exchangeCodeForToken(code);
        if (accessToken == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "GitHub 授权失败");
        }

        Map<String, Object> githubUser = fetchGithubUser(accessToken);
        if (githubUser == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "获取 GitHub 用户信息失败");
        }
        Object githubId = githubUser.get("id");
        String login = (String) githubUser.get("login");
        if (githubId == null || login == null || login.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "GitHub 用户信息不完整");
        }
        String providerUserId = githubId.toString();
        String name = (String) githubUser.get("name");
        String avatarUrl = (String) githubUser.get("avatar_url");
        String email = (String) githubUser.get("email");
        String bio = (String) githubUser.get("bio");
        String blogUrl = (String) githubUser.get("blog");

        if (email == null || email.isBlank()) {
            email = login + "@github.local";
        }
        String nickname = (name != null && !name.isBlank()) ? name : login;

        User user;

        if (bindUserId != null) {
            user = userRepository.findById(bindUserId)
                    .filter(User::isActive)
                    .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "用户不存在"));
            // 检查该 GitHub 是否已被其他人绑定
            var conflict = oauthAccountRepository.findByProviderAndProviderUserId(OAuthProvider.GITHUB, providerUserId);
            if (conflict.isPresent() && !conflict.get().getUser().getId().equals(bindUserId)) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "该 GitHub 账号已被其他用户绑定");
            }
            // 检查当前用户是否已绑定该 GitHub
            var alreadyBound = oauthAccountRepository.findByUserIdAndProvider(bindUserId, OAuthProvider.GITHUB);
            if (alreadyBound.isPresent()) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "您已绑定 GitHub 账号");
            }
            OAuthAccount oauthAccount = new OAuthAccount(user, OAuthProvider.GITHUB, providerUserId, login);
            oauthAccountRepository.save(oauthAccount);
            user.setAvatarUrl(avatarUrl);
            log.info("GitHub 绑定成功: userId={}, github={}", bindUserId, login);
        } else {
            var existingAccount = oauthAccountRepository
                    .findByProviderAndProviderUserId(OAuthProvider.GITHUB, providerUserId);
            if (existingAccount.isPresent()) {
                user = requireActive(existingAccount.get().getUser());
                user.setAvatarUrl(avatarUrl);
                user.setNickname(nickname);
            } else {
                var existingUser = userRepository.findByEmail(email);
                if (existingUser.isPresent()) {
                    throw new ResponseStatusException(
                            HttpStatus.CONFLICT,
                            "该邮箱已注册，请先使用原账号登录后绑定 GitHub"
                    );
                } else {
                    user = User.register(email, null, nickname);
                    user.setAvatarUrl(avatarUrl);
                    user.setBio(bio);
                    user.setBlogUrl(blogUrl);
                    user = userRepository.save(user);
                }
                OAuthAccount oauthAccount = new OAuthAccount(user, OAuthProvider.GITHUB, providerUserId, login);
                oauthAccountRepository.save(oauthAccount);
            }
            log.info("GitHub 登录成功: userId={}, github={}", user.getId(), login);
        }

        JwtService.JwtToken token = jwtService.createAccessToken(user);
        RefreshTokenService.RawRefreshToken refreshToken = refreshTokenService.createFor(user);

        return ApiResponse.ok(new AuthTokenResponse(
                token.value(),
                refreshToken.value(),
                token.expiresAt(),
                UserProfileResponse.from(user)
        ));
    }

    private User requireActive(User user) {
        if (!user.isActive()) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "账号已被禁用");
        }
        return user;
    }

    private String exchangeCodeForToken(String code) {
        try {
            RestClient restClient = RestClient.create();
            @SuppressWarnings("unchecked")
            Map<String, Object> response = restClient.post()
                    .uri("https://github.com/login/oauth/access_token")
                    .header("Accept", "application/json")
                    .body(Map.of("client_id", clientId, "client_secret", clientSecret, "code", code))
                    .retrieve()
                    .body(Map.class);
            if (response == null) {
                log.warn("GitHub token response is null");
                return null;
            }
            if (response.containsKey("error")) {
                log.warn("GitHub token error: {} - {}", response.get("error"), response.get("error_description"));
                return null;
            }
            Object token = response.get("access_token");
            if (token instanceof String tokenStr && !tokenStr.isBlank()) {
                return tokenStr;
            }
            log.warn("GitHub token exchange did not return an access token");
            return null;
        } catch (Exception e) {
            log.error("GitHub token exchange error", e);
            return null;
        }
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> fetchGithubUser(String accessToken) {
        try {
            RestClient restClient = RestClient.create();
            return restClient.get()
                    .uri("https://api.github.com/user")
                    .header("Authorization", "Bearer " + accessToken)
                    .header("Accept", "application/json")
                    .retrieve()
                    .body(Map.class);
        } catch (Exception e) {
            log.error("Fetch GitHub user error", e);
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "获取 GitHub 用户信息失败");
        }
    }
}
