create database user_db_test DEFAULT CHARACTER SET utf8;

use user_db_test;

create table ex_users(
	pid int(10) not null auto_increment primary key,
	username varchar(30),
	password varchar(20),
	name	varchar(30),
	email 	varchar(30),
	affi	varchar(30)
)default charset=utf8;

insert into ex_users (username, password, name, email, affi) values('student', 'student1234', 'coreen', 'coreen@example.org', 'student');
insert into ex_users (username, password, name, email, affi) values('st1', 'st1', 'coreen', 'coreen@example.org', '교수');
