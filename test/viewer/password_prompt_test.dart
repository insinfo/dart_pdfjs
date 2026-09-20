@TestOn('browser')
library;

import 'dart:async';

import 'package:pdfjs/src/shared/util.dart' show PasswordResponses;
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import '../../example/src/overlay_manager.dart';
import '../../example/src/password_prompt.dart';

void main() {
  late web.HTMLDialogElement dialog;
  late web.HTMLParagraphElement label;
  late web.HTMLInputElement input;
  late web.HTMLButtonElement submit;
  late web.HTMLButtonElement cancel;
  late OverlayManager manager;
  late PasswordPrompt prompt;

  setUp(() {
    dialog = web.document.createElement('dialog') as web.HTMLDialogElement;
    label = web.document.createElement('p') as web.HTMLParagraphElement;
    input = web.document.createElement('input') as web.HTMLInputElement;
    submit = web.document.createElement('button') as web.HTMLButtonElement;
    cancel = web.document.createElement('button') as web.HTMLButtonElement;
    dialog
      ..append(label)
      ..append(input)
      ..append(submit)
      ..append(cancel);
    web.document.body!.append(dialog);
    manager = OverlayManager();
  });

  tearDown(() async {
    if (dialog.open) dialog.close();
    await manager.dispose();
    dialog.remove();
  });

  PasswordPrompt create({bool embedded = false}) => PasswordPrompt(
        dialog: dialog,
        label: label,
        input: input,
        submitButton: submit,
        cancelButton: cancel,
        overlayManager: manager,
        isViewerEmbedded: embedded,
      );

  test('opens with normal label and focuses input', () async {
    prompt = create();
    await prompt.setUpdateCallback((_) {}, PasswordResponses.needPassword);
    await prompt.open();
    expect(dialog.open, isTrue);
    expect(label.getAttribute('data-l10n-id'), 'pdfjs-password-label');
    expect(web.document.activeElement, input);
  });

  test('shows invalid label for an incorrect password', () async {
    prompt = create(embedded: true);
    await prompt.setUpdateCallback((_) {}, PasswordResponses.incorrectPassword);
    await prompt.open();
    expect(label.getAttribute('data-l10n-id'), 'pdfjs-password-invalid');
    expect(web.document.activeElement, input);
  });

  test('embedded initial prompt does not steal focus', () async {
    final outside =
        web.document.createElement('button') as web.HTMLButtonElement;
    web.document.body!.append(outside);
    outside.focus();
    prompt = create(embedded: true);
    await prompt.setUpdateCallback((_) {}, PasswordResponses.needPassword);
    await prompt.open();
    expect(web.document.activeElement, outside);
    outside.remove();
  });

  test('submit returns password, clears input, and closes', () async {
    final values = <Object>[];
    prompt = create();
    await prompt.setUpdateCallback(values.add, PasswordResponses.needPassword);
    await prompt.open();
    input.value = 'secret';
    submit.click();
    await Future<void>.delayed(Duration.zero);
    expect(values, ['secret']);
    expect(input.value, isEmpty);
    expect(dialog.open, isFalse);
  });

  test('Enter submits while an empty password does nothing', () async {
    final values = <Object>[];
    prompt = create();
    await prompt.setUpdateCallback(values.add, PasswordResponses.needPassword);
    await prompt.open();
    input.dispatchEvent(
        web.KeyboardEvent('keydown', web.KeyboardEventInit(keyCode: 13)));
    expect(values, isEmpty);
    input.value = 'typed';
    input.dispatchEvent(
        web.KeyboardEvent('keydown', web.KeyboardEventInit(keyCode: 13)));
    expect(values, ['typed']);
  });

  test('cancel reports an error exactly once', () async {
    final values = <Object>[];
    prompt = create();
    await prompt.setUpdateCallback(values.add, PasswordResponses.needPassword);
    await prompt.open();
    cancel.click();
    await Future<void>.delayed(Duration.zero);
    expect(values, hasLength(1));
    expect(values.single, isA<StateError>());
  });

  test('a subsequent callback waits for active prompt to close', () async {
    prompt = create();
    await prompt.setUpdateCallback((_) {}, PasswordResponses.needPassword);
    await prompt.open();
    var installed = false;
    final pending = prompt
        .setUpdateCallback((_) {}, PasswordResponses.incorrectPassword)
        .then((_) => installed = true);
    await Future<void>.delayed(Duration.zero);
    expect(installed, isFalse);
    await prompt.close();
    await pending;
    expect(installed, isTrue);
  });
}
