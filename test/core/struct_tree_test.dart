// Copyright 2021 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'package:pdfjs/src/core/primitives.dart';
import 'package:pdfjs/src/core/struct_tree.dart';
import 'package:test/test.dart';

void main() {
  group('StructTreeRoot RoleMap', () {
    test('resolves custom role Alias0', () {
      final roleMap = Dict()..set('Alias0', Name.get('Role0'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias0'], 'Role0');
      expect(root.resolveRole('Alias0'), 'Role0');
      expect(root.resolveRole('Role0'), 'Role0');
    });

    test('resolves custom role Alias1', () {
      final roleMap = Dict()..set('Alias1', Name.get('Role1'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias1'], 'Role1');
      expect(root.resolveRole('Alias1'), 'Role1');
      expect(root.resolveRole('Role1'), 'Role1');
    });

    test('resolves custom role Alias2', () {
      final roleMap = Dict()..set('Alias2', Name.get('Role2'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias2'], 'Role2');
      expect(root.resolveRole('Alias2'), 'Role2');
      expect(root.resolveRole('Role2'), 'Role2');
    });

    test('resolves custom role Alias3', () {
      final roleMap = Dict()..set('Alias3', Name.get('Role3'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias3'], 'Role3');
      expect(root.resolveRole('Alias3'), 'Role3');
      expect(root.resolveRole('Role3'), 'Role3');
    });

    test('resolves custom role Alias4', () {
      final roleMap = Dict()..set('Alias4', Name.get('Role4'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias4'], 'Role4');
      expect(root.resolveRole('Alias4'), 'Role4');
      expect(root.resolveRole('Role4'), 'Role4');
    });

    test('resolves custom role Alias5', () {
      final roleMap = Dict()..set('Alias5', Name.get('Role5'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias5'], 'Role5');
      expect(root.resolveRole('Alias5'), 'Role5');
      expect(root.resolveRole('Role5'), 'Role5');
    });

    test('resolves custom role Alias6', () {
      final roleMap = Dict()..set('Alias6', Name.get('Role6'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias6'], 'Role6');
      expect(root.resolveRole('Alias6'), 'Role6');
      expect(root.resolveRole('Role6'), 'Role6');
    });

    test('resolves custom role Alias7', () {
      final roleMap = Dict()..set('Alias7', Name.get('Role7'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias7'], 'Role7');
      expect(root.resolveRole('Alias7'), 'Role7');
      expect(root.resolveRole('Role7'), 'Role7');
    });

    test('resolves custom role Alias8', () {
      final roleMap = Dict()..set('Alias8', Name.get('Role8'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias8'], 'Role8');
      expect(root.resolveRole('Alias8'), 'Role8');
      expect(root.resolveRole('Role8'), 'Role8');
    });

    test('resolves custom role Alias9', () {
      final roleMap = Dict()..set('Alias9', Name.get('Role9'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias9'], 'Role9');
      expect(root.resolveRole('Alias9'), 'Role9');
      expect(root.resolveRole('Role9'), 'Role9');
    });

    test('resolves custom role Alias10', () {
      final roleMap = Dict()..set('Alias10', Name.get('Role10'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias10'], 'Role10');
      expect(root.resolveRole('Alias10'), 'Role10');
      expect(root.resolveRole('Role10'), 'Role10');
    });

    test('resolves custom role Alias11', () {
      final roleMap = Dict()..set('Alias11', Name.get('Role11'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias11'], 'Role11');
      expect(root.resolveRole('Alias11'), 'Role11');
      expect(root.resolveRole('Role11'), 'Role11');
    });

    test('resolves custom role Alias12', () {
      final roleMap = Dict()..set('Alias12', Name.get('Role12'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias12'], 'Role12');
      expect(root.resolveRole('Alias12'), 'Role12');
      expect(root.resolveRole('Role12'), 'Role12');
    });

    test('resolves custom role Alias13', () {
      final roleMap = Dict()..set('Alias13', Name.get('Role13'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias13'], 'Role13');
      expect(root.resolveRole('Alias13'), 'Role13');
      expect(root.resolveRole('Role13'), 'Role13');
    });

    test('resolves custom role Alias14', () {
      final roleMap = Dict()..set('Alias14', Name.get('Role14'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias14'], 'Role14');
      expect(root.resolveRole('Alias14'), 'Role14');
      expect(root.resolveRole('Role14'), 'Role14');
    });

    test('resolves custom role Alias15', () {
      final roleMap = Dict()..set('Alias15', Name.get('Role15'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias15'], 'Role15');
      expect(root.resolveRole('Alias15'), 'Role15');
      expect(root.resolveRole('Role15'), 'Role15');
    });

    test('resolves custom role Alias16', () {
      final roleMap = Dict()..set('Alias16', Name.get('Role16'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias16'], 'Role16');
      expect(root.resolveRole('Alias16'), 'Role16');
      expect(root.resolveRole('Role16'), 'Role16');
    });

    test('resolves custom role Alias17', () {
      final roleMap = Dict()..set('Alias17', Name.get('Role17'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias17'], 'Role17');
      expect(root.resolveRole('Alias17'), 'Role17');
      expect(root.resolveRole('Role17'), 'Role17');
    });

    test('resolves custom role Alias18', () {
      final roleMap = Dict()..set('Alias18', Name.get('Role18'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias18'], 'Role18');
      expect(root.resolveRole('Alias18'), 'Role18');
      expect(root.resolveRole('Role18'), 'Role18');
    });

    test('resolves custom role Alias19', () {
      final roleMap = Dict()..set('Alias19', Name.get('Role19'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias19'], 'Role19');
      expect(root.resolveRole('Alias19'), 'Role19');
      expect(root.resolveRole('Role19'), 'Role19');
    });

    test('resolves custom role Alias20', () {
      final roleMap = Dict()..set('Alias20', Name.get('Role20'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias20'], 'Role20');
      expect(root.resolveRole('Alias20'), 'Role20');
      expect(root.resolveRole('Role20'), 'Role20');
    });

    test('resolves custom role Alias21', () {
      final roleMap = Dict()..set('Alias21', Name.get('Role21'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias21'], 'Role21');
      expect(root.resolveRole('Alias21'), 'Role21');
      expect(root.resolveRole('Role21'), 'Role21');
    });

    test('resolves custom role Alias22', () {
      final roleMap = Dict()..set('Alias22', Name.get('Role22'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias22'], 'Role22');
      expect(root.resolveRole('Alias22'), 'Role22');
      expect(root.resolveRole('Role22'), 'Role22');
    });

    test('resolves custom role Alias23', () {
      final roleMap = Dict()..set('Alias23', Name.get('Role23'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias23'], 'Role23');
      expect(root.resolveRole('Alias23'), 'Role23');
      expect(root.resolveRole('Role23'), 'Role23');
    });

    test('resolves custom role Alias24', () {
      final roleMap = Dict()..set('Alias24', Name.get('Role24'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias24'], 'Role24');
      expect(root.resolveRole('Alias24'), 'Role24');
      expect(root.resolveRole('Role24'), 'Role24');
    });

    test('resolves custom role Alias25', () {
      final roleMap = Dict()..set('Alias25', Name.get('Role25'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias25'], 'Role25');
      expect(root.resolveRole('Alias25'), 'Role25');
      expect(root.resolveRole('Role25'), 'Role25');
    });

    test('resolves custom role Alias26', () {
      final roleMap = Dict()..set('Alias26', Name.get('Role26'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias26'], 'Role26');
      expect(root.resolveRole('Alias26'), 'Role26');
      expect(root.resolveRole('Role26'), 'Role26');
    });

    test('resolves custom role Alias27', () {
      final roleMap = Dict()..set('Alias27', Name.get('Role27'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias27'], 'Role27');
      expect(root.resolveRole('Alias27'), 'Role27');
      expect(root.resolveRole('Role27'), 'Role27');
    });

    test('resolves custom role Alias28', () {
      final roleMap = Dict()..set('Alias28', Name.get('Role28'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias28'], 'Role28');
      expect(root.resolveRole('Alias28'), 'Role28');
      expect(root.resolveRole('Role28'), 'Role28');
    });

    test('resolves custom role Alias29', () {
      final roleMap = Dict()..set('Alias29', Name.get('Role29'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias29'], 'Role29');
      expect(root.resolveRole('Alias29'), 'Role29');
      expect(root.resolveRole('Role29'), 'Role29');
    });

    test('resolves custom role Alias30', () {
      final roleMap = Dict()..set('Alias30', Name.get('Role30'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias30'], 'Role30');
      expect(root.resolveRole('Alias30'), 'Role30');
      expect(root.resolveRole('Role30'), 'Role30');
    });

    test('resolves custom role Alias31', () {
      final roleMap = Dict()..set('Alias31', Name.get('Role31'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias31'], 'Role31');
      expect(root.resolveRole('Alias31'), 'Role31');
      expect(root.resolveRole('Role31'), 'Role31');
    });

    test('resolves custom role Alias32', () {
      final roleMap = Dict()..set('Alias32', Name.get('Role32'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias32'], 'Role32');
      expect(root.resolveRole('Alias32'), 'Role32');
      expect(root.resolveRole('Role32'), 'Role32');
    });

    test('resolves custom role Alias33', () {
      final roleMap = Dict()..set('Alias33', Name.get('Role33'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias33'], 'Role33');
      expect(root.resolveRole('Alias33'), 'Role33');
      expect(root.resolveRole('Role33'), 'Role33');
    });

    test('resolves custom role Alias34', () {
      final roleMap = Dict()..set('Alias34', Name.get('Role34'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias34'], 'Role34');
      expect(root.resolveRole('Alias34'), 'Role34');
      expect(root.resolveRole('Role34'), 'Role34');
    });

    test('resolves custom role Alias35', () {
      final roleMap = Dict()..set('Alias35', Name.get('Role35'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias35'], 'Role35');
      expect(root.resolveRole('Alias35'), 'Role35');
      expect(root.resolveRole('Role35'), 'Role35');
    });

    test('resolves custom role Alias36', () {
      final roleMap = Dict()..set('Alias36', Name.get('Role36'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias36'], 'Role36');
      expect(root.resolveRole('Alias36'), 'Role36');
      expect(root.resolveRole('Role36'), 'Role36');
    });

    test('resolves custom role Alias37', () {
      final roleMap = Dict()..set('Alias37', Name.get('Role37'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias37'], 'Role37');
      expect(root.resolveRole('Alias37'), 'Role37');
      expect(root.resolveRole('Role37'), 'Role37');
    });

    test('resolves custom role Alias38', () {
      final roleMap = Dict()..set('Alias38', Name.get('Role38'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias38'], 'Role38');
      expect(root.resolveRole('Alias38'), 'Role38');
      expect(root.resolveRole('Role38'), 'Role38');
    });

    test('resolves custom role Alias39', () {
      final roleMap = Dict()..set('Alias39', Name.get('Role39'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias39'], 'Role39');
      expect(root.resolveRole('Alias39'), 'Role39');
      expect(root.resolveRole('Role39'), 'Role39');
    });

    test('resolves custom role Alias40', () {
      final roleMap = Dict()..set('Alias40', Name.get('Role40'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias40'], 'Role40');
      expect(root.resolveRole('Alias40'), 'Role40');
      expect(root.resolveRole('Role40'), 'Role40');
    });

    test('resolves custom role Alias41', () {
      final roleMap = Dict()..set('Alias41', Name.get('Role41'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias41'], 'Role41');
      expect(root.resolveRole('Alias41'), 'Role41');
      expect(root.resolveRole('Role41'), 'Role41');
    });

    test('resolves custom role Alias42', () {
      final roleMap = Dict()..set('Alias42', Name.get('Role42'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias42'], 'Role42');
      expect(root.resolveRole('Alias42'), 'Role42');
      expect(root.resolveRole('Role42'), 'Role42');
    });

    test('resolves custom role Alias43', () {
      final roleMap = Dict()..set('Alias43', Name.get('Role43'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias43'], 'Role43');
      expect(root.resolveRole('Alias43'), 'Role43');
      expect(root.resolveRole('Role43'), 'Role43');
    });

    test('resolves custom role Alias44', () {
      final roleMap = Dict()..set('Alias44', Name.get('Role44'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias44'], 'Role44');
      expect(root.resolveRole('Alias44'), 'Role44');
      expect(root.resolveRole('Role44'), 'Role44');
    });

    test('resolves custom role Alias45', () {
      final roleMap = Dict()..set('Alias45', Name.get('Role45'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias45'], 'Role45');
      expect(root.resolveRole('Alias45'), 'Role45');
      expect(root.resolveRole('Role45'), 'Role45');
    });

    test('resolves custom role Alias46', () {
      final roleMap = Dict()..set('Alias46', Name.get('Role46'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias46'], 'Role46');
      expect(root.resolveRole('Alias46'), 'Role46');
      expect(root.resolveRole('Role46'), 'Role46');
    });

    test('resolves custom role Alias47', () {
      final roleMap = Dict()..set('Alias47', Name.get('Role47'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias47'], 'Role47');
      expect(root.resolveRole('Alias47'), 'Role47');
      expect(root.resolveRole('Role47'), 'Role47');
    });

    test('resolves custom role Alias48', () {
      final roleMap = Dict()..set('Alias48', Name.get('Role48'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias48'], 'Role48');
      expect(root.resolveRole('Alias48'), 'Role48');
      expect(root.resolveRole('Role48'), 'Role48');
    });

    test('resolves custom role Alias49', () {
      final roleMap = Dict()..set('Alias49', Name.get('Role49'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias49'], 'Role49');
      expect(root.resolveRole('Alias49'), 'Role49');
      expect(root.resolveRole('Role49'), 'Role49');
    });

    test('resolves custom role Alias50', () {
      final roleMap = Dict()..set('Alias50', Name.get('Role50'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias50'], 'Role50');
      expect(root.resolveRole('Alias50'), 'Role50');
      expect(root.resolveRole('Role50'), 'Role50');
    });

    test('resolves custom role Alias51', () {
      final roleMap = Dict()..set('Alias51', Name.get('Role51'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias51'], 'Role51');
      expect(root.resolveRole('Alias51'), 'Role51');
      expect(root.resolveRole('Role51'), 'Role51');
    });

    test('resolves custom role Alias52', () {
      final roleMap = Dict()..set('Alias52', Name.get('Role52'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias52'], 'Role52');
      expect(root.resolveRole('Alias52'), 'Role52');
      expect(root.resolveRole('Role52'), 'Role52');
    });

    test('resolves custom role Alias53', () {
      final roleMap = Dict()..set('Alias53', Name.get('Role53'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias53'], 'Role53');
      expect(root.resolveRole('Alias53'), 'Role53');
      expect(root.resolveRole('Role53'), 'Role53');
    });

    test('resolves custom role Alias54', () {
      final roleMap = Dict()..set('Alias54', Name.get('Role54'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias54'], 'Role54');
      expect(root.resolveRole('Alias54'), 'Role54');
      expect(root.resolveRole('Role54'), 'Role54');
    });

    test('resolves custom role Alias55', () {
      final roleMap = Dict()..set('Alias55', Name.get('Role55'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias55'], 'Role55');
      expect(root.resolveRole('Alias55'), 'Role55');
      expect(root.resolveRole('Role55'), 'Role55');
    });

    test('resolves custom role Alias56', () {
      final roleMap = Dict()..set('Alias56', Name.get('Role56'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias56'], 'Role56');
      expect(root.resolveRole('Alias56'), 'Role56');
      expect(root.resolveRole('Role56'), 'Role56');
    });

    test('resolves custom role Alias57', () {
      final roleMap = Dict()..set('Alias57', Name.get('Role57'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias57'], 'Role57');
      expect(root.resolveRole('Alias57'), 'Role57');
      expect(root.resolveRole('Role57'), 'Role57');
    });

    test('resolves custom role Alias58', () {
      final roleMap = Dict()..set('Alias58', Name.get('Role58'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias58'], 'Role58');
      expect(root.resolveRole('Alias58'), 'Role58');
      expect(root.resolveRole('Role58'), 'Role58');
    });

    test('resolves custom role Alias59', () {
      final roleMap = Dict()..set('Alias59', Name.get('Role59'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias59'], 'Role59');
      expect(root.resolveRole('Alias59'), 'Role59');
      expect(root.resolveRole('Role59'), 'Role59');
    });

    test('resolves custom role Alias60', () {
      final roleMap = Dict()..set('Alias60', Name.get('Role60'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias60'], 'Role60');
      expect(root.resolveRole('Alias60'), 'Role60');
      expect(root.resolveRole('Role60'), 'Role60');
    });

    test('resolves custom role Alias61', () {
      final roleMap = Dict()..set('Alias61', Name.get('Role61'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias61'], 'Role61');
      expect(root.resolveRole('Alias61'), 'Role61');
      expect(root.resolveRole('Role61'), 'Role61');
    });

    test('resolves custom role Alias62', () {
      final roleMap = Dict()..set('Alias62', Name.get('Role62'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias62'], 'Role62');
      expect(root.resolveRole('Alias62'), 'Role62');
      expect(root.resolveRole('Role62'), 'Role62');
    });

    test('resolves custom role Alias63', () {
      final roleMap = Dict()..set('Alias63', Name.get('Role63'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias63'], 'Role63');
      expect(root.resolveRole('Alias63'), 'Role63');
      expect(root.resolveRole('Role63'), 'Role63');
    });

    test('resolves custom role Alias64', () {
      final roleMap = Dict()..set('Alias64', Name.get('Role64'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias64'], 'Role64');
      expect(root.resolveRole('Alias64'), 'Role64');
      expect(root.resolveRole('Role64'), 'Role64');
    });

    test('resolves custom role Alias65', () {
      final roleMap = Dict()..set('Alias65', Name.get('Role65'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias65'], 'Role65');
      expect(root.resolveRole('Alias65'), 'Role65');
      expect(root.resolveRole('Role65'), 'Role65');
    });

    test('resolves custom role Alias66', () {
      final roleMap = Dict()..set('Alias66', Name.get('Role66'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias66'], 'Role66');
      expect(root.resolveRole('Alias66'), 'Role66');
      expect(root.resolveRole('Role66'), 'Role66');
    });

    test('resolves custom role Alias67', () {
      final roleMap = Dict()..set('Alias67', Name.get('Role67'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias67'], 'Role67');
      expect(root.resolveRole('Alias67'), 'Role67');
      expect(root.resolveRole('Role67'), 'Role67');
    });

    test('resolves custom role Alias68', () {
      final roleMap = Dict()..set('Alias68', Name.get('Role68'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias68'], 'Role68');
      expect(root.resolveRole('Alias68'), 'Role68');
      expect(root.resolveRole('Role68'), 'Role68');
    });

    test('resolves custom role Alias69', () {
      final roleMap = Dict()..set('Alias69', Name.get('Role69'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias69'], 'Role69');
      expect(root.resolveRole('Alias69'), 'Role69');
      expect(root.resolveRole('Role69'), 'Role69');
    });

    test('resolves custom role Alias70', () {
      final roleMap = Dict()..set('Alias70', Name.get('Role70'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias70'], 'Role70');
      expect(root.resolveRole('Alias70'), 'Role70');
      expect(root.resolveRole('Role70'), 'Role70');
    });

    test('resolves custom role Alias71', () {
      final roleMap = Dict()..set('Alias71', Name.get('Role71'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias71'], 'Role71');
      expect(root.resolveRole('Alias71'), 'Role71');
      expect(root.resolveRole('Role71'), 'Role71');
    });

    test('resolves custom role Alias72', () {
      final roleMap = Dict()..set('Alias72', Name.get('Role72'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias72'], 'Role72');
      expect(root.resolveRole('Alias72'), 'Role72');
      expect(root.resolveRole('Role72'), 'Role72');
    });

    test('resolves custom role Alias73', () {
      final roleMap = Dict()..set('Alias73', Name.get('Role73'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias73'], 'Role73');
      expect(root.resolveRole('Alias73'), 'Role73');
      expect(root.resolveRole('Role73'), 'Role73');
    });

    test('resolves custom role Alias74', () {
      final roleMap = Dict()..set('Alias74', Name.get('Role74'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias74'], 'Role74');
      expect(root.resolveRole('Alias74'), 'Role74');
      expect(root.resolveRole('Role74'), 'Role74');
    });

    test('resolves custom role Alias75', () {
      final roleMap = Dict()..set('Alias75', Name.get('Role75'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias75'], 'Role75');
      expect(root.resolveRole('Alias75'), 'Role75');
      expect(root.resolveRole('Role75'), 'Role75');
    });

    test('resolves custom role Alias76', () {
      final roleMap = Dict()..set('Alias76', Name.get('Role76'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias76'], 'Role76');
      expect(root.resolveRole('Alias76'), 'Role76');
      expect(root.resolveRole('Role76'), 'Role76');
    });

    test('resolves custom role Alias77', () {
      final roleMap = Dict()..set('Alias77', Name.get('Role77'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias77'], 'Role77');
      expect(root.resolveRole('Alias77'), 'Role77');
      expect(root.resolveRole('Role77'), 'Role77');
    });

    test('resolves custom role Alias78', () {
      final roleMap = Dict()..set('Alias78', Name.get('Role78'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias78'], 'Role78');
      expect(root.resolveRole('Alias78'), 'Role78');
      expect(root.resolveRole('Role78'), 'Role78');
    });

    test('resolves custom role Alias79', () {
      final roleMap = Dict()..set('Alias79', Name.get('Role79'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias79'], 'Role79');
      expect(root.resolveRole('Alias79'), 'Role79');
      expect(root.resolveRole('Role79'), 'Role79');
    });

    test('resolves custom role Alias80', () {
      final roleMap = Dict()..set('Alias80', Name.get('Role80'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias80'], 'Role80');
      expect(root.resolveRole('Alias80'), 'Role80');
      expect(root.resolveRole('Role80'), 'Role80');
    });

    test('resolves custom role Alias81', () {
      final roleMap = Dict()..set('Alias81', Name.get('Role81'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias81'], 'Role81');
      expect(root.resolveRole('Alias81'), 'Role81');
      expect(root.resolveRole('Role81'), 'Role81');
    });

    test('resolves custom role Alias82', () {
      final roleMap = Dict()..set('Alias82', Name.get('Role82'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias82'], 'Role82');
      expect(root.resolveRole('Alias82'), 'Role82');
      expect(root.resolveRole('Role82'), 'Role82');
    });

    test('resolves custom role Alias83', () {
      final roleMap = Dict()..set('Alias83', Name.get('Role83'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias83'], 'Role83');
      expect(root.resolveRole('Alias83'), 'Role83');
      expect(root.resolveRole('Role83'), 'Role83');
    });

    test('resolves custom role Alias84', () {
      final roleMap = Dict()..set('Alias84', Name.get('Role84'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias84'], 'Role84');
      expect(root.resolveRole('Alias84'), 'Role84');
      expect(root.resolveRole('Role84'), 'Role84');
    });

    test('resolves custom role Alias85', () {
      final roleMap = Dict()..set('Alias85', Name.get('Role85'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias85'], 'Role85');
      expect(root.resolveRole('Alias85'), 'Role85');
      expect(root.resolveRole('Role85'), 'Role85');
    });

    test('resolves custom role Alias86', () {
      final roleMap = Dict()..set('Alias86', Name.get('Role86'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias86'], 'Role86');
      expect(root.resolveRole('Alias86'), 'Role86');
      expect(root.resolveRole('Role86'), 'Role86');
    });

    test('resolves custom role Alias87', () {
      final roleMap = Dict()..set('Alias87', Name.get('Role87'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias87'], 'Role87');
      expect(root.resolveRole('Alias87'), 'Role87');
      expect(root.resolveRole('Role87'), 'Role87');
    });

    test('resolves custom role Alias88', () {
      final roleMap = Dict()..set('Alias88', Name.get('Role88'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias88'], 'Role88');
      expect(root.resolveRole('Alias88'), 'Role88');
      expect(root.resolveRole('Role88'), 'Role88');
    });

    test('resolves custom role Alias89', () {
      final roleMap = Dict()..set('Alias89', Name.get('Role89'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias89'], 'Role89');
      expect(root.resolveRole('Alias89'), 'Role89');
      expect(root.resolveRole('Role89'), 'Role89');
    });

    test('resolves custom role Alias90', () {
      final roleMap = Dict()..set('Alias90', Name.get('Role90'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias90'], 'Role90');
      expect(root.resolveRole('Alias90'), 'Role90');
      expect(root.resolveRole('Role90'), 'Role90');
    });

    test('resolves custom role Alias91', () {
      final roleMap = Dict()..set('Alias91', Name.get('Role91'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias91'], 'Role91');
      expect(root.resolveRole('Alias91'), 'Role91');
      expect(root.resolveRole('Role91'), 'Role91');
    });

    test('resolves custom role Alias92', () {
      final roleMap = Dict()..set('Alias92', Name.get('Role92'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias92'], 'Role92');
      expect(root.resolveRole('Alias92'), 'Role92');
      expect(root.resolveRole('Role92'), 'Role92');
    });

    test('resolves custom role Alias93', () {
      final roleMap = Dict()..set('Alias93', Name.get('Role93'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias93'], 'Role93');
      expect(root.resolveRole('Alias93'), 'Role93');
      expect(root.resolveRole('Role93'), 'Role93');
    });

    test('resolves custom role Alias94', () {
      final roleMap = Dict()..set('Alias94', Name.get('Role94'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias94'], 'Role94');
      expect(root.resolveRole('Alias94'), 'Role94');
      expect(root.resolveRole('Role94'), 'Role94');
    });

    test('resolves custom role Alias95', () {
      final roleMap = Dict()..set('Alias95', Name.get('Role95'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias95'], 'Role95');
      expect(root.resolveRole('Alias95'), 'Role95');
      expect(root.resolveRole('Role95'), 'Role95');
    });

    test('resolves custom role Alias96', () {
      final roleMap = Dict()..set('Alias96', Name.get('Role96'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias96'], 'Role96');
      expect(root.resolveRole('Alias96'), 'Role96');
      expect(root.resolveRole('Role96'), 'Role96');
    });

    test('resolves custom role Alias97', () {
      final roleMap = Dict()..set('Alias97', Name.get('Role97'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias97'], 'Role97');
      expect(root.resolveRole('Alias97'), 'Role97');
      expect(root.resolveRole('Role97'), 'Role97');
    });

    test('resolves custom role Alias98', () {
      final roleMap = Dict()..set('Alias98', Name.get('Role98'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias98'], 'Role98');
      expect(root.resolveRole('Alias98'), 'Role98');
      expect(root.resolveRole('Role98'), 'Role98');
    });

    test('resolves custom role Alias99', () {
      final roleMap = Dict()..set('Alias99', Name.get('Role99'));
      final rootDict = Dict()..set('RoleMap', roleMap);
      final root = StructTreeRoot(null, rootDict, null)..init();
      expect(root.roleMap['Alias99'], 'Role99');
      expect(root.resolveRole('Alias99'), 'Role99');
      expect(root.resolveRole('Role99'), 'Role99');
    });

    test('resolves transitive aliases', () {
      final map = Dict()
        ..set('CustomHeading', Name.get('Intermediate'))
        ..set('Intermediate', Name.get('H1'));
      final root = StructTreeRoot(null, Dict()..set('RoleMap', map), null)
        ..init();
      expect(root.resolveRole('CustomHeading'), 'H1');
    });

    test('stops safely on cyclic aliases', () {
      final map = Dict()
        ..set('A', Name.get('B'))
        ..set('B', Name.get('A'));
      final root = StructTreeRoot(null, Dict()..set('RoleMap', map), null)
        ..init();
      expect({'A', 'B'}, contains(root.resolveRole('A')));
    });

    test('ignores malformed role map entries', () {
      final map = Dict()
        ..set('number', 42)
        ..set('string', 'P')
        ..set('valid', Name.get('P'));
      final root = StructTreeRoot(null, Dict()..set('RoleMap', map), null)
        ..init();
      expect(root.roleMap, {'valid': 'P'});
    });

    test('handles a missing role map', () {
      final root = StructTreeRoot(null, Dict(), null)..init();
      expect(root.roleMap, isEmpty);
      expect(root.resolveRole('Document'), 'Document');
    });
  });

  group('StructTreeRoot kid positions', () {
    test('finds kid reference at position 0', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[0]), 0);
      expect(root.getKidPosition(refs[0]), 0);
    });

    test('finds kid reference at position 1', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[1]), 1);
      expect(root.getKidPosition(refs[1]), 1);
    });

    test('finds kid reference at position 2', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[2]), 2);
      expect(root.getKidPosition(refs[2]), 2);
    });

    test('finds kid reference at position 3', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[3]), 3);
      expect(root.getKidPosition(refs[3]), 3);
    });

    test('finds kid reference at position 4', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[4]), 4);
      expect(root.getKidPosition(refs[4]), 4);
    });

    test('finds kid reference at position 5', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[5]), 5);
      expect(root.getKidPosition(refs[5]), 5);
    });

    test('finds kid reference at position 6', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[6]), 6);
      expect(root.getKidPosition(refs[6]), 6);
    });

    test('finds kid reference at position 7', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[7]), 7);
      expect(root.getKidPosition(refs[7]), 7);
    });

    test('finds kid reference at position 8', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[8]), 8);
      expect(root.getKidPosition(refs[8]), 8);
    });

    test('finds kid reference at position 9', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[9]), 9);
      expect(root.getKidPosition(refs[9]), 9);
    });

    test('finds kid reference at position 10', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[10]), 10);
      expect(root.getKidPosition(refs[10]), 10);
    });

    test('finds kid reference at position 11', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[11]), 11);
      expect(root.getKidPosition(refs[11]), 11);
    });

    test('finds kid reference at position 12', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[12]), 12);
      expect(root.getKidPosition(refs[12]), 12);
    });

    test('finds kid reference at position 13', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[13]), 13);
      expect(root.getKidPosition(refs[13]), 13);
    });

    test('finds kid reference at position 14', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[14]), 14);
      expect(root.getKidPosition(refs[14]), 14);
    });

    test('finds kid reference at position 15', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[15]), 15);
      expect(root.getKidPosition(refs[15]), 15);
    });

    test('finds kid reference at position 16', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[16]), 16);
      expect(root.getKidPosition(refs[16]), 16);
    });

    test('finds kid reference at position 17', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[17]), 17);
      expect(root.getKidPosition(refs[17]), 17);
    });

    test('finds kid reference at position 18', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[18]), 18);
      expect(root.getKidPosition(refs[18]), 18);
    });

    test('finds kid reference at position 19', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[19]), 19);
      expect(root.getKidPosition(refs[19]), 19);
    });

    test('finds kid reference at position 20', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[20]), 20);
      expect(root.getKidPosition(refs[20]), 20);
    });

    test('finds kid reference at position 21', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[21]), 21);
      expect(root.getKidPosition(refs[21]), 21);
    });

    test('finds kid reference at position 22', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[22]), 22);
      expect(root.getKidPosition(refs[22]), 22);
    });

    test('finds kid reference at position 23', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[23]), 23);
      expect(root.getKidPosition(refs[23]), 23);
    });

    test('finds kid reference at position 24', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[24]), 24);
      expect(root.getKidPosition(refs[24]), 24);
    });

    test('finds kid reference at position 25', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[25]), 25);
      expect(root.getKidPosition(refs[25]), 25);
    });

    test('finds kid reference at position 26', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[26]), 26);
      expect(root.getKidPosition(refs[26]), 26);
    });

    test('finds kid reference at position 27', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[27]), 27);
      expect(root.getKidPosition(refs[27]), 27);
    });

    test('finds kid reference at position 28', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[28]), 28);
      expect(root.getKidPosition(refs[28]), 28);
    });

    test('finds kid reference at position 29', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[29]), 29);
      expect(root.getKidPosition(refs[29]), 29);
    });

    test('finds kid reference at position 30', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[30]), 30);
      expect(root.getKidPosition(refs[30]), 30);
    });

    test('finds kid reference at position 31', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[31]), 31);
      expect(root.getKidPosition(refs[31]), 31);
    });

    test('finds kid reference at position 32', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[32]), 32);
      expect(root.getKidPosition(refs[32]), 32);
    });

    test('finds kid reference at position 33', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[33]), 33);
      expect(root.getKidPosition(refs[33]), 33);
    });

    test('finds kid reference at position 34', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[34]), 34);
      expect(root.getKidPosition(refs[34]), 34);
    });

    test('finds kid reference at position 35', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[35]), 35);
      expect(root.getKidPosition(refs[35]), 35);
    });

    test('finds kid reference at position 36', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[36]), 36);
      expect(root.getKidPosition(refs[36]), 36);
    });

    test('finds kid reference at position 37', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[37]), 37);
      expect(root.getKidPosition(refs[37]), 37);
    });

    test('finds kid reference at position 38', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[38]), 38);
      expect(root.getKidPosition(refs[38]), 38);
    });

    test('finds kid reference at position 39', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[39]), 39);
      expect(root.getKidPosition(refs[39]), 39);
    });

    test('finds kid reference at position 40', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[40]), 40);
      expect(root.getKidPosition(refs[40]), 40);
    });

    test('finds kid reference at position 41', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[41]), 41);
      expect(root.getKidPosition(refs[41]), 41);
    });

    test('finds kid reference at position 42', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[42]), 42);
      expect(root.getKidPosition(refs[42]), 42);
    });

    test('finds kid reference at position 43', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[43]), 43);
      expect(root.getKidPosition(refs[43]), 43);
    });

    test('finds kid reference at position 44', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[44]), 44);
      expect(root.getKidPosition(refs[44]), 44);
    });

    test('finds kid reference at position 45', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[45]), 45);
      expect(root.getKidPosition(refs[45]), 45);
    });

    test('finds kid reference at position 46', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[46]), 46);
      expect(root.getKidPosition(refs[46]), 46);
    });

    test('finds kid reference at position 47', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[47]), 47);
      expect(root.getKidPosition(refs[47]), 47);
    });

    test('finds kid reference at position 48', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[48]), 48);
      expect(root.getKidPosition(refs[48]), 48);
    });

    test('finds kid reference at position 49', () {
      final refs = [for (var n = 0; n < 50; n++) Ref.get(n + 1, 0)];
      final root = StructTreeRoot(null, Dict()..set('K', refs), null);
      expect(root.getKidPosition(refs[49]), 49);
      expect(root.getKidPosition(refs[49]), 49);
    });

    test('returns a missing position for unknown references', () {
      final root =
          StructTreeRoot(null, Dict()..set('K', [Ref.get(1, 0)]), null);
      expect(root.getKidPosition(Ref.get(2, 0)), isNot(0));
    });

    test('indexes a single dictionary by object id', () {
      final kid = Dict()..objId = '15R';
      final root = StructTreeRoot(null, Dict()..set('K', kid), null);
      expect(root.getKidPosition('15R'), 0);
    });

    test('handles an empty kids entry', () {
      final root = StructTreeRoot(null, Dict(), null);
      expect(root.getKidPosition(Ref.get(1, 0)), isNot(0));
    });

    test('keeps the first index snapshot stable', () {
      final first = Ref.get(1, 0);
      final second = Ref.get(2, 0);
      final kids = [first];
      final root = StructTreeRoot(null, Dict()..set('K', kids), null);
      expect(root.getKidPosition(first), 0);
      kids.add(second);
      expect(root.getKidPosition(second), isNot(1));
    });
  });

  group('structure element constants', () {
    test('defines distinct content kinds', () {
      final values = {
        StructElementType.pageContent,
        StructElementType.streamContent,
        StructElementType.object,
        StructElementType.annotation,
        StructElementType.element,
      };
      expect(values, hasLength(5));
    });

    test('keeps annotation and element kinds stable', () {
      expect(StructElementType.annotation, 4);
      expect(StructElementType.element, 5);
    });
  });
}
