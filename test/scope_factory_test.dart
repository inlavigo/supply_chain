// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:mocktail/mocktail.dart';
import 'package:supply_chain/supply_chain.dart';
import 'package:test/test.dart';

void main() {
  group('scopeFactory', () {
    group('example', () {
      test('should work', () {
        // Get some variables
        final scopeFactory = ScopeFactory.example();
        final scope = scopeFactory.scope;
        final scm = scope.scm;
        final rowHeightsNode = scope.findNode<List<int>>('rowHeights')!;
        expect(rowHeightsNode, isNotNull);

        // Let the SCM produce
        scm.testFlushTasks();
        final initialNodeCount = scm.nodes.length;

        // Initially no row scopes should be created
        expect(scope.children, isEmpty);

        // Assume some row heights are coming in
        rowHeightsNode.product = [10, 20, 30];
        Matcher expectNodeCount() =>
            hasLength(initialNodeCount + rowHeightsNode.product.length);

        scm.testFlushTasks();
        expect(scm.nodes, expectNodeCount());
        expect(scm.preparedNodes, isEmpty);

        // Now we should have 3 row scopes
        expect(scope.children.length, 3);
        final row0 = scope.child('row0')!;
        final row1 = scope.child('row1')!;
        final row2 = scope.child('row2')!;

        // Each row scope should have the right height
        expect(row0.node<int>('rowHeight')?.product, 10);
        expect(row1.node<int>('rowHeight')?.product, 20);
        expect(row2.node<int>('rowHeight')?.product, 30);

        // Update the row heights
        rowHeightsNode.product = [40, 50, 60, 70];

        scm.testFlushTasks();
        expect(scm.nodes, expectNodeCount());

        // The row scopes should have the new heights
        final row3 = scope.child('row3')!;
        expect(row0.node<int>('rowHeight')?.product, 40);
        expect(row1.node<int>('rowHeight')?.product, 50);
        expect(row2.node<int>('rowHeight')?.product, 60);
        expect(row3.node<int>('rowHeight')?.product, 70);

        // Remove row heights
        rowHeightsNode.product = [10];
        scm.testFlushTasks();
        expect(scm.nodes, expectNodeCount());
        expect(scope.children.length, 1);
        expect(row0.node<int>('rowHeight')?.product, 10);
      });
    });

    test('should handle added and removed nodes correctly', () {
      // Instantiate a new sub scope manager
      // and hand over a MockScopeBluePrintFactory.
      final bluePrint = MockScopeBluePrintFactory();
      var producedScopeBluePrints = <ScopeBluePrint>[];

      when(() => bluePrint.initialProduct).thenReturn([]);
      when(() => bluePrint.key).thenReturn('scopeFactory');
      when(() => bluePrint.suppliers).thenReturn(['rowHeights']);
      when(() => bluePrint.allowedProducts).thenReturn([]);
      when(() => bluePrint.produce).thenReturn(
        (List<dynamic> components, List<ScopeBluePrint> previous) =>
            producedScopeBluePrints,
      );

      final scope = Scope.example();
      final scm = scope.scm;

      final scopeFactory = ScopeFactory(
        bluePrint: bluePrint,
        scope: scope,
      );

      // Call the produce method and make the blue print behaving in a way
      // adding and removing nodes is tested.
      scopeFactory.produce(announce: false);
      expect(scm.nodes, hasLength(1));

      // Assume that the produce method adds a child scope
      producedScopeBluePrints = [
        ScopeBluePrint(
          key: 'row0',
          nodes: [
            NodeBluePrint<int>(
              key: 'rowHeight',
              initialProduct: 10,
              suppliers: [],
              produce: (components, previousProduct) => 10,
            ),
          ],
        ),
      ];

      scopeFactory.produce(announce: false);
      expect(scm.nodes, hasLength(2));

      // Change the produced scope. It should add one additional node.
      producedScopeBluePrints = [
        ScopeBluePrint(
          key: 'row0',
          nodes: [
            NodeBluePrint<int>(
              key: 'rowHeight',
              initialProduct: 10,
              suppliers: [],
              produce: (components, previousProduct) => 10,
            ),
            NodeBluePrint<int>(
              key: 'rowHeight2',
              initialProduct: 20,
              suppliers: [],
              produce: (components, previousProduct) => 20,
            ),
          ],
        ),
      ];

      scopeFactory.produce(announce: false);
      expect(scm.nodes, hasLength(3));

      // Change the produced scope. It should remove the last node.
      producedScopeBluePrints = [
        ScopeBluePrint(
          key: 'row0',
          nodes: [
            NodeBluePrint<int>(
              key: 'rowHeight',
              initialProduct: 10,
              suppliers: [],
              produce: (components, previousProduct) => 10,
            ),
          ],
        ),
      ];
      scopeFactory.produce(announce: false);
      expect(scm.nodes, hasLength(2));
    });
  });
}
