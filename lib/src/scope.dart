// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_is_github/gg_is_github.dart';
import 'package:supply_chain/supply_chain.dart';

/// A supply scope is a container for connected nodes
class Scope {
  // ...........................................................................
  /// Creates a scope with a key. Key must be lower camel case.
  Scope({
    required this.key,
    required this.parent,
  })  : scm = parent!.scm,
        assert(key.isCamelCase) {
    _init();
  }

  // ...........................................................................
  /// Create a root supply scope having no parent
  Scope.root({
    required this.key,
    required this.scm,
  })  : parent = null,
        assert(key.isCamelCase) {
    _init();
  }

  // ...........................................................................
  /// Disposes the scope
  void dispose() {
    for (final d in _dispose.reversed) {
      d();
    }
  }

  // ...........................................................................
  /// Returns the node as string
  @override
  String toString() => key;

  // ...........................................................................
  /// The supply scope manager
  final Scm scm;

  /// The key of the scope
  final String key;

  /// The path of the scope
  String get path => _path;

  /// The uinquie id of the scope
  final int id = _idCounter++;

  /// Reset id counter for test purposes
  static void testRestIdCounter() => _idCounter = 0;

  // ...........................................................................
  /// Returns the child scopes
  Iterable<Scope> get children => _children.values;

  /// Returns the child scope with the given key
  Scope? child(String key) => _children[key];

  /// The nodes of this scope
  Iterable<Node<dynamic>> get nodes => _nodes.values;

  /// Returns the own node for a given key or null if not found
  Node<T>? node<T>({required String key}) => _findNodeInOwnScope<T>(key, []);

  // ...........................................................................
  /// Returns the node with key. If not available in scope the node is created.
  Node<T> findOrCreateNode<T>(NodeBluePrint<T> bluePrint) {
    // Return existing node when already existing
    final existingNode = _nodes[bluePrint.key];
    if (existingNode != null) {
      assert(
        existingNode.bluePrint == bluePrint,
        'Node with key "$key" already exists with different configuration',
      );
      return existingNode as Node<T>;
    }

    // Create a new node
    final node = Node<T>(
      bluePrint: bluePrint,
      scope: this,
    );

    return node;
  }

  // ...........................................................................
  /// Returns the node with key. If not available in scope the node is created.
  List<Node<dynamic>> findOrCreateNodes(
    List<NodeBluePrint<dynamic>> bluePrints,
  ) {
    final result = <Node<dynamic>>[];
    for (final bluePrint in bluePrints) {
      final newNode = bluePrint.instantiate(scope: this);
      result.add(newNode);
    }
    return result;
  }

  // ...........................................................................
  /// Returns the first scope with the given path.
  /// Throws if multiple scopes with the same path exist.
  Scope? findScope(String path) {
    return _findScope(path.split('.'));
  }

  // ...........................................................................
  Scope? _findScope(List<String> path) {
    if (path.isEmpty) {
      return null;
    }

    if (path.length == 1 && path.first == key) {
      return this;
    }

    if (path.first == key) {
      return _findScope(path.sublist(1));
    }

    for (final child in _children.values) {
      final result = child._findScope(path);
      if (result != null) {
        return result;
      }
    }

    return null;
  }

  // ...........................................................................
  /// The parent supply scope
  Scope? parent;

  /// Returns the root scope of this scope
  Scope get root {
    var result = this;
    while (result.parent != null) {
      result = result.parent!;
    }
    return result;
  }

  // ...........................................................................
  /// Adds an existing node to the scope
  void addNode<T>(Node<T> node) {
    assert(node.runtimeType != Node<dynamic>);
    // Throw if node with key already exists
    if (_nodes.containsKey(node.key)) {
      throw ArgumentError(
        'Node with key ${node.key} already exists in scope "$key"',
      );
    }

    _nodes[node.key] = node;
  }

  // ...........................................................................
  /// Remove the node from the scope
  void removeNode(String key) {
    _nodes.remove(key);
  }

