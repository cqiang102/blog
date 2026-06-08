package com.caoqiang.blog.auth;

import com.caoqiang.blog.auth.dto.AuthTokenResponse;
import com.caoqiang.blog.auth.entity.OAuthAccount;
import com.caoqiang.blog.auth.enums.OAuthProvider;
import com.caoqiang.blog.auth.repository.OAuthAccountRepository;
import com.caoqiang.blog.auth.service.JwtService;
import com.caoqiang.blog.auth.service.RefreshTokenService;
import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.shared.response.ApiResponse;
import com.caoqiang.blog.user.User;
import com.caoqiang.blog.user.UserProfileResponse;
import com.caoqiang.blog.user.UserRepository;
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

/**
 * GitHub OAuth 控制器
 * 纯 API，返回 JSON，不重定向。
 * <p>
 * 绑定流程：前端调 /bind 获取绑定 URL → 跳 GitHub → 前端收到 code → 前端调 /callback 完成绑定
 * 登录流程：前端跳 GitHub → 前端收到 code → 前端调 /callback（不带 state）完成登录
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
            @Value("${spring.security.oauth2.client.registration.github.client-id:}") String clientId,
            @Value("${spring.security.oauth2.client.registration.github.client-secret:}") String clientSecret,
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
        String githubUrl = "https://github.com/login/oauth/authorize"
                + "?client_id=" + clientId
                + "&redirect_uri=" + callbackUrl
                + "&scope=read:user,user:email"
                + "&state=" + bindingToken;
        return ApiResponse.ok(Map.of("url", githubUrl));
    }

    /**
     * 前端回调接口：交换 GitHub code 获取用户信息，完成登录或绑定。
     * 纯 API，返回 JSON（AuthTokenResponse）。
     *
     * @param code  GitHub 授权码
     * @param state 可选，绑定令牌
     * @return 登录令牌
     */
    @PostMapping("/callback")
    @Transactional
    public ApiResponse<AuthTokenResponse> callback(
            @RequestParam String code,
            @RequestParam(required = false) String state) {

        log.info("GitHub callback: code={}, state={}, clientId={}", code, state, clientId);

        if (clientId == null || clientId.isBlank()) {
            log.error("GitHub client-id is not configured!");
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "GitHub OAuth 未配置");
        }

        String accessToken = exchangeCodeForToken(code);
        if (accessToken == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "GitHub 授权失败");
        }

        Map<String, Object> githubUser = fetchGithubUser(accessToken);
        String providerUserId = String.valueOf(githubUser.get("id"));
        String login = (String) githubUser.get("login");
        String name = (String) githubUser.get("name");
        String avatarUrl = (String) githubUser.get("avatar_url");
        String email = (String) githubUser.get("email");
        String bio = (String) githubUser.get("bio");
        String blogUrl = (String) githubUser.get("blog");

        if (email == null || email.isBlank()) {
            email = login + "@github.local";
        }
        String nickname = (name != null && !name.isBlank()) ? name : login;

        UUID bindUserId = null;
        if (state != null && !state.isBlank()) {
            bindUserId = jwtService.parseBindingToken(state);
        }

        User user;

        if (bindUserId != null) {
            user = userRepository.findById(bindUserId)
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
                user = existingAccount.get().getUser();
                user.setAvatarUrl(avatarUrl);
                user.setNickname(nickname);
            } else {
                var existingUser = userRepository.findByEmail(email);
                if (existingUser.isPresent()) {
                    user = existingUser.get();
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

    private String exchangeCodeForToken(String code) {
        try {
            log.info("Exchanging code for token, clientId={}", clientId);
            RestClient restClient = RestClient.create();
            @SuppressWarnings("unchecked")
            Map<String, Object> response = restClient.post()
                    .uri("https://github.com/login/oauth/access_token")
                    .header("Accept", "application/json")
                    .body(Map.of("client_id", clientId, "client_secret", clientSecret, "code", code))
                    .retrieve()
                    .body(Map.class);
            log.info("GitHub token response keys: {}", response != null ? response.keySet() : "null");
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
                log.info("GitHub access_token obtained successfully");
                return tokenStr;
            }
            log.warn("GitHub token exchange: access_token is missing or empty, response={}", response);
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
