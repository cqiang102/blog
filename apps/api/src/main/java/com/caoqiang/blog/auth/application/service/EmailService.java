package com.caoqiang.blog.auth.application.service;

import jakarta.mail.internet.InternetAddress;
import jakarta.mail.internet.MimeMessage;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

/**
 * 邮件发送服务
 * 处理系统邮件的异步发送，包括验证码邮件、通知邮件等。
 * 位于博客系统的认证模块，是邮件发送的核心组件。
 *
 * <p>关键特性：</p>
 * <ul>
 *   <li>异步发送 - 使用 @Async 注解实现邮件异步发送，不阻塞主线程</li>
 *   <li>HTML 邮件 - 支持发送 HTML 格式的邮件内容</li>
 *   <li>错误处理 - 记录发送失败日志，不影响主业务流程</li>
 *   <li>模板化 - 使用模板构建邮件内容，便于维护和修改</li>
 * </ul>
 *
 * @author blog-mimo
 */
@Service
public class EmailService {

    private static final Logger log = LoggerFactory.getLogger(EmailService.class);

    /** Spring 邮件发送器 */
    private final JavaMailSender mailSender;

    /** SMTP 登录账号，同时作为发件邮箱地址 */
    private final String mailUsername;

    /**
     * 构造函数，注入邮件发送器
     *
     * @param mailSender   邮件发送器实例
     * @param mailUsername SMTP 登录账号
     */
    public EmailService(JavaMailSender mailSender, @Value("${spring.mail.username}") String mailUsername) {
        this.mailSender = mailSender;
        this.mailUsername = mailUsername;
    }

    /**
     * 异步发送验证码邮件
     * 构建 HTML 格式的验证码邮件并发送到指定邮箱。
     * 如果邮件发送失败（例如未配置邮箱服务），则在控制台打印验证码。
     *
     * @param to   收件人邮箱地址
     * @param code 验证码
     */
    @Async
    public void sendVerificationCode(String to, String code) {
        try {
            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");
            helper.setTo(to);
            helper.setFrom(new InternetAddress(mailUsername, "沐凉·日记", "UTF-8"));
            helper.setSubject("【博客系统】邮箱验证码");
            helper.setText(buildEmailContent(code), true);
            mailSender.send(message);
            log.info("验证码邮件发送成功");
        } catch (Exception e) {
            log.warn("验证码邮件发送失败");
            log.debug("邮件发送异常详情: {}", e.getMessage(), e);
        }
    }

    /**
     * 构建验证码邮件的 HTML 内容
     *
     * @param code 验证码
     * @return HTML 格式的邮件内容
     */
    private String buildEmailContent(String code) {
        return """
                <div style="font-family: 'Microsoft YaHei', Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 24px; background: #f9f9f9; border-radius: 8px;">
                    <h2 style="color: #333; text-align: center;">邮箱验证码</h2>
                    <p style="color: #555; font-size: 14px;">您好，您正在注册博客系统账号，验证码如下：</p>
                    <div style="text-align: center; padding: 16px; background: #fff; border-radius: 6px; margin: 16px 0;">
                        <span style="font-size: 28px; font-weight: bold; color: #1976d2; letter-spacing: 6px;">%s</span>
                    </div>
                    <p style="color: #999; font-size: 12px;">验证码 5 分钟内有效，请勿泄露给他人。</p>
                </div>
                """.formatted(code);
    }
}
