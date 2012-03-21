use extmail;
ALTER TABLE `mailbox` ADD `question` text NOT NULL default '' AFTER `disablepop3`;
ALTER TABLE `mailbox` ADD `answer` text NOT NULL default '' AFTER `question`;
ALTER table `domain` change `expiredate` `expiredate` DATE not null default '0000-00-00';
ALTER table `mailbox` change `expiredate` `expiredate` DATE not null default '0000-00-00';
ALTER table `manager` change `expiredate` `expiredate` DATE not null default '0000-00-00';
ALTER table `alias` drop `expiredate`;
