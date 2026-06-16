class AppConstants {
  // App Info
  static const String appName = 'ScanFlow';

  // Route Paths
  static const String routeHome = '/';
  static const String routeScanner = '/scanner';
  static const String routeEditor = '/editor';
  static const String routePdfPreview = '/pdf-preview';
  static const String routeShare = '/share';
  static const String routePdfViewer = '/pdf-viewer';

  // Padding & Spacing
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 12.0;
  static const double spacingL = 16.0;
  static const double spacingXL = 24.0;
  static const double spacingXXL = 32.0;

  // Border Radius
  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 24.0;

  // Filter Names
  static const String filterOriginal = 'Original';
  static const String filterColorDocument = 'Color Document';
  static const String filterEnhancedColor = 'Enhanced Color';
  static const String filterGrayscale = 'Grayscale';
  static const String filterHighContrast = 'High Contrast';
  static const String filterBlackAndWhite = 'Black & White';

  static const List<String> availableFilters = [
    filterOriginal,
    filterColorDocument,
    filterEnhancedColor,
    filterGrayscale,
    filterHighContrast,
    filterBlackAndWhite,
  ];
}
