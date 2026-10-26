/// User-facing strings (Vietnamese).
abstract class AppText {
  static const String appName = 'Giải phẫu 3D';
  static const String appDescription = 'Ứng dụng học giải phẫu người với mô hình 3D tương tác.';
  static const String appTagline = 'Khám phá cơ thể người';

  // Common
  static const String loadingModel = 'Đang tải mô hình…';
  static const String loading = 'Đang tải…';
  static const String close = 'Đóng';
  static const String back = 'Back';
  static const String pronounce = 'Phát âm tiếng Anh';
  static const String englishTag = 'EN';
  static const String parts = 'bộ phận';
  static String partCount(int count) => '$count $parts';
  static String loadError(Object error) => 'Lỗi tải dữ liệu: $error';
  static String systemLoadError(String system, Object error) => 'Không tải được $system: $error';

  // Splash
  static const String loadFailed = 'Không mở được ứng dụng';

  // Home
  static const String search = 'Tìm kiếm';
  static const String quiz = 'Đố vui vị trí';
  static const String quizShort = 'Đố vui';
  static const String assembly = 'Ghép cơ thể 3D';
  static const String info = 'Thông tin';
  static const String live3d = '3D';
  static const String bodySystems = 'Hệ cơ quan';
  static const String resetCamera = 'Về góc nhìn ban đầu';
  static const String zoomInTooltip = 'Phóng to';
  static const String zoomOutTooltip = 'Thu nhỏ';
  static const String rotateModeTooltip = 'Kéo để xoay';
  static const String panModeTooltip = 'Kéo để di chuyển';
  static const String showAll = 'Hiện tất cả';
  static const String viewerHint = 'Chạm để chọn · chạm đúp để phóng to';
  static const String zoomIn = 'Phóng to';
  static const String hide = 'Ẩn';
  static const String ghost = 'Làm mờ';
  static const String unghost = 'Bỏ mờ';
  static const String isolate = 'Tách riêng';

  // Search
  static const String searchTitle = 'Tìm bộ phận';
  static const String searchSubtitle = 'Gõ tên tiếng Việt hoặc tiếng Anh';
  static const String searchHint = 'Tên bộ phận (có dấu hoặc không)';
  static const String searchExample = 'Ví dụ: xuong dui, tim, cơ nhị đầu, femur';
  static const String searchEmpty = 'Không tìm thấy';
  static String searchResults(int count) => '$count kết quả';

  // Quiz
  static const String pickQuizSystem = 'Chọn hệ để đố';
  static String quizTitle(String system) => 'Đố vui · $system';
  static String quizProgress(int index, int total) => 'Câu $index/$total';
  static String quizScore(int score) => 'Điểm: $score';
  static const String quizTapOn = 'CHẠM VÀO';
  static const String quizAttemptsHint = 'Trái/phải theo cơ thể mô hình';
  static const String quizCorrect = 'Chính xác!';
  static String quizWrong(String? name) => 'Sai – đó là ${name ?? 'bộ phận khác'}';
  static const String quizNameHint = 'Nghe tên tiếng Anh: bấm loa';
  static const String quizRevealed = 'Đáp án được tô xanh';
  static const String quizSkip = 'Bỏ qua';
  static const String quizResult = 'Kết quả';
  static String quizResultBody(int score, int total) => 'Bạn trả lời đúng ngay lần đầu $score/$total câu.';
  static String quizBest(int best) => 'Kỷ lục: $best';
  static String quizBestOf(int best, int total) => 'Kỷ lục $best/$total';
  static const String quizNewBest = 'Kỷ lục mới!';
  static const String quizExit = 'Thoát';
  static const String quizAgain = 'Chơi lại';

  // About
  static const String aboutApp = 'Về ứng dụng';
  static const String dataSources = 'Nguồn dữ liệu';
  static const String modelCredit =
      'Mô hình 3D: BodyParts3D, (c) The Database Center for Life Science '
      'licensed under CC Attribution-Share Alike 2.1 Japan.\n'
      'https://dbarchive.biosciencedbc.jp/en/bodyparts3d/';
  static const String modelModified =
      'Các mô hình đã được giản lược lưới và nén để chạy trên điện thoại. '
      'Bản mô hình đã chỉnh sửa được phân phối theo cùng giấy phép CC BY-SA 2.1 JP.';
  static const String zAnatomyCredit = 'Z-Anatomy – The open source atlas of anatomy – CC BY-SA 4.0';
  static const String rendererCredit = 'Hiển thị 3D: three.js (MIT License).';
  static const String openSourceLicenses = 'Giấy phép phần mềm mã nguồn mở';

