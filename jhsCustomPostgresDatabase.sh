#!/bin/sh
# Sjekk paa https://jwt.io/
# eyJraWQiOiJyc2ExIiwiYWxnIjoiUlMyNTYifQ.eyJzdWIiOiJhZG1pbiIsImF6cCI6ImNsaWVudCIsImlzcyI6Imh0dHA6XC9cL2xvY2FsaG9zdDo4MDgwXC9vcGVuaWQtY29ubmVjdC1zZXJ2ZXItd2ViYXBwXC8iLCJleHAiOjE1MDA5MTU2OTYsImlhdCI6MTUwMDkxMjA5NiwianRpIjoiOGI1OWE1ZTItZTBiMS00MWJiLWI3YjItNWQyNGM2MzBmNWJiIn0.VtZo_dtP9dWLv8Quepkabn-3Lq27KQ-_f0S6tuCUk69y0apf59hVg0NuhtX6dq-pMIaE26wyb03lNqtKz8z8Zn4SP4JtfYaADbjVE5Uxsgkb33mNYPqxCxeDrZ_PUYhuRYC7BbTs-C3Ys1JvMrIsSvpuvK3R1ND3UoKZQaOsNd4GgI3TWnuAol6K4K7egSv8O3srN3jKVpd_EhXWLw2BMFRvrnNwybTMxSN_QnUuaFH4T7FWwXe-lOafmBSLjtskyrcza_CIdJU46zAhcYKS50K5T007rnOn91HdbRtn1Cy0k7rPCLf7zrF74KkltWCkEIUW5C8gCU3JgHTifUiY1A
#
#

Doit(){

	CreatePlainDistroDb
	KrimstadAsUsers
	# TellRader
	# SequenceStatus > sequenceStatus.txt; ls -l sequenceStatus.txt
	# InkrEnAuth; InkrEnAuth # Pga to adresser 
	PatchToAfterTwoGrants

}

PatchToAfterTwoGrants(){
# SELECT setval('access_token_id_seq', 5);
# SELECT setval('address_id_seq', 5);
# SELECT setval('authorization_code_id_seq', 5);
# SELECT setval('authentication_holder_id_seq', 10);
# SELECT setval('saved_user_auth_id_seq', 10);
	SetVal access_token_id_seq 5 oic
	SetVal address_id_seq 5 oic
	SetVal authorization_code_id_seq 5 oic
	SetVal authentication_holder_id_seq 10 oic
	SetVal saved_user_auth_id_seq 10 oic
}

InkrEnAuth(){
	local s= seqs="access_token_id_seq address_id_seq authorization_code_id_seq
		authentication_holder_id_seq saved_user_auth_id_seq
		authentication_holder_id_seq saved_user_auth_id_seq"
	for s in $(echo $seqs|sort); do echo Bumping sequence $s to: $(NxtVal $s oic); done
}
SetVal(){
	psql --tuples-only --username=jhs --dbname=$3 -c "select setval('$1',$2);"; 
}
NxtVal(){ 
	psql --tuples-only --username=jhs \
	--dbname=$2 -c "select nextval('$1'::regclass);"; 
}

SequenceStatus(){
	local dbname=oic
	local s="select 'select '''|| relname ||':''|| last_value"
	s="$s from '||relname||';'"
	s="$s from pg_class where relkind='S';"
	psql --tuples-only --username=jhs --dbname=$dbname -c "$s"|\
	psql --tuples-only --username=jhs --dbname=$dbname|\
	sort -u
}

