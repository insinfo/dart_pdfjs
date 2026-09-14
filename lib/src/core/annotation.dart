// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:async';
import 'dart:math' as math;

import '../shared/util.dart';
import 'primitives.dart';

typedef PdfRect = List<double>;
typedef PdfPoint = ({double x, double y});

double _number(dynamic value, [double fallback = 0]) =>
    value is num ? value.toDouble() : fallback;

String? _text(dynamic value) {
  if (value is String) return value;
  if (value is Name) return value.name;
  return null;
}

PdfRect normalizeRect(dynamic value) {
  if (value is! List || value.length != 4) return [0, 0, 0, 0];
  final x1 = _number(value[0]);
  final y1 = _number(value[1]);
  final x2 = _number(value[2]);
  final y2 = _number(value[3]);
  return [
    math.min(x1, x2),
    math.min(y1, y2),
    math.max(x1, x2),
    math.max(y1, y2)
  ];
}

List<List<PdfPoint>> getQuadPoints(dynamic value, PdfRect rect) {
  if (value is! List || value.length % 8 != 0) return const [];
  final result = <List<PdfPoint>>[];
  for (var i = 0; i < value.length; i += 8) {
    final values = value.skip(i).take(8).map(_number).toList();
    if (values.any((v) => v < rect[0] || v > rect[2]) &&
        values.indexed.any((e) => e.$1.isEven)) return const [];
    final points = <PdfPoint>[
      (x: values[0], y: values[1]),
      (x: values[2], y: values[3]),
      (x: values[4], y: values[5]),
      (x: values[6], y: values[7]),
    ];
    if (points.any((p) =>
        p.x < rect[0] || p.x > rect[2] || p.y < rect[1] || p.y > rect[3])) {
      return const [];
    }
    result.add(points);
  }
  return result;
}

class AnnotationBorderStyle {
  int width = 1;
  int style = AnnotationBorderStyleType.solid;
  int horizontalCornerRadius = 0;
  int verticalCornerRadius = 0;
  List<num> dashArray = const [3];

  void setWidth(dynamic value) {
    width = value is num && value >= 0 ? value.toInt() : 1;
  }

  void setStyle(dynamic value) {
    final name = _text(value);
    style = switch (name) {
      'D' => AnnotationBorderStyleType.dashed,
      'B' => AnnotationBorderStyleType.beveled,
      'I' => AnnotationBorderStyleType.inset,
      'U' => AnnotationBorderStyleType.underline,
      _ => AnnotationBorderStyleType.solid,
    };
  }

  void setDashArray(dynamic value) {
    if (value is! List ||
        value.isEmpty ||
        value.any((v) => v is! num || v < 0)) {
      dashArray = const [3];
      return;
    }
    if (value.every((v) => (v as num) == 0)) {
      dashArray = const [3];
      width = 0;
      return;
    }
    dashArray = List<num>.unmodifiable(value.cast<num>());
  }

  void setHorizontalCornerRadius(dynamic value) {
    horizontalCornerRadius = value is num && value >= 0 ? value.toInt() : 0;
  }

  void setVerticalCornerRadius(dynamic value) {
    verticalCornerRadius = value is num && value >= 0 ? value.toInt() : 0;
  }

  factory AnnotationBorderStyle.fromDict(Dict dict) {
    final result = AnnotationBorderStyle();
    final bs = dict.get('BS');
    if (bs is Dict) {
      result
        ..setWidth(bs.get('W'))
        ..setStyle(bs.get('S'))
        ..setDashArray(bs.getArray('D'));
      return result;
    }
    final border = dict.getArray('Border');
    if (border is List) {
      if (border.isNotEmpty) result.setHorizontalCornerRadius(border[0]);
      if (border.length > 1) result.setVerticalCornerRadius(border[1]);
      if (border.length > 2) result.setWidth(border[2]);
      if (border.length > 3) result.setDashArray(border[3]);
    }
    return result;
  }

  AnnotationBorderStyle();

