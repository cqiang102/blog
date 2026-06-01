package com.caoqiang.blog.auth;

import com.caoqiang.blog.common.ApiResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

    @PostMapping("/register")
    public ApiResponse<AuthTokenResponse> register(@Valid @RequestBody RegisterRequest request) {
        return ApiResponse.ok(AuthTokenResponse.placeholder(request.email()));
    }

    @PostMapping("/login")
    public ApiResponse<AuthTokenResponse> login(@Valid @RequestBody LoginRequest request) {
        return ApiResponse.ok(AuthTokenResponse.placeholder(request.email()));
    }

    @PostMapping("/refresh")
    public ApiResponse<AuthTokenResponse> refresh(@Valid @RequestBody RefreshTokenRequest request) {
        return ApiResponse.ok(AuthTokenResponse.placeholder("refreshed@example.com"));
    }

    @GetMapping("/providers")
    public ApiResponse<Map<String, Object>> providers() {
        return ApiResponse.ok(Map.of(
                "enabled", List.of(OAuthProvider.GITHUB),
                "reserved", List.of(OAuthProvider.QQ),
                "githubAuthorizationUrl", "/oauth2/authorization/github"
        ));
    }

    public record RegisterRequest(
            @Email String email,
            @NotBlank @Size(min = 8, max = 80) String password,
            @NotBlank @Size(max = 80) String nickname
    ) {
    }

    public record LoginRequest(
            @Email String email,
            @NotBlank String password
    ) {
    }

    public record RefreshTokenRequest(@NotBlank String refreshToken) {
    }

    public record AuthTokenResponse(
            String accessToken,
            String refreshToken,
            Instant expiresAt,
            UserPrincipal user
    ) {
        static AuthTokenResponse placeholder(String email) {
            return new AuthTokenResponse(
                    "replace-with-signed-jwt",
                    "replace-with-refresh-token",
                    Instant.now().plusSeconds(1800),
                    new UserPrincipal(email, "新用户", Role.USER)
            );
        }
    }

    public record UserPrincipal(String email, String nickname, Role role) {
    }
}
