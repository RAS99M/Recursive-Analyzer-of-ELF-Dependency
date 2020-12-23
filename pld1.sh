#!/bin/bash

function addldlist {
	local flag=0
	for _ld in "${ldlist[@]}"
	do
	    [[ "$_ld" = "$1" ]] && flag=1
	done
	if [ $flag -eq 0 ] ; then
            local n=${#ldlist[@]}
	    ldlist[n]="$1"
	fi

}

printf "\n*************************************\n"

function treeld {

# считываем имена динамических библиотек в массив ldname из elf-файла
    local ldname=()
    readarray -t ldname <<< $(readelf -d "$1" | grep NEEDED | sed -e 's/.*\[//' | sed -e 's/\]//' )

# считываем RPATH из elf-файла
    local rpath="$(readelf -d "$1" | grep RPATH | sed -e 's/.*\[//' | sed -e 's/\]//' ):$3"

# считываем RUNPATH из elf-файла
    local runpath="$(readelf -d "$1" | grep RUNPATH | sed -e 's/.*\[//' | sed -e 's/\]//' ):$4"

    shopt -s extglob
# если на любом уровне вложености был задан RPATH, то всегда ищем в начале там, потом в
# LD_LIBRARY_PATH, дале RUNPATH и в конце d LDCONFIG (проверено с помощью LD_DEBUG)
    
    local findpath="$rpath:$ldpath:$runpath:$ldconfpath"

# убераем лишние : в путях поиска     
    
    findpath=${findpath//+(":")/:}
    findpath=${findpath#":"}
    findpath=${findpath%":"}
    

    readarray -t -d ":" _findpath <<< $findpath

    local indent=$2
    local n=$((${#ldname[@]}-1))

    for ld in "${ldname[@]}"
    do
	[[ "$ld" = "" ]] && break
#	echo "ldname=[$ld] ld[n]=["${ldname[$n]}"] n=$n"
        local out="$indent├───"
	local out1="$indent│   "
        if [ "$ld" = "${ldname[$n]}" ] ; then
		out="$indent└───"
		out1="$indent    "
	fi

        flag_find=0
        for fp in "${_findpath[@]}"
        do
            if [[ "$fp" != "" ]] ; then
                if [ -e "$fp/$ld" ] ; then
                    flag_find=1
		    echo -e -n "$out<\033[34m$fp/\033[0m>\033[32m$ld\033[0m"
	            if [ -L "$fp/$ld" ] ; then
		        local lname=$(readlink -f "$fp/$ld")
	                echo -e " -> \033[36m$lname\033[0m"
		    else
			echo ""
		    fi
		    addldlist "$fp/$ld"
                    treeld "$fp/$ld" "$out1" "$rpath" "$runpath"
		    break
                fi
            fi 
        done
        [ $flag_find -eq 0 ] && echo "$2$ld library not found"
    done

}

if [ ! -e "$1" ] ; then
        echo "file $1 not found!"
        exit
fi

# получаем стандартные пути поиска библиотек в системе, заданные ldconfig в строку ldpath

ldconfpath=$(ldconfig -v 2>/dev/null | grep "\/*:")
ldconfpath="${ldconfpath//$'\n'/}"

# получаем пути поиска библиотек из окружения LD_LIBRARY_PATH

ldpath="$LD_LIBRARY_PATH"

ldlist=()

echo $1

treeld "$1" "" "" ""

printf "\n******************************************\n"
for ld in "${ldlist[@]}"
do
    ldn=${ld//*\//}
    ldp=${ld//$ldn/}
    echo -e "\033[34m$ldp\033[32m$ldn\033[0m"
done
