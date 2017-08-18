#!/bin/sh
Doit(){
	DockerImage
}
DockerImage(){
        local dir=tmp$$
        local saveTo=/dockerimages/
        mkdir $dir
	pg_dump --no-owner oic| grep -v jhs009|gzip -9 > $dir/dump-oicdb.sql.gz
        # cp dump.sql.gz $dir
        # cp tmp-dumps/dump-*.sql.gz $dir
        cat <<-! > $dir/Dockerfile
                FROM postgres:9.6.3-alpine
                COPY dump-*.sql.gz /docker-entrypoint-initdb.d/
	!
        (cd $dir; docker build -t oidcdb .)
        rm $dir/dump-*.sql.gz $dir/Dockerfile
        rmdir $dir
        docker save -o ${saveTo}oidcdb-latest.dockerimage oidcdb:latest

        # docker rmi kodeverkdb:latest
        ls -lh ${saveTo}oidcdb-latest.dockerimage
}
Doit
