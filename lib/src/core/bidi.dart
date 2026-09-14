// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import '../shared/util.dart';

// Implements a subset of the Unicode Bidirectional Algorithm (UBA).
// Specification: https://www.unicode.org/reports/tr9/tr9-48.html

// Character types for symbols from 0000 to 00FF.
// Source: ftp://ftp.unicode.org/Public/UNIDATA/UnicodeData.txt
const List<String> _baseTypes = [
  'BN', 'BN', 'BN', 'BN', 'BN', 'BN', 'BN', 'BN', 'BN', 'S', 'B', 'S',
  'WS', 'B', 'BN', 'BN', 'BN', 'BN', 'BN', 'BN', 'BN', 'BN', 'BN', 'BN',
  'BN', 'BN', 'BN', 'BN', 'B', 'B', 'B', 'S', 'WS', 'ON', 'ON', 'ET',
  'ET', 'ET', 'ON', 'ON', 'ON', 'ON', 'ON', 'ES', 'CS', 'ES', 'CS', 'CS',
  'EN', 'EN', 'EN', 'EN', 'EN', 'EN', 'EN', 'EN', 'EN', 'EN', 'CS', 'ON',
  'ON', 'ON', 'ON', 'ON', 'ON', 'L', 'L', 'L', 'L', 'L', 'L', 'L', 'L',
  'L', 'L', 'L', 'L', 'L', 'L', 'L', 'L', 'L', 'L', 'L', 'L', 'L', 'L',
  'L', 'L', 'L', 'L', 'ON', 'ON', 'ON', 'ON', 'ON', 'ON', 'L', 'L', 'L',
  'L', 'L', 'L', 'L', 'L', 'L', 'L', 'L', 'L', 'L', 'L', 'L', 'L', 'L',
  'L', 'L', 'L', 'L', 'L', 'L', 'L', 'L', 'L', 'ON', 'ON', 'ON', 'ON',
  'BN', 'BN', 'BN', 'BN', 'BN', 'BN', 'B', 'BN', 'BN', 'BN', 'BN', 'BN',
  'BN', 'BN', 'BN', 'BN', 'BN', 'BN', 'BN', 'BN', 'BN', 'BN', 'BN', 'BN',
  'BN', 'BN', 'BN', 'BN', 'BN', 'BN', 'BN', 'BN', 'BN', 'CS', 'ON', 'ET',
  'ET', 'ET', 'ET', 'ON', 'ON', 'ON', 'ON', 'L', 'ON', 'ON', 'BN', 'ON',
  'ON', 'ET', 'ET', 'EN', 'EN', 'ON', 'L', 'ON', 'ON', 'ON', 'EN', 'L',
  'ON', 'ON', 'ON', 'ON', 'ON', 'L', 'L', 'L', 'L', 'L', 'L', 'L', 'L',
  'L', 'L', 'L', 'L', 'L', 'L', 'L', 'L', 'L', 'L', 'L', 'L', 'L', 'L',
  'L', 'ON', 'L', 'L', 'L', 'L', 'L', 'L', 'L', 'L', 'L', 'L', 'L', 'L',
  'L', 'L', 'L', 'L', 'L', 'L', 'L', 'L', 'L', 'L', 'L', 'L', 'L', 'L',
  'L', 'L', 'L', 'L', 'L', 'ON', 'L', 'L', 'L', 'L', 'L', 'L', 'L', 'L',
];

