package com.caoqiang.blog.config;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/** Test-only endpoints used to exercise actuator authorization matchers. */
@RestController
public class SecurityActuatorProbeController {

    @GetMapping({"/actuator/health", "/actuator/health/readiness", "/actuator/metrics"})
    public String probe() {
        return "ok";
    }
}
