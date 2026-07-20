import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// HugeIcons 图标常量映射
/// 将所有用到的 Material Icons 统一映射为 HugeIcons，
/// 方便全局维护和风格统一。
class AppIcons {
  AppIcons._();

  // ── 导航 ──
  static const Widget home = HugeIcon(icon: HugeIcons.strokeRoundedHome01);
  static const Widget homeSelected = HugeIcon(
    icon: HugeIcons.strokeRoundedHome01,
  );
  static const Widget contents = HugeIcon(icon: HugeIcons.strokeRoundedBook01);
  static const Widget friends = HugeIcon(icon: HugeIcons.strokeRoundedLink01);
  static const Widget about = HugeIcon(icon: HugeIcons.strokeRoundedUserCircle);
  static const Widget profile = HugeIcon(icon: HugeIcons.strokeRoundedUser);
  static const Widget admin = HugeIcon(icon: HugeIcons.strokeRoundedSettings01);
  static const Widget login = HugeIcon(icon: HugeIcons.strokeRoundedLogin01);

  // ── 操作 ──
  static const Widget refresh = HugeIcon(icon: HugeIcons.strokeRoundedRefresh);
  static const Widget search = HugeIcon(icon: HugeIcons.strokeRoundedSearch01);
  static const Widget filter = HugeIcon(icon: HugeIcons.strokeRoundedFilter);
  static const Widget close = HugeIcon(icon: HugeIcons.strokeRoundedCancel01);
  static const Widget add = HugeIcon(icon: HugeIcons.strokeRoundedAdd01);
  static const Widget delete = HugeIcon(icon: HugeIcons.strokeRoundedDelete01);
  static const Widget edit = HugeIcon(icon: HugeIcons.strokeRoundedEdit01);
  static const Widget send = HugeIcon(icon: HugeIcons.strokeRoundedSent);
  static const Widget check = HugeIcon(icon: HugeIcons.strokeRoundedTick01);

  // ── 社交 ──
  static const Widget heart = HugeIcon(icon: HugeIcons.strokeRoundedFavourite);
  static const Widget heartFilled = HugeIcon(
    icon: HugeIcons.strokeRoundedFavourite,
  );
  static const Widget comment = HugeIcon(
    icon: HugeIcons.strokeRoundedMessage01,
  );
  static const Widget visibility = HugeIcon(icon: HugeIcons.strokeRoundedView);
  static const Widget share = HugeIcon(icon: HugeIcons.strokeRoundedShare01);

  // ── 媒体 ──
  static const Widget image = HugeIcon(icon: HugeIcons.strokeRoundedImage01);
  static const Widget video = HugeIcon(icon: HugeIcons.strokeRoundedVideo01);
  static const Widget upload = HugeIcon(icon: HugeIcons.strokeRoundedUpload01);
  static const Widget file = HugeIcon(icon: HugeIcons.strokeRoundedFile01);
  static const Widget play = HugeIcon(icon: HugeIcons.strokeRoundedPlay);
  static const Widget brokenImage = HugeIcon(
    icon: HugeIcons.strokeRoundedImageNotFound01,
  );

  // ── 状态/信息 ──
  static const Widget error = HugeIcon(icon: HugeIcons.strokeRoundedAlert01);
  static const Widget info = HugeIcon(
    icon: HugeIcons.strokeRoundedInformationCircle,
  );
  static const Widget cloud = HugeIcon(icon: HugeIcons.strokeRoundedCloud);
  static const Widget clock = HugeIcon(icon: HugeIcons.strokeRoundedClock01);
  static const Widget calendar = HugeIcon(
    icon: HugeIcons.strokeRoundedCalendar01,
  );
  static const Widget lightbulb = HugeIcon(icon: HugeIcons.strokeRoundedIdea01);

  // ── 用户/认证 ──
  static const Widget person = HugeIcon(icon: HugeIcons.strokeRoundedUser);
  static const Widget mail = HugeIcon(icon: HugeIcons.strokeRoundedMail01);
  static const Widget lock = HugeIcon(icon: HugeIcons.strokeRoundedLock);
  static const Widget key = HugeIcon(icon: HugeIcons.strokeRoundedKey01);
  static const Widget logout = HugeIcon(icon: HugeIcons.strokeRoundedLogout01);

  // ── 内容/编辑 ──
  static const Widget book = HugeIcon(icon: HugeIcons.strokeRoundedBook01);
  static const Widget tag = HugeIcon(icon: HugeIcons.strokeRoundedTag01);
  static const Widget link = HugeIcon(icon: HugeIcons.strokeRoundedLink01);
  static const Widget code = HugeIcon(icon: HugeIcons.strokeRoundedCode);
  static const Widget bold = HugeIcon(icon: HugeIcons.strokeRoundedTextBold);
  static const Widget italic = HugeIcon(
    icon: HugeIcons.strokeRoundedTextItalic,
  );
  static const Widget list = HugeIcon(
    icon: HugeIcons.strokeRoundedLeftToRightListBullet,
  );
  static const Widget quote = HugeIcon(
    icon: HugeIcons.strokeRoundedLeftToRightBlockQuote,
  );
  static const Widget settings = HugeIcon(
    icon: HugeIcons.strokeRoundedSettings01,
  );
  static const Widget archive = HugeIcon(icon: HugeIcons.strokeRoundedArchive);
  static const Widget pin = HugeIcon(icon: HugeIcons.strokeRoundedPin);
  static const Widget schedule = HugeIcon(icon: HugeIcons.strokeRoundedClock01);

  // ── AI 头像 ──
  static Widget robot({double radius = 20, Color? backgroundColor}) {
    return CircleAvatar(
      radius: radius,
      backgroundImage: const AssetImage('assets/images/lacia.png'),
      backgroundColor: backgroundColor,
    );
  }
}
