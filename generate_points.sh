#!/bin/bash


#####
#   USER-DEFINED MODEL PARAMETERS
#####

# Geographic corners of the model (ordered)
LON_CORNER_1=-75.0
LAT_CORNER_1=-35.0
LON_CORNER_2=-75.0
LAT_CORNER_2=-25.0
LON_CORNER_3=-65.0
LAT_CORNER_3=-25.0
LON_CORNER_4=-65.0
LAT_CORNER_4=-35.0

# Sampling interval (km)
D="30"

# Plate thickness (km)
THICKNESS=50

# Trench file
TRENCH_FILE=/home/mherman2/Research/slab2/Slab2Distribute_Mar2018/trenches/sam_slab2_trench_02.23.18.xyz

# Trench depth (km)
TRENCH_DEPTH=-6  # User-defined trench depth
TRENCH_DEPTH=AUTO  # Mean trench depth from input file








####################################################################################################
####################################################################################################
####################################################################################################
#------------------------------------ MODIFY AT YOUR OWN RISK! ------------------------------------#
#-------------------------------- EMAIL mherman2@csub.edu FOR HELP --------------------------------#
####################################################################################################
####################################################################################################
####################################################################################################




#####
#   INITIALIZE
#####
EPOCH=`date "+%s"`
SCRIPT=`basename $0`
function timenow () {
    date "+%H:%M:%S"
}

# Clean up function
function cleanup () {
    rm -f intersect_side_${SCRIPT}_${EPOCH}.tmp
    rm -f intersect_${SCRIPT}_${EPOCH}.tmp
    rm -f intersect_[1-4]_${SCRIPT}_${EPOCH}.tmp
    rm -f line_${SCRIPT}_${EPOCH}.tmp
    rm -f trench_${SCRIPT}_${EPOCH}.tmp
}
trap "cleanup" 0 1 2 3 8 9


echo "$SCRIPT [`timenow`]: starting"






#####
#   CHECKS
#####

echo "$SCRIPT [`timenow`]: checking inputs"

# Look for input trench file
if [ -z $TRENCH_FILE ]; then echo "$SCRIPT [ERROR]: no trench file defined" 1>&2 ; exit 1; fi
test -f $TRENCH_FILE || { echo "$SCRIPT [ERROR]: could not find trench file $TRENCH_FILE" 1>&2 ; exit 1 ; }

echo





#####
#   CUT TRENCH TO MODEL BOUNDARIES
#####

echo "$SCRIPT [`timenow`]: trimming trench"


# Make all longitudes in range 0-360
echo "$SCRIPT [`timenow`]: setting corner longitudes to be in range 0-360"
LON_CORNER_1=`echo $LON_CORNER_1 | awk '{if($1<0){print $1+360}else{print $1}}'`
LON_CORNER_2=`echo $LON_CORNER_2 | awk '{if($1<0){print $1+360}else{print $1}}'`
LON_CORNER_3=`echo $LON_CORNER_3 | awk '{if($1<0){print $1+360}else{print $1}}'`
LON_CORNER_4=`echo $LON_CORNER_4 | awk '{if($1<0){print $1+360}else{print $1}}'`



# For each side of the model, test whether trench intersects it
echo "$SCRIPT [`timenow`]: determining where trench intersects model sides"

for ISIDE in 1 2 3 4
do

    # Get corner coordinates for the side
    case $ISIDE in
        1) LO1=$LON_CORNER_1; LA1=$LAT_CORNER_1; LO2=$LAT_CORNER_2; LA2=$LAT_CORNER_2;;
        2) LO1=$LON_CORNER_2; LA1=$LAT_CORNER_2; LO2=$LAT_CORNER_3; LA2=$LAT_CORNER_3;;
        3) LO1=$LON_CORNER_3; LA1=$LAT_CORNER_3; LO2=$LAT_CORNER_4; LA2=$LAT_CORNER_4;;
        4) LO1=$LON_CORNER_4; LA1=$LAT_CORNER_4; LO2=$LAT_CORNER_1; LA2=$LAT_CORNER_1;;
    esac

    # Calculate distance and azimuth along side
    DIST=`lola2distaz -c $LO1 $LA1 $LO2 $LA2 | awk '{print $1}'`
    AZ=`lola2distaz -c $LO1 $LA1 $LO2 $LA2 | awk '{print $2}'`

    # Divide side into 1000 segments
    grid -x 0 $DIST -nx 1000 |\
        awk '{print '$LO1','$LA1',$1,'$AZ'}' |\
        distaz2lola -f stdin |\
        awk 'BEGIN{print ">"}{print $0}END{print ">"}' > intersect_side_${SCRIPT}_${EPOCH}.tmp

    # Put side segments and trench segments into file for gmtspatial intersection calculation
    cat intersect_side_${SCRIPT}_${EPOCH}.tmp $TRENCH_FILE > intersect_${SCRIPT}_${EPOCH}.tmp
    INTERSECTION=`gmt gmtspatial intersect_${SCRIPT}_${EPOCH}.tmp -Ie | sed -ne "1p" | awk '{print $1,$2}'`
    if [ "$INTERSECTION" != "" ]
    then
        echo $INTERSECTION > intersect_${ISIDE}_${SCRIPT}_${EPOCH}.tmp
    fi
