package com.caoqiang.blog.auth.application.dto;

/** Provider-neutral data needed to resolve a GitHub login or binding. */
public record GithubProfile(
        String providerUserId,
        String login,
        String email,
        String nickname,
        String avatarUrl,
        String bio,
        String blogUrl) {
    public GithubProfile {
        providerUserId = required(providerUserId, "GitHub 用户标识为空");
        login = required(login, "GitHub 登录名为空");
        email = normalizedEmail(email, login);
        nickname = nickname == null || nickname.isBlank() ? login : nickname.trim();
    }

    private static String required(String value, String message) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(message);
        }
        return value.trim();
    }

    private static String normalizedEmail(String email, String login) {
        return email == null || email.isBlank() ? login + "@github.local" : email.trim();
    }
}