TellRader(){
	local dbname=oic
        psql --tuples-only --username=jhs --dbname=$dbname -c "
	select 'select ~'||table_name||': ~||count(*) from '||table_name||';' from information_schema.tables WHERE 
	table_schema='public' AND table_type='BASE TABLE'"|tr "~" "'"|\
	psql --tuples-only --username=jhs --dbname=$dbname|sort -n -k 2
}
CreatePlainDistroDb(){
	# MakeKeyStore
	DropAndCreatePostgresDatabase oic
	CreateDatabaseTablesAndSecuritySchema oic
	Scopes oic
	Clients oic
	Users oic
	CreateAccessUserAndGrantAll oic oic oic
	# ------------------------ FERDIG ----
	# NB: vurdere aa endre
	# vi /etc/postgresql/9.5/main/pg_hba.conf 
	### sett md5 istfor peer
	##endre linjen local all all peer til
	##endre linjen local all all md5 hvis vi vil ha peerbasert innlogging, alternativt bruk --host=localhost
	# psql --username=oic --password --host=localhost --dbname=oic

}
DropAndCreatePostgresDatabase(){ dropdb $1; createdb $1; }
CreateDatabaseTablesAndSecuritySchema(){
	local t=
        # t="$t ../OpenID-Connect-Java-Spring-Server/openid-connect-server-webapp/src/main/resources/db/psql/psql_database_tables.sql"
        t="$t psql_database_tables.sql.patch-address-id-as-bigserial"
        t="$t ../OpenID-Connect-Java-Spring-Server/openid-connect-server-webapp/src/main/resources/db/psql/psql_database_index.sql"
        t="$t ../OpenID-Connect-Java-Spring-Server/openid-connect-server-webapp/src/main/resources/db/psql/security-schema.sql"
	cat $t| psql --username=jhs --dbname=$1 
}
Scopes(){
	cat<<-! | psql $1
		START TRANSACTION;
		INSERT INTO system_scope (scope, description, icon, restricted, default_scope, 
			structured, structured_param_description) VALUES
		('openid', 'log in using your identity', 'user', false, true, false, null),
		('profile', 'basic profile information', 'list-alt', false, true, false, null),
		('email', 'email address', 'envelope', false, true, false, null),
		('address', 'physical address', 'home', false, true, false, null),
		('phone', 'telephone number', 'bell', false, true, false, null),
		('offline_access', 'offline access', 'time', false, false, false, null);
		commit;
	!
}

