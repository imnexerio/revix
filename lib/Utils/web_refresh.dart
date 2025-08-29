// Web-specific implementation for page refresh functionality
import 'dart:js_interop';

/// Refresh the web page - WEB ONLY implementation
void refreshWebPage() {
  // Use js_interop for WASM compatibility
  _reloadPage();
}

@JS('location.reload')
external void _reloadPage();