  // ...........................................................................
  /// Replace an existing node with the same key
  void replaceNode(NodeBluePrint<dynamic> bluePrint) {
    final existingNode = _nodes[bluePrint.key];
    if (existingNode == null) {
      throw ArgumentError(
        'Node with key "${bluePrint.key}" does not exist in scope "$key"',
      );
    }

    existingNode.update(bluePrint);
  }

  // ...........................................................................
  /// Returns true if this scope is an ancestor of the given scope
  bool isAncestorOf(Scope scope) {
    if (_children.containsKey(scope.key)) {
      return true;
    }

    for (final child in _children.values) {
      if (child.isAncestorOf(scope)) {
        return true;
      }
    }

    return false;
  }

  // ...........................................................................
  /// Returns true if this scope is a descendant of the given scope
  bool isDescendantOf(Scope scope) {
    if (scope._children.containsKey(key)) {
      return true;
    }

    for (final child in scope._children.values) {
      if (isDescendantOf(child)) {
        return true;
      }
    }

    return false;
  }

  // ...........................................................................
  /// Returns true if a node with the given key exists in this or a
  /// parent supply scope
  bool hasNode(String key) {
    if (_nodes.containsKey(key)) {
      return true;
    }

    return parent?.hasNode(key) ?? false;
  }

  // ...........................................................................
  /// Returns the node of key in this or any parent nodes
  Node<T>? findNode<T>(
    String key, {
    bool throwIfNotFound = false,
  }) {
    final keyParts = key.split('.');
    final nodeKey = keyParts.last;
    final scopePath = keyParts.sublist(0, keyParts.length - 1);

    final node = _findNodeInOwnScope<T>(nodeKey, scopePath) ??
        _findNodeNodeInParentScopes(nodeKey, scopePath) ??
        _findNodeInDirectSiblingScopes(nodeKey, scopePath) ??
        _findAnyUniqueNode<T>(nodeKey, scopePath);

    if (node == null && throwIfNotFound) {
      throw ArgumentError('Node with key "$key" not found.');
    }

    return node;
  }

  // Print graph

  // ...........................................................................
  /// Returns a graph that can be turned into svg using graphviz
  String get graph {
    var result = '';
    result += 'digraph unix { ';
    result += 'graph [nodesep = 0.5; ranksep=2]; ';
    result += _graphNodes;
    result += _graphEdges;
    result += '}';
    return result;
  }

  /// Save the graph to a file
  ///
  /// The format can be
  /// bmp canon cgimage cmap cmapx cmapx_np dot dot_json eps exr fig gd gd2 gif
  /// gv icns ico imap imap_np ismap jp2 jpe jpeg jpg json json0 kitty kittyz
  /// mp pct pdf pic pict plain plain-ext png pov ps ps2 psd sgi svg svgz tga
  /// tif tiff tk vrml vt vt-24bit wbmp webp xdot xdot1.2 xdot1.4 xdot_json
  Future<void> saveGraphToFile(
    String path,
  ) async {
    final format = path.split('.').last;

    final content = graph;
    final file = File(path);
    if (format == 'dot') {
      await file.writeAsString(content);
      return;
    }
    // coveralls:ignore-start
    else {
      if (!isGitHub) {
        // coverage:ignore-start
        // Write dot file to tmp
        final fileName = path.split('/').last;
        final tempDir = await Directory.systemTemp.createTemp();
        final tempPath = '${tempDir.path}/$fileName.dot';
        final tempFile = File(tempPath);
        tempFile.writeAsStringSync(content);

        // Convert dot file to target format
        final process = await Process.run(
          'dot',
          ['-T$format', tempPath, '-o$path'],
        );
        await tempDir.delete(recursive: true);
        assert(process.exitCode == 0, process.stderr);
        // coverage:ignore-end
      }
    }
    // coveralls:ignore-end
  }

  // Test helpers

  // ...........................................................................
  /// Creates an example instance of Scope
  factory Scope.example({
    Scm? scm,
    String key = 'example',
  }) {
    scm ??= Scm.example();
    return Scope.root(key: key, scm: scm);
  }

