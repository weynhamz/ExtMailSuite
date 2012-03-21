use extmail;
ALTER TABLE `mailbox` DROP `authorizedservices`;
ALTER TABLE `mailbox` ADD `mailhost` VARCHAR( 255 ) NOT NULL AFTER `name`;
ALTER TABLE `mailbox` ADD `disablesmtpd` smallint(1);
ALTER TABLE `mailbox` ADD `disablesmtp` smallint(1);
ALTER TABLE `mailbox` ADD `disablewebmail` smallint(1);
ALTER TABLE `mailbox` ADD `disablenetdisk` smallint(1);
ALTER TABLE `mailbox` ADD `disableimap` smallint(1);
ALTER TABLE `mailbox` ADD `disablepop3` smallint(1);
