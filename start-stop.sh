#!/bin/sh
# Shellscript to start or stop this dockerbased service
# NOTE: We dont use docker.hub for various reasons and we need the files ...
#  oidcdb-latest.dockerimage
#  oidc-latest.dockerimage
Doit(){

	if [ "$1" = "stop" ];then 
		Stop oidc oidcdb 
		UnloadImage oidc:latest oidcdb:latest 
		exit; 
	elif [ "$1" = "start" -o "$1" = "restart" ];then
		Stop oidc oidcdb 
		UnloadImage oidc:latest oidcdb:latest 
		Load oidc:latest oidcdb:latest 
		RunBoth
	elif [ "$1" = "status" ];then
		Status oidcdb oidc
	elif [ "$1" = "psql" ];then
		Psql
	elif [ "$1" = "kundb" ];then
		Load oidcdb:latest
		DbStart #  evt 
		# DbStartEx
	# elif [ "$1" = "ivp" ];then
		# sh ./ivp-kodeverk.sh
	else
		echo Usage: $0 '[ stop | start ]' >&2
		echo '   ' Shellscript to stop or start the service >&2
		echo '   ' >&2
		echo ' - ' start: Start service >&2
		echo ' - ' stop: Stop and cleanup '(offloades)' dockerimages >&2
	fi
}

DbStart(){
	local e="$1"
        e="${e} -e POSTGRES_PASSWORD=oic";
        e="${e} -e POSTGRES_USER=oic";
        e="${e} -e POSTGRES_DB=oic";
	# NB: passord, databasenavn og databasebruker maa matche jndi-datasource-parametrne
	docker run -d $e --name oidcdb oidcdb
}
# DbStartEx(){ DbStart -p5432:5430; } 
RunBoth(){
	DbStart
	WaitOnDatabase oidcdb # Venter til databasen kommer opp slik at databaseinitialisering ikke feiler
	# Kan ikke ha --link i kombinasjon med --net host, maa derfor bruke db PrivateLinking
	HostName=$(hostname -f);
	HostName=localhost
	IssuerUrl=http://$HostName:8080/openid-connect-server-webapp/ # DOCKER-TEST-001.pit-test.no, // FIXME
	echo IssuerUrl=$IssuerUrl
	docker run -d -p 8080:8080 --add-host oidcdb:$(ContainerIp oidcdb) -e ISSUER=$IssuerUrl --name oidc oidc:latest 
	#                          T------------PrivateLinking-----------T           
}

Psql(){
	echo Bruk password oic
	docker run -it --rm --link oidcdb:oidcdb oidcdb \
	psql --dbname=oic --host=oidcdb --username=oic
}
##################### END-OF-CUSTOMIZE #######################
ContainerIp(){ docker inspect --format {{.NetworkSettings.IPAddress}} $1; }
WaitOnDatabase(){
	# ContainerIp(){ docker inspect --format {{.NetworkSettings.IPAddress}} $1; }
	WaitUntilHostPortIsAvailable(){
		if [ "$1" = "" ];then return 0; fi
		arg(){ echo $1|awk -F: -v n=$2 '{printf "%s\n",$(n);}'; }
		local addr=$(arg $1 1);
		local port=$(arg $1 2);
		echo Waiting for $addr:$port to become available
		while ! timeout 1 bash -c \
		"cat < /dev/null > /dev/tcp/$addr/$port" \
		>/dev/null 2>&1; do sleep 0.3; done
		echo $addr:$port is up
	}
	WaitUntilHostPortIsAvailable $(ContainerIp $1):5432
}
UnloadImage(){
	local _x; for _x in $*;do
		if [ "$(docker images $_x --format {{.Repository}}":"{{.Tag}})" = "$_x" ];then 
			docker rmi -f $_x; 
		fi
	done
}
Load(){ 
	local _x ; for _x in $*;do
		docker load -i $(echo $_x|tr : '-').dockerimage
	done
}
RunningStatusOne(){ GeneralStatusOne $1; }
AllStatusOne(){ GeneralStatusOne $1 --all; }
GeneralStatusOne(){
	local _x
	for _x in $(docker ps $2 --format {{.Names}} --filter name=$1); do
		if [ "$_x" = "$1" ];then echo true; return 0; fi
	done
	echo false
	return 1
}
Status(){
	local _x _y _t ; for _x in $*;do 
		if [ "$(RunningStatusOne $_x)" = "true" ];then
			echo $_x Running
		elif [ "$(AllStatusOne $_x)" = "true" ];then
			echo $_x ContainerExist
		else
			echo
		fi
	done 
}
StopIfRunning(){
	local _x; for _x in $*;do
		if [ "$(RunningStatusOne $_x)" = "true" ];then
			echo $_x Running
			docker stop $_x; # Alternativt kill
		fi
	done
}
PurgeIfContainerExist(){
	local _x; for _x in $*;do
		if [ "$(RunningStatusOne $_x)" = "true" ];then
			echo $_x Running, Stop it first
		elif [ "$(AllStatusOne $_x)" = "true" ];then
			docker rm $_x
		fi
	done
}

Stop(){
	local _x; for _x in $*;do
		StopIfRunning $_x; 
		PurgeIfContainerExist $_x; 
	done
}

Doit $*
