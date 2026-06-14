package com.caoqiang.blog.auth.infrastructure.web;

import com.caoqiang.blog.auth.application.dto.GithubOAuth2User;
import com.caoqiang.blog.auth.application.dto.AuthTokenResponse;
import com.caoqiang.blog.auth.application.service.JwtService;
import com.caoqiang.blog.auth.application.service.OAuthLoginCodeService;
import com.caoqiang.blog.auth.application.service.RefreshTokenService;

import com.caoqiang.blog.user.domain.model.User;
import com.caoqiang.blog.user.application.dto.UserProfileResponse;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.core.Authentication;
import org.springframework.security.web.authentication.AuthenticationSuccessHandler;
import org.springframework.stereotype.Component;

/**
 * OAuth2 登录成功处理器
 * GitHub 授权成功后重定向到前端，携带 JWT token。
 */
@Component
public class OAuth2LoginSuccessHandler implements AuthenticationSuccessHandler {

    private final JwtService jwtService;
    private final RefreshTokenService refreshTokenService;
    private final OAuthLoginCodeService oAuthLoginCodeService;
    private final String frontendBaseUrl;

    public OAuth2LoginSuccessHandler(
            JwtService jwtService,
            RefreshTokenService refreshTokenService,
            OAuthLoginCodeService oAuthLoginCodeService,
            @Value("${blog.frontend.base-url:http://localhost:3000}") String frontendBaseUrl) {
        this.jwtService = jwtService;
        this.refreshTokenService = refreshTokenService;
        this.oAuthLoginCodeService = oAuthLoginCodeService;
        this.frontendBaseUrl = frontendBaseUrl;
    }

    @Override
    public void onAuthenticationSuccess(HttpServletRequest request, HttpServletResponse response,
                                        Authentication authentication) throws IOException, ServletException {
        GithubOAuth2User oauth2User = (GithubOAuth2User) authentication.getPrincipal();
        User user = oauth2User.getUser();

        JwtService.JwtToken accessToken = jwtService.createAccessToken(user);
        RefreshTokenService.RawRefreshToken refreshToken = refreshTokenService.createFor(user);

        AuthTokenResponse session = new AuthTokenResponse(
                accessToken.value(),
                refreshToken.value(),
                accessToken.expiresAt(),
                UserProfileResponse.from(user)
        );
        String loginCode = oAuthLoginCodeService.create(session);
        String redirectUrl = frontendBaseUrl + "/login/oauth2/code/github?login_code=" + loginCode;

        response.sendRedirect(redirectUrl);
    }
}
