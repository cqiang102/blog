package com.caoqiang.blog.shared;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.caoqiang.blog.shared.exception.BusinessException;
import com.caoqiang.blog.shared.util.PasswordPolicy;
import org.junit.jupiter.api.Test;

class PasswordPolicyTest {

    @Test
    void acceptsPasswordWithinBcryptByteLimit() {
        assertThatCode(() -> PasswordPolicy.validate("12345678")).doesNotThrowAnyException();
    }

    @Test
    void rejectsMultibytePasswordOverBcryptByteLimit() {
        assertThatThrownBy(() -> PasswordPolicy.validate("中".repeat(25)))
                .isInstanceOfSatisfying(
                        BusinessException.class,
                        exception -> org.assertj.core.api.Assertions.assertThat(exception.getMessage())
                                .isEqualTo("密码不能超过 72 个 UTF-8 字节"));
    }
}
