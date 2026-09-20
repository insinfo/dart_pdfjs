// Copyright 2021 Mozilla Foundation
//
// Licensed under the Apache License, Version 2.0.

/// Keys used internally by XFA objects.
///
/// JavaScript uses freshly-created `Symbol` values for these keys. Dart
/// symbols are named and canonical, so each key is given its variable name to
/// retain the important property here: keys from this list never collide with
/// one another or with ordinary string properties.
const Symbol $acceptWhitespace = Symbol(r'$acceptWhitespace');
const Symbol $addHTML = Symbol(r'$addHTML');
const Symbol $appendChild = Symbol(r'$appendChild');
const Symbol $childrenToHTML = Symbol(r'$childrenToHTML');
const Symbol $clean = Symbol(r'$clean');
const Symbol $cleanPage = Symbol(r'$cleanPage');
const Symbol $cleanup = Symbol(r'$cleanup');
const Symbol $clone = Symbol(r'$clone');
const Symbol $consumed = Symbol(r'$consumed');
const Symbol $content = Symbol('content');
const Symbol $data = Symbol('data');
const Symbol $dump = Symbol(r'$dump');
const Symbol $extra = Symbol('extra');
const Symbol $finalize = Symbol(r'$finalize');
const Symbol $flushHTML = Symbol(r'$flushHTML');
const Symbol $getAttributeIt = Symbol(r'$getAttributeIt');
const Symbol $getAttributes = Symbol(r'$getAttributes');
const Symbol $getAvailableSpace = Symbol(r'$getAvailableSpace');
const Symbol $getChildren = Symbol(r'$getChildren');
const Symbol $getChildrenByClass = Symbol(r'$getChildrenByClass');
const Symbol $getChildrenByName = Symbol(r'$getChildrenByName');
const Symbol $getChildrenByNameIt = Symbol(r'$getChildrenByNameIt');
const Symbol $getContainedChildren = Symbol(r'$getContainedChildren');
const Symbol $getDataValue = Symbol(r'$getDataValue');
const Symbol $getExtra = Symbol(r'$getExtra');
const Symbol $getNextPage = Symbol(r'$getNextPage');
const Symbol $getParent = Symbol(r'$getParent');
const Symbol $getRealChildrenByNameIt = Symbol(r'$getRealChildrenByNameIt');
const Symbol $getSubformParent = Symbol(r'$getSubformParent');
const Symbol $getTemplateRoot = Symbol(r'$getTemplateRoot');
const Symbol $globalData = Symbol(r'$globalData');
const Symbol $hasSettableValue = Symbol(r'$hasSettableValue');
const Symbol $ids = Symbol(r'$ids');
const Symbol $indexOf = Symbol(r'$indexOf');
const Symbol $insertAt = Symbol(r'$insertAt');
const Symbol $isBindable = Symbol(r'$isBindable');
const Symbol $isCDATAXml = Symbol(r'$isCDATAXml');
const Symbol $isDataValue = Symbol(r'$isDataValue');
const Symbol $isDescendent = Symbol(r'$isDescendent');
const Symbol $isNsAgnostic = Symbol(r'$isNsAgnostic');
const Symbol $isSplittable = Symbol(r'$isSplittable');
const Symbol $isThereMoreWidth = Symbol(r'$isThereMoreWidth');
const Symbol $isTransparent = Symbol(r'$isTransparent');
const Symbol $isUsable = Symbol(r'$isUsable');
const Symbol $lastAttribute = Symbol(r'$lastAttribute');
const Symbol $namespaceId = Symbol('namespaceId');
const Symbol $nodeName = Symbol('nodeName');
const Symbol $nsAttributes = Symbol(r'$nsAttributes');
const Symbol $onChild = Symbol(r'$onChild');
const Symbol $onChildCheck = Symbol(r'$onChildCheck');
const Symbol $onText = Symbol(r'$onText');
const Symbol $popPara = Symbol(r'$popPara');
const Symbol $pushGlyphs = Symbol(r'$pushGlyphs');
const Symbol $pushPara = Symbol(r'$pushPara');
const Symbol $removeChild = Symbol(r'$removeChild');
const Symbol $resolvePrototypes = Symbol(r'$resolvePrototypes');
const Symbol $root = Symbol('root');
const Symbol $searchNode = Symbol(r'$searchNode');
const Symbol $setId = Symbol(r'$setId');
const Symbol $setSetAttributes = Symbol(r'$setSetAttributes');
const Symbol $setValue = Symbol(r'$setValue');
const Symbol $tabIndex = Symbol(r'$tabIndex');
const Symbol $text = Symbol(r'$text');
const Symbol $toHTML = Symbol(r'$toHTML');
const Symbol $toPages = Symbol(r'$toPages');
const Symbol $toString = Symbol(r'$toString');
const Symbol $toStyle = Symbol(r'$toStyle');
const Symbol $uid = Symbol('uid');
