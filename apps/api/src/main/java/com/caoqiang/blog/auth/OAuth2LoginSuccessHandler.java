package com.caoqiang.blog.auth;

import com.caoqiang.blog.user.User;
import com.caoqiang.blog.user.UserProfileResponse;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.security.core.Authentication;
import org.springframework.security.web.authentication.AuthenticationSuccessHandler;
import org.springframework.stereotype.Component;

@Component
public class OAuth2LoginSuccessHandler implements AuthenticationSuccessHandler {

    private final JwtService jwtService;
    private final RefreshTokenService refreshTokenService;
    private final ObjectMapper objectMapper;

    public OAuth2LoginSuccessHandler(JwtService jwtService, RefreshTokenService refreshTokenService, ObjectMapper objectMapper) {
        this.jwtService = jwtService;
        this.refreshTokenService = refreshTokenService;
        this.objectMapper = objectMapper;
    }

    @Override
    public void onAuthenticationSuccess(HttpServletRequest request, HttpServletResponse response,
                                        Authentication authentication) throws IOException, ServletException {
        GithubOAuth2User oauth2User = (GithubOAuth2User) authentication.getPrincipal();
        User user = oauth2User.getUser();

        JwtService.JwtToken accessToken = jwtService.createAccessToken(user);
        RefreshTokenService.RawRefreshToken refreshToken = refreshTokenService.createFor(user);

        response.setContentType("application/json;charset=UTF-8");
        response.getWriter().write(objectMapper.writeValueAsString(new AuthTokenResponse(
                accessToken.value(),
                refreshToken.value(),
                accessToken.expiresAt(),
                UserProfileResponse.from(user)
        )));
    }
}
