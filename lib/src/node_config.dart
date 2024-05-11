// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import '../supply_chain.dart';

/// The configuration of a node
class NodeConfig<T> {
  /// Constructor of the node
  const NodeConfig({
    required this.key,
    required this.initialProduct,
    required this.suppliers,
    required this.produce,
  });

  /// The initial product of the node
  final T initialProduct;

  /// The key of this node
  final String key;

  /// A list of supplier keys
  final List<String> suppliers;

  /// The produce function
  final Produce<T> produce;

  /// An example instance for test purposes
  static final example = NodeConfig<int>(
    key: 'Node',
    initialProduct: 0,
    suppliers: ['Supplier'],
    produce: (components, previousProduct) => previousProduct + 1,
  );
}