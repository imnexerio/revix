/// Utility class for common grid layout calculations
class GridLayoutUtils {
  /// Calculates the number of columns based on screen width
  static int calculateColumns(double width) {
    if (width < 500) return 1;         // Mobile
    else if (width < 900) return 2;    // Tablet
    else if (width < 1200) return 3;   // Small desktop
    else if (width < 1500) return 4;   // Medium desktop
    else return 5;                     // Large desktop
  }
}