// Character types for symbols from 0600 to 06FF.
const List<String> _arabicTypes = [
  'AN', 'AN', 'AN', 'AN', 'AN', 'AN', 'ON', 'ON', 'AL', 'ET', 'ET', 'AL',
  'CS', 'AL', 'ON', 'ON', 'NSM', 'NSM', 'NSM', 'NSM', 'NSM', 'NSM', 'NSM',
  'NSM', 'NSM', 'NSM', 'NSM', 'AL', 'AL', '', 'AL', 'AL', 'AL', 'AL', 'AL',
  'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL',
  'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL',
  'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL',
  'AL', 'AL', 'AL', 'AL', 'NSM', 'NSM', 'NSM', 'NSM', 'NSM', 'NSM', 'NSM',
  'NSM', 'NSM', 'NSM', 'NSM', 'NSM', 'NSM', 'NSM', 'NSM', 'NSM', 'NSM',
  'NSM', 'NSM', 'NSM', 'NSM', 'AN', 'AN', 'AN', 'AN', 'AN', 'AN', 'AN',
  'AN', 'AN', 'AN', 'ET', 'AN', 'AN', 'AL', 'AL', 'AL', 'NSM', 'AL', 'AL',
  'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL',
  'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL',
  'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL',
  'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL',
  'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL',
  'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL',
  'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL',
  'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL',
  'AL', 'AL', 'AL', 'NSM', 'NSM', 'NSM', 'NSM', 'NSM', 'NSM', 'NSM', 'AN',
  'ON', 'NSM', 'NSM', 'NSM', 'NSM', 'NSM', 'NSM', 'AL', 'AL', 'NSM', 'NSM',
  'ON', 'NSM', 'NSM', 'NSM', 'NSM', 'AL', 'AL', 'EN', 'EN', 'EN', 'EN',
  'EN', 'EN', 'EN', 'EN', 'EN', 'EN', 'AL', 'AL', 'AL', 'AL', 'AL', 'AL',
];

bool _isOdd(int i) => (i & 1) != 0;
bool _isEven(int i) => (i & 1) == 0;

int _findUnequal(List<String> arr, int start, String value) {
  for (var j = start; j < arr.length; ++j) {
    if (arr[j] != value) {
      return j;
    }
  }
  return arr.length;
}

void _reverseValues(List<String> arr, int start, int end) {
  for (var i = start, j = end - 1; i < j; ++i, --j) {
    final temp = arr[i];
    arr[i] = arr[j];
    arr[j] = temp;
  }
}

class BidiText {
  const BidiText({required this.str, required this.dir});

  final String str;
  final String dir;

  @override
  String toString() => str;
}

BidiText _createBidiText(String str, bool isLTR, [bool vertical = false]) {
  var dir = 'ltr';
  if (vertical) {
    dir = 'ttb';
  } else if (!isLTR) {
    dir = 'rtl';
  }
  return BidiText(str: str, dir: dir);
}

