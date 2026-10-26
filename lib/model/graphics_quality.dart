import '../resource/app_text.dart';

/// Rendering quality of the 3D viewer; sent to the page as [name].
enum GraphicsQuality {
  high(AppText.qualityHigh),
  low(AppText.qualityLow);

  const GraphicsQuality(this.label);

  final String label;

  static GraphicsQuality fromName(String? name) =>
      GraphicsQuality.values.firstWhere((q) => q.name == name, orElse: () => GraphicsQuality.high);
}
