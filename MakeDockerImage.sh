#!/bin/sh
Doit(){
	MakeDockerTarContext
	DockerBuild
	OffloadImage
	Cleanup
}
OffloadImage(){ docker save -o oidc-latest.dockerimage oidc:latest ; }
Cleanup(){ rm Dockerfile context.tgz openid-connect-server-webapp.war ; }
DockerBuild(){ docker build -t oidc - < ./context.tgz ; }
MakeDockerTarContext(){
	local warFrom=../OpenID-Connect-Java-Spring-Server/openid-connect-server-webapp/target/
	local war=openid-connect-server-webapp.war
	if [ ! -f ${warFrom}/$war ];then echo Feil, Bygg $war forst; exit 1; fi
	cp ${warFrom}$war $war
	# local deploy="$deploy $war"
	# deploy="$deploy oidc.xml"
	# local logback=logback-test.xml  

	cat <<-! > Dockerfile
		FROM jetty:9.4.6-alpine
		COPY $deploy /var/lib/jetty/webapps/
		# COPY $logback /var/lib/jetty/resources/
	!

	tar cvf - $logback $deploy Dockerfile | gzip -9 > context.tgz
}

Doit
