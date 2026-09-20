// Copyright 2026
// SPDX-License-Identifier: Apache-2.0

import 'package:web/web.dart' as web;

Map<String, Object?> readAppOptionsEnvironment() => <String, Object?>{
      'language': web.window.navigator.language,
      'documentUrl': web.document.URL,
      'userAgent': web.window.navigator.userAgent,
      'platform': web.window.navigator.platform,
      'maxTouchPoints': web.window.navigator.maxTouchPoints,
    };
