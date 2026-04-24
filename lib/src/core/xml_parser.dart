// Copyright 2018 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'core_utils.dart';

class XMLParserErrorCode {
  static const int noError = 0;
  static const int endOfDocument = -1;
  static const int unterminatedCdat = -2;
  static const int unterminatedXmlDeclaration = -3;
  static const int unterminatedDoctypeDeclaration = -4;
  static const int unterminatedComment = -5;
  static const int malformedElement = -6;
  static const int outOfMemory = -7;
  static const int unterminatedAttributeValue = -8;
  static const int unterminatedElement = -9;
  static const int elementNeverBegun = -10;
}

class XMLAttribute {
  const XMLAttribute({
    required this.name,
    required this.value,
  });

  final String name;
  final String value;
}

class ParsedXMLContent {
  const ParsedXMLContent({
    required this.name,
    required this.attributes,
    required this.parsed,
  });

  final String name;
  final List<XMLAttribute> attributes;
  final int parsed;
}

class ParsedXMLProcessingInstruction {
  const ParsedXMLProcessingInstruction({
    required this.name,
    required this.value,
    required this.parsed,
  });

  final String name;
  final String value;
  final int parsed;
}

bool isXmlWhitespace(String s, int index) {
  final ch = s.codeUnitAt(index);
  return ch == 0x20 || ch == 0x0a || ch == 0x0d || ch == 0x09;
}

bool isXmlWhitespaceString(String s) {
  for (var i = 0; i < s.length; i++) {
    if (!isXmlWhitespace(s, i)) {
      return false;
    }
  }
  return true;
}

class XMLParserBase {
  String _resolveEntities(String s) {
    return s.replaceAllMapped(RegExp(r'&([^;]+);'), (match) {
      final entity = match.group(1)!;
      if (entity.startsWith('#x')) {
        return String.fromCharCode(int.parse(entity.substring(2), radix: 16));
      }
      if (entity.startsWith('#')) {
        return String.fromCharCode(int.parse(entity.substring(1)));
      }
      switch (entity) {
        case 'lt':
          return '<';
        case 'gt':
          return '>';
        case 'amp':
          return '&';
        case 'quot':
          return '"';
        case 'apos':
          return "'";
      }
      return onResolveEntity(entity);
    });
  }

  ParsedXMLContent? _parseContent(String s, int start) {
    var pos = start;

    void skipWs() {
      while (pos < s.length && isXmlWhitespace(s, pos)) {
        pos++;
      }
    }

    while (pos < s.length &&
        !isXmlWhitespace(s, pos) &&
        s[pos] != '>' &&
        s[pos] != '/') {
      pos++;
    }
    final name = s.substring(start, pos);
    final attributes = <XMLAttribute>[];
    skipWs();
    while (pos < s.length && s[pos] != '>' && s[pos] != '/' && s[pos] != '?') {
      skipWs();
      var attrName = '';
      while (pos < s.length && !isXmlWhitespace(s, pos) && s[pos] != '=') {
        attrName += s[pos++];
      }
      skipWs();
      if (pos >= s.length || s[pos] != '=') {
        return null;
      }
      pos++;
      skipWs();
      if (pos >= s.length) {
        return null;
      }
      final attrEndChar = s[pos];
      if (attrEndChar != '"' && attrEndChar != "'") {
        return null;
      }
      final attrEndIndex = s.indexOf(attrEndChar, pos + 1);
      if (attrEndIndex < 0) {
        return null;
      }
      final attrValue = s.substring(pos + 1, attrEndIndex);
      attributes.add(XMLAttribute(
        name: attrName,
        value: _resolveEntities(attrValue),
      ));
      pos = attrEndIndex + 1;
      skipWs();
    }
    return ParsedXMLContent(
      name: name,
      attributes: attributes,
      parsed: pos - start,
    );
  }

  ParsedXMLProcessingInstruction _parseProcessingInstruction(
      String s, int start) {
    var pos = start;

    void skipWs() {
      while (pos < s.length && isXmlWhitespace(s, pos)) {
        pos++;
      }
    }

    while (pos < s.length &&
        !isXmlWhitespace(s, pos) &&
        s[pos] != '>' &&
        s[pos] != '?' &&
        s[pos] != '/') {
      pos++;
    }
    final name = s.substring(start, pos);
    skipWs();
    final attrStart = pos;
    while (pos < s.length && (s[pos] != '?' || s[pos + 1] != '>')) {
      pos++;
    }
    return ParsedXMLProcessingInstruction(
      name: name,
      value: s.substring(attrStart, pos),
      parsed: pos - start,
    );
  }