  Map<String, dynamic> toMap() => {
        'width': width,
        'style': style,
        'horizontalCornerRadius': horizontalCornerRadius,
        'verticalCornerRadius': verticalCornerRadius,
        'dashArray': dashArray,
      };
}

class AnnotationGlobals {
  final Dict? acroForm;
  final Dict? collection;
  final bool hasAcroForm;
  final bool hasXfa;
  const AnnotationGlobals(
      {this.acroForm,
      this.collection,
      this.hasAcroForm = false,
      this.hasXfa = false});
}

class Annotation {
  final Dict dict;
  final dynamic ref;
  final String id;
  final int annotationType;
  late final PdfRect rect;
  late final int flags;
  late final List<int> color;
  late final AnnotationBorderStyle borderStyle;
  late final String? contents;
  late final String? modificationDate;
  late final String? title;
  late final bool hasAppearance;

  Annotation(
      {required this.dict,
      required this.id,
      required this.annotationType,
      this.ref}) {
    rect = normalizeRect(dict.getArray('Rect'));
    flags = dict.get('F') is int ? dict.get('F') as int : 0;
    color = _parseColor(dict.getArray('C'));
    borderStyle = AnnotationBorderStyle.fromDict(dict);
    contents = _text(dict.get('Contents'));
    modificationDate = _text(dict.get('M'));
    title = _text(dict.get('T'));
    hasAppearance = dict.get('AP') != null;
  }

  static List<int> _parseColor(dynamic value) {
    if (value is! List || value.isEmpty) return const [0, 0, 0];
    int byte(dynamic v) => (_number(v).clamp(0, 1) * 255).round();
    if (value.length == 1) {
      final gray = byte(value[0]);
      return [gray, gray, gray];
    }
    if (value.length == 3) return value.map(byte).toList();
    if (value.length == 4) {
      final c = _number(value[0]).clamp(0, 1);
      final m = _number(value[1]).clamp(0, 1);
      final y = _number(value[2]).clamp(0, 1);
      final k = _number(value[3]).clamp(0, 1);
      return [
        ((1 - math.min(1, c + k)) * 255).round(),
        ((1 - math.min(1, m + k)) * 255).round(),
        ((1 - math.min(1, y + k)) * 255).round(),
      ];
    }
    return const [0, 0, 0];
  }

  bool get viewable =>
      flags & AnnotationFlag.invisible == 0 &&
      flags & AnnotationFlag.hidden == 0 &&
      flags & AnnotationFlag.noView == 0;
  bool get printable =>
      flags & AnnotationFlag.print != 0 &&
      flags & AnnotationFlag.invisible == 0 &&
      flags & AnnotationFlag.hidden == 0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'annotationType': annotationType,
        'rect': rect,
        'flags': flags,
        'color': color,
        'borderStyle': borderStyle.toMap(),
        'contents': contents,
        'modificationDate': modificationDate,
        'title': title,
        'hasAppearance': hasAppearance,
      };
}

class MarkupAnnotation extends Annotation {
  late final String? creationDate;
  late final String? subject;
  late final double opacity;
  late final String? replyType;
  late final String? inReplyTo;

  MarkupAnnotation(
      {required super.dict,
      required super.id,
      required super.annotationType,
      super.ref}) {
    creationDate = _text(dict.get('CreationDate'));
    subject = _text(dict.get('Subj'));
    opacity = _number(dict.get('CA'), 1).clamp(0, 1).toDouble();
    replyType = _text(dict.get('RT'));
    inReplyTo = dict.getRaw('IRT')?.toString();
  }

  @override
  Map<String, dynamic> toMap() => super.toMap()
    ..addAll({
      'creationDate': creationDate,
      'subject': subject,
      'opacity': opacity,
      'replyType': replyType,
      'inReplyTo': inReplyTo,
    });
}

class WidgetAnnotation extends Annotation {
  late final String fieldName;
  late final dynamic fieldValue;
  late final dynamic defaultFieldValue;
  late final int fieldFlags;
  late final String? alternativeText;
  late final String? defaultAppearance;

