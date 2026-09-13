// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'dart:async';

import 'package:web/web.dart' as web;

import 'routing.dart' show normalizeRoutePath;

String getBrowserPath() => normalizeRoutePath(web.window.location.pathname);

void setBrowserPath(String path) {
  web.window.history.pushState(null, '', path);
}

Object? listenBrowserPath(void Function(String path) onChange) {
  return web.window.onPopState.listen((_) {
    onChange(normalizeRoutePath(web.window.location.pathname));
  });
}

void cancelBrowserPathListener(Object? subscription) {
  (subscription as StreamSubscription?)?.cancel();
}