  void parseXml(String s) {
    var i = 0;
    while (i < s.length) {
      final ch = s[i];
      var j = i;
      if (ch == '<') {
        j++;
        final ch2 = s[j];
        int q;
        switch (ch2) {
          case '/':
            j++;
            q = s.indexOf('>', j);
            if (q < 0) {
              onError(XMLParserErrorCode.unterminatedElement);
              return;
            }
            onEndElement(s.substring(j, q));
            j = q + 1;
            break;
          case '?':
            j++;
            final pi = _parseProcessingInstruction(s, j);
            if (s.substring(j + pi.parsed, j + pi.parsed + 2) != '?>') {
              onError(XMLParserErrorCode.unterminatedXmlDeclaration);
              return;
            }
            onPi(pi.name, pi.value);
            j += pi.parsed + 2;
            break;
          case '!':
            if (s.substring(j + 1, j + 3) == '--') {
              q = s.indexOf('-->', j + 3);
              if (q < 0) {
                onError(XMLParserErrorCode.unterminatedComment);
                return;
              }
              onComment(s.substring(j + 3, q));
              j = q + 3;
            } else if (s.substring(j + 1, j + 8) == '[CDATA[') {
              q = s.indexOf(']]>', j + 8);
              if (q < 0) {
                onError(XMLParserErrorCode.unterminatedCdat);
                return;
              }
              onCdata(s.substring(j + 8, q));
              j = q + 3;
            } else if (s.substring(j + 1, j + 8) == 'DOCTYPE') {
              final q2 = s.indexOf('[', j + 8);
              var complexDoctype = false;
              q = s.indexOf('>', j + 8);
              if (q < 0) {
                onError(XMLParserErrorCode.unterminatedDoctypeDeclaration);
                return;
              }
              if (q2 > 0 && q > q2) {
                q = s.indexOf(']>', j + 8);
                if (q < 0) {
                  onError(XMLParserErrorCode.unterminatedDoctypeDeclaration);
                  return;
                }
                complexDoctype = true;
              }
              onDoctype(s.substring(j + 8, q + (complexDoctype ? 1 : 0)));
              j = q + (complexDoctype ? 2 : 1);
            } else {
              onError(XMLParserErrorCode.malformedElement);
              return;
            }
            break;
          default:
            final content = _parseContent(s, j);
            if (content == null) {
              onError(XMLParserErrorCode.malformedElement);
              return;
            }
            var isClosed = false;
            if (s.substring(j + content.parsed, j + content.parsed + 2) ==
                '/>') {
              isClosed = true;
            } else if (s.substring(
                    j + content.parsed, j + content.parsed + 1) !=
                '>') {
              onError(XMLParserErrorCode.unterminatedElement);
              return;
            }
            onBeginElement(content.name, content.attributes, isClosed);
            j += content.parsed + (isClosed ? 2 : 1);
            break;
        }
      } else {
        while (j < s.length && s[j] != '<') {
          j++;
        }
        onText(_resolveEntities(s.substring(i, j)));
      }
      i = j;
    }
  }

  String onResolveEntity(String name) => '&$name;';
  void onPi(String name, String value) {}
  void onComment(String text) {}
  void onCdata(String text) {}
  void onDoctype(String doctypeContent) {}
  void onText(String text) {}
  void onBeginElement(
      String name, List<XMLAttribute> attributes, bool isEmpty) {}
  void onEndElement(String name) {}
  void onError(int code) {}
}

class SimpleDOMNode {
  SimpleDOMNode(this.nodeName, [this.nodeValue]);

  final String nodeName;
  final String? nodeValue;
  SimpleDOMNode? parentNode;
  List<SimpleDOMNode>? childNodes;
  List<XMLAttribute>? attributes;

  SimpleDOMNode? get firstChild =>
      childNodes == null || childNodes!.isEmpty ? null : childNodes!.first;

  SimpleDOMNode? get nextSibling {
    final siblings = parentNode?.childNodes;
    if (siblings == null) {
      return null;
    }
    final index = siblings.indexOf(this);
    if (index == -1 || index + 1 >= siblings.length) {
      return null;
    }
    return siblings[index + 1];
  }

  String get textContent {
    final children = childNodes;
    if (children == null) {
      return nodeValue ?? '';
    }
    return children.map((child) => child.textContent).join('');
  }

  List<SimpleDOMNode> get children => childNodes ?? const <SimpleDOMNode>[];

  bool hasChildNodes() => childNodes?.isNotEmpty ?? false;

