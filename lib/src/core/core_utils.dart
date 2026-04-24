// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

class MissingDataException implements Exception {
  final int begin;
  final int end;
  MissingDataException(this.begin, this.end);
  @override
  String toString() => 'MissingDataException: from $begin to $end';
}

bool isWhiteSpace(int ch) {
  return ch == 0x20 || ch == 0x09 || ch == 0x0D || ch == 0x0A;
}

bool isSpace(int ch) {
  return ch == 0x20 || ch == 0x09 || ch == 0x0D || ch == 0x0A;
}

class ParserEOFException implements Exception {
  final String message;
  ParserEOFException(this.message);
  @override
  String toString() => 'ParserEOFException: $message';
}

class XRefParseException implements Exception {
  final String message;
  XRefParseException([this.message = '']);
  @override
  String toString() => 'XRefParseException: $message';
}

class XRefEntryException implements Exception {
  final String message;
  XRefEntryException([this.message = '']);
  @override
  String toString() => 'XRefEntryException: $message';
}
