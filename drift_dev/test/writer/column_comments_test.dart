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
}
