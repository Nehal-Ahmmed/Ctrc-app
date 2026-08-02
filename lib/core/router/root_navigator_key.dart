import 'package:flutter/widgets.dart';

/// The app's top-level navigator.
///
/// Lives in its own file so things that need a context without being handed
/// one — the toast overlay, the global error handlers in `main.dart` — can
/// reach it without importing the whole router (and every page with it).
final rootNavigatorKey = GlobalKey<NavigatorState>();
