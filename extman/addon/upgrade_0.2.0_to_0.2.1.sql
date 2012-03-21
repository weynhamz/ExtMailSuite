use extmail;
ALTER TABLE `mailbox` ADD `clearpwd` VARCHAR(255) NOT NULL AFTER `password`;
