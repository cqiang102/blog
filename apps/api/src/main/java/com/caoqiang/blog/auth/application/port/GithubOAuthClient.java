package com.caoqiang.blog.auth.application.port;

import com.caoqiang.blog.auth.application.dto.GithubProfile;

/** External GitHub OAuth capability exposed to the application layer. */
public interface GithubOAuthClient {

    String authorizationUrl(String callbackUrl, String state);

    GithubProfile exchange(String code);
}
