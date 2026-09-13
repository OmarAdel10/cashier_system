// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'dart:async';

import 'package:web/web.dart' as web;

import 'routing.dart' show normalizeRoutePath;

String getBrowserPath() => normalizeRoutePath(web.window.location.pathname);

void setBrowserPath(String path) {
  final normalized = normalizeRoutePath(path);
  if (!normalized.startsWith('/')) return;
  web.window.history.pushState(null, '', normalized);
}

Object? listenBrowserPath(void Function(String path) onChange) {
  return web.window.onPopState.listen((_) {
    onChange(normalizeRoutePath(web.window.location.pathname));
  });
}

void cancelBrowserPathListener(Object? subscription) {
  (subscription as StreamSubscription?)?.cancel();
}

/// Language persistence via localStorage. Falls back silently when
/// storage is unavailable (private mode) or on unexpected errors.
String getStoredLanguage(String fallback) {
  try {
    final stored = web.window.localStorage.getItem('daftari-lang');
    if (stored == 'ar') return 'ar';
    if (stored == 'en') return 'en';
    return fallback;
  } catch (_) {
    return fallback;
  }
}

void storeLanguage(String lang) {
  try {
    web.window.localStorage.setItem('daftari-lang', lang);
  } catch (_) {}
}
