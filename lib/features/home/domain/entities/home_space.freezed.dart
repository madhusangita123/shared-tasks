// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'home_space.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$HomeSpace {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  List<String> get memberUids => throw _privateConstructorUsedError;
  int get openTaskCount => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;
  List<MemberAvatar> get memberAvatars => throw _privateConstructorUsedError;

  /// Create a copy of HomeSpace
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $HomeSpaceCopyWith<HomeSpace> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $HomeSpaceCopyWith<$Res> {
  factory $HomeSpaceCopyWith(HomeSpace value, $Res Function(HomeSpace) then) =
      _$HomeSpaceCopyWithImpl<$Res, HomeSpace>;
  @useResult
  $Res call({
    String id,
    String name,
    List<String> memberUids,
    int openTaskCount,
    DateTime updatedAt,
    List<MemberAvatar> memberAvatars,
  });
}

/// @nodoc
class _$HomeSpaceCopyWithImpl<$Res, $Val extends HomeSpace>
    implements $HomeSpaceCopyWith<$Res> {
  _$HomeSpaceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of HomeSpace
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? memberUids = null,
    Object? openTaskCount = null,
    Object? updatedAt = null,
    Object? memberAvatars = null,
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
            memberUids: null == memberUids
                ? _value.memberUids
                : memberUids // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            openTaskCount: null == openTaskCount
                ? _value.openTaskCount
                : openTaskCount // ignore: cast_nullable_to_non_nullable
                      as int,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            memberAvatars: null == memberAvatars
                ? _value.memberAvatars
                : memberAvatars // ignore: cast_nullable_to_non_nullable
                      as List<MemberAvatar>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$HomeSpaceImplCopyWith<$Res>
    implements $HomeSpaceCopyWith<$Res> {
  factory _$$HomeSpaceImplCopyWith(
    _$HomeSpaceImpl value,
    $Res Function(_$HomeSpaceImpl) then,
  ) = __$$HomeSpaceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    List<String> memberUids,
    int openTaskCount,
    DateTime updatedAt,
    List<MemberAvatar> memberAvatars,
  });
}

/// @nodoc
class __$$HomeSpaceImplCopyWithImpl<$Res>
    extends _$HomeSpaceCopyWithImpl<$Res, _$HomeSpaceImpl>
    implements _$$HomeSpaceImplCopyWith<$Res> {
  __$$HomeSpaceImplCopyWithImpl(
    _$HomeSpaceImpl _value,
    $Res Function(_$HomeSpaceImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of HomeSpace
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? memberUids = null,
    Object? openTaskCount = null,
    Object? updatedAt = null,
    Object? memberAvatars = null,
  }) {
    return _then(
      _$HomeSpaceImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        memberUids: null == memberUids
            ? _value._memberUids
            : memberUids // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        openTaskCount: null == openTaskCount
            ? _value.openTaskCount
            : openTaskCount // ignore: cast_nullable_to_non_nullable
                  as int,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        memberAvatars: null == memberAvatars
            ? _value._memberAvatars
            : memberAvatars // ignore: cast_nullable_to_non_nullable
                  as List<MemberAvatar>,
      ),
    );
  }
}

/// @nodoc

class _$HomeSpaceImpl extends _HomeSpace {
  const _$HomeSpaceImpl({
    required this.id,
    required this.name,
    required final List<String> memberUids,
    required this.openTaskCount,
    required this.updatedAt,
    required final List<MemberAvatar> memberAvatars,
  }) : _memberUids = memberUids,
       _memberAvatars = memberAvatars,
       super._();

  @override
  final String id;
  @override
  final String name;
  final List<String> _memberUids;
  @override
  List<String> get memberUids {
    if (_memberUids is EqualUnmodifiableListView) return _memberUids;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_memberUids);
  }

  @override
  final int openTaskCount;
  @override
  final DateTime updatedAt;
  final List<MemberAvatar> _memberAvatars;
  @override
  List<MemberAvatar> get memberAvatars {
    if (_memberAvatars is EqualUnmodifiableListView) return _memberAvatars;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_memberAvatars);
  }

  @override
  String toString() {
    return 'HomeSpace(id: $id, name: $name, memberUids: $memberUids, openTaskCount: $openTaskCount, updatedAt: $updatedAt, memberAvatars: $memberAvatars)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HomeSpaceImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            const DeepCollectionEquality().equals(
              other._memberUids,
              _memberUids,
            ) &&
            (identical(other.openTaskCount, openTaskCount) ||
                other.openTaskCount == openTaskCount) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            const DeepCollectionEquality().equals(
              other._memberAvatars,
              _memberAvatars,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    const DeepCollectionEquality().hash(_memberUids),
    openTaskCount,
    updatedAt,
    const DeepCollectionEquality().hash(_memberAvatars),
  );

  /// Create a copy of HomeSpace
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$HomeSpaceImplCopyWith<_$HomeSpaceImpl> get copyWith =>
      __$$HomeSpaceImplCopyWithImpl<_$HomeSpaceImpl>(this, _$identity);
}

abstract class _HomeSpace extends HomeSpace {
  const factory _HomeSpace({
    required final String id,
    required final String name,
    required final List<String> memberUids,
    required final int openTaskCount,
    required final DateTime updatedAt,
    required final List<MemberAvatar> memberAvatars,
  }) = _$HomeSpaceImpl;
  const _HomeSpace._() : super._();

  @override
  String get id;
  @override
  String get name;
  @override
  List<String> get memberUids;
  @override
  int get openTaskCount;
  @override
  DateTime get updatedAt;
  @override
  List<MemberAvatar> get memberAvatars;

  /// Create a copy of HomeSpace
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$HomeSpaceImplCopyWith<_$HomeSpaceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
