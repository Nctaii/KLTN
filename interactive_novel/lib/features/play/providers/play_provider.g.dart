// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'play_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$playServiceHash() => r'8a97797cdced0f59b425fa18a31ccf0c98f13836';

/// See also [playService].
@ProviderFor(playService)
final playServiceProvider = AutoDisposeProvider<PlayService>.internal(
  playService,
  name: r'playServiceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$playServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PlayServiceRef = AutoDisposeProviderRef<PlayService>;
String _$mySessionsHash() => r'96905d8e1ed4f27ae5b72e4998f41a6f00412c29';

/// See also [MySessions].
@ProviderFor(MySessions)
final mySessionsProvider = AutoDisposeAsyncNotifierProvider<MySessions,
    List<PlaySessionSummary>>.internal(
  MySessions.new,
  name: r'mySessionsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$mySessionsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$MySessions = AutoDisposeAsyncNotifier<List<PlaySessionSummary>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
