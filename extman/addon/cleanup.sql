/*
* cleanup.sql - a sql script to destroy extmail data
*               use it as your own risk, it will purge
*               all data and your accounts will lost!!
*
* Author: He zhiqiang <hzqbbc@hzqbbc.com>
*/

use mysql;
DELETE from db where Db='extmail' AND User='extmail';
DELETE from user where User='extmail' AND Host='localhost';
DELETE from db where Db='extmail' AND User='webman';
DELETE from user where User='webman' AND Host='localhost';
DROP DATABASE extmail;
