import 'package:drift/drift.dart' show DriftSqlType;
import 'package:sqlparser/sqlparser.dart' as sql;

import 'dart.dart';
import 'element.dart';

import 'column.dart';
import 'result_sets.dart';

class DriftTable extends DriftElementWithResultSet {
  @override
  final List<DriftColumn> columns;

  final List<DriftTableConstraint> tableConstraints;

  final Set<DriftColumn>? primaryKeyFromTableConstraint;

  @override
  final List<DriftElement> references;

  @override
  final ExistingRowClass? existingRowClass;

  @override
  final AnnotatedDartCode? customParentClass;

  /// The fixed [entityInfoName] to use, overriding the default.
  final String? fixedEntityInfoName;

  /// The default name to use for the [entityInfoName].
  final String baseDartName;

  @override
  final String nameOfRowClass;

  final bool withoutRowId;

  final bool strict;

  DriftTable(
    super.id,
    super.declaration, {
    required this.columns,
    required this.baseDartName,
    required this.nameOfRowClass,
    this.references = const [],
    this.existingRowClass,
    this.customParentClass,
    this.fixedEntityInfoName,
    this.withoutRowId = false,
    this.strict = false,
    this.primaryKeyFromTableConstraint,
    this.tableConstraints = const [],
  }) {
    for (final column in columns) {
      column.owner = this;
    }
  }

  @override
  String get dbGetterName => DriftSchemaElement.dbFieldName(baseDartName);

  /// The primary key for this table, computed by looking at the
  /// [primaryKeyFromTableConstraint] and primary key constraints applied to
  /// individiual columns.
  Set<DriftColumn> get fullPrimaryKey {
    if (primaryKeyFromTableConstraint != null) {
      return primaryKeyFromTableConstraint!;
    }

    return columns
        .where((c) => c.constraints.any((f) => f is PrimaryKeyColumn))
        .toSet();
  }

  /// Determines whether [column] would be required for inserts performed via
  /// companions.
  bool isColumnRequiredForInsert(DriftColumn column) {
    assert(columns.contains(column));

    if (column.defaultArgument != null ||
        column.clientDefaultCode != null ||
        column.nullable ||
        column.isGenerated) {
      // default value would be applied, so it's not required for inserts
      return false;
    }

    // A column isn't required if it's an alias for the rowid, as explained
    // at https://www.sqlite.org/lang_createtable.html#rowid
    final fullPk = fullPrimaryKey;
    final isAliasForRowId = !withoutRowId &&
        column.sqlType == DriftSqlType.int &&
        fullPk.length == 1 &&
        fullPk.single == column;

    return !isAliasForRowId;
  }

  @override
  String get entityInfoName {
    // if this table was parsed from sql, a user might want to refer to it
    // directly because there is no user defined parent class.
    // So, turn CREATE TABLE users into something called "Users" instead of
    // "$UsersTable".
    final name =
        fixedEntityInfoName ?? _tableInfoNameForTableClass(baseDartName);
    if (name == nameOfRowClass) {
      // resolve clashes if the table info class has the same name as the data
      // class. This can happen because the data class name can be specified by
      // the user.
      return '${name}Table';
    }
    return name;
  }

  static String _tableInfoNameForTableClass(String className) =>
      '\$${className}Table';
}

abstract class DriftTableConstraint {}

class UniqueColumns extends DriftTableConstraint {
  final Set<DriftColumn> uniqueSet;

  UniqueColumns(this.uniqueSet);
}

class ForeignKeyTable extends DriftTableConstraint {
  final List<DriftColumn> localColumns;
  final DriftTable otherTable;
  final List<DriftColumn> otherColumns;

  final sql.ReferenceAction? onUpdate;
  final sql.ReferenceAction? onDelete;

  ForeignKeyTable({
    required this.localColumns,
    required this.otherTable,
    required this.otherColumns,
    this.onUpdate,
    this.onDelete,
  });
}