Users(){
	local dbname=$1
	local admin_user_info_id=
	local admin_addr_id=
	local user_user_info_id=
	local user_addr_id=

# Pga feil i oppsettet maa disse sequencene oppdateres med like mange 
# admin_user_info_id=$(NxtVal authentication_holder_id_seq $dbname) # <== Dummy, trengs ikke, bug
# admin_user_info_id=$(NxtVal saved_user_auth_id_seq $dbname) # <== Dummy, trengs ikke, bug
admin_user_info_id=$(NxtVal user_info_id_seq $dbname)
admin_addr_id=$(NxtVal user_info_address_id_seq $dbname)

# user_user_info_id=$(NxtVal authentication_holder_id_seq $dbname) # <== Dummy, trengs ikke, bug
# user_user_info_id=$(NxtVal saved_user_auth_id_seq $dbname) # <== Dummy, trengs ikke, bug
user_user_info_id=$(NxtVal user_info_id_seq $dbname)
user_addr_id=$(NxtVal user_info_address_id_seq $dbname)

# user_user_info_id=$(psql --tuples-only --username=jhs --dbname=$dbname -c "select nextval('user_info_id_seq'::regclass)")
# user_addr_id=$(psql --tuples-only --username=jhs --dbname=$dbname -c "select nextval('user_info_address_id_seq'::regclass)")

	echo admin: user_info_id: $admin_user_info_id admin_addr_id=$admin_addr_id
	echo user: user_info_id: $user_user_info_id user_addr_id=$user_addr_id

	cat<<-! | psql $dbname
		START TRANSACTION;

		INSERT INTO users (username, password, enabled) VALUES
		 ('admin','password',true),
		 ('user','password',true);

		INSERT INTO authorities (username, authority) VALUES
		  ('admin','ROLE_ADMIN'),
		  ('admin','ROLE_USER'),
		  ('user','ROLE_USER');

		INSERT INTO user_info (id,address_id,sub, preferred_username, name, email, email_verified) VALUES
		  ($admin_user_info_id,$admin_addr_id,'90342.ASDFJWFA','admin','Demo Admin','admin@example.com', true),
		  ($user_user_info_id,$user_addr_id,'01921.FLANRJQW','user','Demo User','user@example.com', true);

		insert into address (id,street_address,locality,formatted,region,country,postal_code) values
			($admin_addr_id,'Fridtjof Nansens vei 14','Oslo','placeholder-formatted','placeholder-region','Norge','0369'),
			($user_addr_id,'Ávjovárgeaidnu 50','Kárášjohka','Sametingets adresse, Sameland (nordsamisk skrivemåte) ','placeholder-region','Sápmi','9730');
		commit;
	!
}
Clients(){
	local dbname=$1
	local clientId=
	local myspringsecId=
	clientId=$(psql --tuples-only --username=jhs --dbname=$dbname -c "select nextval('client_details_id_seq'::regclass)")
	myspringsecId=$(psql --tuples-only --username=jhs --dbname=$dbname -c "select nextval('client_details_id_seq'::regclass)")
	echo clientId=$clientId myspringsecId=$myspringsecId
	# NullstillClients_details_scope_redirects_grants # Trengs bare for omkjoring
	cat <<-! | psql $dbname
		START TRANSACTION;

		INSERT INTO client_details (id,client_id, client_secret, client_name, dynamically_registered, refresh_token_validity_seconds, 
		access_token_validity_seconds, id_token_validity_seconds, allow_introspection) values 
		($clientId, 'client', 'secret', 'Test Client', false, null, 3600, 600, true),
		($myspringsecId, 'myspringsec', 'myspringsecsecret', 'Spring Security OIDC testklient', false, null, 3600, 600, true);

		INSERT INTO client_scope (owner_id,scope) values
			($clientId, 'openid'),
			($clientId, 'profile'),
			($clientId, 'email'),
			($clientId, 'address'),
			($clientId, 'phone'),
			($myspringsecId, 'offline_access'),
			($myspringsecId, 'openid'),
			($myspringsecId, 'profile'),
			($myspringsecId, 'email'),
			($myspringsecId, 'address'),
			($myspringsecId, 'phone');

		INSERT INTO client_redirect_uri (owner_id,redirect_uri) values 
			($clientId, 'http://localhost:8081/simple-web-app/openid_connect_login'),
			($myspringsecId, 'http://localhost:8082/oauth2/authorize/code/mitre'); 

		INSERT INTO client_grant_type (owner_id,grant_type) values 
			($clientId, 'authorization_code'),
			($clientId, 'urn:ietf:params:oauth:grant_type:redelegate'),
			($clientId, 'implicit'),
			($clientId, 'refresh_token'),
			($myspringsecId, 'authorization_code');
		    
		COMMIT;
	!

}
CreateAccessUserAndGrantAll(){
	local dbname=$1
	local username=$2
	local password=$3

	dropuser $username
	psql $dbname -c "create role $username login unencrypted password '"$password"'"
	# echo Connect med ...
	# echo psql --username=oic --password --host=localhost --dbname=oic

	psql --tuples-only --username=jhs --dbname=$dbname -c "SELECT 'grant select,update,delete,insert on '
		|| table_name||' to $username;'
		FROM information_schema.tables WHERE table_schema='public'
		AND table_type='BASE TABLE'"|\
	psql --tuples-only --username=jhs --dbname=$dbname

	psql --tuples-only --username=jhs --dbname=$dbname -c "SELECT 'grant select,usage on '
	|| c.relname ||' to $username;' 
	from pg_class c 
	  join pg_namespace n on n.oid = c.relnamespace
	  join pg_user u on u.usesysid = c.relowner
	where c.relkind = 'S'
	  and u.usename = current_user"|\
	psql --tuples-only --username=jhs --dbname=oic
}
### =======================   <=== Krimstad
KrimstadAsUsers(){
	ImporterePersonTabellFraKrimstad
	psql --tuples-only --username=jhs --dbname=oic -c "grant select,update,delete,insert on personer to oic;"

	cat<<-! | psql oic
	START TRANSACTION;

	insert into users select fodselsnummer as username, 'password' as password, true as enabled 
	from personer where fodselsnummer is not null and fodselsnummer not like '';

	insert into authorities select fodselsnummer as username, 'ROLE_USER' as authority 
	from personer where fodselsnummer is not null and fodselsnummer not like '';

	delete from user_info where id in (select fodselsnummer::bigint from personer where fodselsnummer is not null and fodselsnummer not like '');
	delete from address where id in (select fodselsnummer::bigint from personer where fodselsnummer is not null and fodselsnummer not like '');

	insert into user_info (id,sub,preferred_username,name,email,email_verified,address_id,gender,phone_number,phone_number_verified,
		given_name,middle_name,nickname,family_name) select 
		fodselsnummer::bigint as id, 
		'fodselsnummer.'||fodselsnummer as sub,
		fodselsnummer as preferred_username, 
		fornavn||' '||(case when length(mellomnavn)>0 then mellomnavn||' ' else '' end)||etternavn as name, 
		(case when email != '' then email else 'fodselsnummer.'||fodselsnummer||'@fake.epost.com' end) as email, 
		false as email_verified, 
		fodselsnummer::bigint as address_id,
		kjonn as gender,
		telefon as phone_number,
		true as phone_number_verified,
		fornavn as given_name,
		mellomnavn as middle_name,
		fornavn as nickname,
		etternavn as family_name
	from personer where fodselsnummer is not null and fodselsnummer != '';

	insert into address (id,street_address,locality,formatted,region,country,postal_code) select 
		fodselsnummer::bigint as id,
		adresse as street_address,
		poststed as locality,
		'placeholder-formatted' as formatted,
		'placeholder-region' as region,
		'placeholder-country' as country,
		postnummer as postal_code
	from personer where fodselsnummer is not null and fodselsnummer != '';

	commit;
	!
	KrimstadUsersPhoneNumberVerifiedFixup
}
ImporterePersonTabellFraKrimstad(){
	psql --dbname oic -c "drop table if exists personer";
	psql --file Krimstad_personer.sql --dbname oic|sort -u
	psql --dbname oic --tuples-only -c "select 'Antall personer med personnummer i Krimstad persontabellen: '
		||count(*) from personer where fodselsnummer is not null and fodselsnummer != ''";
}
KrimstadUsersPhoneNumberVerifiedFixup(){
# select 90000000+id%10000 from user_info where id=13051299668
	# psql --dbname oic --tuples-only -c "update user_info set 
	# phone_number_verified=null where phone_number is null or phone_number != ''"; 
	psql --dbname oic --tuples-only -c "
	update user_info set phone_number_verified=false, phone_number = 90000000+id%10000
		where phone_number is null or phone_number != '' and id > 1000000"; 
}


