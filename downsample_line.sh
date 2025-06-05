#!/bin/bash

####################################################################################################
# Take a geographically sorted set of points and downsample to user-specfied spacing. Assumes that
# points have gone through spatial filter, otherwise results will be aliased.
####################################################################################################

#####
#   INITIALIZE
#####
SCRIPT=`basename $0`
EPOCH=`date "+%s"`
function cleanup () {
    rm -f lola_${SCRIPT}_${EPOCH}.tmp
    rm -f distaz_${SCRIPT}_${EPOCH}.tmp
    rm -f tmp${OFILE}
}
trap "cleanup" 0 1 2 3 8 9



#####
#       PARSE COMMAND LINE AND USAGE STATEMENT
#####
function usage {
    echo Usage: $SCRIPT -f FILE -d SAMP -o OFILE 1>&2
    exit 1
}

FILE=""
OFILE=""
SAMP=""
while [ "$1" != "" ]
do
    case $1 in
        -f) shift; FILE="$1";;
        -o) shift; OFILE="$1";;
        -d) shift; SAMP="$1";;
        *) echo "$SCRIPT [ERROR]: no option $1" 1>&2; usage
    esac
    shift
done
if [ "$FILE" == "" ]; then echo "$SCRIPT [ERROR]: input file must be defined with -f" 1>&2; usage; fi
if [ "$OFILE" == "" ]; then echo "$SCRIPT [ERROR]: output file must be defined with -o" 1>&2; usage; fi
if [ "$SAMP" == "" ]; then echo "$SCRIPT [ERROR]: sampling interval must be defined with -d" 1>&2; usage; fi
if [ ! -f "$FILE" ]; then echo "$SCRIPT [ERROR]: no input file found named $FILE" 1>&2; usage; fi


#####
#	DOWNSAMPLE THE INPUT GEOGRAPHIC LINE SEGMENTS
#####
# Count number of points in the file
NPTS=`wc $FILE | awk '{print $1}'`

# Compute distances between points in file (assumes points are ordered)
awk '{
    if (NR==1) {
        print $1,$2,$1,$2
    } else {
        print lo,la,$1,$2
    }
    lo=$1
    la=$2
}' $FILE > lola_${SCRIPT}_${EPOCH}.tmp
lola2distaz -f lola_${SCRIPT}_${EPOCH}.tmp -o distaz_${SCRIPT}_${EPOCH}.tmp ||\
    { echo "$SCRIPT [ERROR]: could not calculate distance/azimuth between points" 1>&2 ; exit 1 ; }

# Keep points every SAMP km, and both endpoints
paste distaz_${SCRIPT}_${EPOCH}.tmp $FILE |\
    awk 'BEGIN{dist=0}{
        dist = dist + $1
        if (dist>='"$SAMP"') {dist=0}
        if (dist<=1e-6&&NR!='"$NPTS"') {print $0}
    }END{print $0}' |\
    awk '{for(i=3;i<=NF;i++){printf("%s "),$i};print ""}' > tmp${OFILE}

# Check last two points are not too close together
NPTS=`wc tmp${OFILE} | awk '{print $1}'`
lola2distaz -c `tail -2 tmp${OFILE} | awk '{x1=$1;y1=$2;getline;print x1,y1,$1,$2}'` > distaz_${SCRIPT}_${EPOCH}.tmp ||\
    { echo "$SCRIPT [ERROR]: could not calculate distance/azimuth between last two points" 1>&2 ; exit 1 ; }
DIST=`awk '{printf("%.2f"),$1}' distaz_${SCRIPT}_${EPOCH}.tmp`
echo $SCRIPT: distance between last two points is $DIST km 1>&2
awk '{
    if (NR<'"$NPTS"'-1 || NR=='"$NPTS"') {
        print $0
    } else {
        if ('"$DIST"'>'"$SAMP"'*2/3) {
            print $0
        } else {
            print "'$0': removing penultimate point" > "/dev/stderr"
        }
    }
}' tmp${OFILE} > ${OFILE}





