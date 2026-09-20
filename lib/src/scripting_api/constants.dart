// Copyright 2020 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

abstract final class Border {
  static const s = 'solid';
  static const d = 'dashed';
  static const b = 'beveled';
  static const i = 'inset';
  static const u = 'underline';
}

abstract final class Cursor {
  static const visible = 0;
  static const hidden = 1;
  static const delay = 2;
}

abstract final class Display {
  static const visible = 0;
  static const hidden = 1;
  static const noPrint = 2;
  static const noView = 3;
}

abstract final class Font {
  static const Times = 'Times-Roman';
  static const TimesB = 'Times-Bold';
  static const TimesI = 'Times-Italic';
  static const TimesBI = 'Times-BoldItalic';
  static const Helv = 'Helvetica';
  static const HelvB = 'Helvetica-Bold';
  static const HelvI = 'Helvetica-Oblique';
  static const HelvBI = 'Helvetica-BoldOblique';
  static const Cour = 'Courier';
  static const CourB = 'Courier-Bold';
  static const CourI = 'Courier-Oblique';
  static const CourBI = 'Courier-BoldOblique';
  static const Symbol = 'Symbol';
  static const ZapfD = 'ZapfDingbats';
  static const KaGo = 'HeiseiKakuGo-W5-UniJIS-UCS2-H';
  static const KaMi = 'HeiseiMin-W3-UniJIS-UCS2-H';
}

abstract final class Highlight {
  static const n = 'none';
  static const i = 'invert';
  static const p = 'push';
  static const o = 'outline';
}

abstract final class Position {
  static const textOnly = 0;
  static const iconOnly = 1;
  static const iconTextV = 2;
  static const textIconV = 3;
  static const iconTextH = 4;
  static const textIconH = 5;
  static const overlay = 6;
}

abstract final class ScaleHow {
  static const proportional = 0;
  static const anamorphic = 1;
}

abstract final class ScaleWhen {
  static const always = 0;
  static const never = 1;
  static const tooBig = 2;
  static const tooSmall = 3;
}

abstract final class Style {
  static const ch = 'check';
  static const cr = 'cross';
  static const di = 'diamond';
  static const ci = 'circle';
  static const st = 'star';
  static const sq = 'square';
}

abstract final class Trans {
  static const blindsH = 'BlindsHorizontal';
  static const blindsV = 'BlindsVertical';
  static const boxI = 'BoxIn';
  static const boxO = 'BoxOut';
  static const dissolve = 'Dissolve';
  static const glitterD = 'GlitterDown';
  static const glitterR = 'GlitterRight';
  static const glitterRD = 'GlitterRightDown';
  static const random = 'Random';
  static const replace = 'Replace';
  static const splitHI = 'SplitHorizontalIn';
  static const splitHO = 'SplitHorizontalOut';
  static const splitVI = 'SplitVerticalIn';
  static const splitVO = 'SplitVerticalOut';
  static const wipeD = 'WipeDown';
  static const wipeL = 'WipeLeft';
  static const wipeR = 'WipeRight';
  static const wipeU = 'WipeUp';
}

abstract final class ZoomType {
  static const none = 'NoVary';
  static const fitP = 'FitPage';
  static const fitW = 'FitWidth';
  static const fitH = 'FitHeight';
  static const fitV = 'FitVisibleWidth';
  static const pref = 'Preferred';
  static const refW = 'ReflowWidth';
}

// Names intentionally match the PDF JavaScript API.
// ignore_for_file: constant_identifier_names
abstract final class GlobalConstants {
  static const IDS_GREATER_THAN =
      'Invalid value: must be greater than or equal to % s.';
  static const IDS_GT_AND_LT =
      'Invalid value: must be greater than or equal to % s '
      'and less than or equal to % s.';
  static const IDS_LESS_THAN =
      'Invalid value: must be less than or equal to % s.';
  static const IDS_INVALID_MONTH = '** Invalid **';
  static const IDS_INVALID_DATE =
      'Invalid date / time: please ensure that the date / time exists. Field';
  static const IDS_INVALID_DATE2 = ' should match format ';
  static const IDS_INVALID_VALUE =
      'The value entered does not match the format of the field';
  static const IDS_AM = 'am';
  static const IDS_PM = 'pm';
  static const IDS_MONTH_INFO =
      'January[1] February[2] March[3] April[4] May[5] '
      'June[6] July[7] August[8] September[9] October[10] '
      'November[11] December[12] Sept[9] Jan[1] Feb[2] Mar[3] '
      'Apr[4] Jun[6] Jul[7] Aug[8] Sep[9] Oct[10] Nov[11] Dec[12]';
  static const IDS_STARTUP_CONSOLE_MSG = '** ^ _ ^ **';
  static const RE_NUMBER_ENTRY_DOT_SEP = [r'[+-]?\d*\.?\d*'];
  static const RE_NUMBER_COMMIT_DOT_SEP = [
    r'[+-]?\d+(\.\d+)?',
    r'[+-]?\.\d+',
    r'[+-]?\d+\.',
  ];
  static const RE_NUMBER_ENTRY_COMMA_SEP = [r'[+-]?\d*,?\d*'];
  static const RE_NUMBER_COMMIT_COMMA_SEP = [
    r'[+-]?\d+([.,]\d+)?',
    r'[+-]?[.,]\d+',
    r'[+-]?\d+[.,]',
  ];
  static const RE_ZIP_ENTRY = [r'\d{0,5}'];
  static const RE_ZIP_COMMIT = [r'\d{5}'];
  static const RE_ZIP4_ENTRY = [r'\d{0,5}(\.|[- ])?\d{0,4}'];
  static const RE_ZIP4_COMMIT = [r'\d{5}(\.|[- ])?\d{4}'];
  static const RE_PHONE_ENTRY = [
    r'\d{0,3}(\.|[- ])?\d{0,3}(\.|[- ])?\d{0,4}',
    r'\(\d{0,3}',
    r'\(\d{0,3}\)(\.|[- ])?\d{0,3}(\.|[- ])?\d{0,4}',
    r'\(\d{0,3}(\.|[- ])?\d{0,3}(\.|[- ])?\d{0,4}',
    r'\d{0,3}\)(\.|[- ])?\d{0,3}(\.|[- ])?\d{0,4}',
    r'011(\.|[- \d])*',
  ];
  static const RE_PHONE_COMMIT = [
    r'\d{3}(\.|[- ])?\d{4}',
    r'\d{3}(\.|[- ])?\d{3}(\.|[- ])?\d{4}',
    r'\(\d{3}\)(\.|[- ])?\d{3}(\.|[- ])?\d{4}',
    r'011(\.|[- \d])*',
  ];
  static const RE_SSN_ENTRY = [
    r'\d{0,3}(\.|[- ])?\d{0,2}(\.|[- ])?\d{0,4}',
  ];
  static const RE_SSN_COMMIT = [r'\d{3}(\.|[- ])?\d{2}(\.|[- ])?\d{4}'];
}
