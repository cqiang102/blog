package com.caoqiang.blog.shared.infrastructure.web;

import com.caoqiang.blog.shared.response.ApiResponse;
import com.caoqiang.blog.shared.response.AppMetadata;
import java.time.Instant;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 元数据与健康检查端点控制器。
 * <p>
 * 提供应用的基本元信息（名称、版本、当前时间），可用于：
 * <ul>
 *     <li>部署后快速验证服务是否正常启动</li>
 *     <li>负载均衡器健康探测</li>
 *     <li>前端获取 API 版本信息</li>
 * </ul>
 * <p>
 * 此接口已配置为匿名可访问（见 {@link com.caoqiang.blog.config.SecurityConfig}）。
 *
 * @author caoqiang
 */
@RestController
@RequestMapping("/api/v1/meta")
public class MetaController {

    /**
     * 获取应用元数据信息。
     *
     * @return 应用元数据
     */
    @GetMapping
    public ApiResponse<AppMetadata> meta() {
        return ApiResponse.ok(new AppMetadata("personal-blog-api", "0.1.0-SNAPSHOT", Instant.now()));
    }
}
