package com.caoqiang.blog.auth.infrastructure.github;

import com.caoqiang.blog.auth.application.dto.GithubProfile;
import com.caoqiang.blog.auth.application.exception.GithubAccountException;
import com.caoqiang.blog.auth.application.port.GithubOAuthClient;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.web.client.RestClient;
import org.springframework.web.util.UriComponentsBuilder;

/** GitHub HTTP adapter; raw provider payloads do not leak into application services. */
@Component
public class RestGithubOAuthClient implements GithubOAuthClient {

    private static final Logger log = LoggerFactory.getLogger(RestGithubOAuthClient.class);

    private final RestClient restClient;
    private final String clientId;
    private final String clientSecret;

    public RestGithubOAuthClient(
            RestClient.Builder restClientBuilder,
            @Value("${blog.oauth.github.client-id:}") String clientId,
            @Value("${blog.oauth.github.client-secret:}") String clientSecret) {
        this.restClient = restClientBuilder.build();
        this.clientId = clientId;
        this.clientSecret = clientSecret;
    }

    @Override
    public String authorizationUrl(String callbackUrl, String state) {
        requireConfigured();
        return UriComponentsBuilder.fromUriString("https://github.com/login/oauth/authorize")
                .queryParam("client_id", clientId)
                .queryParam("redirect_uri", callbackUrl)
                .queryParam("scope", "read:user,user:email")
                .queryParam("state", state)
                .build()
                .encode()
                .toUriString();
    }

    @Override
    public GithubProfile exchange(String code) {
        requireConfigured();
        try {
            String accessToken = exchangeCodeForToken(code);
            Map<String, Object> user = fetchUser(accessToken);
            return new GithubProfile(
                    stringValue(user, "id"),
                    stringValue(user, "login"),
                    optionalString(user, "email"),
                    optionalString(user, "name"),
                    optionalString(user, "avatar_url"),
                    optionalString(user, "bio"),
                    optionalString(user, "blog"));
        } catch (GithubAccountException exception) {
            throw exception;
        } catch (IllegalArgumentException exception) {
            throw providerError(HttpStatus.BAD_REQUEST, "GitHub 用户信息不完整", exception);
        } catch (Exception exception) {
            throw providerError(HttpStatus.BAD_GATEWAY, "GitHub OAuth 服务暂不可用", exception);
        }
    }

    @SuppressWarnings("unchecked")
    private String exchangeCodeForToken(String code) {
        LinkedMultiValueMap<String, String> form = new LinkedMultiValueMap<>();
        form.add("client_id", clientId);
        form.add("client_secret", clientSecret);
        form.add("code", code);

        Map<String, Object> response = restClient
                .post()
                .uri("https://github.com/login/oauth/access_token")
                .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                .header("Accept", MediaType.APPLICATION_JSON_VALUE)
                .body(form)
                .retrieve()
                .body(Map.class);
        if (response == null) {
            throw providerError(HttpStatus.BAD_GATEWAY, "GitHub 令牌响应为空", null);
        }
        if (response.containsKey("error")) {
            log.warn(
                    "GitHub 令牌交换失败: code={}, description={}", response.get("error"), response.get("error_description"));
            throw providerError(HttpStatus.BAD_REQUEST, "GitHub 授权失败", null);
        }
        String token = optionalString(response, "access_token");
        if (token == null || token.isBlank()) {
            throw providerError(HttpStatus.BAD_REQUEST, "GitHub 授权未返回访问令牌", null);
        }
        return token;
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> fetchUser(String accessToken) {
        Map<String, Object> response = restClient
                .get()
                .uri("https://api.github.com/user")
                .header("Authorization", "Bearer " + accessToken)
                .header("Accept", "application/vnd.github+json")
                .header("X-GitHub-Api-Version", "2022-11-28")
                .retrieve()
                .body(Map.class);
        if (response == null) {
            throw providerError(HttpStatus.BAD_GATEWAY, "GitHub 用户响应为空", null);
        }
        return response;
    }

    private void requireConfigured() {
        if (clientId == null || clientId.isBlank() || clientSecret == null || clientSecret.isBlank()) {
            throw providerError(HttpStatus.SERVICE_UNAVAILABLE, "GitHub OAuth 未配置", null);
        }
    }

    private String stringValue(Map<String, Object> source, String key) {
        String value = optionalString(source, key);
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException("Missing GitHub field: " + key);
        }
        return value;
    }

    private String optionalString(Map<String, Object> source, String key) {
        Object value = source.get(key);
        return value == null ? null : value.toString();
    }

    private GithubAccountException providerError(HttpStatus status, String message, Exception cause) {
        if (cause != null) {
            log.warn("{}: {}", message, cause.getMessage());
        }
        return new GithubAccountException("provider_error", status, message);
    }
}
