package com.caoqiang.blog.auth.application.exception;

import com.caoqiang.blog.shared.exception.BusinessException;
import org.springframework.http.HttpStatus;

/** Carries a stable OAuth error code for both API and Spring Security adapters. */
public class GithubAccountException extends BusinessException {

    private final String code;

    public GithubAccountException(String code, HttpStatus status, String message) {
        super(status, message);
        this.code = code;
    }

    public String code() {
        return code;
    }
}
