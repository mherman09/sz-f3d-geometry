#!/bin/bash

echo "----------------------------------------------------------------------------------------------------"
echo "$0: starting"
echo "----------------------------------------------------------------------------------------------------"


#####
#   USER-DEFINED MODEL PARAMETERS
#####

# Geographic corners of the model (do they need to be ordered in a certain direction?)
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
TRENCH_FILE=/Users/mherman2/Dropbox/south_america_illapel_cycle/model_geometry/sam_trench_dep.txt

# Trench depth (km)
TRENCH_DEPTH=-6  # User-defined trench depth
TRENCH_DEPTH=AUTO  # Mean trench depth from input file






####################################################################################################
#------------------------------------ MODIFY AT YOUR OWN RISK! ------------------------------------#
#-------------------------------- EMAIL mherman2@csub.edu FOR HELP --------------------------------#
####################################################################################################


EPOCH=`date "+%s"`



#####
#   CUT TRENCH TO MODEL BOUNDARIES
#####


# Make all longitudes in range 0-360
echo $0: setting longitudes to be in range 0-360
LON_CORNER_1=`echo $LON_CORNER_1 | awk '{if($1<0){print $1+360}else{print $1}}'`
LON_CORNER_2=`echo $LON_CORNER_2 | awk '{if($1<0){print $1+360}else{print $1}}'`
LON_CORNER_3=`echo $LON_CORNER_3 | awk '{if($1<0){print $1+360}else{print $1}}'`
LON_CORNER_4=`echo $LON_CORNER_4 | awk '{if($1<0){print $1+360}else{print $1}}'`



# For each side of the model, test whether trench intersects it
echo $0: determining where trench intersects model sides
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
        awk 'BEGIN{print ">"}{print $0}END{print ">"}' > intersect_side.tmp
    # Put side segments and trench segments into file for gmtspatial intersection calculation
    cat intersect_side.tmp $TRENCH_FILE > intersect.tmp
    INTERSECTION=`gmt gmtspatial intersect.tmp -Ie | sed -ne "1p" | awk '{print $1,$2}'`
    if [ "$INTERSECTION" != "" ]
    then
        echo $INTERSECTION > intersect_$ISIDE.tmp
    fi
done
# Clean up
rm intersect_side.tmp intersect.tmp



# Check that there are 2 and only 2 intersections between trench and model sides
echo $0: checking that there are only 2 intersections
NINTERSECTIONS=`ls intersect_[1-4].tmp | wc | awk '{print $1}'`
if [ "$NINTERSECTIONS" != "2" ]
then
    echo "$0 [ERROR]: found $NINTERSECTIONS intersections between trench and model edges" 1>&2
    echo "$0 [ERROR]: there should be 2 ... exiting" 1>&2
    exit 1
fi



# Trim trench to model domain
echo $0: trimming trench to model domain
# Remove temporary line file if present
test -f line.tmp && rm -f line.tmp
# Get indices of points on trench between each intersection
for I in 1 2
do
    LO0=`cat intersect_[1-4].tmp | sed -ne "${I}p" | awk '{print $1}'`
    LA0=`cat intersect_[1-4].tmp | sed -ne "${I}p" | awk '{print $2}'`
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
    }' $TRENCH_FILE >> line.tmp
done
NR_START=`sort -g line.tmp | awk '{if(NR==1){print $2}}'`
NR_END=`sort -g line.tmp | awk '{if(NR==2){print $1}}'`
PT_START=`sort -g line.tmp | awk '{if(NR==1){print $3,$4}}'`
PT_END=`sort -g line.tmp | awk '{if(NR==2){print $3,$4}}'`
# Trim trench file
awk 'BEGIN{print "'"$PT_START"'"}{
    if ('$NR_START'<=NR && NR<='$NR_END') {print $0}
}END{ print "'"$PT_END"'"}' $TRENCH_FILE > trench_${EPOCH}.tmp
# Clean up
rm intersect_[1-4].tmp line.tmp



# Get trench depth
echo $0: setting trench depth
if [ "$TRENCH_DEPTH" == "AUTO" ]
then
    echo $0: AUTO mode - calculating mean trench depth
    TRENCH_DEPTH=`awk 'BEGIN{sum=0;n=0}{if(NF==3){sum+=$3;n++}}END{print sum/n}' trench_${EPOCH}.tmp`
    echo $0: mean trench depth is $TRENCH_DEPTH km
else
    echo $0: USER mode - setting mean trench depth to $TRENCH_DEPTH km
fi
rm trench_${EPOCH}.tmp











