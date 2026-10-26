/// User-facing strings (Vietnamese).
abstract class AppText {
  static const String appName = 'Giải phẫu 3D';
  static const String appDescription = 'Ứng dụng học giải phẫu người với mô hình 3D tương tác.';

  // Common
  static const String loadingModel = 'Đang tải mô hình…';
  static const String loading = 'Đang tải…';
  static const String close = 'Đóng';
  static const String pronounce = 'Phát âm';
  static const String parts = 'bộ phận';
  static String loadError(Object error) => 'Lỗi tải dữ liệu: $error';
  static String systemLoadError(String system, Object error) => 'Không tải được $system: $error';

  // Home
  static const String search = 'Tìm kiếm';
  static const String quiz = 'Đố vui vị trí';
  static const String info = 'Thông tin';
  static const String bodySystems = 'Hệ cơ quan';
  static const String resetCamera = 'Về góc nhìn ban đầu';
  static const String showAll = 'Hiện tất cả';
  static const String viewerHint = 'Chạm để chọn · chạm đúp để phóng to';
  static const String zoomIn = 'Phóng to';
  static const String hide = 'Ẩn';
  static const String ghost = 'Làm mờ';
  static const String unghost = 'Bỏ mờ';
  static const String isolate = 'Tách riêng';

  // Search
  static const String searchHint = 'Tên bộ phận (tiếng Anh)';
  static const String searchExample = 'Ví dụ: femur, heart, biceps, skull';
  static const String searchEmpty = 'Không tìm thấy';

  // Quiz
  static const String pickQuizSystem = 'Chọn hệ để đố';
  static String quizTitle(String system) => 'Đố vui · $system';
  static String quizProgress(int index, int total) => 'Câu $index/$total';
  static String quizScore(int score) => 'Điểm: $score';
  static const String quizTapOn = 'Chạm vào:';
  static String quizAttemptsLeft(int left) => 'Còn $left lượt · trái/phải theo cơ thể mô hình';
  static const String quizCorrect = 'Chính xác!';
  static String quizWrong(String? name) => 'Sai – đó là ${name ?? 'bộ phận khác'}';
  static const String quizRevealed = 'Đáp án được tô xanh';
  static const String quizSkip = 'Bỏ qua';
  static const String quizResult = 'Kết quả';
  static String quizResultBody(int score, int total) =>
      'Bạn trả lời đúng ngay lần đầu $score/$total câu.';
  static String quizBest(int best) => 'Kỷ lục: $best';
  static const String quizNewBest = 'Kỷ lục mới!';
  static const String quizExit = 'Thoát';
  static const String quizAgain = 'Chơi lại';

  // About
  static const String dataSources = 'Nguồn dữ liệu';
  static const String modelCredit =
      'Mô hình 3D: BodyParts3D, (c) The Database Center for Life Science '
      'licensed under CC Attribution-Share Alike 2.1 Japan.\n'
      'https://dbarchive.biosciencedbc.jp/en/bodyparts3d/';
  static const String modelModified =
      'Các mô hình đã được giản lược lưới và nén để chạy trên điện thoại. '
      'Bản mô hình đã chỉnh sửa được phân phối theo cùng giấy phép CC BY-SA 2.1 JP.';
  static const String rendererCredit = 'Hiển thị 3D: three.js (MIT License).';
  static const String openSourceLicenses = 'Giấy phép phần mềm mã nguồn mở';
}