  WidgetAnnotation({required super.dict, required super.id, super.ref})
      : super(annotationType: AnnotationType.widget) {
    fieldName = _collectFieldName(dict);
    fieldValue = dict.get('V');
    defaultFieldValue = dict.get('DV');
    fieldFlags = dict.get('Ff') is int ? dict.get('Ff') as int : 0;
    alternativeText = _text(dict.get('TU'));
    defaultAppearance = _text(dict.get('DA'));
  }

  static String _collectFieldName(Dict dict) {
    final parts = <String>[];
    Dict? current = dict;
    final seen = <Dict>{};
    while (current != null && seen.add(current)) {
      final part = _text(current.get('T'));
      if (part != null && part.isNotEmpty) parts.insert(0, part);
      final parent = current.get('Parent');
      current = parent is Dict ? parent : null;
    }
    return parts.join('.');
  }

  bool hasFieldFlag(int flag) => fieldFlags & flag != 0;

  @override
  Map<String, dynamic> toMap() => super.toMap()
    ..addAll({
      'fieldName': fieldName,
      'fieldValue': fieldValue,
      'defaultFieldValue': defaultFieldValue,
      'fieldFlags': fieldFlags,
      'alternativeText': alternativeText,
      'defaultAppearance': defaultAppearance,
    });
}

class TextWidgetAnnotation extends WidgetAnnotation {
  late final int? maxLen;
  late final bool multiLine;
  late final bool password;
  late final bool comb;
  TextWidgetAnnotation({required super.dict, required super.id, super.ref}) {
    maxLen = dict.get('MaxLen') is int ? dict.get('MaxLen') as int : null;
    multiLine = hasFieldFlag(AnnotationFieldFlag.multiline);
    password = hasFieldFlag(AnnotationFieldFlag.password);
    comb = hasFieldFlag(AnnotationFieldFlag.comb) &&
        maxLen != null &&
        maxLen! > 0 &&
        !multiLine &&
        !password;
  }
  @override
  Map<String, dynamic> toMap() => super.toMap()
    ..addAll({
      'maxLen': maxLen,
      'multiLine': multiLine,
      'password': password,
      'comb': comb
    });
}

class ButtonWidgetAnnotation extends WidgetAnnotation {
  late final bool checkBox;
  late final bool radioButton;
  late final bool pushButton;
  ButtonWidgetAnnotation({required super.dict, required super.id, super.ref}) {
    pushButton = hasFieldFlag(AnnotationFieldFlag.pushButton);
    radioButton = !pushButton && hasFieldFlag(AnnotationFieldFlag.radio);
    checkBox = !pushButton && !radioButton;
  }
  @override
  Map<String, dynamic> toMap() => super.toMap()
    ..addAll({
      'checkBox': checkBox,
      'radioButton': radioButton,
      'pushButton': pushButton
    });
}

class ChoiceWidgetAnnotation extends WidgetAnnotation {
  late final List<Map<String, String>> options;
  late final bool combo;
  late final bool multiSelect;
  ChoiceWidgetAnnotation({required super.dict, required super.id, super.ref}) {
    combo = hasFieldFlag(AnnotationFieldFlag.combo);
    multiSelect = hasFieldFlag(AnnotationFieldFlag.multiSelect);
    final raw = dict.getArray('Opt');
    options = raw is List
        ? raw.map((option) {
            if (option is List && option.length >= 2) {
              return {
                'exportValue': _text(option[0]) ?? '',
                'displayValue': _text(option[1]) ?? ''
              };
            }
            final text = _text(option) ?? '';
            return {'exportValue': text, 'displayValue': text};
          }).toList()
        : const [];
  }
  @override
  Map<String, dynamic> toMap() => super.toMap()
    ..addAll({'options': options, 'combo': combo, 'multiSelect': multiSelect});
}

