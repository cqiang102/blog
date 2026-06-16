package com.caoqiang.blog.shared.util;

import com.caoqiang.blog.shared.exception.BusinessException;
import java.nio.charset.StandardCharsets;
import org.springframework.http.HttpStatus;

public final class PasswordPolicy {

    public static final int MIN_CHARACTERS = 8;
    public static final int MAX_BCRYPT_BYTES = 72;

    private PasswordPolicy() {
    }

    public static void validate(String password) {
        if (password == null || password.length() < MIN_CHARACTERS) {
            throw new BusinessException(HttpStatus.BAD_REQUEST, "密码至少需要 8 个字符");
        }
        if (password.getBytes(StandardCharsets.UTF_8).length > MAX_BCRYPT_BYTES) {
            throw new BusinessException(HttpStatus.BAD_REQUEST, "密码不能超过 72 个 UTF-8 字节");
        }
    }
}
