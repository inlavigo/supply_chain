// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:supply_chain/supply_chain.dart';
import 'package:test/test.dart';

import 'sample_nodes.dart';

void main() {
  late Node<int> node;

  setUp(() {
    Node.testRestIdCounter();
    SupplyChain.testRestIdCounter();
    scope = SupplyChain.example();

    node = scope.createNode(
      initialProduct: 0,
      produce: (components, previousProduct) => previousProduct,
      key: 'Node',
    );
  });

  group('Chain', () {
    group('basic properties', () {
      test('example', () {
        expect(scope, isA<SupplyChain>());
      });

      test('scm', () {
        expect(scope.scm, Scm.testInstance);
      });

      test('key', () {
        expect(scope.key, 'Example');
      });

      test('children', () {
        expect(scope.children, isEmpty);
      });
    });

    group('createNode(), addNode()', () {
      test('should create a node and set the scope and SCM correctly', () {
        expect(node.scope, scope);
        expect(node.scm, scope.scm);
      });

      test('should throw if a node with the same key already exists', () {
        expect(
          () => scope.createNode(
            initialProduct: 0,
            produce: (components, previousProduct) => previousProduct,
            key: 'Node',
          ),
          throwsA(
            predicate<ArgumentError>(
              (e) => e.toString().contains('already exists'),
            ),
          ),
        );
      });

      test('should add the node to the scope\'s nodes', () {
        expect(scope.nodes, [node]);
      });
    });

    group('node.dispose(), removeNode()', () {
      test('should remove the node from the scope', () {
        expect(scope.nodes, isNotEmpty);
        node.dispose();
        expect(scope.nodes, isEmpty);
      });
    });

    group('createHierarchy()', () {
      test('should allow to create a hierarchy of scopes', () {
        final scm = Scm.testInstance;
        final root = ExampleChainRoot(scm: scm);
        root.createHierarchy();
        expect(root.nodes.map((n) => n.key), ['RootA', 'RootB']);
        for (var element in root.nodes) {
          scm.nominate(element);
        }
        expect(root.children.map((e) => e.key), ['ChildChainA', 'ChildChainB']);

        final childA = root.child('ChildChainA')!;
        final childB = root.child('ChildChainB')!;
        expect(childA.nodes.map((n) => n.key), ['ChildNodeA', 'ChildNodeB']);
        expect(childB.nodes.map((n) => n.key), ['ChildNodeA', 'ChildNodeB']);

        for (var element in childA.nodes) {
          scm.nominate(element);
        }

        for (var element in childB.nodes) {
          scm.nominate(element);
        }

        final grandChild = childA.child('GrandChildChain')!;
        for (final element in grandChild.nodes) {
          scm.nominate(element);
        }
        scm.tick();
        scm.testFlushTasks();
      });
    });

    group('build', () {
      test('should return an empty array by default', () {
        expect(scope.build(), isEmpty);
      });
    });

    group('graph', () {
      test('should print a simple graph correctly', () {
        initSupplierProducerCustomer();
        createSimpleChain();
        final graph = scope.graph;
        expect(
          graph,
          'digraph unix { '
          'subgraph cluster_Example_0 '
          '{ label = "Example"; '
          'Node_0 [label="Node"]; '
          'Supplier_1 [label="Supplier"]; '
          'Producer_2 [label="Producer"]; '
          'Customer_3 [label="Customer"]; '
          '"Supplier_1" -> "Producer_2"; '
          '"Producer_2" -> "Customer_3"; }}',
        );
      });

      test('should print a more advanced graph correctly', () {
        initMusicExampleNodes();

        // .................................
        // Create the following supply chain
        //  key
        //   |-synth
        //   |  |-audio (realtime)
        //   |
        //   |-screen
        //   |  |-grid
        key.addCustomer(synth);
        key.addCustomer(screen);
        synth.addCustomer(audio);
        screen.addCustomer(grid);
        final graph = scope.graph;
        expect(
          graph,
          'digraph unix { '
          'subgraph cluster_Example_0 { '
          'label = "Example";'
          ' Node_0 [label="Node"];'
          ' Key_1 [label="Key"];'
          ' Synth_2 [label="Synth"];'
          ' Audio_3 [label="Audio"];'
          ' Screen_4 [label="Screen"];'
          ' Grid_5 [label="Grid"]; '
          '"Key_1" -> "Synth_2";'
          ' "Key_1" -> "Screen_4";'
          ' "Synth_2" -> "Audio_3";'
          ' "Screen_4" -> "Grid_5";'
          ' }}',
        );
      });

      test('should print scopes correctly', () {
        final root = ExampleChainRoot(scm: Scm.testInstance);
        root.createHierarchy();
        root.initSuppliers();
        final graph = root.graph;
        expect(
          graph,
          'digraph unix '
          '{ subgraph cluster_ExampleRoot_1 '
          '{ label = "ExampleRoot"; '
          'subgraph cluster_ChildChainA_2 '
          '{ label = "ChildChainA"; '
          'subgraph cluster_GrandChildChain_4 '
          '{ label = "GrandChildChain"; '
          'GrandChildNodeA_5 [label="GrandChildNodeA"]; '
          '}ChildNodeA_3 [label="ChildNodeA"]; '
          'ChildNodeB_4 [label="ChildNodeB"]; '
          '"ChildNodeB_4" -> "ChildNodeA_3"; '
          '}subgraph cluster_ChildChainB_3 '
          '{ label = "ChildChainB"; '
          'subgraph cluster_GrandChildChain_5 '
          '{ label = "GrandChildChain"; '
          'GrandChildNodeA_8 [label="GrandChildNodeA"]; '
          '}ChildNodeA_6 [label="ChildNodeA"]; '
          'ChildNodeB_7 [label="ChildNodeB"]; '
          '"ChildNodeB_7" -> "ChildNodeA_6"; '
          '}RootA_1 [label="RootA"]; RootB_2 [label="RootB"]; '
          '"RootA_1" -> "ChildNodeA_3"; '
          '"RootA_1" -> "GrandChildNodeA_5"; '
          '"RootA_1" -> "ChildNodeA_6"; '
          '"RootA_1" -> "GrandChildNodeA_8"; '
          '"RootB_2" -> "ChildNodeA_3"; '
          '"RootB_2" -> "ChildNodeA_6"; '
          '}}',
        );
      });
    });

    group('findSupplier(key)', () {
      test('should return the supplier with the given key or null', () {
        final rootChain = ExampleChainRoot(scm: Scm.testInstance);
        rootChain.createHierarchy();

        // Find a node directly contained in scope
        final rootA = rootChain.findNode('RootA');
        expect(rootA?.key, 'RootA');

        final rootB = rootChain.findNode('RootB');
        expect(rootB?.key, 'RootB');

        // Unknown node? Return null
        final unknownNode = rootChain.findNode('Unknown');
        expect(unknownNode, isNull);

        // Should not return child nodes
        final childNodeA = rootChain.findNode('ChildNodeA');
        expect(childNodeA, isNull);

        // Should return nodes from parent scope
        final childChainA = rootChain.child('ChildChainA')!;
        final rootAFromChild = childChainA.findNode('RootA');
        expect(rootAFromChild?.key, 'RootA');

        // Child nodes should find their own nodes
        final childNodeAFromChild = childChainA.findNode('ChildNodeA');
        expect(childNodeAFromChild?.key, 'ChildNodeA');
      });
    });

    group('initSuppliers()', () {
      test(
        'should find and add the suppliers added on createNode(....)',
        () {
          final scm = Scm.testInstance;
          final rootChain = ExampleChainRoot(scm: scm);
          rootChain.createHierarchy();
          rootChain.initSuppliers();

          // The root node has no suppliers
          final rootA = rootChain.findNode('RootA');
          final rootB = rootChain.findNode('RootB');
          expect(rootA?.suppliers, isEmpty);
          expect(rootB?.suppliers, isEmpty);

          /// The child node a should have the root nodes as suppliers
          final childChainA = rootChain.child('ChildChainA')!;
          final childNodeA = childChainA.findNode('ChildNodeA');
          final childNodeB = childChainA.findNode('ChildNodeB');
          expect(childNodeA?.suppliers, hasLength(3));
          expect(childNodeA?.suppliers, contains(rootA));
          expect(childNodeA?.suppliers, contains(rootB));
          expect(childNodeA?.suppliers, contains(childNodeB));
        },
      );

      test('should throw if a supplier is not found', () {
        final scm = Scm.testInstance;
        final scope = SupplyChain.example(scm: scm);

        scope.createNode<int>(
          key: 'Node',
          suppliers: ['Unknown'],
          initialProduct: 0,
          produce: (components, previous) => previous,
        );

        expect(
          () => scope.initSuppliers(),
          throwsA(
            predicate<ArgumentError>(
              (e) => e.toString().contains(
                    'Chain "Example": Supplier with key "Unknown" not found.',
                  ),
            ),
          ),
        );
      });

      group('isAncestorOf(node)', () {
        test('should return true if the scope is an ancestor', () {
          final rootChain = ExampleChainRoot(scm: Scm.testInstance);
          rootChain.createHierarchy();
          final childChainA = rootChain.child('ChildChainA')!;
          final childChainB = rootChain.child('ChildChainB')!;
          final grandChildChain = childChainA.child('GrandChildChain')!;
          expect(rootChain.isAncestorOf(childChainA), isTrue);
          expect(rootChain.isAncestorOf(childChainB), isTrue);
          expect(childChainA.isAncestorOf(childChainB), isFalse);
          expect(childChainB.isAncestorOf(childChainA), isFalse);
          expect(rootChain.isAncestorOf(grandChildChain), isTrue);
        });
      });

      group('isDescendantOf(node)', () {
        test('should return true if the scope is a descendant', () {
          final rootChain = ExampleChainRoot(scm: Scm.testInstance);
          rootChain.createHierarchy();
          final childChainA = rootChain.child('ChildChainA')!;
          final childChainB = rootChain.child('ChildChainB')!;
          final grandChildChain = childChainA.child('GrandChildChain')!;
          expect(childChainA.isDescendantOf(rootChain), isTrue);
          expect(childChainB.isDescendantOf(rootChain), isTrue);
          expect(childChainA.isDescendantOf(childChainB), isFalse);
          expect(childChainB.isDescendantOf(childChainA), isFalse);
          expect(grandChildChain.isDescendantOf(rootChain), isTrue);
        });
      });
    });
  });
}
