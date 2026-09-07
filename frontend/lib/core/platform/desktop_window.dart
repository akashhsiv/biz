import 'dart:io';

/// True on the platforms where `window_manager` (frameless window, drag-to-move, minimize/
/// maximize/close, [CustomTitleBar]/[TopStatusBar]'s window controls) actually has a native
/// implementation. `window_manager` has no Android/iOS plugin registered, so calling into it there
/// throws a MissingPluginException - every call site guards on this instead of assuming desktop.
/// Today this app only ships Windows and Android, so `Platform.isWindows` alone is enough; extend
/// this if macOS/Linux desktop builds are ever added.
final bool isDesktopWindowed = Platform.isWindows;
