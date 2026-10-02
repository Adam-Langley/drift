import '../node.dart';
import '../statements/statement.dart';
import '../visitor.dart';
import 'declared_statement.dart';
import 'import_statement.dart';

/// Marker interface for AST nodes that are drift-specific.
abstract class DriftSpecificNode implements AstNode {}

/// Something that can appear as a top-level declaration inside a `.drift` file.
abstract class PartOfDriftFile implements Statement, DriftSpecificNode {}

/// A parsed `.drift` file.
///
/// A drift file consists of [ImportStatement]s, followed by ddl statements,
/// followed by [DeclaredStatement]s.
class DriftFile extends AstNode implements DriftSpecificNode {
  List<PartOfDriftFile> statements;

  DriftFile(this.statements);

  @override
  R accept<A, R>(AstVisitor<A, R> visitor, A arg) {
    return visitor.visitDriftSpecificNode(this, arg);
  }

  @override
  void transformChildren<A>(Transformer<A> transformer, A arg) {
    statements = transformer.transformChildren(statements, this, arg);
  }

  @override
  Iterable<AstNode> get childNodes => statements;

  /// Returns the imports defined in this file.
  Iterable<ImportStatement> get imports =>
      childNodes.whereType<ImportStatement>();
}

class DriftTableName extends AstNode implements DriftSpecificNode {
  final String overriddenDataClassName;
  final String? constructorName;
  final bool useExistingDartClass;

  /// Dart interfaces the generated row class implements, from
  /// `AS Name IMPLEMENTS A, B`. The same as `@DataClassName(implementing:)`
  /// on a Dart table; they are resolved through the drift file's imports.
  final List<String> implementing;

  DriftTableName({
    required this.useExistingDartClass,
    required this.overriddenDataClassName,
    this.constructorName,
    this.implementing = const [],
  });

  @override
  R accept<A, R>(AstVisitor<A, R> visitor, A arg) {
    return visitor.visitDriftSpecificNode(this, arg);
  }

  @override
  Iterable<AstNode> get childNodes => const Iterable.empty();

  @override
  void transformChildren<A>(Transformer<A> transformer, A arg) {}
}
