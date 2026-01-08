import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'DisplayName.dart';
import 'DecodeProfilePic.dart';

class ProfileProvider with ChangeNotifier {
  Uint8List? _profileImageBytes;  // Cache bytes instead of Image widget
  Image? _profileImage;
  String? _displayName;
  bool _isLoadingImage = false;
  bool _isLoadingName = false;

  Image? get profileImage {
    // Create Image widget from cached bytes on demand
    if (_profileImage == null && _profileImageBytes != null) {
      _profileImage = Image.memory(_profileImageBytes!);
    }
    return _profileImage;
  }
  String? get displayName => _displayName;
  bool get isLoadingImage => _isLoadingImage;
  bool get isLoadingName => _isLoadingName;

  // Load locally stored profile image first, then check for updates
  Future<void> loadProfileImage(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? imageData = prefs.getString('profile_image');

    if (imageData != null && _profileImageBytes == null) {
      // Load cached image immediately only if not already loaded
      _profileImageBytes = base64Decode(imageData);
      _profileImage = Image.memory(_profileImageBytes!);
      notifyListeners();
    }

    // Check for updates in background
    fetchAndUpdateProfileImage(context, forceUpdate: false);
  }

  // Load locally stored display name first, then check for updates
  Future<void> loadDisplayName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? nameData = prefs.getString('display_name');

    if (nameData != null && _displayName == null) {
      // Load cached name immediately only if not already loaded
      _displayName = nameData;
      notifyListeners();
    }

    // Check for updates in background
    fetchAndUpdateDisplayName(forceUpdate: false);
  }

  // Fetch the latest profile image and update if needed
  Future<void> fetchAndUpdateProfileImage(BuildContext context, {bool forceUpdate = true}) async {
    if (_isLoadingImage) return; // Prevent multiple simultaneous updates

    final wasLoading = _isLoadingImage;
    _isLoadingImage = true;
    if (forceUpdate && !wasLoading) notifyListeners();

    try {
      final newImage = await decodeProfileImage(context);

      // Check if image has changed before updating
      if (newImage != null && (forceUpdate || await _hasImageChanged(newImage))) {
        _profileImage = newImage;
        await _saveProfileImageLocally(newImage);
        notifyListeners();
      }
    } catch (e) {
      print('Error fetching profile image: $e');
    } finally {
      final wasLoadingBefore = _isLoadingImage;
      _isLoadingImage = false;
      // Only notify if loading state actually changed and we haven't notified already
      if (wasLoadingBefore && forceUpdate) {
        // Already notified above when data changed, no need to notify again
      }
    }
  }

  // Fetch the latest display name and update if needed
  Future<void> fetchAndUpdateDisplayName({bool forceUpdate = true}) async {
    if (_isLoadingName) return; // Prevent multiple simultaneous updates

    final wasLoading = _isLoadingName;
    _isLoadingName = true;
    if (forceUpdate && !wasLoading) notifyListeners();

    try {
      final newName = await getDisplayName();

      // Only update if name has changed
      if (newName != _displayName) {
        _displayName = newName;
        await _saveDisplayNameLocally(newName);
        notifyListeners();
      }
    } catch (e) {
      print('Error fetching display name: $e');
    } finally {
      final wasLoadingBefore = _isLoadingName;
      _isLoadingName = false;
      // Only notify if loading state actually changed and we haven't notified already
      if (wasLoadingBefore && forceUpdate) {
        // Already notified above when data changed, no need to notify again
      }
    }
  }

  // Save profile image with timestamp
  Future<void> _saveProfileImageLocally(Image image) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final byteData = await _getImageByteData(image);
    final bytes = byteData.buffer.asUint8List();
    final base64Image = base64Encode(bytes);

    await prefs.setString('profile_image', base64Image);
    await prefs.setString('profile_image_updated_at', DateTime.now().toIso8601String());
  }

  // Save display name with timestamp
  Future<void> _saveDisplayNameLocally(String displayName) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('display_name', displayName);
    await prefs.setString('display_name_updated_at', DateTime.now().toIso8601String());
  }

  // Check if the new image is different from the stored one
  Future<bool> _hasImageChanged(Image newImage) async {
    if (_profileImage == null) return true;

    try {
      final oldBytes = await _getImageBytes(_profileImage!);
      final newBytes = await _getImageBytes(newImage);

      // Simple byte comparison
      if (oldBytes.length != newBytes.length) return true;

      // For more detailed comparison, you could compare byte by byte
      // or implement a hash-based solution for better performance
      for (var i = 0; i < oldBytes.length; i++) {
        if (oldBytes[i] != newBytes[i]) return true;
      }

      return false;
    } catch (e) {
      print('Error comparing images: $e');
      return true; // If comparison fails, assume it changed
    }
  }

  // Get image as bytes for comparison
  Future<Uint8List> _getImageBytes(Image image) async {
    final byteData = await _getImageByteData(image);
    return byteData.buffer.asUint8List();
  }

  Future<ByteData> _getImageByteData(Image image) async {
    final completer = Completer<ByteData>();
    image.image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) async {
        final byteData = await info.image.toByteData(format: ImageByteFormat.png);
        completer.complete(byteData!);
      }),
    );
    return completer.future;
  }
}