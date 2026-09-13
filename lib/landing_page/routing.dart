// Copyright (c) 2024 Daftari POS. All rights reserved.

String normalizeRoutePath(String path) {
  if (path.isEmpty) return '/';
  if (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return path;
}

String getBrowserPath() => '/';

void setBrowserPath(String path) {}

Object? listenBrowserPath(void Function(String path) onChange) => null;

void cancelBrowserPathListener(Object? subscription) {}
