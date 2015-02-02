#!/bin/bash

# both $1 and $2 are absolute paths
# returns $2 relative to $1
function rel_path() (
	if [[ "$1" == "$2" ]]
	then
		echo ""
		exit
	fi

	IFS="/"

	local current=($1)
	local absolute=($2)

	local abssize=${#absolute[@]}
	local cursize=${#current[@]}

	while [[ ${absolute[level]} == ${current[level]} ]]
	do
		(( level++ ))
		if (( level > abssize || level > cursize ))
		then
			break
		fi
	done

	for ((i = level; i < cursize; i++))
	do
		if ((i > level))
		then
			newpath=$newpath"/"
		fi
		newpath=$newpath".."
	done

	for ((i = level; i < abssize; i++))	
	do
		if [[ -n $newpath ]]
		then
			newpath=$newpath"/"
		fi
		newpath=$newpath${absolute[i]}
	done

	echo "$newpath/"
)

# evaluate parameterized objects (one level only)
function eval_val() (
	if [[ $1 == \$\(*:*\) ]] ; then
		local VAL=`echo $1 | sed 's/.*$(\(.*\):.*/\1/'`
		local str1=`echo $1 | sed 's/.*:%\(.*\)=.*/\1/'`
		local str2=`echo $1 | sed 's/.*=%\(.*\)).*/\1/'`
		grep "$VAL =" $2 | sed 's/.*= \(.*\)/\1/' | sed "s%${str1}%${str2}%"
		
	elif [[ $1 == \$\(*\) ]] ; then
		local VAL=`echo $1 | sed 's/$(\(.*\)).*/\1/'`
		grep "$VAL =" $2 | sed 's/.*= \(.*\)/\1/'
	else
		echo $1
	fi
)

function eval_obj() (
	local TARGET_OBJs=`grep 'bnx2x-objs = ' $1 | sed "s/.*= \(.*\)/\1/" `
	OBJ=`cat $makefile  | grep 'bnx2x-objs' |  sed "s/\(.*\)=.*/\1= /"`
	for P in $TARGET_OBJs ; do
		OBJ="$OBJ $(eval_val $P $1)"
	done
	echo $OBJ
)

if [ $# != 2 ]; then
	echo "Usage: $0 <kernel-source-dir> <bnx2x-source-dir>"
	exit 255
fi

KSRC=$1
BNX2X_SRC=$2

PATCH=bnx2x.patch

#locate bnx2x kernel Makefile
makefile=`find ${KSRC} -name Makefile | xargs grep "bnx2x\.o" | cut -d":" -f1`
if [ -z "$makefile" ]; then
	echo Unable to locate bnx2x sources in kernel tree $1
	exit 255
fi

#sanity:
if [ ! -f $BNX2X_SRC/Makefile ]; then
	echo Unable to locate bnx2x sources in provided directory $2
	exit 255
fi

#extract bnx2x directory
bnx2x_dir=`echo $makefile | sed 's%\(.*\/\).*%\1%' | sed "s%${KSRC}%%g"`
echo located kernel bnx2x sources at ${KSRC}$bnx2x_dir

#locate cnic_if.h
cnic_dir=`find ${KSRC} -name cnic.h | sed 's%\(.*\/\).*%\1%' | sed "s%${KSRC}%%"`

if [ ! -z "$cnic_dir" ]; then
	echo located kernel cnic sources at ${KSRC}$cnic_dir
	#calculate relative path for cnic
	cnic_rel=$(rel_path ${bnx2x_dir} ${cnic_dir})
	bnx2x_rel=$(rel_path ${cnic_dir} ${bnx2x_dir})
fi
	


ALOCAL="a/${bnx2x_dir}"
BLOCAL="b/${bnx2x_dir}"

mkdir -p ${ALOCAL}
mkdir -p ${BLOCAL}

cp ${KSRC}/${bnx2x_dir}/bnx2x*.[ch] ${ALOCAL}
if [ ! -z "$cnic_dir" ]; then
	cp ${KSRC}/${bnx2x_dir}/${cnic_rel}/cnic_if.h ${ALOCAL}/${cnic_rel}
fi
cp ${KSRC}/${bnx2x_dir}/Makefile ${ALOCAL}
cp ${BNX2X_SRC}/bnx2x*.[ch] ${BLOCAL}
cp ${BNX2X_SRC}/cnic_if.h ${BLOCAL}/${cnic_rel}

# rebuild objects structure
ORIG_OBJs=`grep bnx2x-obj $makefile`
TARGET_OBJs=$(eval_obj  ${BNX2X_SRC}/Makefile)
cat ${ALOCAL}/Makefile | sed "s%${ORIG_OBJs}%${TARGET_OBJs}%" > ${BLOCAL}/Makefile
#replace cnic in source
for F in ${BLOCAL}/*.[ch]; do
	sed -i "s%#include .*cnic_if.h.*%#include \"${cnic_rel}cnic_if.h\"%" $F
done
#replce bnx2xes in cnic
sed -i "s%#include .*\(bnx2x.*.h\).*%#include \"${bnx2x_rel}\1\"%" ${BLOCAL}/${cnic_rel}/cnic_if.h

diff -Nrup a b > $PATCH
echo $PATCH is ready
rm -rf a b


