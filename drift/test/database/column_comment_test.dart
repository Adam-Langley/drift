@TestOn('vm')
library;

import 'package:drift/drift.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import '../generated/todos.dart';

void main() {
  String definition(GeneratedColumn column) {
    final context = GenerationContext.fromDb(TodoDb());
    column.writeColumnDefinition(context);
    return context.sql;
  }

  test('a comment is written right after the type, before the constraints', () {
    expect(
      definition(GeneratedColumn<String>(
        'name',
        'tbl',
        false,
        type: DriftSqlType.string,
        $comment: 'The name people know it by.',
      )),
      '"name" TEXT /* The name people know it by. */ NOT NULL',
    );
    expect(
      definition(GeneratedColumn<int>(
        'id',
        'tbl',
        false,
        type: DriftSqlType.int,
        $customConstraints: 'NOT NULL PRIMARY KEY',
        $comment: 'The row id.',
      )),
      '"id" INTEGER /* The row id. */ NOT NULL PRIMARY KEY',
    );
  });

  test('a comment is written on one line, and cannot end itself early', () {
    expect(
      definition(GeneratedColumn<String>(
        'note',
        'tbl',
        true,
        type: DriftSqlType.string,
        $comment: '  First line,\n  then a */ in the text ',
      )),
      '"note" TEXT /* First line, then a * / in the text */ NULL',
    );
  });

  test('a blank comment, or none, writes nothing', () {
    for (final comment in [null, '', '  ']) {
      expect(
        definition(GeneratedColumn<String>(
          'name',
          'tbl',
          false,
          type: DriftSqlType.string,
          $comment: comment,
        )),
        '"name" TEXT NOT NULL',
      );
    }
  });

  test('a type converter keeps the comment', () {
    final column = GeneratedColumn<String>(
      'name',
      'tbl',
      false,
      type: DriftSqlType.string,
      $comment: 'Kept.',
    ).withConverter(const _Identity());

    expect(column.$comment, 'Kept.');
    expect(definition(column), '"name" TEXT /* Kept. */ NOT NULL');
  });

  test('sqlite3 keeps the comments in its schema, for a table made and a column added', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.dispose);
    final name = GeneratedColumn<String>('name', 'tbl', false,
        type: DriftSqlType.string, $comment: 'The name people know it by.');
    final note = GeneratedColumn<String>('note', 'tbl', true,
        type: DriftSqlType.string, $comment: 'Anything else worth knowing.');

    db.execute('CREATE TABLE tbl (${definition(name)})');
    db.execute('ALTER TABLE tbl ADD COLUMN ${definition(note)}');

    final sql = db.select("SELECT sql FROM sqlite_master WHERE name = 'tbl'").single['sql'] as String;
    expect(sql, contains('"name" TEXT /* The name people know it by. */ NOT NULL'));
    expect(sql, contains('"note" TEXT /* Anything else worth knowing. */'));
  });
}

class _Identity extends TypeConverter<String, String> {
  const _Identity();

  @override
  String fromSql(String fromDb) => fromDb;

  @override
  String toSql(String value) => value;
}