  // Assembly game
  static const String assemblyLevelsTitle = 'Ghép cơ thể 3D';
  static const String assemblyLevelsSubtitle = 'Ghép các mảnh về đúng vị trí';
  static const String assemblyPickLevel = 'Chọn màn chơi';
  static const String assemblyNotPlayed = 'Chưa chơi';
  static String assemblyPieces(int count) => '$count mảnh';
  static String assemblyPiecesRange(int min, int max) => min == max ? '$min mảnh' : '$min–$max mảnh';
  static String assemblyDetailCount(int count) => '$count mức';
  static const String assemblyPickDetail = 'Chọn độ chi tiết';
  static const String assemblyPickDetailHint = 'Cùng một vùng, chia thành mảnh to hay nhỏ tùy bạn';
  static const String assemblyRecommended = 'Đề xuất';
  static String assemblyStarTotal(int stars, int max) => '$stars/$max';
  static const String assemblyDragHint = 'Kéo từng mảnh vào đúng bóng mờ của nó';
  static const String assemblyHint = 'Gợi ý';
  static String assemblyHintCount(int used) => used == 0 ? assemblyHint : '$assemblyHint ($used)';
  static const String assemblyRestart = 'Xếp lại';
  static const String assemblyComplete = 'Hoàn thành!';
  static const String assemblyNewRecord = 'Kỷ lục mới!';
  static const String assemblyTime = 'Thời gian';
  static const String assemblyMistakes = 'Đặt sai';
  static const String assemblyHints = 'Gợi ý';
  static const String assemblyNext = 'Màn tiếp';
  static const String assemblyReplay = 'Chơi lại';
  static const String assemblyToList = 'Về danh sách';
  static const String assemblyScore = 'Điểm';
  static const String assemblyBestScore = 'Điểm cao';
  static const String assemblyNewBestScore = 'Điểm cao mới!';
  static String assemblyCombo(int count) => 'Combo x$count!';
  static String assemblyComboBonus(int bonus) => '+$bonus';
  static const String assemblyMaxCombo = 'Combo';
  static const String assemblyTimeBonus = 'Thưởng thời gian';
  static const String assemblyHelp = 'Hướng dẫn';
  static String assemblyChapterStars(int stars, int max) => '$stars/$max';
  static const String assemblyIntroTapHint = 'Chạm để bắt đầu';
  static const String assemblyIntroBest = 'Kỷ lục';
  static const String assemblyIntroNoRecord = 'Chưa có kỷ lục';
  static String assemblyIntroRecord(int stars, String time, int? score) =>
      score == null ? '$stars★ · $time' : '$stars★ · $time · $score điểm';

  // Assembly tutorial
  static const String tutorialTitle = 'Cách chơi';
  static const String tutorialStep1 = 'Kéo mảnh vào bóng mờ của nó';
  static const String tutorialStep2 = 'Kéo chỗ trống để xoay, 2 ngón để phóng to';
  static const String tutorialStep3 = 'Bí thì bấm Gợi ý';
  static const String tutorialStart = 'Bắt đầu';

  // Settings
  static const String settings = 'Cài đặt';
  static const String settingsSound = 'Âm thanh';
  static const String settingsOn = 'Bật';
  static const String settingsOff = 'Tắt';
  static const String settingsQuality = 'Chất lượng đồ họa';
  static const String settingsQualityHint = 'Chọn Thấp nếu máy bị nóng hoặc giật';
  static const String settingsTutorial = 'Xem lại hướng dẫn';
  static const String qualityHigh = 'Cao';
  static const String qualityLow = 'Thấp';

  // Exam (setup, exam screen, result)
  static const String examSetupTitle = 'Thi thử giải phẫu';
  static const String examSetupSubtitle = 'Ôn thi theo đề hỗn hợp 3D & thuật ngữ';
  static const String examScope = 'Phạm vi';
  static const String examWholeBody = 'Toàn thân';
  static const String examLength = 'Số câu';
  static const String examMode = 'Chế độ';
  static const String examModePractice = 'Luyện tập';
  static const String examModePracticeHint = 'Không tính giờ · có giải thích';
  static const String examModeTest = 'Thi thử';
  static String examModeTestHint(int seconds) => '$seconds giây/câu · thưởng điểm nhanh';
  static String examQuestions(int count) => '$count câu';
  static String examBest(int best) => 'Kỷ lục $best';
  static const String examNoBest = 'Chưa thi';
  static const String examStart = 'Bắt đầu thi';
  static String examTitle(String scope) => 'Thi · $scope';
  static const String examTagTapPart = 'CHẠM VÀO';
  static const String examTagNamePart = 'BỘ PHẬN ĐANG SÁNG';
  static const String examTagEnToVi = 'ANH → VIỆT';
  static const String examTagViToEn = 'VIỆT → ANH';
  static const String examNamePartPrompt = 'Đây là bộ phận nào?';
  static const String examCorrect = 'Chính xác!';
  static String examPoints(int points) => '+$points';
  static const String examWrong = 'Chưa đúng';
  static const String examTimeout = 'Hết giờ!';
  static const String examSkipped = 'Đã bỏ qua';
  static const String examSkip = 'Bỏ qua';
  static const String examNext = 'Tiếp tục';
  static const String examFinish = 'Xem kết quả';
  static String examSystem(String system) => 'Hệ $system';
  static const String examEmpty = 'Không đủ dữ liệu để tạo đề cho phạm vi này.';
  static const String examResult = 'Kết quả';
  static String examScore(int score) => '$score điểm';
  static String examCorrectCount(int correct, int total) => 'Đúng $correct/$total câu';
  static const String examAccuracy = 'Chính xác';
  static const String examTime = 'Thời gian';
  static const String examXp = 'Kinh nghiệm';
  static String examXpValue(int xp) => '+$xp XP';
  static const String examNewBest = 'Kỷ lục mới!';
  static String examBestScore(int best) => 'Kỷ lục: $best điểm';
  static const String examLevelUp = 'Lên cấp!';
  static String examMissedTitle(int count) => 'Cần ôn lại ($count)';
  static const String examAllCorrect = 'Không sai câu nào. Tuyệt vời!';
  static const String examAgain = 'Làm lại';
  static const String examBack = 'Quay lại';