  // ...........................................................................
  /// Allows to mock the content of the scope
  ///
  /// ```dart
  /// final scope = Scope.example();
  /// scope.mockContent({
  ///   'a': {
  ///     'int': 5,
  ///     'b': {
  ///       'int': 10,
  ///       'double': 3.14,
  ///       'string': 'hello',
  ///       'bool': true,
  ///       'enum': const NodeBluePrint<TestEnum>(
  ///         key: 'enum',
  ///         initialProduct: TestEnum.a,
  ///       ),
  ///     },
  ///     'c': [
  ///       const ScopeBluePrint(key: 'd'),
  ///       const ScopeBluePrint(key: 'e'),
  ///       const ScopeBluePrint(key: 'f'),
  ///     ],
  ///   },
  /// });
  ///
  /// ```
  void mockContent(Object content) {
    assert(content is Map<String, dynamic>);
    final map = content as Map<String, dynamic>;

    // Iterate all entries of the map
    for (final key in map.keys) {
      final value = map[key];

      // If the entry is a map, create a child scope
      if (value is Map<String, dynamic>) {
        final bluePrint = ScopeBluePrint(key: key);
        final child = bluePrint.instantiate(scope: this);

        // Forward child content to child
        child.mockContent(value);
      }

      // If value is a NodeBluePrint, create a child node
      else if (value is NodeBluePrint) {
        value.instantiate(scope: this);
      }

      // If value is a ScopeBluePrint, instantiate the scope
      else if (value is ScopeBluePrint) {
        assert(value.key == key);
        value.instantiate(scope: this);
      }

      // If value is a ScopeBluePrint, instantiate the scope
      else if (value is List) {
        final scope = ScopeBluePrint(key: key).instantiate(scope: this);

        for (final item in value) {
          if (item is ScopeBluePrint) {
            item.instantiate(scope: scope);
          } else {
            throw ArgumentError(
              'Lists must only contain ScopeBluePrints.',
            );
          }
        }
      }

      // If value is a basic type, create a node
      else {
        final bluePrint = switch (value.runtimeType) {
          const (int) => NodeBluePrint<int>(
              key: key,
              initialProduct: value as int,
            ),
          const (double) => NodeBluePrint<double>(
              initialProduct: value as double,
              key: key,
            ),
          const (String) => NodeBluePrint<String>(
              initialProduct: value as String,
              key: key,
            ),
          const (bool) => NodeBluePrint<bool>(
              initialProduct: value as bool,
              key: key,
            ),
          _ => throw ArgumentError(
              'Type ${value.runtimeType} not supported. '
              'Use NodeBluePrint<${value.runtimeType}> instead.',
            ),
        };

        bluePrint.instantiate(scope: this);
      }
    }
  }

  // ######################
  // Private
  // ######################

  // ...........................................................................
  final List<void Function()> _dispose = [];
  late final String _path;

  // ...........................................................................
  final Map<String, Scope> _children = {};
  final Map<String, Node<dynamic>> _nodes = {};
  static int _idCounter = 0;

  // ...........................................................................
  void _init() {
    _initParent();
    _initPath();
    _initNodes();
  }

  // ...........................................................................
  void _initParent() {
    if (parent == null) {
      return;
    }

    // Add scope to parent scope
    parent!._children[key] = this;

    // Remove scope from parent scope on dispose
    _dispose.add(() {
      parent!._children.remove(key);
    });
  }

  // ...........................................................................
  void _initNodes() {
    // On dispose, all nodes should be disposed
    _dispose.add(() {
      for (final node in [..._nodes.values]) {
        node.dispose();
      }
    });
  }

  // ...........................................................................
  void _initPath() {
    _path = parent == null ? key : '${parent!.path}.$key';
  }

  // ...........................................................................
  String _nodeId(Node<dynamic> node) => '${node.key}_${node.id}';

  // ...........................................................................
  // Graph
  String get _graphNodes {
    {
      var result = '';

      final scopeId = '${key}_$id';

      // Create a cluster for this scope
      result += 'subgraph cluster_$scopeId { ';
      result += 'label = "$key"; ';

      // Write the child scopes
      for (final childScope in children) {
        result += childScope._graphNodes;
      }

      // Write each node
      for (final node in nodes) {
        final nodeId = _nodeId(node);
        result += '$nodeId [label="${node.key}"]; ';
      }

      result += '}'; // cluster

      return result;
    }
  }

