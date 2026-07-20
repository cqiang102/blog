package com.caoqiang.blog.shared.response;

import java.time.Instant;

/**
 * 应用元数据 DTO。
 * <p>
 * 用于返回应用的基本元信息，替代 {@code Map<String, Object>}。
 *
 * @param name    应用名称
 * @param version 版本号
 * @param time    服务器当前时间
 * @author caoqiang
 */
public record AppMetadata(String name, String version, Instant time) {}