class SignatureWidgetAnnotation extends WidgetAnnotation {
  SignatureWidgetAnnotation(
      {required super.dict, required super.id, super.ref});
}

class TextAnnotation extends MarkupAnnotation {
  late final bool open;
  late final String name;
  TextAnnotation({required super.dict, required super.id, super.ref})
      : super(annotationType: AnnotationType.text) {
    open = dict.get('Open') == true;
    name = _text(dict.get('Name')) ?? 'Note';
  }
}

class LinkAnnotation extends Annotation {
  late final String? url;
  late final dynamic destination;
  late final String? action;
  LinkAnnotation({required super.dict, required super.id, super.ref})
      : super(annotationType: AnnotationType.link) {
    final a = dict.get('A');
    url = a is Dict ? _text(a.get('URI')) : null;
    action = a is Dict ? _text(a.get('S')) : null;
    destination = dict.get('Dest');
  }
}

class PopupAnnotation extends Annotation {
  PopupAnnotation({required super.dict, required super.id, super.ref})
      : super(annotationType: AnnotationType.popup);
}

class FreeTextAnnotation extends MarkupAnnotation {
  FreeTextAnnotation({required super.dict, required super.id, super.ref})
      : super(annotationType: AnnotationType.freetext);
}

class LineAnnotation extends MarkupAnnotation {
  late final List<double> lineCoordinates;
  LineAnnotation({required super.dict, required super.id, super.ref})
      : super(annotationType: AnnotationType.line) {
    lineCoordinates = (dict.getArray('L') is List)
        ? (dict.getArray('L') as List).map(_number).toList()
        : const [];
  }
}

class SquareAnnotation extends MarkupAnnotation {
  SquareAnnotation({required super.dict, required super.id, super.ref})
      : super(annotationType: AnnotationType.square);
}

class CircleAnnotation extends MarkupAnnotation {
  CircleAnnotation({required super.dict, required super.id, super.ref})
      : super(annotationType: AnnotationType.circle);
}

class PolylineAnnotation extends MarkupAnnotation {
  late final List<PdfPoint> vertices;
  PolylineAnnotation(
      {required super.dict, required super.id, required int type, super.ref})
      : super(annotationType: type) {
    final raw = dict.getArray('Vertices');
    vertices = raw is List
        ? [
            for (var i = 0; i + 1 < raw.length; i += 2)
              (x: _number(raw[i]), y: _number(raw[i + 1]))
          ]
        : const [];
  }
}

class PolygonAnnotation extends PolylineAnnotation {
  PolygonAnnotation({required super.dict, required super.id, super.ref})
      : super(type: AnnotationType.polygon);
}

class InkAnnotation extends MarkupAnnotation {
  late final List<List<PdfPoint>> inkLists;
  InkAnnotation({required super.dict, required super.id, super.ref})
      : super(annotationType: AnnotationType.ink) {
    final raw = dict.getArray('InkList');
    inkLists = raw is List
        ? raw
            .whereType<List>()
            .map((line) => [
                  for (var i = 0; i + 1 < line.length; i += 2)
                    (x: _number(line[i]), y: _number(line[i + 1]))
                ])
            .toList()
        : const [];
  }
}

class HighlightAnnotation extends MarkupAnnotation {
  HighlightAnnotation({required super.dict, required super.id, super.ref})
      : super(annotationType: AnnotationType.highlight);
}

class UnderlineAnnotation extends MarkupAnnotation {
  UnderlineAnnotation({required super.dict, required super.id, super.ref})
      : super(annotationType: AnnotationType.underline);
}

class SquigglyAnnotation extends MarkupAnnotation {
  SquigglyAnnotation({required super.dict, required super.id, super.ref})
      : super(annotationType: AnnotationType.squiggly);
}

class StrikeOutAnnotation extends MarkupAnnotation {
  StrikeOutAnnotation({required super.dict, required super.id, super.ref})
      : super(annotationType: AnnotationType.strikeout);
}