  SimpleDOMNode? searchNode(List<dynamic> paths, int pos) {
    if (pos >= paths.length) {
      return this;
    }

    final component = paths[pos];
    final name = _componentName(component);
    final componentPos = _componentPos(component);
    if (name.startsWith('#') && pos < paths.length - 1) {
      return searchNode(paths, pos + 1);
    }

    final stack = <({SimpleDOMNode parent, int currentPos})>[];
    var node = this;
    while (true) {
      if (name == node.nodeName) {
        if (componentPos == 0) {
          final result = node.searchNode(paths, pos + 1);
          if (result != null) {
            return result;
          }
        } else if (stack.isEmpty) {
          return null;
        } else {
          final parent = stack.removeLast().parent;
          var siblingPos = 0;
          for (final child in parent.childNodes ?? const <SimpleDOMNode>[]) {
            if (name == child.nodeName) {
              if (siblingPos == componentPos) {
                return child.searchNode(paths, pos + 1);
              }
              siblingPos++;
            }
          }
          return node.searchNode(paths, pos + 1);
        }
      }

      final children = node.childNodes;
      if (children != null && children.isNotEmpty) {
        stack.add((parent: node, currentPos: 0));
        node = children.first;
      } else if (stack.isEmpty) {
        return null;
      } else {
        while (stack.isNotEmpty) {
          final entry = stack.removeLast();
          final newPos = entry.currentPos + 1;
          final siblings = entry.parent.childNodes!;
          if (newPos < siblings.length) {
            stack.add((parent: entry.parent, currentPos: newPos));
            node = siblings[newPos];
            break;
          }
        }
        if (stack.isEmpty) {
          return null;
        }
      }
    }
  }

  void dump(List<String> buffer) {
    if (nodeName == '#text') {
      buffer.add(encodeToXmlString(nodeValue ?? ''));
      return;
    }

    buffer.add('<$nodeName');
    final attrs = attributes;
    if (attrs != null) {
      for (final attribute in attrs) {
        buffer.add(
          ' ${attribute.name}="${encodeToXmlString(attribute.value)}"',
        );
      }
    }
    if (hasChildNodes()) {
      buffer.add('>');
      for (final child in childNodes!) {
        child.dump(buffer);
      }
      buffer.add('</$nodeName>');
    } else if (nodeValue != null && nodeValue!.isNotEmpty) {
      buffer.add('>${encodeToXmlString(nodeValue!)}</$nodeName>');
    } else {
      buffer.add('/>');
    }
  }
}

class SimpleXMLDocument {
  const SimpleXMLDocument(this.documentElement);

  final SimpleDOMNode documentElement;
}

class SimpleXMLParser extends XMLParserBase {
  SimpleXMLParser({
    bool hasAttributes = false,
    bool lowerCaseName = false,
  })  : _hasAttributes = hasAttributes,
        _lowerCaseName = lowerCaseName;

  List<SimpleDOMNode> _currentFragment = <SimpleDOMNode>[];
  List<List<SimpleDOMNode>> _stack = <List<SimpleDOMNode>>[];
  int _errorCode = XMLParserErrorCode.noError;
  final bool _hasAttributes;
  final bool _lowerCaseName;

  SimpleXMLDocument? parseFromString(String data) {
    _currentFragment = <SimpleDOMNode>[];
    _stack = <List<SimpleDOMNode>>[];
    _errorCode = XMLParserErrorCode.noError;

    parseXml(data);
    if (_errorCode != XMLParserErrorCode.noError) {
      return null;
    }

    if (_currentFragment.isEmpty) {
      return null;
    }
    return SimpleXMLDocument(_currentFragment.first);
  }

  @override
  void onText(String text) {
    if (isXmlWhitespaceString(text)) {
      return;
    }
    _currentFragment.add(SimpleDOMNode('#text', text));
  }

  @override
  void onCdata(String text) {
    _currentFragment.add(SimpleDOMNode('#text', text));
  }

  @override
  void onBeginElement(
      String name, List<XMLAttribute> attributes, bool isEmpty) {
    var nodeName = name;
    if (_lowerCaseName) {
      nodeName = nodeName.toLowerCase();
    }
    final node = SimpleDOMNode(nodeName)..childNodes = <SimpleDOMNode>[];
    if (_hasAttributes) {
      node.attributes = attributes;
    }
    _currentFragment.add(node);
    if (isEmpty) {
      return;
    }
    _stack.add(_currentFragment);
    _currentFragment = node.childNodes!;
  }

  @override
  void onEndElement(String name) {
    _currentFragment = _stack.isNotEmpty ? _stack.removeLast() : [];
    if (_currentFragment.isEmpty) {
      return;
    }
    final lastElement = _currentFragment.last;
    for (final childNode in lastElement.childNodes ?? const <SimpleDOMNode>[]) {
      childNode.parentNode = lastElement;
    }
  }

  @override
  void onError(int code) {
    _errorCode = code;
  }
}

String _componentName(dynamic component) {
  if (component is Map) {
    return component['name'] as String;
  }
  return component.name as String;
}

int _componentPos(dynamic component) {
  if (component is Map) {
    return component['pos'] as int;
  }
  return component.pos as int;
}
