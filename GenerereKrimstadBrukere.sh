#!/bin/sh

Doit(){
	ImporterePersonerFraKrimstad
	InsertIntoOic|psql oic
	psql --dbname oic --tuples-only -c "select 'Antall rader i users: '||count(*) from users"
	psql --dbname oic --tuples-only -c "select 'Antall rader i user_info: '||count(*) from user_info"
	psql --dbname oic --tuples-only -c "select 'Antall rader i authorities: '||count(*) from authorities"
}
CleanupTempTables(){
	psql --dbname oic --tuples-only -c 'delete from users_TEMP'
	psql --dbname oic --tuples-only -c 'delete from authorities_TEMP'
	psql --dbname oic --tuples-only -c 'delete from user_info_TEMP'
}
InsertIntoOic(){
	cat<<-!
	START TRANSACTION;

	INSERT INTO users_TEMP (username, password, enabled) VALUES
	 ('admin','password',true),
	 ('user','password',true);

	insert into users_temp select 
		fodselsnummer as username, 
		'password' as password, 
		true as enabled 
	from personer where fodselsnummer is not null and fodselsnummer not like '';


	INSERT INTO authorities_TEMP (username, authority) VALUES
	  ('admin','ROLE_ADMIN'),
	  ('admin','ROLE_USER'),
	  ('user','ROLE_USER');

	insert into authorities_TEMP select 
		fodselsnummer as username, 
		'ROLE_USER' as authority 
	from personer where fodselsnummer is not null and fodselsnummer not like '';


	-- By default, the username column here has to match the username column in the users table, above
	INSERT INTO user_info_TEMP (sub, preferred_username, name, email, email_verified) VALUES
	  ('90342.ASDFJWFA','admin','Demo Admin','admin@example.com', true),
	  ('01921.FLANRJQW','user','Demo User','user@example.com', true);


	insert into user_info_TEMP (sub, preferred_username, name, email, email_verified) select 
		'fodselsnummer.'||fodselsnummer as sub,
		fodselsnummer as preferred_username, 
		fornavn||' '||(case when length(mellomnavn)>0 then mellomnavn||' ' else '' end)||etternavn as name, 
		(case when email != '' then email else 'fodselsnummer.'||fodselsnummer||'@fake.epost.com' end) as email, 
		false as email_verified 
	from personer where fodselsnummer is not null and fodselsnummer != '';


	INSERT INTO users
	  SELECT username, password, enabled FROM users_TEMP
	  ON CONFLICT(username)
	  DO NOTHING;

	INSERT INTO authorities
	  SELECT username, authority FROM authorities_TEMP
	  ON CONFLICT(username, authority)
	  DO NOTHING;

	INSERT INTO user_info (sub, preferred_username, name, email, email_verified)
	  SELECT sub, preferred_username, name, email, email_verified FROM user_info_TEMP
	  ON CONFLICT
	  DO NOTHING;

	commit;
	!
}

ImporterePersonerFraKrimstad(){
	psql --dbname oic -c "drop table if exists personer";
	psql --file main_Personer.sql --dbname oic|sort -u
	psql --dbname oic -c "select 'Antall personer i Krimstad persontabellen: '||count(*) from personer";
}

Doit
