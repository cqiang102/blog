package com.caoqiang.blog.ai.chat.application.service;

import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.springframework.stereotype.Service;

/**
 * 敏感词检查服务。
 * <p>
 * 支持两种匹配方式：
 * <ul>
 *   <li>关键词匹配（contains）— 快速精确命中</li>
 *   <li>正则匹配（Pattern）— 覆盖变体和模糊写法</li>
 * </ul>
 */
@Service
public class SensitiveWordService {

    /** 关键词敏感词（精确包含匹配） */
    private static final List<String> KEYWORDS = List.of(
            // 赌博
            "赌博",
            "博彩",
            "彩票预测",
            "网赌",
            "赌球",
            "赌马",
            "外围博彩",
            "百家乐",
            "老虎机",
            "六合彩",
            "时时彩",
            "北京赛车",
            // 色情
            "色情",
            "裸聊",
            "约炮",
            "一夜情",
            "援交",
            "楼凤",
            "成人视频",
            "黄色网站",
            "AV资源",
            "自慰",
            "情色",
            // 违法犯罪
            "代开发票",
            "办证",
            "假证",
            "假身份证",
            "假学历",
            "枪支",
            "弹药",
            "炸药",
            "毒品",
            "冰毒",
            "大麻",
            "海洛因",
            "K粉",
            "摇头丸",
            "麻古",
            // 传销诈骗
            "传销",
            "庞氏骗局",
            "杀猪盘",
            "刷单返利",
            "网络诈骗",
            "电信诈骗",
            "资金盘",
            "拉人头",
            // 非法服务
            "代孕",
            "买卖器官",
            "代考",
            "替考",
            "论文代写",
            "洗钱",
            "跑分",
            "银行卡收购",
            // 网络违规
            "翻墙",
            "VPN",
            "SSR",
            "V2Ray",
            "Trojan",
            "外挂",
            "私服",
            "游戏破解",
            // 人身攻击
            "去死",
            "傻逼",
            "操你妈",
            "草泥马",
            "你妈死了",
            "废物",
            "贱人",
            "狗杂种");

    /** 正则敏感词（覆盖变体写法，如数字替代、符号分隔等） */
    private static final List<Pattern> REGEX_PATTERNS = List.of(
            // 赌博变体：赌*b、dubo、DB 等
            Pattern.compile("d[uúü]b[óo]", Pattern.CASE_INSENSITIVE),
            Pattern.compile("[赌賭][\\s\\W]*[博b]", Pattern.CASE_INSENSITIVE),
            // 色情变体
            Pattern.compile("[色s][èe\\s]*[情qíng]", Pattern.CASE_INSENSITIVE),
            Pattern.compile("约[\\s\\W]*炮", Pattern.CASE_INSENSITIVE),
            // 毒品变体
            Pattern.compile("[冰b][\\s\\W]*[毒d]", Pattern.CASE_INSENSITIVE),
            // 诈骗关键词组合
            Pattern.compile("日赚[\\d]+[元万千]", Pattern.CASE_INSENSITIVE),
            Pattern.compile("稳赚[不b]?赔", Pattern.CASE_INSENSITIVE),
            Pattern.compile("保证[百b]%?[分f]?[之z]?[百b]", Pattern.CASE_INSENSITIVE),
            // 联系方式引流（微信号/QQ号/手机号 + 营销话术）
            Pattern.compile("(加[微wWxX]|[微wWxX]信)[\\s:：]?[a-zA-Z0-9_]{5,}", Pattern.CASE_INSENSITIVE),
            Pattern.compile("[Qq]{2}[\\s:：]?\\d{5,}"),
            // 代办证件类
            Pattern.compile("(代[办开]|快速办理).{0,4}(证件|发票|学历|驾照|证书)", Pattern.CASE_INSENSITIVE),
            // 侮辱性正则
            Pattern.compile("nmsl|sb|煞笔|沙比|草拟吗", Pattern.CASE_INSENSITIVE));

    /**
     * 检查文本是否包含敏感词。
     *
     * @param text 待检查文本
     * @return true 如果包含敏感词
     */
    public boolean containsSensitiveWord(String text) {
        return findMatchedWord(text) != null;
    }

    /**
     * 查找文本中匹配到的敏感词。
     *
     * @param text 待检查文本
     * @return 匹配到的敏感词或匹配到的正则表达式描述，未匹配返回 null
     */
    public String findMatchedWord(String text) {
        if (text == null || text.isEmpty()) {
            return null;
        }

        // 关键词匹配
        for (String keyword : KEYWORDS) {
            if (text.contains(keyword)) {
                return keyword;
            }
        }

        // 正则匹配
        for (Pattern pattern : REGEX_PATTERNS) {
            Matcher matcher = pattern.matcher(text);
            if (matcher.find()) {
                return "regex:" + pattern.pattern();
            }
        }

        return null;
    }
}
