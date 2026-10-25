/**
 * @아이디(User.nickname) 규칙: 영문 소문자·숫자·밑줄·마침표 3~20자.
 * 마침표로 시작·끝나거나 연속될 수 없다. 저장 전 소문자로 통일한다.
 * 가입(또는 소셜 가입 직후 첫 화면)에서 한 번 정하면 바꿀 수 없다.
 */
export const HANDLE_RE = /^(?!\.)(?!.*\.\.)[a-z0-9_.]{3,20}(?<!\.)$/;
export const HANDLE_MESSAGE = '아이디는 영문 소문자·숫자·밑줄(_)·마침표(.) 3~20자예요';

export const normalizeHandle = (v: unknown) =>
  typeof v === 'string' ? v.trim().toLowerCase() : v;
