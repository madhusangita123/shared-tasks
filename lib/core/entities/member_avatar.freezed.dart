// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'member_avatar.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$MemberAvatar {
  String get uid => throw _privateConstructorUsedError;
  String get displayName => throw _privateConstructorUsedError;
  String? get photoUrl => throw _privateConstructorUsedError;

  /// Create a copy of MemberAvatar
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MemberAvatarCopyWith<MemberAvatar> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MemberAvatarCopyWith<$Res> {
  factory $MemberAvatarCopyWith(
    MemberAvatar value,
    $Res Function(MemberAvatar) then,
  ) = _$MemberAvatarCopyWithImpl<$Res, MemberAvatar>;
  @useResult
  $Res call({String uid, String displayName, String? photoUrl});
}

/// @nodoc
class _$MemberAvatarCopyWithImpl<$Res, $Val extends MemberAvatar>
    implements $MemberAvatarCopyWith<$Res> {
  _$MemberAvatarCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MemberAvatar
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? uid = null,
    Object? displayName = null,
    Object? photoUrl = freezed,
  }) {
    return _then(
      _value.copyWith(
            uid: null == uid
                ? _value.uid
                : uid // ignore: cast_nullable_to_non_nullable
                      as String,
            displayName: null == displayName
                ? _value.displayName
                : displayName // ignore: cast_nullable_to_non_nullable
                      as String,
            photoUrl: freezed == photoUrl
                ? _value.photoUrl
                : photoUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MemberAvatarImplCopyWith<$Res>
    implements $MemberAvatarCopyWith<$Res> {
  factory _$$MemberAvatarImplCopyWith(
    _$MemberAvatarImpl value,
    $Res Function(_$MemberAvatarImpl) then,
  ) = __$$MemberAvatarImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String uid, String displayName, String? photoUrl});
}

/// @nodoc
class __$$MemberAvatarImplCopyWithImpl<$Res>
    extends _$MemberAvatarCopyWithImpl<$Res, _$MemberAvatarImpl>
    implements _$$MemberAvatarImplCopyWith<$Res> {
  __$$MemberAvatarImplCopyWithImpl(
    _$MemberAvatarImpl _value,
    $Res Function(_$MemberAvatarImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MemberAvatar
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? uid = null,
    Object? displayName = null,
    Object? photoUrl = freezed,
  }) {
    return _then(
      _$MemberAvatarImpl(
        uid: null == uid
            ? _value.uid
            : uid // ignore: cast_nullable_to_non_nullable
                  as String,
        displayName: null == displayName
            ? _value.displayName
            : displayName // ignore: cast_nullable_to_non_nullable
                  as String,
        photoUrl: freezed == photoUrl
            ? _value.photoUrl
            : photoUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$MemberAvatarImpl implements _MemberAvatar {
  const _$MemberAvatarImpl({
    required this.uid,
    required this.displayName,
    this.photoUrl,
  });

  @override
  final String uid;
  @override
  final String displayName;
  @override
  final String? photoUrl;

  @override
  String toString() {
    return 'MemberAvatar(uid: $uid, displayName: $displayName, photoUrl: $photoUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MemberAvatarImpl &&
            (identical(other.uid, uid) || other.uid == uid) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.photoUrl, photoUrl) ||
                other.photoUrl == photoUrl));
  }

  @override
  int get hashCode => Object.hash(runtimeType, uid, displayName, photoUrl);

  /// Create a copy of MemberAvatar
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MemberAvatarImplCopyWith<_$MemberAvatarImpl> get copyWith =>
      __$$MemberAvatarImplCopyWithImpl<_$MemberAvatarImpl>(this, _$identity);
}

abstract class _MemberAvatar implements MemberAvatar {
  const factory _MemberAvatar({
    required final String uid,
    required final String displayName,
    final String? photoUrl,
  }) = _$MemberAvatarImpl;

  @override
  String get uid;
  @override
  String get displayName;
  @override
  String? get photoUrl;

  /// Create a copy of MemberAvatar
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MemberAvatarImplCopyWith<_$MemberAvatarImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
