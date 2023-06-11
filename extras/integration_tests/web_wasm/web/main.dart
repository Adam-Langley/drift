import 'dart:convert';
import 'dart:html';
import 'dart:js_util';

import 'package:async/async.dart';
import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
// ignore: invalid_use_of_internal_member
import 'package:drift/src/web/wasm_setup.dart';
import 'package:web_wasm/src/database.dart';

const dbName = 'drift_test';
TestDatabase? openedDatabase;
StreamQueue<void>? tableUpdates;

void main() {
  _addCallbackForWebDriver('detectImplementations', _detectImplementations);
  _addCallbackForWebDriver('open', _open);
  _addCallbackForWebDriver('insert', _insert);
  _addCallbackForWebDriver('get_rows', _getRows);
  _addCallbackForWebDriver('wait_for_update', _waitForUpdate);

  document.getElementById('selfcheck')?.onClick.listen((event) async {
    print('starting');
    final database = await _opener.open();

    print('selected storage: ${database.chosenImplementation}');
    print('missing features: ${database.missingFeatures}');
  });
}

void _addCallbackForWebDriver(String name, Future Function(String?) impl) {
  setProperty(globalThis, name,
      allowInterop((String? arg, Function callback) async {
    Object? result;

    try {
      result = await impl(arg);
    } catch (e, s) {
      final console = getProperty(globalThis, 'console');
      callMethod(console, 'error', [e, s]);
    }

    callMethod(callback, 'call', [null, result]);
  }));
}

WasmDatabaseOpener get _opener {
  return WasmDatabaseOpener(
    databaseName: dbName,
    sqlite3WasmUri: Uri.parse('/sqlite3.wasm'),
    driftWorkerUri: Uri.parse('/worker.dart.js'),
  );
}

Future<String> _detectImplementations(String? _) async {
  final opener = _opener;
  await opener.probe();

  return json.encode({
    'impls': opener.availableImplementations.map((r) => r.name).toList(),
    'missing': opener.missingFeatures.map((r) => r.name).toList(),
  });
}

Future<void> _open(String? implementationName) async {
  final opener = _opener;
  WasmDatabaseResult result;

  if (implementationName != null) {
    await opener.probe();
    result = await opener
        .openWith(WasmStorageImplementation.values.byName(implementationName));
  } else {
    result = await opener.open();
  }

  final db = openedDatabase = TestDatabase(result.resolvedExecutor);

  // Make sure it works!
  await db.customSelect('SELECT 1').get();

  tableUpdates = StreamQueue(db.testTable.all().watch());
  await tableUpdates!.next;
}

Future<void> _waitForUpdate(String? _) async {
  await tableUpdates!.next;
}

Future<void> _insert(String? _) async {
  final db = openedDatabase!;
  await db
      .into(db.testTable)
      .insert(TestTableCompanion.insert(content: DateTime.now().toString()));
}

Future<int> _getRows(String? _) async {
  final db = openedDatabase!;
  final count = countAll();

  final query = db.selectOnly(db.testTable)..addColumns([count]);
  return await query.map((row) => row.read(count)!).getSingle();
}