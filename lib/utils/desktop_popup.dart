import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:win32/win32.dart' as win32;
import 'dart:ffi' as ffi; // for sizeOf, Int32, nullptr
import 'package:ffi/ffi.dart' as pkgffi; // for calloc/malloc

class DesktopPopup {
  // TaskDialog callback to force topmost and foreground on create
  static int _taskDialogCallback(int hwnd, int msg, int wParam, int lParam, int lpRefData) {
    // Ensure dialog is topmost and foreground whenever we get a callback
    if (hwnd != 0) {
      win32.SetWindowPos(hwnd, win32.HWND_TOPMOST, 0, 0, 0, 0, win32.SWP_NOMOVE | win32.SWP_NOSIZE);
      win32.SetForegroundWindow(hwnd);
    }
    return 0;
  }
  static void showInfo(String title, String message, {BuildContext? context}) {
    if (Platform.isWindows) {
  final msgPtr = message.toNativeUtf16();
  final titlePtr = title.toNativeUtf16();
      win32.MessageBox(
        win32.NULL,
        msgPtr,
        titlePtr,
        win32.MB_OK | win32.MB_ICONINFORMATION | win32.MB_SETFOREGROUND | win32.MB_SYSTEMMODAL | win32.MB_TOPMOST,
      );
  pkgffi.malloc.free(msgPtr);
  pkgffi.malloc.free(titlePtr);
      return;
    }
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  static Future<bool> confirmCustomButtons(
    String title,
    String message, {
    required String positive,
    required String negative,
    BuildContext? context,
  }) async {
    if (Platform.isWindows) {
      try {
  final buttons = pkgffi.calloc<win32.TASKDIALOG_BUTTON>(2);
  final posText = positive.toNativeUtf16();
  final negText = negative.toNativeUtf16();

  final btn0 = (buttons + 0).ref;
        btn0.nButtonID = 100;
        btn0.pszButtonText = posText;
  final btn1 = (buttons + 1).ref;
        btn1.nButtonID = 101;
        btn1.pszButtonText = negText;

        final titlePtr = title.toNativeUtf16();
        final msgPtr = message.toNativeUtf16();

  final cfg = pkgffi.calloc<win32.TASKDIALOGCONFIG>();
  cfg.ref.cbSize = ffi.sizeOf<win32.TASKDIALOGCONFIG>();
        cfg.ref.hwndParent = win32.NULL;
        cfg.ref.dwFlags = 0;
        cfg.ref.dwCommonButtons = 0;
        cfg.ref.pszWindowTitle = titlePtr;
        cfg.ref.pszMainInstruction = titlePtr;
        cfg.ref.pszContent = msgPtr;
        cfg.ref.cButtons = 2;
        cfg.ref.pButtons = buttons;
  cfg.ref.nDefaultButton = 100;
  // Force topmost via callback when dialog is created
  cfg.ref.pfCallback = ffi.Pointer.fromFunction<win32.PFTASKDIALOGCALLBACK>(_taskDialogCallback, 0);

  final pnButton = pkgffi.calloc<ffi.Int32>();
  final hr = win32.TaskDialogIndirect(cfg, pnButton, ffi.nullptr, ffi.nullptr);
        final pressed = pnButton.value;

  pkgffi.calloc.free(pnButton);
  pkgffi.calloc.free(cfg);
  pkgffi.malloc.free(msgPtr);
  pkgffi.malloc.free(titlePtr);
  pkgffi.malloc.free(posText);
  pkgffi.malloc.free(negText);
  pkgffi.calloc.free(buttons);

        if (hr == win32.S_OK) return pressed == 100;
      } catch (_) {
        // fallback below
      }
      // Fallback to basic MessageBox Yes/No (labels not custom)
      final msgPtr = message.toNativeUtf16();
      final titlePtr = title.toNativeUtf16();
      final result = win32.MessageBox(
        win32.NULL,
        msgPtr,
        titlePtr,
        win32.MB_YESNO | win32.MB_ICONQUESTION | win32.MB_SETFOREGROUND | win32.MB_SYSTEMMODAL | win32.MB_TOPMOST,
      );
      pkgffi.malloc.free(msgPtr);
      pkgffi.malloc.free(titlePtr);
      return result == win32.IDYES;
    }
    if (context != null) {
      return await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(negative)),
                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(positive)),
              ],
            ),
          ) ??
          false;
    }
    return false;
  }
}
