// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:supply_chain/supply_chain.dart';
import 'package:test/test.dart';

import 'sample_nodes.dart';

enum TestEnum {
  a,
  b,
  c,
}

void main() {
  late Node<int> node;

  int produce(List<dynamic> components, int previousProduct) => previousProduct;

  setUp(() {
    Node.testResetIdCounter();
    Scope.testRestIdCounter();
    scm = Scm.example();
    scope = Scope.example(scm: scm);

    node = scope.findOrCreateNode(
      NodeBluePrint(
        initialProduct: 0,
        produce: produce,
        key: 'node',
      ),
    );
  });

  group('Scope', () {
    group('basic properties', () {
      test('example', () {
        expect(scope, isA<Scope>());
      });

      test('scm', () {
        expect(scope.scm, scm);
      });

      test('key', () {
        expect(scope.key, 'example');
      });

      test('children', () {
        expect(scope.children, isEmpty);
      });

      group('deepChildren, deepParents', () {
        final scope = Scope.example()
          ..mockContent({
            'p2': {
              'p1': {
                'p0': {
                  'x': {
                    'c0': {
                      'c00': {
                        'c000': 0,
                      },
                      'c01': {
                        'c010': 0,
                      },
                    },
                    'c1': {
                      'c10': {
                        'c100': 0,
                      },
                      'c11': {
                        'c110': 0,
                      },
                    },
                  },
                },
              },
            },
          });

        final x = scope.findScope('x')!;

        test('should return empty array, when depth = 0', () {
          final parents = x.deepParents(depth: 0).map((e) => e.key);
          expect(parents, <Scope>[]);

          final children = x.deepChildren(depth: 0).map((e) => e.key);
          expect(children, <Scope>[]);
        });

        group('should only return the direct parent / children', () {
          test('when depth = 0', () {
            final parents = x.deepParents(depth: 1).map((e) => e.key);
            expect(parents, ['p0']);

            final children = x.deepChildren(depth: 1).map((e) => e.key);
            expect(children, ['c0', 'c1']);
          });
        });

        group('should return parent of parents, children of children', () {
          test('when depth = 1', () {
            final parents = x.deepParents(depth: 2).map((e) => e.key).toList();
            expect(parents, ['p0', 'p1']);

            final children =
                x.deepChildren(depth: 2).map((e) => e.key).toList();
            expect(children, ['c0', 'c1', 'c00', 'c01', 'c10', 'c11']);
          });
        });

        group('should return all parents / children', () {
          test('when depth = -1 or 1000', () {
            var parents = x.deepParents(depth: 1000).map((e) => e.key).toList();
            expect(parents, ['p0', 'p1', 'p2', 'example']);

            parents = x.deepParents(depth: -1).map((e) => e.key).toList();
            expect(parents, ['p0', 'p1', 'p2', 'example']);

            var children =
                x.deepChildren(depth: 1000).map((e) => e.key).toList();
            expect(children, ['c0', 'c1', 'c00', 'c01', 'c10', 'c11']);

            children = x.deepChildren(depth: -1).map((e) => e.key).toList();
            expect(children, ['c0', 'c1', 'c00', 'c01', 'c10', 'c11']);
          });
        });
      });

      group('allScopes', () {
        test('should provide an iterator iterating over all scopes recursively',
            () {
          final scope = Scope.example()
            ..mockContent({
              'a': {
                'b': {
                  'c': {
                    'd': 0,
                  },
                },
              },
              'x': {
                'y': {
                  'z': {
                    'w': 0,
                  },
                },
              },
            });

          final allScopes = scope.allScopes.map((e) => e.key).toList();
          expect(allScopes, ['example', 'a', 'b', 'c', 'x', 'y', 'z']);
        });
      });
    });

    test('string', () {
      expect(scope.toString(), scope.key);
    });

    group('reset', () {
      test('should reset all nodes in this and child scopes', () {
        final scope = Scope.example();
        scope.mockContent({
          'a': {
            'b': {
              'n0': 10,
              'c': {
                'n1': 11,
              },
            },
          },
        });

        final n0 = scope.findNode<int>('a.b.n0')!;
        final n1 = scope.findNode<int>('a.b.c.n1')!;

        // Initally we have the following products
        scope.scm.testFlushTasks();
        expect(n0.product, 10);
        expect(n1.product, 11);

        // Let's change the products
        n0.product = 20;
        n1.product = 21;
        scope.scm.testFlushTasks();

        // Reset
        scope.reset();
        scope.scm.testFlushTasks();

        // The products should be reset to their initial values
        expect(n0.product, 10);
        expect(n1.product, 11);
      });
    });

    group('root', () {
      test('should return the scope itself, if scope is the root', () {
        final root = Scope.example();
        expect(root.root, root);
      });

      test('should return the root node', () {
        final root = Scope.example();
        root.mockContent({
          'a': {
            'b': {
              'c': {
                'd': 0,
              },
            },
          },
        });
        final c = root.findScope('a.b.c')!;
        expect(c.root, root);
      });
    });

    group(
      'commonParent(scope)',
      () {
        test('should return the scope itself when the other scope is scope',
            () {
          final root = ExampleScopeRoot(scm: Scm.testInstance);
          final childScopeA = root.child('childScopeA')!;
          expect(childScopeA.commonParent(childScopeA), childScopeA);
        });

        test('should return the common parent scope', () {
          final root = ExampleScopeRoot(scm: Scm.testInstance);
          final childScopeA = root.child('childScopeA')!;
          final childScopeB = root.child('childScopeB')!;
          final grandChildScope = childScopeA.child('grandChildScope')!;
          final grandChildNodeA =
              grandChildScope.findNode<int>('grandChildNodeA')!;

          var commonScope = root.commonParent(grandChildNodeA.scope);
          expect(commonScope, root);

          commonScope = childScopeA.commonParent(grandChildScope);
          expect(commonScope, childScopeA);

          commonScope = grandChildScope.commonParent(childScopeA);
          expect(commonScope, childScopeA);

          commonScope = grandChildScope.commonParent(root);
          expect(commonScope, root);

          commonScope = childScopeA.commonParent(childScopeB);
          expect(commonScope, root);
        });

        test('should throw if no common parent is found', () {
          final scope = Scope.example();
          final scopeB = Scope.example();
          expect(
            () => scopeB.commonParent(scope),
            throwsA(
              isA<ArgumentError>().having(
                (e) => e.message,
                'message',
                'No common parent found.',
              ),
            ),
          );
        });
      },
    );

    group('dispose', () {
      test('should remove the scope from its parent', () {
        final parent = Scope.example(scm: scm);
        final scope =
            const ScopeBluePrint(key: 'child').instantiate(scope: parent);

        // Before dispose the scope belongs to it's parent
        expect(scope.parent!.children, contains(scope));

        // Dispose the scope
        scope.dispose();

        // After dispose the scope is removed from it's parent
        expect(scope.parent!.children, isNot(contains(scope)));
      });

      test('should dispose all nodes', () {
        // Before dispose the scope has nodes.
        // These nodes are part of the scm
        expect(scope.nodes, isNotEmpty);
        for (final node in scope.nodes) {
          expect(scm.nodes, contains(node));
        }

        // Dispose the scope
        scope.dispose();

        // After dispose the scope's nodes are removed
        // from the scope and also the SCM
        expect(scope.nodes, isEmpty);
        for (final node in scope.nodes) {
          expect(scm.nodes, isNot(contains(node)));
        }
      });
    });

    group('path, pathArray, pathDepth', () {
      test('should return the path of the scope', () {
        final root = ExampleScopeRoot(scm: Scm.testInstance);
        final childScopeA = root.child('childScopeA')!;
        final grandChildScope = childScopeA.child('grandChildScope')!;
        expect(root.path, 'exampleRoot');
        expect(childScopeA.path, 'exampleRoot.childScopeA');
        expect(childScopeA.pathArray, ['exampleRoot', 'childScopeA']);
        expect(grandChildScope.path, 'exampleRoot.childScopeA.grandChildScope');
        expect(
          grandChildScope.pathArray,
          ['exampleRoot', 'childScopeA', 'grandChildScope'],
        );
        expect(grandChildScope.depth, 3);
      });
    });

    group('matchesPath(path), matchesPathArry(pathArray)', () {
      group('with aliases', () {
        test('should return true if path matches', () {
          final scope = Scope.example();
          scope.mockContent({
            'a': {
              'b': {
                'c0|c1|c2': {
                  'd': 0,
                },
              },
            },
          });

          final c = scope.findScope('a.b.c0')!;
          expect(c.matchesPath('a.b.c0'), isTrue);
          expect(c.matchesPath('a.b.c1'), isTrue);
          expect(c.matchesPath('a.b.c2'), isTrue);
          expect(c.matchesPath('a.b.c3'), isFalse);

          final b = scope.findScope('a.b')!;
          expect(b.matchesPath('c0'), isFalse);
        });
      });
    });

    group('addChild(child), remove()', () {
      test('should instantiate and add the child to the scope', () {
        final scope = Scope.example();
        const childBluePrint = ScopeBluePrint(key: 'child');
        final child = scope.addChild(childBluePrint);
        expect(scope.children, hasLength(1));
        expect(scope.children.first, child);

        child.remove();
        expect(child.isDisposed, isTrue);
        expect(scope.children, isEmpty);
      });
    });

    group('node(key)', () {
      test('should return the node with the given key', () {
        expect(scope.node<int>('node'), node);
      });

      test('should return null if the node does not exist', () {
        expect(scope.node<int>('unknown'), isNull);
      });

      test('should throw if the type does not match', () {
        expect(
          () => scope.node<String>('node'),
          throwsA(
            predicate<ArgumentError>(
              (e) => e.toString().contains(
                    'Node with key "node" is not of type String',
                  ),
            ),
          ),
        );
      });
    });

    group('findScope(path)', () {
      group('should return the scope with the given path', () {
        test('when the path has the name of the scope', () {
          final scope = Scope.example();
          expect(scope.findScope('example'), scope);
        });

        test('when the path has the name of an alias', () {
          final scope = Scope.example(aliases: ['x', 'y', 'z']);
          expect(scope.findScope('x'), scope);
          expect(scope.findScope('y'), scope);
          expect(scope.findScope('z'), scope);
          expect(scope.findScope('u'), isNull);
        });
        test('when the path has the name of a child node', () {
          final scope = Scope.example();
          scope.mockContent({
            'a': {
              'b': {
                'c': 0,
              },
            },
          });
          expect(scope.findScope('a')?.key, 'a');
          expect(scope.findScope('b')?.key, 'b');
          expect(scope.findScope('c')?.key, null);
        });
        test('when the path contains multiple path segments', () {
          final scope = Scope.example();
          scope.mockContent({
            'a': {
              'b': {
                'c': {
                  'd': 0,
                },
              },
            },
          });
          expect(scope.findScope('a.b')?.key, 'b');
          expect(scope.findScope('a.b.c')?.key, 'c');
          expect(scope.findScope('a.b.c.d'), isNull);
        });
      });
      group('should return null', () {
        test('if the scope does not exist', () {
          final root = ExampleScopeRoot(scm: Scm.testInstance);
          expect(root.findScope('unknown'), isNull);
        });
        test('if the key is empty', () {
          final root = ExampleScopeRoot(scm: Scm.testInstance);
          expect(root.findScope(''), isNull);
        });
      });

      test('should throw if multiple scopes with the path exist', () {
        final scope = Scope.example();
        scope.mockContent(
          {
            'a': {
              'duplicate': {
                'c': 0,
                'duplicate': {
                  'd': 0,
                },
              },
            },
          },
        );
      });
    });

    group('replaceScope(newScope, path)', () {
      group('should throw', () {
        test('when the path does not exist', () {
          final scope = Scope.example();
          scope.mockContent({
            'a': {
              'b': {
                'c': 0,
              },
            },
          });

          expect(
            () => scope.replaceChild(
              const ScopeBluePrint(key: 'd'),
              path: 'a.b.d',
            ),
            throwsA(
              predicate<ArgumentError>(
                (e) => e.toString().contains(
                      'Scope with path "a.b.d" not found.',
                    ),
              ),
            ),
          );
        });
      });

      group('should replace the old scope', () {
        group('when a path is given', () {
          test('and the path ends with a different key', () {
            final scope = Scope.example();
            scope.mockContent({
              'a': {
                'b': {
                  'c': 0,
                },
              },
            });

            final c = scope.findNode<int>('a.b.c')!;
            final newScope = ScopeBluePrint.fromJson({
              'x': {
                'y': {
                  'z': 0,
                },
              },
            });

            scope.replaceChild(newScope, path: 'a');
            expect(scope.children, hasLength(1));
            expect(scope.children.first.key, 'x');
            expect(c.isDisposed, isTrue);
          });
        });
      });

      group('should upate the old scope', () {
        group('when a path is given', () {
          test('and the path ends with a same key', () {
            final scope = Scope.example();
            scope.mockContent({
              'a': {
                'b': {
                  'c': 0,
                  'p': 10,
                },
                'x': {
                  'y': {
                    'z': 0,
                  },
                },
              },
            });

            final a = scope.findScope('a')!;
            final b = scope.findScope('a.b')!;
            final c = scope.findNode<int>('a.b.c')!;
            final x = scope.findScope('a.x')!;
            final y = scope.findScope('a.x.y')!;
            final z = scope.findNode<int>('a.x.y.z')!;

            // Replace the scope
            final newScope = ScopeBluePrint.fromJson({
              'a': {
                'b': {
                  'c': 5,
                  'd': 6,
                },
                'k': {
                  'l': 7,
                },
              },
            });

            scope.replaceChild(newScope, path: 'a');

            final aOut = scope.findScope('a')!;
            final bout = scope.findScope('a.b')!;
            final cOut = scope.findNode<int>('a.b.c')!;
            final kOut = scope.findScope('a.k');
            final pOut = scope.findNode<int>('a.b.p');

            // The original scopes should be kept
            expect(aOut, a);
            expect(bout, b);
            expect(cOut, c);
            expect(kOut, isNotNull);
            expect(pOut, isNull);

            // An additional node should be added
            expect(scope.findNode<int>('a.b.d')?.product, 6);

            // The blue print of the node should be updated
            expect(cOut.bluePrint.initialProduct, 5);

            // The scopes x, y, z should be removed and disposed
            expect(scope.findScope('a.x'), isNull);
            expect(x.isDisposed, isTrue);

            expect(scope.findScope('a.x.y'), isNull);
            expect(y.isDisposed, isTrue);

            expect(scope.findNode<int>('a.x.z'), isNull);
            expect(z.isDisposed, isTrue);
          });
        });
      });
    });

    group('findOrCreateNode()', () {
      test('should return an existing node when possible', () {
        expect(
          scope.findOrCreateNode(
            NodeBluePrint(
              initialProduct: 0,
              produce: produce,
              key: 'node',
            ),
          ),
          node,
        );
      });

      group('should throw', () {
        group('when existing node exists', () {
          test('but have a different produce method', () {
            expect(
              () => scope.findOrCreateNode<int>(
                NodeBluePrint(
                  initialProduct: 0,
                  produce: (components, previousProduct) => 0,
                  key: 'node',
                ),
              ),
              throwsA(
                predicate<AssertionError>(
                  (e) => e.toString().contains(
                        'Node with key "example" already exists '
                        'with different configuration',
                      ),
                ),
              ),
            );
          });

          test('but has a different type', () {
            expect(
              () => scope.findOrCreateNode<String>(
                NodeBluePrint(
                  initialProduct: 'hello',
                  produce: (components, previousProduct) => 'world',
                  key: 'node',
                ),
              ),
              throwsA(
                predicate<AssertionError>(
                  (e) => e.toString().contains(
                        'Node with key "example" already exists '
                        'with different configuration',
                      ),
                ),
              ),
            );
          });
        });
      });
    });

    group('findOrCreateNodes', () {
      test('should return a list of nodes', () {
        final bluePrint = ScopeBluePrint.example().scopeOverrides.first;
        final nodes = scope.findOrCreateNodes(bluePrint.nodeOverrides);
        expect(nodes, hasLength(2));
        expect(nodes[0].key, 'node');
        expect(nodes[1].key, 'customer');
      });
    });
    group('addNode()', () {
      test('should create a node and set the scope and SCM correctly', () {
        expect(node.scope, scope);
        expect(node.scm, scope.scm);
      });

      test('should throw if a node with the same key already exists', () {
        expect(
          () => scope.addNode(
            Node<int>(
              bluePrint: NodeBluePrint<int>(
                initialProduct: 0,
                produce: (components, previousProduct) => previousProduct,
                key: 'node',
              ),
              scope: scope,
            ),
          ),
          throwsA(
            predicate<ArgumentError>(
              (e) => e.toString().contains('already exists'),
            ),
          ),
        );
      });

      test('should add the node to the chain\'s nodes', () {
        expect(scope.nodes, [node]);
      });
    });

    group('replaceNode()', () {
      test('should replace the node with the given key', () {
        final newNode = NodeBluePrint<int>(
          initialProduct: 0,
          produce: (components, previousProduct) => previousProduct,
          key: 'node',
        );

        scope.replaceNode(newNode);
        expect(scope.node<int>('node')?.bluePrint, newNode);
      });

      test('should throw if the node does not exist', () {
        final newNode = NodeBluePrint<int>(
          initialProduct: 0,
          produce: (components, previousProduct) => previousProduct,
          key: 'unknown',
        );

        expect(
          () => scope.replaceNode(newNode),
          throwsA(
            predicate<ArgumentError>(
              (e) => e.toString().contains(
                    'Node with key "unknown" does not exist in scope "example"',
                  ),
            ),
          ),
        );
      });
    });
    group('removeNode()', () {
      test('should remove the node with the given key', () {
        expect(scope.node<int>('node'), isNotNull);
        scope.removeNode('node');
        expect(scope.node<int>('node'), isNull);
      });

      test('should also remove the plugins of the node', () {
        final scope = Scope.example();
        final host = scope.findOrCreateNode<int>(
          NodeBluePrint(
            initialProduct: 0,
            produce: (components, previousProduct) => previousProduct,
            key: 'node',
          ),
        );

        final pluginNode = PluginNode.example(host: host);
        expect(pluginNode.isDisposed, isFalse);

        scope.removeNode('node');
        expect(pluginNode.isDisposed, isTrue);
      });

      test('should do nothing if node does not exist', () {
        expect(
          () => scope.removeNode('Unknown'),
          returnsNormally,
        );
      });
    });

    group('isAncestorOf(scope)', () {
      test('should return true if the scope is an ancestor of the given scope',
          () {
        final root = ExampleScopeRoot(scm: Scm.testInstance);
        final childScopeA = root.child('childScopeA')!;
        final grandChildScope = childScopeA.child('grandChildScope')!;
        expect(root.isAncestorOf(childScopeA), isTrue);
        expect(root.isAncestorOf(grandChildScope), isTrue);
        expect(childScopeA.isAncestorOf(grandChildScope), isTrue);
      });
    });

    group('isDescendantOf(scope)', () {
      test('should return true if the scope is a descendant of the given scope',
          () {
        final root = ExampleScopeRoot(scm: Scm.testInstance);
        final childScopeA = root.child('childScopeA')!;
        final grandChildScope = childScopeA.child('grandChildScope')!;
        expect(childScopeA.isDescendantOf(root), isTrue);
        expect(grandChildScope.isDescendantOf(root), isTrue);
        expect(grandChildScope.isDescendantOf(childScopeA), isTrue);
      });
    });

    group('node.dispose(), removeNode()', () {
      test('should remove the node from the chain', () {
        expect(scope.nodes, isNotEmpty);
        node.dispose();
        expect(scope.nodes, isEmpty);
      });
    });

    group('initSuppliers()', () {
      test('should allow to create a hierarchy of scopes', () {
        final scm = Scm.testInstance;
        final root = ExampleScopeRoot(scm: scm);
        expect(root.nodes.map((n) => n.key), ['rootA', 'rootB']);
        for (var element in root.nodes) {
          scm.nominate(element);
        }
        expect(root.children.map((e) => e.key), ['childScopeA', 'childScopeB']);
        expect(root.path, 'exampleRoot');

        final childA = root.child('childScopeA')!;
        final childB = root.child('childScopeB')!;
        expect(childA.nodes.map((n) => n.key), ['childNodeA', 'childNodeB']);
        expect(childB.nodes.map((n) => n.key), ['childNodeA', 'childNodeB']);

        expect(childA.path, 'exampleRoot.childScopeA');
        expect(childB.path, 'exampleRoot.childScopeB');

        for (var element in childA.nodes) {
          scm.nominate(element);
        }

        for (var element in childB.nodes) {
          scm.nominate(element);
        }

        final grandChild = childA.child('grandChildScope')!;
        for (final element in grandChild.nodes) {
          scm.nominate(element);
        }
        expect(grandChild.path, 'exampleRoot.childScopeA.grandChildScope');
        expect(
          grandChild.nodes.first.path,
          'exampleRoot.childScopeA.grandChildScope.grandChildNodeA',
        );

        scm.testFlushTasks();
      });
    });

    group('graph, saveGraphToFile', () {
      // .......................................................................
      Future<void> updateGraphFile(Scope chain, String fileName) async {
        final cwd = Directory.current.path;
        final graphFile = '$cwd/test/graphs/$fileName';

        // Save dot file
        await chain.writeImageFile(graphFile);

        // Save svg file
        final svgFile = graphFile.replaceAll('.dot', '.svg');
        await chain.writeImageFile(svgFile);

        // Create graph directly
        final graph = chain.dot();
        expect(graph, isNotNull);
      }

      // .......................................................................
      test('should print a simple graph correctly', () async {
        initSupplierProducerCustomer();
        createSimpleChain();
        await updateGraphFile(scope, 'simple_graph.dot');
      });

      test('should print a more advanced graph correctly', () async {
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
        await updateGraphFile(scope, 'advanced_graph.dot');
      });

      test('should print scopes correctly', () async {
        final root = ExampleScopeRoot(scm: Scm.testInstance);
        await updateGraphFile(root, 'graphs_with_scopes.dot');
      });
    });

    group('findNode(key)', () {
      group('without scope in key', () {
        group('returns', () {
          group('the right node', () {
            late final ExampleScopeRoot rootScope;

            setUpAll(() {
              rootScope = ExampleScopeRoot(scm: Scm.testInstance);
            });

            test('when the node is contained in own scope', () {
              // Find a node directly contained in chain
              final rootA = rootScope.findNode<int>('rootA');
              expect(rootA?.key, 'rootA');

              final rootB = rootScope.findNode<int>('rootB');
              expect(rootB?.key, 'rootB');

              // Child nodes should find their own nodes
              final childScopeA = rootScope.child('childScopeA')!;
              final childNodeAFromChild =
                  childScopeA.findNode<int>('childNodeA');
              expect(childNodeAFromChild?.key, 'childNodeA');
            });

            test('when the path contains an alias', () {
              final scope = Scope.example();
              scope.mockContent({
                'a': {
                  'b': {
                    'c0|c1|c2': {
                      'd': 0,
                    },
                  },
                },
              });

              // Find the node c
              expect(scope.findNode<int>('a.b.c0.d')?.key, 'd');
              expect(scope.findNode<int>('a.b.c1.d')?.key, 'd');
              expect(scope.findNode<int>('a.b.c2.d')?.key, 'd');
              expect(scope.findNode<int>('a.b.c3.d')?.key, isNull);
            });

            group('when the node is contained in parent chain', () {
              test('part 1', () {
                // Should return nodes from parent chain
                final childScopeA = rootScope.child('childScopeA')!;
                final rootAFromChild = childScopeA.findNode<int>('rootA');
                expect(rootAFromChild?.key, 'rootA');
              });

              test('part 2', () {
                final corpus = Scope.example(key: 'corpus');
                corpus.mockContent({
                  'width': 600.0,
                  'depth': 615.0,
                  'panels': {
                    'rightPanel': {
                      'thickness': 19.0,
                    },
                    'leftPanel': {
                      'thickness': 19.0,
                    },
                    'bottomPanel': ScopeBluePrint(
                      key: 'bottomPanel',
                      nodeOverrides: [
                        NodeBluePrint<double>(
                          key: 'thickness',
                          initialProduct: 19.0,
                          produce: (components, previousProduct) => 19.0,
                        ),
                      ],
                    ),
                  },
                });

                final panel = corpus.findScope('bottomPanel')!;
                final corpusWidth = panel.findNode<double>('corpus.width');
                expect(corpusWidth, isNotNull);
              });
            });

            test('when the node is contained in sibling chain', () {
              // Create a new chain
              final root = Scope.example();

              // Create two child scopes
              Scope(
                bluePrint: const ScopeBluePrint(key: 'childScopeA'),
                parent: root,
              );

              final b = Scope(
                bluePrint: const ScopeBluePrint(key: 'childScopeA'),
                parent: root,
              );

              // Add a NodeA to ChildScopeA
              final nodeA = root.child('childScopeA')!.findOrCreateNode<int>(
                    NodeBluePrint(
                      key: 'nodeA',
                      initialProduct: 0,
                      produce: (components, previous) => previous,
                    ),
                  );

              // ChildScopeB should find the node in ChildScopeA
              final Node<int>? foundNodeA = b.findNode<int>('nodeA');
              expect(foundNodeA, nodeA);
            });

            test('when the node is contained somewhere else', () {
              final root = ExampleScopeRoot(scm: Scm.testInstance);

              // Create a node somewhere deep in the hierarchy
              final grandChildScope =
                  root.child('childScopeA')!.child('grandChildScope')!;

              final grandChildNodeX = Node<int>(
                bluePrint: NodeBluePrint<int>(
                  key: 'grandChildNodeX',
                  initialProduct: 0,
                  produce: (components, previousProduct) => 0,
                ),
                scope: grandChildScope,
              );

              // Search the node from the root
              final foundGRandChildNodeX =
                  root.findNode<int>('grandChildNodeX');
              expect(foundGRandChildNodeX, grandChildNodeX);
            });
          });

          group('null', () {
            group('when node cannot be found', () {
              test('and throwIfNotFound is false or not defined', () {
                final unknownNode = scope.findNode<int>(
                  'Unknown',
                  throwIfNotFound: false,
                );
                expect(unknownNode, isNull);

                final unknownNode1 = scope.findNode<int>('Unknown');
                expect(unknownNode1, isNull);
              });
            });
          });
        });
      });

      group('with scope in key', () {
        group('return', () {
          group('the right node', () {
            test('when the node is contained in own scope', () {
              final rootScope = ExampleScopeRoot(scm: Scm.testInstance);
              final childScopeA = rootScope.child('childScopeA')!;
              final grandChildScope = childScopeA.child('grandChildScope')!;
              final grandChildNodeAExpected = grandChildScope.findNode<int>(
                'grandChildNodeA',
              );

              final grandChildNodeReal = grandChildScope.findNode<int>(
                'childScopeA.grandChildScope.grandChildNodeA',
              );
              expect(grandChildNodeReal, grandChildNodeAExpected);
            });

            test('when the node is contained in parent scope', () {
              final rootScope = ExampleScopeRoot(scm: Scm.testInstance);
              final childScopeA = rootScope.child('childScopeA')!;
              final grandChildScope = childScopeA.child('grandChildScope')!;
              final childNodeAExpected = childScopeA.findNode<int>(
                'childNodeA',
              );

              final childNodeAReal = grandChildScope.findNode<int>(
                'childScopeA.childNodeA',
              );
              expect(childNodeAReal, childNodeAExpected);
            });

            test('when the node is contained in sibling scope', () {
              final rootScope = ExampleScopeRoot(scm: Scm.testInstance);
              final childScopeA = rootScope.child('childScopeA')!;
              final grandChildScope = childScopeA.child('grandChildScope')!;
              final grandChildNodeBExpected = grandChildScope.findNode<int>(
                'grandChildNodeB',
              );

              final grandChildNodeReal = grandChildScope.findNode<int>(
                'childScopeA/grandChildScope/grandChildNodeB',
              );
              expect(grandChildNodeReal, grandChildNodeBExpected);
            });
          });
        });
      });

      group('throws', () {
        test('if the type does not match', () {
          final rootScope = ExampleScopeRoot(scm: Scm.testInstance);
          expect(
            () => rootScope.findNode<String>('rootA'),
            throwsA(
              predicate<ArgumentError>(
                (e) => e
                    .toString()
                    .contains('Node with key "rootA" is not of type String'),
              ),
            ),
          );
        });

        test('if throwIfNotFound is true and node is not found', () {
          final supplyScope = Scope.example();
          expect(
            () => supplyScope.findNode<int>('unknown', throwIfNotFound: true),
            throwsA(
              predicate<ArgumentError>(
                (e) =>
                    e.toString().contains('Node with key "unknown" not found'),
              ),
            ),
          );
        });

        test('if multiple nodes of the same key and type are found', () {
          final supplyScope = ExampleScopeRoot(scm: Scm.testInstance);
          expect(
            () => supplyScope.findNode<int>('grandChildNodeA'),
            throwsA(
              predicate<ArgumentError>(
                (e) => e.toString().contains(
                      'More than one node with key "grandChildNodeA" and '
                      'Type<int> found.',
                    ),
              ),
            ),
          );
        });
      });
    });

    group('hasNode(key)', () {
      test('should return true if the scope has a node with the given key', () {
        final rootScope = ExampleScopeRoot(scm: Scm.testInstance);
        expect(rootScope.hasNode('rootA'), isTrue);
        expect(rootScope.hasNode('rootB'), isTrue);
        expect(rootScope.hasNode('Unknown'), isFalse);

        final childScope = rootScope.child('childScopeA')!;
        expect(childScope.hasNode('childNodeA'), isTrue);
        expect(childScope.hasNode('childNodeB'), isTrue);
        expect(childScope.hasNode('Unknown'), isFalse);
        expect(childScope.hasNode('rootA'), isTrue);
      });
    });

    group('plugins', () {
      group('addPlugin(plugin)', () {
        group('should throw', () {
          test('if the plugin is already added', () {
            const plugin = ScopePlugin(nodePlugins: {}, key: 'plugin');
            scope.addPlugin(plugin);
            expect(
              () => scope.addPlugin(plugin),
              throwsA(
                predicate<ArgumentError>(
                  (e) => e.toString().contains(
                        'Plugin already added.',
                      ),
                ),
              ),
            );
          });

          test('when there are multiple node plugins with the same key', () {
            final plugin0 = ScopePlugin(
              key: 'plugin0',
              nodePlugins: {
                'node0': NodeBluePrint.example(key: 'key'),
                'node1': NodeBluePrint.example(key: 'key'),
              },
            );

            expect(
              () => scope.addPlugin(plugin0),
              throwsA(
                predicate<ArgumentError>(
                  (e) => e.toString().contains(
                        'Found multiple node plugins with key "key"',
                      ),
                ),
              ),
            );
          });
          test('when host nodes cannot be found', () {
            final plugin = ScopePlugin(
              key: 'plugin0',
              nodePlugins: {
                'unknown0': NodeBluePrint.example(key: 'unknown'),
                'unknown1': NodeBluePrint.example(key: 'unknown1'),
              },
            );
            expect(
              () => scope.addPlugin(plugin),
              throwsA(
                predicate<ArgumentError>(
                  (e) => e.toString().contains(
                        'Host nodes not found: unknown0, unknown1',
                      ),
                ),
              ),
            );
          });

          test('when types of host nodes and plugin nodes do not match', () {
            final scope = Scope.example();
            scope.mockContent({
              'node0': 'string',
            });

            const plugin = ScopePlugin(
              key: 'plugin0',
              nodePlugins: {
                'node0': NodeBluePrint<int>(key: 'plugin0', initialProduct: 0),
              },
            );

            expect(
              () => scope.addPlugin(plugin),
              throwsA(
                predicate<Error>(
                  (e) => e.toString().contains(
                        '\'Node<String>\' is not a subtype of type '
                        '\'Node<int>\' of \'host\'',
                      ),
                ),
              ),
            );
          });
        });

        test('should add the plugin to the list of plugins', () {
          const plugin = ScopePlugin(
            nodePlugins: {},
            key: 'plugin0',
          );
          scope.addPlugin(plugin);
          expect(scope.plugins, [plugin]);
        });

        test('should add the node plugins to their corresponding hosts', () {
          // Define an existing node and scope hierarchy
          final scope = Scope.example();
          scope.mockContent({
            'a': {
              'b': {
                'n0': 0,
              },
              'c': {
                'n1': 0,
              },
            },
          });

          // Get the two nodes we want to add plugins to
          final node0 = scope.findNode<int>('a.b.n0')!;
          final node1 = scope.findNode<int>('a.c.n1')!;

          // Define a node plugin that modifies the two nodes
          final scopePlugin = ScopePlugin(
            key: 'plugin0',
            nodePlugins: {
              'b.n0': NodeBluePrint<int>(
                key: 'byTwo',
                initialProduct: 0,
                produce: (components, previousProduct) =>
                    (components.first as int) * 2,
              ),
              'a.c.n1': NodeBluePrint<int>(
                key: 'byThree',
                initialProduct: 0,
                produce: (components, previousProduct) =>
                    (components.first as int) * 3,
              ),
            },
          );

          // Add the plugin to the scope
          scope.addPlugin(scopePlugin);

          // The plugins should have been added to the nodes
          expect(node0.plugins, hasLength(1));
          expect(node0.plugins.first.key, 'byTwo');
          expect(node1.plugins, hasLength(1));
          expect(node1.plugins.first.key, 'byThree');

          // Remove the plugin from the scope
          scope.removePlugin(scopePlugin);

          // The plugins should have been removed from the nodes
          expect(node0.plugins, isEmpty);
          expect(node1.plugins, isEmpty);
        });
      });

      group('removePlugin(plugin)', () {
        group('should throw', () {
          test('if the plugin is not added', () {
            const plugin = ScopePlugin(
              key: 'plugin0',
              nodePlugins: {},
            );
            expect(
              () => scope.removePlugin(plugin),
              throwsA(
                predicate<ArgumentError>(
                  (e) => e.toString().contains(
                        'Plugin "plugin0" not found.',
                      ),
                ),
              ),
            );
          });

          test('if one of the plugin nodes in the plugin is not found', () {
            final scope = Scope.example();
            scope.mockContent({
              'node0': 0,
            });

            // Create a plugin with a node that does not exist
            const plugin = ScopePlugin(
              key: 'plugin0',
              nodePlugins: {
                'node0':
                    NodeBluePrint<int>(key: 'pluginNode0', initialProduct: 0),
              },
            );

            // Add the plugin
            scope.addPlugin(plugin);

            // Remove the node that the plugin is supposed to modify
            final pluginNode = scope.findNode<int>('pluginNode0')!;
            pluginNode.dispose();

            // Try to remove the plugin
            expect(
              () => scope.removePlugin(plugin),
              throwsA(
                predicate<ArgumentError>(
                  (e) => e.toString().contains(
                        'PluginNode with key "pluginNode0" not found.',
                      ),
                ),
              ),
            );
          });
        });

        test('should remove the plugin from the list of plugins', () {
          const plugin = ScopePlugin(
            key: 'plugin0',
            nodePlugins: {},
          );
          scope.addPlugin(plugin);
          scope.removePlugin(plugin);
          expect(scope.plugins, isEmpty);
        });

        test('should remove the node plugins from it\'s hosts', () {
          // Is tested in addPlugin()
        });
      });
    });

    group('mockContent', () {
      test('should create a mock content', () {
        final scope = Scope.example();
        scope.mockContent({
          'a': {
            'int': 5,
            'b': {
              'int': 10,
              'double': 3.14,
              'string': 'hello',
              'bool': true,
              'enum': const NodeBluePrint<TestEnum>(
                key: 'enum',
                initialProduct: TestEnum.a,
              ),
              'c': [
                const ScopeBluePrint(key: 'd'),
                const ScopeBluePrint(key: 'e'),
                const ScopeBluePrint(key: 'f'),
              ],
              'g': const ScopeBluePrint(key: 'g'),
            },
          },
        });

        expect(scope.findNode<int>('a.int')?.product, 5);
        expect(scope.findNode<int>('a.b.int')?.product, 10);
        expect(scope.findNode<double>('a.b.double')?.product, 3.14);
        expect(scope.findNode<bool>('a.b.bool')?.product, true);
        expect(scope.findNode<TestEnum>('a.b.enum')?.product, TestEnum.a);

        expect(scope.findScope('a.b.c.d')!.key, 'd');
        expect(scope.findScope('a.b.c.e')!.key, 'e');
        expect(scope.findScope('a.b.c.f')!.key, 'f');
        expect(scope.findScope('a.b.g')!.key, 'g');
      });

      group('should throw', () {
        test('if an unsupported type is mocked', () {
          final scope = Scope.example();
          expect(
            () => scope.mockContent({
              'a': {
                'unsupported': TestEnum.a,
              },
            }),
            throwsA(
              predicate<ArgumentError>(
                (e) => e.toString().contains(
                      'Type TestEnum not supported. '
                      'Use NodeBluePrint<TestEnum> instead.',
                    ),
              ),
            ),
          );
        });

        test('if a list does not contain ScopeBluePrint', () {
          final scope = Scope.example();
          expect(
            () => scope.mockContent({
              'a': {
                'b': [5],
              },
            }),
            throwsA(
              predicate<ArgumentError>(
                (e) => e.toString().contains(
                      'Lists must only contain ScopeBluePrints.',
                    ),
              ),
            ),
          );
        });
      });
    });
  });
}
