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

insert into ex_users (username, password, name, email, affi) values('student1', 'student1234', '홍길동', 'coreen@example.org', 'student');
insert into ex_users (username, password, name, email, affi) values('student2', 'student1234', 'Mary Kim', 'coreen@example.org', '교수');
insert into ex_users (username, password, name, email, affi) values('student3', 'student1234', '선우용녀', 'coreen@example.org', '직원');
insert into ex_users (username, password, name, email, affi) values('student4', 'student1234', '김숙', 'coreen@example.org', '대학원생');
insert into ex_users (username, password, name, email, affi) values('student5', 'student1234', 'Sweet Hony Hyun', 'coreen@example.org', '대학원생');

