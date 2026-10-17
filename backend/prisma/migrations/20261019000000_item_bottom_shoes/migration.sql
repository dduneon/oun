-- 하의·신발 카테고리(= 장착 슬롯). 가구는 상점에서 내렸지만 기존 데이터 때문에 값은 남긴다.
ALTER TABLE `Item` MODIFY `category` ENUM('clothing', 'hair', 'prop', 'furniture', 'bottom', 'shoes') NOT NULL;
