import 'package:flutter/widgets.dart';

/// App-wide route observer so the always-on ambient layers ([RouteAware]) can
/// pause their tickers while another route covers them.
///
/// Typed to [PageRoute] on purpose: dialogs, bottom sheets, popup menus and
/// other transparent overlays leave the screen below visible, so the ambience
/// must keep running there — only full-screen page pushes should pause it.
final routeObserver = RouteObserver<PageRoute<void>>();
