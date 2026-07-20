package com.caoqiang.blog;

import static org.assertj.core.api.Assertions.assertThat;

import com.caoqiang.blog.shared.response.ApiResponse;
import org.junit.jupiter.api.Test;

class ApiResponseTest {

    @Test
    void okWrapsData() {
        ApiResponse<String> response = ApiResponse.ok("ready");

        assertThat(response.success()).isTrue();
        assertThat(response.data()).isEqualTo("ready");
        assertThat(response.message()).isEqualTo("ok");
    }
}
