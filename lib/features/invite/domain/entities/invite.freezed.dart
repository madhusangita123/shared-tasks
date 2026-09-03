// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'invite.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$Invite {
  String get spaceId => throw _privateConstructorUsedError;
  String get token => throw _privateConstructorUsedError;
  DateTime get expiresAt => throw _privateConstructorUsedError;

  /// Create a copy of Invite
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $InviteCopyWith<Invite> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $InviteCopyWith<$Res> {
  factory $InviteCopyWith(Invite value, $Res Function(Invite) then) =
      _$InviteCopyWithImpl<$Res, Invite>;
  @useResult
  $Res call({String spaceId, String token, DateTime expiresAt});
}

/// @nodoc
class _$InviteCopyWithImpl<$Res, $Val extends Invite>
    implements $InviteCopyWith<$Res> {
  _$InviteCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Invite
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? spaceId = null,
    Object? token = null,
    Object? expiresAt = null,
  }) {
    return _then(
      _value.copyWith(
            spaceId: null == spaceId
                ? _value.spaceId
                : spaceId // ignore: cast_nullable_to_non_nullable
                      as String,
            token: null == token
                ? _value.token
                : token // ignore: cast_nullable_to_non_nullable
                      as String,
            expiresAt: null == expiresAt
                ? _value.expiresAt
                : expiresAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$InviteImplCopyWith<$Res> implements $InviteCopyWith<$Res> {
  factory _$$InviteImplCopyWith(
    _$InviteImpl value,
    $Res Function(_$InviteImpl) then,
  ) = __$$InviteImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String spaceId, String token, DateTime expiresAt});
}

/// @nodoc
class __$$InviteImplCopyWithImpl<$Res>
    extends _$InviteCopyWithImpl<$Res, _$InviteImpl>
    implements _$$InviteImplCopyWith<$Res> {
  __$$InviteImplCopyWithImpl(
    _$InviteImpl _value,
    $Res Function(_$InviteImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Invite
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? spaceId = null,
    Object? token = null,
    Object? expiresAt = null,
  }) {
    return _then(
      _$InviteImpl(
        spaceId: null == spaceId
            ? _value.spaceId
            : spaceId // ignore: cast_nullable_to_non_nullable
                  as String,
        token: null == token
            ? _value.token
            : token // ignore: cast_nullable_to_non_nullable
                  as String,
        expiresAt: null == expiresAt
            ? _value.expiresAt
            : expiresAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc

class _$InviteImpl extends _Invite {
  const _$InviteImpl({
    required this.spaceId,
    required this.token,
    required this.expiresAt,
  }) : super._();

  @override
  final String spaceId;
  @override
  final String token;
  @override
  final DateTime expiresAt;

  @override
  String toString() {
    return 'Invite(spaceId: $spaceId, token: $token, expiresAt: $expiresAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$InviteImpl &&
            (identical(other.spaceId, spaceId) || other.spaceId == spaceId) &&
            (identical(other.token, token) || other.token == token) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt));
  }

  @override
  int get hashCode => Object.hash(runtimeType, spaceId, token, expiresAt);

  /// Create a copy of Invite
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$InviteImplCopyWith<_$InviteImpl> get copyWith =>
      __$$InviteImplCopyWithImpl<_$InviteImpl>(this, _$identity);
}

abstract class _Invite extends Invite {
  const factory _Invite({
    required final String spaceId,
    required final String token,
    required final DateTime expiresAt,
  }) = _$InviteImpl;
  const _Invite._() : super._();

  @override
  String get spaceId;
  @override
  String get token;
  @override
  DateTime get expiresAt;

  /// Create a copy of Invite
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$InviteImplCopyWith<_$InviteImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
