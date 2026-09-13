// Copyright (c) 2024 Daftari POS. All rights reserved.

/// Shared routing helpers. Web implementation lives in `routing_web.dart`
/// (conditional import); this stub serves static pre-render / VM contexts.
String normalizeRoutePath(String path) {
  var p = path.split('?').first.split('#').first.trim();
  if (p.isEmpty) return '/';
  p = p.toLowerCase();
  while (p.length > 1 && p.endsWith('/')) {
    p = p.substring(0, p.length - 1);
  }
  while (p.length > 1 && p.startsWith('//')) {
    p = p.substring(1);
  }
  if (!p.startsWith('/')) p = '/$p';
  return p;
}

String getBrowserPath() => '/';

void setBrowserPath(String path) {}

Object? listenBrowserPath(void Function(String path) onChange) => null;

void cancelBrowserPathListener(Object? subscription) {}

/// Language persistence. Stub returns fallback; web override uses localStorage.
String getStoredLanguage(String fallback) => fallback;

void storeLanguage(String lang) {}