BidiText bidi(String str, [int startLevel = -1, bool vertical = false]) {
  var isLTR = true;
  final strLength = str.length;
  if (strLength == 0 || vertical) {
    return _createBidiText(str, isLTR, vertical);
  }

  final chars = List<String>.filled(strLength, '');
  final types = List<String>.filled(strLength, '');
  var numBidi = 0;

  for (var i = 0; i < strLength; ++i) {
    chars[i] = str[i];
    final charCode = str.codeUnitAt(i);
    var charType = 'L';
    if (charCode <= 0x00ff) {
      charType = _baseTypes[charCode];
    } else if (0x0590 <= charCode && charCode <= 0x05f4) {
      charType = 'R';
    } else if (0x0600 <= charCode && charCode <= 0x06ff) {
      final idx = charCode & 0xff;
      charType = idx < _arabicTypes.length ? _arabicTypes[idx] : '';
      if (charType.isEmpty) {
        warn('Bidi: invalid Unicode character ${charCode.toRadixString(16)}');
      }
    } else if ((0x0700 <= charCode && charCode <= 0x08ac) ||
        (0xfb50 <= charCode && charCode <= 0xfdff) ||
        (0xfe70 <= charCode && charCode <= 0xfeff)) {
      charType = 'AL';
    }
    if (charType == 'R' || charType == 'AL' || charType == 'AN') {
      numBidi++;
    }
    types[i] = charType;
  }

  // Detect the bidi method
  if (numBidi == 0) {
    isLTR = true;
    return _createBidiText(str, isLTR);
  }

  if (startLevel == -1) {
    if (numBidi / strLength < 0.3 && strLength > 4) {
      isLTR = true;
      startLevel = 0;
    } else {
      isLTR = false;
      startLevel = 1;
    }
  }

  final levels = List<int>.filled(strLength, startLevel);

  final e = _isOdd(startLevel) ? 'R' : 'L';
  final sor = e;
  final eor = sor;

  // W1
  var lastType = sor;
  for (var i = 0; i < strLength; ++i) {
    if (types[i] == 'NSM') {
      types[i] = lastType;
    } else {
      lastType = types[i];
    }
  }

  // W2
  lastType = sor;
  for (var i = 0; i < strLength; ++i) {
    final t = types[i];
    if (t == 'EN') {
      types[i] = lastType == 'AL' ? 'AN' : 'EN';
    } else if (t == 'R' || t == 'L' || t == 'AL') {
      lastType = t;
    }
  }

  // W3
  for (var i = 0; i < strLength; ++i) {
    if (types[i] == 'AL') {
      types[i] = 'R';
    }
  }

  // W4
  for (var i = 1; i < strLength - 1; ++i) {
    if (types[i] == 'ES' && types[i - 1] == 'EN' && types[i + 1] == 'EN') {
      types[i] = 'EN';
    }
    if (types[i] == 'CS' &&
        (types[i - 1] == 'EN' || types[i - 1] == 'AN') &&
        types[i + 1] == types[i - 1]) {
      types[i] = types[i - 1];
    }
  }

  // W5
  for (var i = 0; i < strLength; ++i) {
    if (types[i] == 'EN') {
      for (var j = i - 1; j >= 0; --j) {
        if (types[j] != 'ET') break;
        types[j] = 'EN';
      }
      for (var j = i + 1; j < strLength; ++j) {
        if (types[j] != 'ET') break;
        types[j] = 'EN';
      }
    }
  }

  // W6
  for (var i = 0; i < strLength; ++i) {
    final t = types[i];
    if (t == 'WS' || t == 'ES' || t == 'ET' || t == 'CS') {
      types[i] = 'ON';
    }
  }

  // W7
  lastType = sor;
  for (var i = 0; i < strLength; ++i) {
    final t = types[i];
    if (t == 'EN') {
      types[i] = lastType == 'L' ? 'L' : 'EN';
    } else if (t == 'R' || t == 'L') {
      lastType = t;
    }
  }

  // N1
  for (var i = 0; i < strLength; ++i) {
    if (types[i] == 'ON') {
      final end = _findUnequal(types, i + 1, 'ON');
      var before = sor;
      for (var j = i - 1; j >= 0; j--) {
        final tt = types[j];
        if (tt == 'L') {
          before = 'L';
          break;
        }
        if (tt == 'R' || tt == 'EN' || tt == 'AN') {
          before = 'R';
          break;
        }
      }

      var after = eor;
      for (var j = end; j < strLength; j++) {
        final tt = types[j];
        if (tt == 'L') {
          after = 'L';
          break;
        }
        if (tt == 'R' || tt == 'EN' || tt == 'AN') {
          after = 'R';
          break;
        }
      }

      if (before == after) {
        for (var k = i; k < end; k++) {
          types[k] = before;
        }
      }
      i = end - 1;
    }
  }

  // N2
  for (var i = 0; i < strLength; ++i) {
    if (types[i] == 'ON') {
      types[i] = e;
    }
  }

  // I1, I2
  for (var i = 0; i < strLength; ++i) {
    final t = types[i];
    if (_isEven(levels[i])) {
      if (t == 'R') {
        levels[i] += 1;
      } else if (t == 'AN' || t == 'EN') {
        levels[i] += 2;
      }
    } else if (t == 'L' || t == 'AN' || t == 'EN') {
      levels[i] += 1;
    }
  }

  // L2: reverse segments
  var highestLevel = -1;
  var lowestOddLevel = 99;
  for (var i = 0; i < levels.length; ++i) {
    final lvl = levels[i];
    if (highestLevel < lvl) {
      highestLevel = lvl;
    }
    if (lowestOddLevel > lvl && _isOdd(lvl)) {
      lowestOddLevel = lvl;
    }
  }

  for (var level = highestLevel; level >= lowestOddLevel; --level) {
    var start = -1;
    for (var i = 0; i < levels.length; ++i) {
      if (levels[i] < level) {
        if (start >= 0) {
          _reverseValues(chars, start, i);
          start = -1;
        }
      } else if (start < 0) {
        start = i;
      }
    }
    if (start >= 0) {
      _reverseValues(chars, start, levels.length);
    }
  }

  for (var i = 0; i < chars.length; ++i) {
    final ch = chars[i];
    if (ch == '<' || ch == '>') {
      chars[i] = '';
    }
  }

  return _createBidiText(chars.join(''), isLTR);
}
