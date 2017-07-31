#!/bin/sh
Doit(){
	CreSel

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
Doit
