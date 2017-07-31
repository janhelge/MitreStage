#!/bin/sh

Doit(){
	DockerImage
}


DockerImage(){
	local dir=tmp$$
	local saveTo=/dockerimages/
	mkdir $dir
	pg_dump oic > $dir/oic.sql
	cat <<-! > $dir/Dockerfile
		FROM postgres:9.6.3-alpine
		COPY oic.sql /docker-entrypoint-initdb.d/
	!
	(cd $dir; docker build -t oidcdb .)
	rm $dir/oic.sql $dir/Dockerfile
	rmdir $dir
	docker save -o ${saveTo}oidcdb-latest.dockerimage oidcdb:latest

	ls -lh ${saveTo}oidcdb-latest.dockerimage
}

Doit
