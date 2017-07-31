#!/bin/sh
Doit(){

	# CreateBid jhs009
	Parse
}
jhs009(){
	username=janhelge
	authority="ROLE_ADMIN ROLE_USER"
	street_address="Bjerkesvingen 6a"
	sub=sssa.saae
	preferred_username=janhelge
	birthdate=19571212
	email_verified=true
}
Parse(){
	jhs009
local users="username password enabled"
local authorities="username password enabled authority"

local user_info="sub preferred_username name given_name family_name
middle_name nickname profile picture website email
email_verified gender zone_info locale phone_number
phone_number_verified address_id updated_time birthdate"

local address="formatted street_address locality region postal_code country"

local vals cols comma=
col=
vals=
table=user_info
allFields=true
for x in $info; do
	val="$(eval echo \$$x)"
	if [ "$val" != "" ];then
		case $x in *_verified|enabled) fnutt=
			if [ "$val" != "true" -a "$val" != "false" ];then 
				echo Invalid value $x=$val; exit 1; 
		fi ;;esac
		cols=$cols$comma$x;
		vals=$vals$comma$fnutt$val$fnutt;
		comma=,;fnutt="'";
	elif [ $allFields = true ];then
		echo Required field $x missing; exit
	fi
done
	if [ "$cols" != "" ];then
		echo insert into user_info "($cols) values ($vals);"
	else
		echo No insert in table
	fi
}
Users(){
	local dbname=$1
	local admin_user_info_id=
	local admin_addr_id=
	local user_user_info_id=
	local user_addr_id=

	bid_user_info_id=$(psql --tuples-only --username=jhs --dbname=$dbname -c "select nextval('user_info_id_seq'::regclass)")
	bid_addr_id=$(psql --tuples-only --username=jhs --dbname=$dbname -c "select nextval('user_info_address_id_seq'::regclass)")
	echo bid: bid_info_id: $bid_user_info_id bid_addr_id=$bid_addr_id

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
Doit
