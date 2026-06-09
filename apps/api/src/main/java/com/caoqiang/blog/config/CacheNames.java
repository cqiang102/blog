package com.caoqiang.blog.config;

/**
 * 缓存名称常量类
 * <p>
 * 集中管理所有缓存名称，避免魔法字符串散落在代码各处。
 * 位于配置层，供 {@link RedisConfig} 和各业务服务引用。
 * </p>
 * <p>
 * 缓存说明：
 * <ul>
 *   <li>{@link #RECOMMENDATIONS} - 推荐内容缓存</li>
 *   <li>{@link #AI_QUOTA} - AI 配额计数缓存</li>
 *   <li>{@link #KNOWLEDGE_DOCS} - 知识库文档缓存</li>
 * </ul>
 * </p>
 */
public final class CacheNames {

    /** 推荐内容缓存 */
    public static final String RECOMMENDATIONS = "recommendations";
    /** AI 配额计数缓存 */
    public static final String AI_QUOTA = "aiQuota";
    /** 知识库文档缓存 */
    public static final String KNOWLEDGE_DOCS = "knowledgeDocs";

    private CacheNames() {
        // 私有构造函数，防止实例化
    }
}