class StampAnnotation extends MarkupAnnotation {
  StampAnnotation({required super.dict, required super.id, super.ref})
      : super(annotationType: AnnotationType.stamp);
}

class FileAttachmentAnnotation extends MarkupAnnotation {
  late final String? fileName;
  FileAttachmentAnnotation({required super.dict, required super.id, super.ref})
      : super(annotationType: AnnotationType.fileattachment) {
    final fs = dict.get('FS');
    fileName = fs is Dict ? _text(fs.get('UF', 'F')) : null;
  }
}

class AnnotationFactory {
  static AnnotationGlobals createGlobals(dynamic pdfManager) =>
      const AnnotationGlobals();

  static Future<Annotation?> create(dynamic xref, dynamic ref, dynamic globals,
      [dynamic idFactory,
      bool collectFields = false,
      dynamic orphanFields,
      dynamic collectByType,
      dynamic pageRef]) async {
    final value = ref is Dict ? ref : xref?.fetch(ref);
    if (value is! Dict) return null;
    final id = ref?.toString() ??
        value.objId?.toString() ??
        'annot_${identityHashCode(value)}';
    return fromDict(value, id: id, ref: ref);
  }

  static Annotation fromDict(Dict dict, {required String id, dynamic ref}) {
    final subtype = _text(dict.get('Subtype'));
    if (subtype == 'Widget') {
      return switch (_text(dict.get('FT'))) {
        'Tx' => TextWidgetAnnotation(dict: dict, id: id, ref: ref),
        'Btn' => ButtonWidgetAnnotation(dict: dict, id: id, ref: ref),
        'Ch' => ChoiceWidgetAnnotation(dict: dict, id: id, ref: ref),
        'Sig' => SignatureWidgetAnnotation(dict: dict, id: id, ref: ref),
        _ => WidgetAnnotation(dict: dict, id: id, ref: ref),
      };
    }
    return switch (subtype) {
      'Text' => TextAnnotation(dict: dict, id: id, ref: ref),
      'Link' => LinkAnnotation(dict: dict, id: id, ref: ref),
      'Popup' => PopupAnnotation(dict: dict, id: id, ref: ref),
      'FreeText' => FreeTextAnnotation(dict: dict, id: id, ref: ref),
      'Line' => LineAnnotation(dict: dict, id: id, ref: ref),
      'Square' => SquareAnnotation(dict: dict, id: id, ref: ref),
      'Circle' => CircleAnnotation(dict: dict, id: id, ref: ref),
      'PolyLine' => PolylineAnnotation(
          dict: dict, id: id, type: AnnotationType.polyline, ref: ref),
      'Polygon' => PolygonAnnotation(dict: dict, id: id, ref: ref),
      'Ink' => InkAnnotation(dict: dict, id: id, ref: ref),
      'Highlight' => HighlightAnnotation(dict: dict, id: id, ref: ref),
      'Underline' => UnderlineAnnotation(dict: dict, id: id, ref: ref),
      'Squiggly' => SquigglyAnnotation(dict: dict, id: id, ref: ref),
      'StrikeOut' => StrikeOutAnnotation(dict: dict, id: id, ref: ref),
      'Stamp' => StampAnnotation(dict: dict, id: id, ref: ref),
      'FileAttachment' =>
        FileAttachmentAnnotation(dict: dict, id: id, ref: ref),
      _ => Annotation(dict: dict, id: id, annotationType: 0, ref: ref),
    };
  }

  static Future<Map<String, dynamic>> saveNewAnnotations(
      dynamic evaluator,
      dynamic xref,
      dynamic task,
      dynamic annotations,
      dynamic imagePromises,
      dynamic changes) async {
    final serialized = <Map<String, dynamic>>[];
    if (annotations is Iterable) {
      for (final value in annotations) {
        if (value is Annotation) serialized.add(value.toMap());
        if (value is Map<String, dynamic>) serialized.add(Map.of(value));
      }
    }
    return {'annotations': serialized};
  }
}
