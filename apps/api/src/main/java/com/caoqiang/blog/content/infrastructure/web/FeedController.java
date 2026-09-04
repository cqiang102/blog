package com.caoqiang.blog.content.infrastructure.web;

import com.caoqiang.blog.content.application.service.FeedQueryService;
import jakarta.servlet.http.HttpServletRequest;
import java.nio.charset.StandardCharsets;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.util.DigestUtils;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Public XML endpoint; Caddy exposes it at the canonical /atom.xml address. */
@RestController
@RequestMapping("/api/v1/feed")
public class FeedController {

    private final FeedQueryService feedQueryService;

    public FeedController(FeedQueryService feedQueryService) {
        this.feedQueryService = feedQueryService;
    }

    @GetMapping(value = "/atom", produces = "application/atom+xml;charset=UTF-8")
    public ResponseEntity<byte[]> atom(HttpServletRequest request) {
        byte[] body = feedQueryService.atom().getBytes(StandardCharsets.UTF_8);
        // MVC compares concrete ETags (including weak/list validators). Handle existence checks
        // explicitly because its safe-method conditional response handling ignores '*'.
        boolean existsValidator = "*".equals(request.getHeader(HttpHeaders.IF_NONE_MATCH));
        var response = ResponseEntity.status(existsValidator ? HttpStatus.NOT_MODIFIED : HttpStatus.OK)
                .contentType(new MediaType("application", "atom+xml", StandardCharsets.UTF_8))
                .cacheControl(CacheControl.noCache().cachePublic())
                .eTag(DigestUtils.md5DigestAsHex(body));
        if (existsValidator) {
            return response.build();
        }
        if ("HEAD".equals(request.getMethod())) {
            return response.contentLength(body.length).build();
        }
        return response.body(body);
    }
}
