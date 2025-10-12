import 'dart:io' show Platform;
import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart' as pkgffi;
import 'package:win32/win32.dart' as win32;

class WindowsStartup {
  static const _runKeyPath = r'Software\Microsoft\Windows\CurrentVersion\Run';
  static const _valueName = 'log_work';

  static Future<bool> isEnabled() async {
    if (!Platform.isWindows) return false;
    final hKeyPtr = pkgffi.calloc<ffi.IntPtr>();
    final subKey = _runKeyPath.toNativeUtf16();
    try {
      final open = win32.RegOpenKeyEx(
          win32.HKEY_CURRENT_USER, subKey, 0, win32.KEY_READ, hKeyPtr);
      if (open != win32.ERROR_SUCCESS) return false;
      final hKey = hKeyPtr.value;
      final namePtr = _valueName.toNativeUtf16();
      final typePtr = pkgffi.calloc<ffi.Uint32>();
      final dataLenPtr = pkgffi.calloc<ffi.Uint32>();
      final q = win32.RegQueryValueEx(hKey, namePtr, ffi.nullptr, typePtr,
          ffi.nullptr, dataLenPtr);
      pkgffi.malloc.free(namePtr);
      pkgffi.calloc.free(typePtr);
      pkgffi.calloc.free(dataLenPtr);
      win32.RegCloseKey(hKey);
      return q == win32.ERROR_SUCCESS;
    } finally {
      pkgffi.calloc.free(hKeyPtr);
      pkgffi.malloc.free(subKey);
    }
  }

  static Future<bool> enable() async {
    if (!Platform.isWindows) return false;
    final exe = _currentExePath();
    if (exe == null) return false;
    final quoted = '"$exe"';
    final hKeyPtr = pkgffi.calloc<ffi.IntPtr>();
    final subKey = _runKeyPath.toNativeUtf16();
    try {
      final open = win32.RegOpenKeyEx(
          win32.HKEY_CURRENT_USER, subKey, 0, win32.KEY_SET_VALUE, hKeyPtr);
      if (open != win32.ERROR_SUCCESS) return false;
      final hKey = hKeyPtr.value;
      final namePtr = _valueName.toNativeUtf16();
      final dataPtr = quoted.toNativeUtf16();
      final dataSize = (quoted.length + 1) * 2; // bytes for UTF-16 with NUL
      final res = win32.RegSetValueEx(
          hKey, namePtr, 0, win32.REG_SZ, dataPtr.cast(), dataSize);
      win32.RegCloseKey(hKey);
      pkgffi.malloc.free(namePtr);
      pkgffi.malloc.free(dataPtr);
      return res == win32.ERROR_SUCCESS;
    } finally {
      pkgffi.calloc.free(hKeyPtr);
      pkgffi.malloc.free(subKey);
    }
  }

  static Future<bool> disable() async {
    if (!Platform.isWindows) return false;
    final hKeyPtr = pkgffi.calloc<ffi.IntPtr>();
    final subKey = _runKeyPath.toNativeUtf16();
    try {
      final open = win32.RegOpenKeyEx(
          win32.HKEY_CURRENT_USER, subKey, 0, win32.KEY_SET_VALUE, hKeyPtr);
      if (open != win32.ERROR_SUCCESS) return false;
      final hKey = hKeyPtr.value;
      final namePtr = _valueName.toNativeUtf16();
  final res = win32.RegDeleteValue(hKey, namePtr);
      win32.RegCloseKey(hKey);
      pkgffi.malloc.free(namePtr);
  return res == win32.ERROR_FILE_NOT_FOUND || res == win32.ERROR_SUCCESS;
    } finally {
      pkgffi.calloc.free(hKeyPtr);
      pkgffi.malloc.free(subKey);
    }
  }

  static String? _currentExePath() {
    final bufLen = win32.MAX_PATH;
    final buffer = pkgffi.calloc<ffi.Uint16>(bufLen);
    try {
  final len = win32.GetModuleFileName(0, buffer.cast<pkgffi.Utf16>(), bufLen);
  if (len == 0) return null;
  // Use the Utf16Pointer extension explicitly to avoid ambiguity
  return pkgffi.Utf16Pointer(buffer.cast<pkgffi.Utf16>()).toDartString(length: len);
    } finally {
      pkgffi.calloc.free(buffer);
    }
  }
}
