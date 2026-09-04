package com.caoqiang.blog.content;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.head;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.caoqiang.blog.auth.application.service.JwtService;
import com.caoqiang.blog.auth.infrastructure.web.JwtAuthenticationFilter;
import com.caoqiang.blog.config.SecurityConfig;
import com.caoqiang.blog.content.application.service.FeedQueryService;
import com.caoqiang.blog.content.infrastructure.web.FeedController;
import com.caoqiang.blog.user.application.api.UserAccountService;
import java.nio.charset.StandardCharsets;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(controllers = FeedController.class)
@Import({SecurityConfig.class, JwtAuthenticationFilter.class})
class FeedControllerTest {

    private static final String URL = "/api/v1/feed/atom";
    private static final String XML = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
            + "<feed xmlns=\"http://www.w3.org/2005/Atom\"><title>沐凉·日记</title></feed>";

    @Autowired
    private MockMvc mvc;

    @MockitoBean
    private FeedQueryService feedQueryService;

    @MockitoBean
    private JwtService jwtService;

    @MockitoBean
    private UserAccountService userAccountService;

    @BeforeEach
    void feed() {
        when(feedQueryService.atom()).thenReturn(XML);
    }

    @Test
    void anonymousReadersReceiveUtf8XmlAndValidators() throws Exception {
        mvc.perform(get(URL))
                .andExpect(status().isOk())
                .andExpect(content().contentType("application/atom+xml;charset=UTF-8"))
                .andExpect(content().bytes(XML.getBytes(StandardCharsets.UTF_8)))
                .andExpect(header().exists("ETag"))
                .andExpect(header().string("Cache-Control", "no-cache, public"));
    }

    @Test
    void anonymousHeadReturnsHeadersWithoutBody() throws Exception {
        String etag = etag();
        mvc.perform(head(URL))
                .andExpect(status().isOk())
                .andExpect(content().string(""))
                .andExpect(header().string("ETag", etag))
                .andExpect(
                        header().string("Content-Length", String.valueOf(XML.getBytes(StandardCharsets.UTF_8).length)));
    }

    @Test
    void matchingStrongWeakAndWildcardValidatorsReturn304() throws Exception {
        String etag = etag();
        for (String validator : new String[] {etag, "\"old\", W/" + etag, "*"}) {
            mvc.perform(get(URL).header("If-None-Match", validator))
                    .andExpect(status().isNotModified())
                    .andExpect(content().string(""))
                    .andExpect(header().string("ETag", etag))
                    .andExpect(header().string("Cache-Control", "no-cache, public"));
        }
        mvc.perform(head(URL).header("If-None-Match", etag)).andExpect(status().isNotModified());
    }

    @Test
    void changedContentReturnsNewXmlAndEtag() throws Exception {
        String etag = etag();
        String updated = XML.replace("沐凉·日记", "更新后的日记");
        when(feedQueryService.atom()).thenReturn(updated);

        var result = mvc.perform(get(URL).header("If-None-Match", etag))
                .andExpect(status().isOk())
                .andExpect(content().bytes(updated.getBytes(StandardCharsets.UTF_8)))
                .andReturn();

        assertThat(result.getResponse().getHeader("ETag")).isNotEqualTo(etag);
    }

    @Test
    void feedPermissionDoesNotAllowAnonymousWritesOrOtherFeedPaths() throws Exception {
        mvc.perform(post(URL)).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/feed/private")).andExpect(status().isUnauthorized());
    }

    private String etag() throws Exception {
        return mvc.perform(get(URL)).andReturn().getResponse().getHeader("ETag");
    }
}
