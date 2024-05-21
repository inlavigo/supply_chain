// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:supply_chain/supply_chain.dart';

/// Produce delegate that does nothing
T doNothing<T>(List<dynamic> components, T previousProduct) => previousProduct;

/// The configuration of a node
class NodeBluePrint<T> {
  /// Constructor of the node
  const NodeBluePrint({
    required this.key,
    required this.initialProduct,
    this.suppliers = const <String>[],
    Produce<T>? produce,
  }) : produce = produce ?? doNothing<T>;

  /// Checks if the configuration is valid
  void check() {
    assert(key.isNotEmpty, 'The key must not be empty');
    assert(key.isPascalCase, 'The key must be in PascalCase');
    produce([], initialProduct);
    assert(
      !(suppliers.isNotEmpty && produce == doNothing<T>),
      'If suppliers are not empty, a produce function must be provided',
    );
  }

  /// The initial product of the node
  final T initialProduct;

  /// The key of this node
  final String key;

  /// A list of supplier keys
  final Iterable<String> suppliers;

  /// The produce function
  final Produce<T> produce;

  /// An example instance for test purposes
  static NodeBluePrint<int> example({String? key}) => NodeBluePrint<int>(
        key: key ?? nextKey,
        initialProduct: 0,
        suppliers: ['Supplier'],
        produce: (components, previousProduct) => previousProduct + 1,
      );

  /// Instantiates the blue print in the given scope
  Node<T> instantiate({
    required Scope scope,
  }) {
    final node = scope.findNode<T>(key);
    if (node != null) {
      return node;
    }

    return Node<T>(
      bluePrint: this,
      scope: scope,
    );
  }

  /// Provites an operator =
  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }

    if (other is NodeBluePrint<T>) {
      if (suppliers.length != other.suppliers.length) {
        return false;
      }

      for (int i = 0; i < suppliers.length; i++) {
        if (suppliers.elementAt(i) != other.suppliers.elementAt(i)) {
          return false;
        }
      }

      return key == other.key &&
          initialProduct == other.initialProduct &&
          other.produce == produce;
    }
    return false;
  }

  @override
  int get hashCode {
    final suppliersHash = suppliers.fold<int>(
      0,
      (previousValue, element) => previousValue ^ element.hashCode,
    );

    return key.hashCode ^
        initialProduct.hashCode ^
        produce.hashCode ^
        suppliersHash;
  }

  @override
  String toString() => key;
}
