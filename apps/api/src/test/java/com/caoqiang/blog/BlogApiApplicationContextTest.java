package com.caoqiang.blog;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.MOCK)
@ActiveProfiles({"local", "nodb"})
class BlogApiApplicationContextTest {

    @Test
    void contextLoadsWithoutDatabaseForDiagnostics() {
    }
}
