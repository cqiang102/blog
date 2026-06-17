package com.caoqiang.blog.ai;

import static org.assertj.core.api.Assertions.assertThat;

import com.caoqiang.blog.config.AiConfig;
import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.shared.model.Role;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class AiConfigTest {

    @Test
    void systemPromptSeparatesBloggerAndCurrentUserRoles() {
        AuthenticatedUser currentUser = new AuthenticatedUser(
                UUID.fromString("11111111-1111-1111-1111-111111111111"),
                "reader@example.com",
                "读者",
                Role.USER
        );

        String prompt = AiConfig.systemPrompt(currentUser);

        assertThat(prompt)
                .contains("“用户”“访客”“我”“我的”“帮我”通常指正在提问的当前登录用户")
                .contains("当用户问“我是谁/我的信息”时，优先根据下方当前登录用户上下文回答")
                .contains("- 用户昵称：读者")
                .contains("- 用户邮箱：reader@example.com")
                .contains("- 用户角色：USER")
                .doesNotContain("{{currentUserNickname}}");
    }
}
