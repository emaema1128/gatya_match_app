// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_thread_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$chatThreadControllerHash() =>
    r'b5afe5d2ea75686f0c6da1b673a89a00d50efe22';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$ChatThreadController
    extends BuildlessAutoDisposeAsyncNotifier<ChatThreadState> {
  late final int partnerId;

  FutureOr<ChatThreadState> build(int partnerId);
}

/// See also [ChatThreadController].
@ProviderFor(ChatThreadController)
const chatThreadControllerProvider = ChatThreadControllerFamily();

/// See also [ChatThreadController].
class ChatThreadControllerFamily extends Family<AsyncValue<ChatThreadState>> {
  /// See also [ChatThreadController].
  const ChatThreadControllerFamily();

  /// See also [ChatThreadController].
  ChatThreadControllerProvider call(int partnerId) {
    return ChatThreadControllerProvider(partnerId);
  }

  @override
  ChatThreadControllerProvider getProviderOverride(
    covariant ChatThreadControllerProvider provider,
  ) {
    return call(provider.partnerId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'chatThreadControllerProvider';
}

/// See also [ChatThreadController].
class ChatThreadControllerProvider
    extends
        AutoDisposeAsyncNotifierProviderImpl<
          ChatThreadController,
          ChatThreadState
        > {
  /// See also [ChatThreadController].
  ChatThreadControllerProvider(int partnerId)
    : this._internal(
        () => ChatThreadController()..partnerId = partnerId,
        from: chatThreadControllerProvider,
        name: r'chatThreadControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$chatThreadControllerHash,
        dependencies: ChatThreadControllerFamily._dependencies,
        allTransitiveDependencies:
            ChatThreadControllerFamily._allTransitiveDependencies,
        partnerId: partnerId,
      );

  ChatThreadControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.partnerId,
  }) : super.internal();

  final int partnerId;

  @override
  FutureOr<ChatThreadState> runNotifierBuild(
    covariant ChatThreadController notifier,
  ) {
    return notifier.build(partnerId);
  }

  @override
  Override overrideWith(ChatThreadController Function() create) {
    return ProviderOverride(
      origin: this,
      override: ChatThreadControllerProvider._internal(
        () => create()..partnerId = partnerId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        partnerId: partnerId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<ChatThreadController, ChatThreadState>
  createElement() {
    return _ChatThreadControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ChatThreadControllerProvider &&
        other.partnerId == partnerId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, partnerId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ChatThreadControllerRef
    on AutoDisposeAsyncNotifierProviderRef<ChatThreadState> {
  /// The parameter `partnerId` of this provider.
  int get partnerId;
}

class _ChatThreadControllerProviderElement
    extends
        AutoDisposeAsyncNotifierProviderElement<
          ChatThreadController,
          ChatThreadState
        >
    with ChatThreadControllerRef {
  _ChatThreadControllerProviderElement(super.provider);

  @override
  int get partnerId => (origin as ChatThreadControllerProvider).partnerId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
