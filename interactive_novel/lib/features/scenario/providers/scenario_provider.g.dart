// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scenario_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$scenarioServiceHash() => r'bab863dcd4a1d4cd5d7a004f1e08202cbbf34c5a';

/// See also [scenarioService].
@ProviderFor(scenarioService)
final scenarioServiceProvider = AutoDisposeProvider<ScenarioService>.internal(
  scenarioService,
  name: r'scenarioServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$scenarioServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ScenarioServiceRef = AutoDisposeProviderRef<ScenarioService>;
String _$scenarioListHash() => r'f8139e0c1a5d974d9c5e41f9e931e0d633d854f5';

/// See also [ScenarioList].
@ProviderFor(ScenarioList)
final scenarioListProvider = AutoDisposeAsyncNotifierProvider<ScenarioList,
    List<ScenarioSummary>>.internal(
  ScenarioList.new,
  name: r'scenarioListProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$scenarioListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ScenarioList = AutoDisposeAsyncNotifier<List<ScenarioSummary>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
