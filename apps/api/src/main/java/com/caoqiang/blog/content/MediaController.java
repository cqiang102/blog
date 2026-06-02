package com.caoqiang.blog.content;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.UUID;
import org.springframework.core.io.InputStreamResource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.util.StringUtils;

@RestController
@RequestMapping("/api/v1/media-assets")
public class MediaController {

    private final MediaAdminService mediaAdminService;

    public MediaController(MediaAdminService mediaAdminService) {
        this.mediaAdminService = mediaAdminService;
    }

    @GetMapping("/{id}/file")
    public ResponseEntity<InputStreamResource> file(@PathVariable UUID id) {
        MediaDownload download = mediaAdminService.download(id);
        String filename = StringUtils.hasText(download.filename()) ? download.filename() : id.toString();
        String encodedFilename = URLEncoder.encode(filename, StandardCharsets.UTF_8).replace("+", "%20");
        MediaType mediaType = StringUtils.hasText(download.contentType())
                ? MediaType.parseMediaType(download.contentType())
                : MediaType.APPLICATION_OCTET_STREAM;

        ResponseEntity.BodyBuilder response = ResponseEntity.ok()
                .contentType(mediaType)
                .header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename=\"" + encodedFilename + "\"");
        if (download.byteSize() != null) {
            response.contentLength(download.byteSize());
        }
        return response.body(new InputStreamResource(download.inputStream()));
    }
}
