/**
 * Firestore collection and field name constants used by Cloud Functions.
 *
 * These MUST stay in sync with `lib/core/constants/firestore_constants.dart`
 * — that file is the source of truth for every collection/field name string
 * in the app. Do not guess a value here; when adding or changing one,
 * verify it against `FirestoreConstants` in that file first.
 */

export const SPACES_COLLECTION = "spaces";
export const MEMBER_UIDS = "memberUids";
export const INVITE_TOKEN = "inviteToken";
export const INVITE_EXPIRES_AT = "inviteExpiresAt";
export const UPDATED_AT = "updatedAt";
