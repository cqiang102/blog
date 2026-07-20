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
                UUID.fromString("11111111-1111-1111-1111-111111111111"), "reader@example.com", "读者", Role.USER);

        String prompt = AiConfig.systemPrompt(currentUser);

        assertThat(prompt)
                .contains("“用户”“访客”“我”“我的”“帮我”通常指正在提问的当前登录用户")
                .contains("当用户问“我是谁/我的信息”时，优先根据下方当前登录用户上下文回答")
                .contains("“博主”“站长”“管理员”“你”“你的”默认指沐凉个人博客的主人")
                .contains("当用户问“你是谁/你会什么技术/你的技术栈/你的项目/你的经历/你的联系方式/你喜欢什么”时，搜索知识库并按博主资料回答")
                .contains("- 用户昵称：读者")
                .contains("回复格式规则")
                .contains("回复内容策略")
                .contains("不要输出用户 ID、邮箱、角色等内部账号信息")
                .contains("用户问“你会什么技术/你的技术栈是什么”时，回答博主沐凉的技术栈")
                .contains("不要回答 AI 助手自己的搜索、工具调用或模型能力")
                .doesNotContain("{{currentUserNickname}}")
                .doesNotContain("11111111-1111-1111-1111-111111111111")
                .doesNotContain("reader@example.com")
                .doesNotContain("- 用户角色：USER");
    }
}
