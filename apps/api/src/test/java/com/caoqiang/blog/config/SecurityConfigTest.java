package com.caoqiang.blog.config;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.caoqiang.blog.auth.application.service.JwtService;
import com.caoqiang.blog.auth.infrastructure.web.JwtAuthenticationFilter;
import com.caoqiang.blog.user.application.api.UserAccountService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(controllers = SecurityActuatorProbeController.class)
@Import({SecurityConfig.class, JwtAuthenticationFilter.class})
class SecurityConfigTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private JwtService jwtService;

    @MockitoBean
    private UserAccountService userAccountService;

    @Test
    void healthEndpointsRemainPublic() throws Exception {
        mockMvc.perform(get("/actuator/health/readiness"))
                .andExpect(status().isOk())
                .andExpect(content().string("ok"));
    }

    @Test
    void otherActuatorEndpointsRejectAnonymousUsers() throws Exception {
        mockMvc.perform(get("/actuator/metrics")).andExpect(status().isUnauthorized());
    }

    @Test
    void otherActuatorEndpointsRejectRegularUsers() throws Exception {
        mockMvc.perform(get("/actuator/metrics").with(user("reader").roles("USER")))
                .andExpect(status().isForbidden());
    }

    @Test
    void otherActuatorEndpointsAllowAdministrators() throws Exception {
        mockMvc.perform(get("/actuator/metrics").with(user("admin").roles("ADMIN")))
                .andExpect(status().isOk())
                .andExpect(content().string("ok"));
    }

    @Test
    void responsesIncludeSecurityHeaders() throws Exception {
        mockMvc.perform(get("/actuator/health/readiness"))
                .andExpect(header().string("X-Frame-Options", "DENY"))
                .andExpect(header().string("X-Content-Type-Options", "nosniff"))
                .andExpect(header().string("Referrer-Policy", "strict-origin-when-cross-origin"))
                .andExpect(header().string(
                                "Content-Security-Policy",
                                "default-src 'self'; img-src 'self' data: https:; style-src 'self' 'unsafe-inline'"));
    }

    @Test
    void httpsResponsesIncludeHstsHeader() throws Exception {
        mockMvc.perform(get("/actuator/health/readiness").secure(true))
                .andExpect(header().string("Strict-Transport-Security", "max-age=31536000 ; includeSubDomains"));
    }
}
