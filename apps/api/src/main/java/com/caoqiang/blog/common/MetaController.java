package com.caoqiang.blog.common;

import java.time.Instant;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/meta")
public class MetaController {

    @GetMapping
    public ApiResponse<Map<String, Object>> meta() {
        return ApiResponse.ok(Map.of(
                "name", "personal-blog-api",
                "version", "0.1.0-SNAPSHOT",
                "time", Instant.now()
        ));
    }
}