done



# Check that there are 2 and only 2 intersections between trench and model sides
echo "$SCRIPT [`timenow`]: checking that there are only 2 intersections"
NINTERSECTIONS=`ls intersect_[1-4]_${SCRIPT}_${EPOCH}.tmp 2> /dev/null | wc | awk '{print $1}'`
if [ "$NINTERSECTIONS" != "2" ]
then
    echo "$SCRIPT [ERROR]: found $NINTERSECTIONS intersections between trench and model edges" 1>&2
    echo "$SCRIPT [ERROR]: there should be 2 ... exiting" 1>&2
    exit 1
fi


# Trim trench to model domain
echo "$SCRIPT [`timenow`]: trimming trench to model domain"

# Remove temporary line file if present
test -f line_${SCRIPT}_${EPOCH}.tmp && rm -f line_${SCRIPT}_${EPOCH}.tmp

# Get indices of points on trench between each intersection
for I in 1 2
do
    LO0=`cat intersect_[1-4]_${SCRIPT}_${EPOCH}.tmp | sed -ne "${I}p" | awk '{print $1}'`
    LA0=`cat intersect_[1-4]_${SCRIPT}_${EPOCH}.tmp | sed -ne "${I}p" | awk '{print $2}'`
    awk 'BEGIN{lo0='$LO0';la0='$LA0'}{
        if (NR>2) {
            lo2 = $1
            la2 = $2
            dlo1 = lo1-lo0
            dla1 = la1-la0
            dlo2 = lo2-lo0
            dla2 = la2-la0
            dot = dlo1*dlo2 + dla1*dla2
            if (dot<0) {
                print NR-1,NR,lo0,la0
                exit
            }
        }
        lo1 = $1
        la1 = $2
    }' $TRENCH_FILE >> line_${SCRIPT}_${EPOCH}.tmp
done
NR_START=`sort -g line_${SCRIPT}_${EPOCH}.tmp | awk '{if(NR==1){print $2}}'`
NR_END=`sort -g line_${SCRIPT}_${EPOCH}.tmp | awk '{if(NR==2){print $1}}'`

# Save starting and ending points
PT_START=`sort -g line_${SCRIPT}_${EPOCH}.tmp | awk '{if(NR==1){print $3,$4}}'`
PT_END=`sort -g line_${SCRIPT}_${EPOCH}.tmp | awk '{if(NR==2){print $3,$4}}'`

# Trim trench file, saving points at sampling interval
awk 'BEGIN{print "'"$PT_START"'"}{
    if ('$NR_START'<=NR && NR<='$NR_END') {print $0}
}END{ print "'"$PT_END"'"}' $TRENCH_FILE > trench_${SCRIPT}_${EPOCH}.tmp



# Sample to user-specified distance scale
echo "$SCRIPT [`timenow`]: downsampling trench to points every $D km"
downsample_line.sh -f trench_${SCRIPT}_${EPOCH}.tmp -d $D -o trench_${SCRIPT}_${EPOCH}.tmp || exit 1



# Get trench depth
echo "$SCRIPT [`timenow`]: setting trench depth"

# Calculate or manually set trench depth
if [ "$TRENCH_DEPTH" == "AUTO" ]
then
    echo "$SCRIPT [`timenow`]: AUTO mode - calculating mean trench depth"
    TRENCH_DEPTH=`awk 'BEGIN{sum=0;n=0}{if(NF==3){sum+=$3;n++}}END{printf("%.1f"),sum/n}' trench_${SCRIPT}_${EPOCH}.tmp`
    echo "$SCRIPT [`timenow`]: mean trench depth is $TRENCH_DEPTH km"
else
    echo "$SCRIPT [`timenow`]: USER mode - setting mean trench depth to $TRENCH_DEPTH km"
fi