  // ...........................................................................
  String get _graphEdges {
    {
      var result = '';

      // Write dependencies
      for (final node in nodes) {
        for (final customer in node.customers) {
          final from = _nodeId(node);
          final to = _nodeId(customer);

          result += '"$from" -> "$to"; ';
        }
      }

      // Write the child scopes
      for (final childScope in children) {
        result += childScope._graphEdges;
      }

      return result;
    }
  }

  // ...........................................................................
  Node<T>? _findNodeInOwnScope<T>(String nodeKey, List<String> scopePath) {
    final node = _nodes[nodeKey];
    if (node == null) {
      return null;
    }

    if (scopePath.isNotEmpty) {
      if (!node.scope.path.endsWith(scopePath.join('.'))) {
        return null;
      }
    }

    if (node is! Node<T>) {
      throw ArgumentError('Node with key "$nodeKey" is not of type $T');
    }

    return node;
  }

  // ...........................................................................
  Node<T>? _findNodeNodeInParentScopes<T>(String key, List<String> scopePath) {
    return parent?._findNodeInOwnScope<T>(key, scopePath) ??
        parent?._findNodeNodeInParentScopes<T>(key, scopePath);
  }

  // ...........................................................................
  Node<T>? _findNodeInDirectSiblingScopes<T>(
    String key,
    List<String> scopePath,
  ) {
    if (parent == null) {
      return null;
    }

    for (final sibling in parent!._children.values) {
      final node = sibling._findNodeInOwnScope<T>(key, scopePath);
      if (node != null) {
        return node;
      }
    }

    return null;
  }

  // ...........................................................................
  Node<T>? _findAnyUniqueNode<T>(String key, List<String> scopePath) {
    final scopePathString = scopePath.join('.');
    final nodes = scm.nodesWithKey<T>(key).where(
          (element) => element.scope.path.endsWith(scopePathString),
        );
    if (nodes.length == 1) {
      return nodes.first;
    }

    if (nodes.length > 1) {
      throw ArgumentError(
        'More than one node with key "$key" and Type<$T> found.',
      );
    }

    return null;
  }
}

// #############################################################################
// Example scopes for test purposes

// .............................................................................
/// An example root scope
class ExampleScopeRoot extends Scope {
  /// Constructor
  ExampleScopeRoot({
    required super.scm,
    super.key = 'exampleRoot',
  }) : super.root() {
    findOrCreateNode(
      NodeBluePrint(
        initialProduct: 0,
        produce: (components, previous) =>
            previous + 1, // coveralls:ignore-line
        key: 'rootA',
      ),
    );

    findOrCreateNode(
      NodeBluePrint(
        initialProduct: 0,
        produce: (components, previous) =>
            previous + 1, // coveralls:ignore-line
        key: 'rootB',
      ),
    );

    ExampleChildScope(key: 'childScopeA', parent: this);
    ExampleChildScope(key: 'childScopeB', parent: this);
  }
}

// .............................................................................
/// An example child scope
class ExampleChildScope extends Scope {
  /// Constructor
  ExampleChildScope({
    required super.key,
    required super.parent,
  }) {
    /// Create a node
    findOrCreateNode(
      NodeBluePrint(
        initialProduct: 0,
        produce: (components, previous) => previous + 1,
        key: 'childNodeA',
        suppliers: ['rootA', 'rootB', 'childScopeA.childNodeB'],
      ),
    );

    findOrCreateNode(
      NodeBluePrint(
        initialProduct: 0,
        produce: (components, previous) => previous + 1,
        key: 'childNodeB',
      ),
    );

    /// Create two example child scopes
    ExampleGrandChildScope(
      key: 'grandChildScope',
      parent: this,
    );
  }
}

// .............................................................................
/// An example child scope
class ExampleGrandChildScope extends Scope {
  /// Constructor
  ExampleGrandChildScope({
    required super.key,
    required super.parent,
  }) {
    findOrCreateNode(
      NodeBluePrint(
        initialProduct: 0,
        produce: (components, previous) => previous + 1,
        key: 'grandChildNodeA',
        suppliers: [
          'rootA',
        ],
      ),
    );
  }
}
