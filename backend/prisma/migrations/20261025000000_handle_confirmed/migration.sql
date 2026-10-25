-- @아이디(nickname)는 가입 때 한 번만 정한다. 소셜 가입은 임시 아이디로 만들고
-- 첫 화면에서 정하면 true가 된다.
ALTER TABLE `User` ADD COLUMN `handleConfirmed` BOOLEAN NOT NULL DEFAULT true;
