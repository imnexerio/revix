// Web-specific implementation for page refresh functionality
import 'dart:html' as html;

/// Refresh the web page - WEB ONLY implementation
void refreshWebPage() {
  html.window.location.reload();
}
