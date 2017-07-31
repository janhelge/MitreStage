#!/bin/sh

StageDir=../GitIgnore-stage
PatchConfig=$StageDir/PatchConfig.lst
Doit(){

		

	# HvilketMiljo kodeverk-service/src/test/resources/jetty/jetty-env.xml
	DoPatch
}
DoPatch(){
	local t= x=

	(cd $StageDir;
	if [ ! -f $PatchConfig ];then echo Feil, $PatchConfig missing; exit 1; fi
	for t in $(cat $PatchConfig); do
		# echo t=$t
		# x=$StageDir/$(basename $t)
		# valg=$(ls $x.*|awk -v f=$x '{print substr($1,length(f)+2);}')
		HvilketMiljo $t
	done
	)


}
Col(){
	Norm="\033[0m"; Bold="\033[1m"; Rev="\033[7m"; Dim="\033[2m";
	Red="\033[31m"; Green="\033[32m"; Yellow="\033[33m"; Blue="\033[34m";
	Magenta="\033[35m"; Cyan="\033[36m"; White="\033[37m";
	# echo -e "${Bold}${Red}EZZ${Norm}aa"
}
Sha1sum(){ sha1sum $1|awk '{print $1}'; }
HvilketMiljo(){
	local conf=
	Col
	local y=$StageDir/$(basename $1)
	# ls $1.* 
	valg=$(ls $y.*|awk -v f=$y '{print substr($1,length(f)+2);}')
	echo "Alternativer for $Bold$1$Norm er..."
	Comma=" "
	ShaCurrentConfig=$(Sha1sum $1)
	for x in $valg; do 
		ShaActual=$(Sha1sum $y.$x)
		if [ "$ShaActual" = "$ShaCurrentConfig" ];then
			ConfigEqualCurrent=$x
			echo -n $Comma"$Red$x$Norm"; 
		else
			echo -n $Comma"$Dim$x$Norm"; 
		fi
		Comma=,; 
	done
	echo -n "  Ditt valg  ==> "
	read conf
	# echo Conf=$conf
	if [ "$conf" = "" ];then
		echo Endrer ikke, $1 = $y.$ConfigEqualCurrent forblir uendret
	elif [ -f $y.$conf ];then 
		echo Endrer til $y.$conf
		cp $y.$conf $1; 
	fi
}

Doit
