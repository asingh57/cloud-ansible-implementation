CREATE DATABASE IF NOT EXISTS preferencedb;

CREATE TABLE IF NOT EXISTS preferencedb.preferences (
  preference_id INT NOT NULL AUTO_INCREMENT, 
  name VARCHAR(30) NOT NULL UNIQUE,
  colour VARCHAR(20) NOT NULL, 
  animal ENUM("cat","dog") NOT NULL,
  PRIMARY KEY(preference_id)
);

DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
/*
Disable remote root access
*/

FLUSH PRIVILEGES; 
