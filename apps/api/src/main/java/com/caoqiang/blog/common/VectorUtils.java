package com.caoqiang.blog.common;

/**
 * 向量工具类。
 * <p>
 * 提供向量数据格式转换等通用方法，供 AI 知识库索引和搜索模块使用。
 *
 * @author caoqiang
 */
public final class VectorUtils {

    private VectorUtils() {
    }

    /**
     * 将 float 数组转换为 PostgreSQL vector 类型的字符串格式。
     * <p>
     * 例如：{@code [1.0,2.0,3.0]}
     *
     * @param embedding float 数组
     * @return PostgreSQL vector 字符串
     */
    public static String toPgVectorString(float[] embedding) {
        StringBuilder sb = new StringBuilder("[");
        for (int i = 0; i < embedding.length; i++) {
            if (i > 0) sb.append(",");
            sb.append(embedding[i]);
        }
        sb.append("]");
        return sb.toString();
    }
}
