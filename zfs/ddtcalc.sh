#!/usr/bin/ksh
################################################################################
# ddtcalc
# 
# Purpose:	Calculate Max dedupable zpool size from available RAM given a 
#		known block size.
#  Author:	Tim Kennedy <tim@coraid.com>
#    Date:	Thursday, May  3, 2013 03:01:37 PM EDT
# Version:	1.0
# 
################################################################################
# Changelog:
# ----------    ----    -------------------------------------------------------
# 2013-05-03	1.0	Initial Version
# 

################################################################################
# Locking
#
#	See if anothing instance of the same script is running, and if it is,
#	then this instance bails out, logging an error.
#
lockfile=/var/tmp/${0}.lock

if ( set -o noclobber; echo "$$" > "$lockfile") 2> /dev/null; then

trap 'rm -f "$lockfile"; exit $?' INT TERM EXIT
################################################################################
# SETTABLE VARIABLES           
#
################################################################################
# Body of the script goes here
#===============================================================================
# 2^10 = KB, 2^20 = MB, 2^30 = GB, 2^40 = TB

function hr {
	printf "%-80s\n" "--------------------------------------------------------------------------------"
}

function bytestamp {
        b=$1
        if [ -z $b ] || (( $b < 1 )); then
                printf "%-s\n" "Error:  no valid data in $replog!"
        else
                if (( $b > 1099511627776 )); then
                        bytestamp="$( printf "%-4.2f %-s\n" "$(echo "$b / 2^40" | bc -l)" "TB" )"
                elif (( $b > 1073741824 )); then
                        bytestamp="$( printf "%-4.2f %-s\n" "$(echo "$b / 2^30" | bc -l)" "GB" )"
                elif (( $b > 1048576 )); then
                        bytestamp="$( printf "%-4.2f %-s\n" "$(echo "$b / 2^20" | bc -l)" "MB" )"
                else
                        bytestamp="$( printf "%-4.2f %-s\n" "$(echo "$b / 2^10" | bc -l)" "KB" )"
                fi
        fi
        printf "%-s" "${bytestamp}"
}

function st2ram {
	size=$1
	ddtblocks128=$(( $size / (128 * 1024) )) 
	ddtblocks64=$(( $size / (64 * 1024) )) 
	ddtblocks4=$(( $size / (4 * 1024) )) 
	ddtsize128=$(( $ddtblocks128 * 376 ))
	ddtsize64=$(( $ddtblocks64 * 376 ))
	ddtsize4=$(( $ddtblocks4 * 376 ))
	hr
	echo "RAM Required for DDT to enable dedup for $( bytestamp $size ) of unique data: "
	echo "	128KB ZFS Block Size:	" $( bytestamp $ddtsize128 )
	echo "	 64KB ZFS Block Size:	" $( bytestamp $ddtsize64 )
	echo "	  4KB ZFS Block Size:	" $( bytestamp $ddtsize4 )
	hr
	echo "Main System RAM Required:	"
	echo "	128KB ZFS Block Size:	" $( bytestamp $(( $ddtsize128 * 5 )) )
	echo "	 64KB ZFS Block Size:	" $( bytestamp $(( $ddtsize64 * 5 )) )
	echo "	  4KB ZFS Block Size:	" $( bytestamp $(( $ddtsize4 * 5 )) )
	hr
}

function ram2st {
	ram=$1
	# From the IllumOS Source Code, we know DDT maxes out at 20% PHYSMEM
	# define	MAX_DDT_PHYSMEM_PERCENT		20
	ddtram=$(( $ram / 5 )) 

	# ::sizeof ddt_entry = 0x178
	ddtblocks=$(( $ddtram / 376  )) 

	ddtsize128=$(( $ddtblocks * $(( 128 * 1024 )) ))
	ddtsize64=$(( $ddtblocks * $(( 64 * 1024 )) ))
	ddtsize4=$(( $ddtblocks * $(( 4 * 1024 )) ))
	hr
	echo "Maximum size of ZFS dedup with $( bytestamp $ram ) RAM:"
	echo "	128KB ZFS Block Size:	" $( bytestamp $ddtsize128 ) "of unique data"
	echo "	 64KB ZFS Block Size:	" $( bytestamp $ddtsize64 ) "of unique data"
	echo "	  4KB ZFS Block Size:	" $( bytestamp $ddtsize4 ) "of unique data"
	hr
}

function usage {
	echo "Usage: $0 <options>"
	echo "	-k N	: N = number of KB of storage to dedup	"
	echo "	-m N	: N = number of MB of storage to dedup	"
	echo "	-g N	: N = number of GB of storage to dedup	"
	echo "	-t N	: N = number of TB of storage to dedup"
	echo "	-r N	: N = Total GB of RAM in system"
	exit 1
}

(( ${#} < 1 )) && usage

while getopts ':k:m:g:t:r:K:M:G:T:R:' opts; do
	case $opts in
	k|K) size=$(( $OPTARG * 1024 )) ; func="str" ;;
	m|M) size=$(( $OPTARG * 1024 * 1024 )) ; func="str" ;;
	g|G) size=$(( $OPTARG * 1024 * 1024 * 1024 )) ; func="str" ;;
	t|T) size=$(( $OPTARG * 1024 * 1024 * 1024 * 1024 )) ; func="str" ;;
	r|R) ram=$(( $OPTARG * 1024 * 1024 * 1024 )) ; func="rts" ;;
	*) usage ;;
	esac
done

case $func in
	rts) ram2st $ram ;;
	str) st2ram $size ;;
esac

#===============================================================================
# clean up after yourself, and release your trap
rm -f "$lockfile"
trap - INT TERM EXIT
else
echo "Lock Exists: $lockfile owned by $(cat $lockfile)"
fi
################################################################################