## ===================================   <== Gamle funksjoner
# CreateScopes(){
# local t=../OpenID-Connect-Java-Spring-Server/openid-connect-server-webapp/src/main/resources/db/psql/scopes.sql
# cat $t |psql --username=jhs --dbname=oic
# }
NullstillClients_details_scope_redirects_grants(){
	psql --dbname oic -c "delete from client_details"
	psql --dbname oic -c "delete from client_scope"
	psql --dbname oic -c "delete from client_redirect_uri"
	psql --dbname oic -c "delete from client_grant_type"
} 

MakeKeyStore(){
	JwksKeystore=OpenID-Connect-Java-Spring-Server/openid-connect-server-webapp/src/main/resources/jhskeystore.jwks
	GenerateKeysAndReplace $JwksKeystore
	echo Sammenligne $JwksKeystore ...med
	echo OpenID-Connect-Java-Spring-Server/openid-connect-server-webapp/src/main/resources/keystore.jwks
	# NB: Sjekk filen $JwksKeystore - det er noe groms foerst i fila 
}
GenerateKeysAndReplace(){
	local _jar=json-web-key-generator/target/json-web-key-generator-*-jar-with-dependencies.jar
	if [ ! -f $_jar ];then cd json-web-key-generator;mvn clean install; cd ..; fi
	_jar=json-web-key-generator/target/json-web-key-generator-*-jar-with-dependencies.jar
	java -jar $_jar -t RSA -s 1024 -S -i rsa1 > $1
	# json-web-key-generator/target$ java -jar 
	# json-web-key-generator-0.4-SNAPSHOT-jar-with-dependencies.jar \
	# -t RSA -s 1024 -S -i rsa1 > jhs-generated-key.tmp
}
DropTempTables(){
	local dbname=oic
        psql --tuples-only --username=jhs --dbname=$dbname -c "
	select 'drop table '||table_name||';' from information_schema.tables WHERE 
	table_schema='public' AND table_type='BASE TABLE' and table_name like '%temp'"|\
        psql --tuples-only --username=jhs --dbname=$dbname
}

# CreateTempTablesForInnlesning(){ psql --username=jhs --dbname=oic --file create-temp-tables.sql; }
Doit
