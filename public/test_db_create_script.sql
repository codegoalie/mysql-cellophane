CREATE USER 'cello_test'@'localhost';
GRANT ALL *.* TO 'cello_test'@'localhost';
CREATE DATABASE cell_test;
USE cello_test;
CREATE TABLE test_one (
  id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(20) NULL DEFAULT NULL,
  age INT NULL DEFAULT NULL);
INSERT INTO test_one (name, age) VALUES ('Chris', 26), ('Hayley', 24);