  // Daily challenge
  static const String examDailyTitle = 'Thử thách hôm nay';
  static const String examDailySubtitle = 'Cùng một đề cho mọi người';
  static String examDailyDate(String date) => 'Ngày $date';
  static String examDailyInfo(int count, int seconds) => '$count câu hỗn hợp · Toàn thân · $seconds giây/câu';
  static String examDailyReward(int bonus) => 'Hoàn thành lần đầu trong ngày: +$bonus XP thưởng';
  static const String examDailyClaimed = 'Đã nhận thưởng hôm nay';
  static String examDailyBonus(int bonus) => 'Thưởng ngày +$bonus XP';
  static String examDailyToday(int score) => 'Điểm hôm nay: $score';
  static const String examDailyStart = 'Bắt đầu';
  static const String examDailyReplay = 'Chơi lại';
  static const String examStreak = 'Chuỗi ngày';
  static String examStreakDays(int days) => '$days ngày liên tiếp';

  // Mistake book
  static const String examMistakesTitle = 'Sổ lỗi sai';
  static String examMistakesSubtitle(int count) => '$count bộ phận cần ôn';
  static const String examMistakesEmpty = 'Chưa có lỗi sai nào';
  static const String examMistakesEmptyBody =
      'Bộ phận nào bạn trả lời sai khi thi hoặc đố vui sẽ được lưu ở đây để ôn lại. Cứ tự tin làm bài nhé!';
  static const String examMistakesReview = 'Ôn lại';
  static const String examMistakesReviewTitle = 'Ôn lỗi sai';
  static const String examMistakesHint = 'Chạm vào một bộ phận để xem mô hình 3D';
  static String examMissCount(int count) => 'Sai $count lần';

  // Learn hub
  static const String learnHubTitle = 'Học & Thi';
  static const String learnHubSubtitle = 'Học theo vùng, thử thách và ôn thi';
  static String learnLevel(int level) => 'Cấp $level';
  static String learnXp(int xp) => '$xp XP';
  static String learnXpToNext(int xp) => 'Còn $xp XP để lên cấp';
  static String learnStreakDays(int days) => '$days ngày';
  static String learnBestStreak(int days) => 'Kỷ lục $days';
  static const String learnStreak = 'Chuỗi ngày';
  static const String learnMistakes = 'Lỗi sai';
  static const String learnModes = 'Chế độ học';
  static const String learnDaily = 'Thử thách hôm nay';
  static const String learnDailyTodo = 'Chưa làm · có XP thưởng';
  static const String learnDailyNew = 'Mới';
  static const String learnShort = 'Học & Thi';
  static String learnDailyDone(int score) => 'Đã xong · $score điểm';
  static const String learnByRegion = 'Học theo vùng';
  static String learnByRegionHint(int done, int total) => 'Đã học $done/$total bài';
  static const String learnExam = 'Ôn thi';
  static const String learnExamHint = 'Làm đề theo hệ cơ quan';
  static const String learnMistakeBook = 'Sổ lỗi sai';
  static String learnMistakeHint(int count) => count == 0 ? 'Chưa có lỗi sai' : '$count bộ phận cần ôn';

  // Lessons
  static const String lessonsTitle = 'Học theo vùng';
  static const String lessonsSubtitle = 'Thuật ngữ giải phẫu tiếng Việt';
  static String lessonParts(int count) => '$count cấu trúc';
  static const String lessonNotStudied = 'Chưa học';
  static String lessonStars(int stars, int max) => '$stars/$max';
  static const String lessonStudy = 'HỌC';
  static const String lessonCheck = 'KIỂM TRA';
  static String lessonStep(int index, int total) => '$index/$total';
  static String lessonCheckStep(int index, int total) => 'Kiểm tra · câu $index/$total';
  static const String lessonPrev = 'Trước';
  static const String lessonNext = 'Tiếp';
  static const String lessonStartCheck = 'Kiểm tra';
  static const String lessonCheckHint = 'Chỉ các cấu trúc của bài mới chạm được';
  static const String lessonResult = 'Hoàn thành bài học';
  static String lessonResultBody(int score, int total) => 'Đúng ngay lần đầu $score/$total câu.';
  static String lessonXpGain(int xp) => '+$xp XP';
  static String lessonLevelUp(int level) => 'Lên cấp $level!';
  static const String lessonNewBest = 'Kỷ lục sao mới!';
  static const String lessonRestudy = 'Học lại';
  static const String lessonToList = 'Về danh sách';
}
