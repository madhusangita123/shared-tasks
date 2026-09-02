// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'space.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$Space {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get ownerUid => throw _privateConstructorUsedError;
  List<String> get memberUids => throw _privateConstructorUsedError;
  String get inviteToken => throw _privateConstructorUsedError;
  DateTime get inviteExpiresAt => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Create a copy of Space
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SpaceCopyWith<Space> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SpaceCopyWith<$Res> {
  factory $SpaceCopyWith(Space value, $Res Function(Space) then) =
      _$SpaceCopyWithImpl<$Res, Space>;
  @useResult
  $Res call({
    String id,
    String name,
    String ownerUid,
    List<String> memberUids,
    String inviteToken,
    DateTime inviteExpiresAt,
    DateTime createdAt,
  });
}

/// @nodoc
class _$SpaceCopyWithImpl<$Res, $Val extends Space>
    implements $SpaceCopyWith<$Res> {
  _$SpaceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Space
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? ownerUid = null,
    Object? memberUids = null,
    Object? inviteToken = null,
    Object? inviteExpiresAt = null,
    Object? createdAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            ownerUid: null == ownerUid
                ? _value.ownerUid
                : ownerUid // ignore: cast_nullable_to_non_nullable
                      as String,
            memberUids: null == memberUids
                ? _value.memberUids
                : memberUids // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            inviteToken: null == inviteToken
                ? _value.inviteToken
                : inviteToken // ignore: cast_nullable_to_non_nullable
                      as String,
            inviteExpiresAt: null == inviteExpiresAt
                ? _value.inviteExpiresAt
                : inviteExpiresAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SpaceImplCopyWith<$Res> implements $SpaceCopyWith<$Res> {
  factory _$$SpaceImplCopyWith(
    _$SpaceImpl value,
    $Res Function(_$SpaceImpl) then,
  ) = __$$SpaceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String ownerUid,
    List<String> memberUids,
    String inviteToken,
    DateTime inviteExpiresAt,
    DateTime createdAt,
  });
}

/// @nodoc
class __$$SpaceImplCopyWithImpl<$Res>
    extends _$SpaceCopyWithImpl<$Res, _$SpaceImpl>
    implements _$$SpaceImplCopyWith<$Res> {
  __$$SpaceImplCopyWithImpl(
    _$SpaceImpl _value,
    $Res Function(_$SpaceImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Space
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? ownerUid = null,
    Object? memberUids = null,
    Object? inviteToken = null,
    Object? inviteExpiresAt = null,
    Object? createdAt = null,
  }) {
    return _then(
      _$SpaceImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        ownerUid: null == ownerUid
            ? _value.ownerUid
            : ownerUid // ignore: cast_nullable_to_non_nullable
                  as String,
        memberUids: null == memberUids
            ? _value._memberUids
            : memberUids // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        inviteToken: null == inviteToken
            ? _value.inviteToken
            : inviteToken // ignore: cast_nullable_to_non_nullable
                  as String,
        inviteExpiresAt: null == inviteExpiresAt
            ? _value.inviteExpiresAt
            : inviteExpiresAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc

class _$SpaceImpl implements _Space {
  const _$SpaceImpl({
    required this.id,
    required this.name,
    required this.ownerUid,
    required final List<String> memberUids,
    required this.inviteToken,
    required this.inviteExpiresAt,
    required this.createdAt,
  }) : _memberUids = memberUids;

  @override
  final String id;
  @override
  final String name;
  @override
  final String ownerUid;
  final List<String> _memberUids;
  @override
  List<String> get memberUids {
    if (_memberUids is EqualUnmodifiableListView) return _memberUids;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_memberUids);
  }

  @override
  final String inviteToken;
  @override
  final DateTime inviteExpiresAt;
  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'Space(id: $id, name: $name, ownerUid: $ownerUid, memberUids: $memberUids, inviteToken: $inviteToken, inviteExpiresAt: $inviteExpiresAt, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SpaceImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.ownerUid, ownerUid) ||
                other.ownerUid == ownerUid) &&
            const DeepCollectionEquality().equals(
              other._memberUids,
              _memberUids,
            ) &&
            (identical(other.inviteToken, inviteToken) ||
                other.inviteToken == inviteToken) &&
            (identical(other.inviteExpiresAt, inviteExpiresAt) ||
                other.inviteExpiresAt == inviteExpiresAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    ownerUid,
    const DeepCollectionEquality().hash(_memberUids),
    inviteToken,
    inviteExpiresAt,
    createdAt,
  );

  /// Create a copy of Space
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SpaceImplCopyWith<_$SpaceImpl> get copyWith =>
      __$$SpaceImplCopyWithImpl<_$SpaceImpl>(this, _$identity);
}

abstract class _Space implements Space {
  const factory _Space({
    required final String id,
    required final String name,
    required final String ownerUid,
    required final List<String> memberUids,
    required final String inviteToken,
    required final DateTime inviteExpiresAt,
    required final DateTime createdAt,
  }) = _$SpaceImpl;

  @override
  String get id;
  @override
  String get name;
  @override
  String get ownerUid;
  @override
  List<String> get memberUids;
  @override
  String get inviteToken;
  @override
  DateTime get inviteExpiresAt;
  @override
  DateTime get createdAt;

  /// Create a copy of Space
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SpaceImplCopyWith<_$SpaceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
