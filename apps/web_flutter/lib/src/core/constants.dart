// 应用全局常量
// 提取魔法值为命名常量，便于维护和一致性

/// 响应式布局断点
const double kWideBreakpoint = 900;
const double kDesktopBreakpoint = 1100;
const double kTabletBreakpoint = 720;
const double kSmallTabletBreakpoint = 560;
const double kCompactBreakpoint = 680;

/// AI 聊天限制
const int kMaxSessionMessages = 40;

/// 分页默认值
const int kDefaultPageSize = 20;
const int kAdminPageSize = 50;

/// 滚动预加载距离（像素）
const double kScrollThreshold = 200;

/// 自动保存间隔
const Duration kAutoSaveInterval = Duration(seconds: 30);

/// UI 尺寸
const double kCarouselHeight = 300;
const double kContentCardAspectRatioWide = 1.35;
const double kContentCardAspectRatioNarrow = 2.4;
const double kAdminNumberFieldWidth = 148;
const double kEditorDialogMaxWidth = 800;
const double kEditorDialogSplitMaxWidth = 1200;
const double kEditorDialogMaxHeightRatio = 0.85;
const double kFriendCardMaxWidth = 360;
const double kFriendCardHeight = 172;
const double kThumbWidth = 132;
const double kThumbHeight = 92;
const double kAdminThumbWidth = 96;
const double kAdminThumbHeight = 64;

/// 密码最小长度
const int kMinPasswordLength = 6;

/// 日期范围起始年
const int kDateRangeStartYear = 2020;
