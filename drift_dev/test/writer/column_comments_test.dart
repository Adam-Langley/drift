import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';

import '../utils.dart';

void main() {
  test('a column comment is analysed and written into its generated column', () async {
    final result = await emulateDriftBuild(
      inputs: {
        'a|lib/main.dart': r'''
import 'package:drift/drift.dart';

part 'main.drift.dart';

class TodoItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().comment('What the item asks for.')();
  TextColumn get description => text().nullable()();
}

@DriftDatabase(tables: [TodoItems])
class Database extends _$Database {}
''',
      },
    );

    checkOutputs(
      {
        'a|lib/main.drift.dart': decodedMatches(
          allOf(
            contains(r"$comment: 'What the item asks for.'"),
            // Only on the column that has one.
            predicate<String>((code) => r'$comment:'.allMatches(code).length == 1, 'one column with a comment'),
          ),
        ),
      },
      result.dartOutputs,
      result.writer,
    );
  }, tags: 'analyzer');

  test('drift_file_comments_in_ddl writes a .drift column comment into the DDL', () async {
    const drift = '''
CREATE TABLE things (
  -- The thing's name, as people know it;
  -- across two lines.
  name TEXT NOT NULL,
  /* not a line comment, still documentation */
  code TEXT,
  plain INTEGER
);
''';
    for (final enabled in [true, false]) {
      final result = await emulateDriftBuild(
        inputs: {
          'a|lib/a.drift': drift,
          'a|lib/main.dart': r'''
import 'package:drift/drift.dart';

part 'main.drift.dart';

@DriftDatabase(include: {'a.drift'})
class Database extends _$Database {}
''',
        },
        options: BuilderOptions({'drift_file_comments_in_ddl': enabled}),
      );
      checkOutputs(
        {
          'a|lib/main.drift.dart': decodedMatches(
            allOf(
              // Documentation either way.
              contains("/// The thing's name, as people know it;"),
              enabled
                  ? allOf(
                      contains(r"$comment: 'The thing\'s name, as people know it; across two lines.'"),
                      contains(r"$comment: 'not a line comment, still documentation'"),
                      predicate<String>((code) => r'$comment:'.allMatches(code).length == 2, 'only the commented columns'),
                    )
                  : isNot(contains(r'$comment')),
            ),
          ),
        },
        result.dartOutputs,
        result.writer,
      );
    }
  }, tags: 'analyzer');
}
