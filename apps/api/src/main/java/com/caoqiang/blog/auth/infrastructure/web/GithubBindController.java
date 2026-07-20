package com.caoqiang.blog.auth.infrastructure.web;

import com.caoqiang.blog.auth.application.dto.AuthTokenResponse;
import com.caoqiang.blog.auth.application.port.GithubOAuthClient;
import com.caoqiang.blog.auth.application.service.GithubAccountService;
import com.caoqiang.blog.auth.application.service.JwtService;
import com.caoqiang.blog.auth.application.service.OAuthStateService;
import com.caoqiang.blog.auth.application.service.RefreshTokenService;
import com.caoqiang.blog.content.application.api.ContentMediaService;
import com.caoqiang.blog.shared.exception.BusinessException;
import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.shared.response.ApiResponse;
import com.caoqiang.blog.user.application.api.IdentityUser;
import com.caoqiang.blog.user.application.api.UserProfileResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.util.Map;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** Maps GitHub login and binding HTTP requests onto the shared OAuth application flow. */
@RestController
@RequestMapping("/api/v1/auth/github")
public class GithubBindController {

    private final JwtService jwtService;
    private final OAuthStateService oAuthStateService;
    private final OAuthStateCookieService oAuthStateCookieService;
    private final GithubOAuthClient githubOAuthClient;
    private final GithubAccountService githubAccountService;
    private final RefreshTokenService refreshTokenService;
    private final ContentMediaService contentMediaService;
    private final RefreshTokenCookieService refreshTokenCookieService;
    private final String frontendBaseUrl;

    public GithubBindController(
            JwtService jwtService,
            OAuthStateService oAuthStateService,
            OAuthStateCookieService oAuthStateCookieService,
            GithubOAuthClient githubOAuthClient,
            GithubAccountService githubAccountService,
            RefreshTokenService refreshTokenService,
            ContentMediaService contentMediaService,
            RefreshTokenCookieService refreshTokenCookieService,
            @Value("${blog.frontend.base-url:http://localhost:3000}") String frontendBaseUrl) {
        this.jwtService = jwtService;
        this.oAuthStateService = oAuthStateService;
        this.oAuthStateCookieService = oAuthStateCookieService;
        this.githubOAuthClient = githubOAuthClient;
        this.githubAccountService = githubAccountService;
        this.refreshTokenService = refreshTokenService;
        this.contentMediaService = contentMediaService;
        this.refreshTokenCookieService = refreshTokenCookieService;
        this.frontendBaseUrl = frontendBaseUrl;
    }

    @GetMapping("/bind")
    public ApiResponse<Map<String, String>> bind(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            HttpServletRequest request,
            HttpServletResponse response) {
        if (currentUser == null) {
            throw new BusinessException(HttpStatus.UNAUTHORIZED, "请先登录");
        }
        String browserId = oAuthStateCookieService.resolveOrCreate(request, response);
        String state = oAuthStateService.createBindingState(currentUser.id(), browserId);
        response.setHeader(HttpHeaders.CACHE_CONTROL, "no-store");
        return ApiResponse.ok(Map.of("url", githubOAuthClient.authorizationUrl(callbackUrl(), state)));
    }

    @PostMapping("/callback")
    public ApiResponse<AuthTokenResponse> callback(
            @RequestParam String code,
            @RequestParam String state,
            HttpServletRequest request,
            HttpServletResponse response) {
        OAuthStateService.ConsumedState consumedState =
                oAuthStateService.consume(state, oAuthStateCookieService.read(request));
        UUID bindingUserId = consumedState.bindingUserId();

        IdentityUser user = githubAccountService.resolve(githubOAuthClient.exchange(code), bindingUserId);
        JwtService.JwtToken accessToken = jwtService.createAccessToken(user);
        RefreshTokenService.RawRefreshToken refreshToken = refreshTokenService.createFor(user.id());
        refreshTokenCookieService.write(response, refreshToken.value());

        return ApiResponse.ok(new AuthTokenResponse(
                accessToken.value(),
                accessToken.expiresAt(),
                UserProfileResponse.from(user, contentMediaService.resolveUrl(user.avatarUrl()))));
    }

    private String callbackUrl() {
        return frontendBaseUrl + "/login/oauth2/code/github";
    }
}
