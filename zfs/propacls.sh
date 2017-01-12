#!/usr/bin/env ksh
################################################################################
# propacls
# 
# Purpose:	Script to propagate ZFS ACLs down a directory tree
#		
#		Examine the target object's existing ACLs and use them
#		to derive the natural inherited ACLs for the children
#		as if they were newly created.
#		
#		this *will* reset the ACLs for the whole tree down from
#		the target object ($object).
#		
#  Author:	Tim Kennedy <tim@coraid.com>
#    Date:	20140618
# Version:	1.0
# 
################################################################################
# Changelog:
# ----------    ----    -------------------------------------------------------
# 20140618       1.0	Initial Script Version
#
################################################################################
# Locking
#
#	See if anothing instance of the same script is running, and if it is,
#	then this instance bails out, logging an error.
#===============================================================================
lockfile=/var/tmp/$(basename $0).lock

if ( set -o noclobber; echo "$$" > "$lockfile") 2>/dev/null; then
	trap 'rm -f "$lockfile"; exit $?' INT TERM EXIT

################################################################################
# VARIABLES           
#===============================================================================
myself=$0
object=$1

################################################################################
# Functions
#===============================================================================
function usage {
	echo "Usage: $myself <path>"
	echo
	exit 1
}
################################################################################
# Body of the script goes here between the two lines of '=' characters
#===============================================================================
if [ -z $object ]; then
	echo
	echo "Error: mising a file or directory to operate on."
	echo
	usage
elif [ ! -d $object ]; then
	# if the object is not a directory, and it's not a file
	# spit out some usage...
	#
	if [ ! -f $object ]; then
		echo
		echo "Error: $object is not a file or directory."
		echo
		usage
	fi
fi

# Get the current ACL of the ojbect we pass in on the CLI.
#
cur_acl=$( /usr/bin/ls -Vd $object | egrep -v '^[a-z]|^-' | tr -s '\n' ',' | tr -d ' ' )


if [ -d $object ]; then
	# Once we have that, we'll munge it to set the 
	# 'I' (inherited) flag on the ACL for it's child directories.
	dir_acl=$( echo $cur_acl | sed -e 's/-:allow/I:allow/g' )

	# set our calculated directory ACL on all the $object's 
	# children directories.
	echo "propagating ACLs to directories:"
	for dir in $(find $object/* -type d); do
		printf "%-70s" "      $dir"
		/usr/bin/chmod A=$dir_acl $dir
		if (( $? > 0 )); then
			printf "%-8s\n" "[err]"
		else
			printf "%-8s\n" "[ok]"
		fi
	done
	# Then set our calculated file ACL on all the $object's
	# children files.
	echo "propagating ACLs to files:"
	for file in $(find $object/* -type f); do
		if [[ -x "$file" ]]; then
			fil_acl=$( echo $cur_acl | gsed -e 's/:fd/:--/g' | gsed -e 's/-:allow/I:allow/g' )
		else
			fil_acl=$( echo $cur_acl | gsed -e 's/:\([r-]\)\([w-]\)\(x\)\([p-]\)/:\1\2-\4/g' | gsed -e 's/:fd/:--/g' | gsed -e 's/-:allow/I:allow/g' )
		fi
		printf "%-70s" "      $file"
		/usr/bin/chmod A=$fil_acl $file
		if (( $? > 0 )); then
			printf "%-8s\n" "[err]"
		else
			printf "%-8s\n" "[ok]"
		fi
	done
elif [ -f $object ]; then
	# if we got here, it's because the inital object is a file.
	# so we'll grab it's parent ACL and reset the inherited 
	# ACLs.
	parent=$(dirname $object)
	par_acl=$( /usr/bin/ls -Vd $parent | egrep -v '^[a-z]|^-' | tr -s '\n' ',' | tr -d ' ' )
	fil_acl=$( echo $par_acl | gsed -e 's/:\([r-]\)\([w-]\)\(x\)\([p-]\)/:\1\2-\4/g' | gsed -e 's/:fd/:--/g' | gsed -e 's/-:allow/I:allow/g' )
	
	echo "resetting ACLs on $object"
	/usr/bin/chmod A=$fil_acl $object
fi

#===============================================================================
# clean up after yourself, and release your trap
	rm -f "$lockfile"
	trap - INT TERM EXIT
else
	echo "Lock Exists: $lockfile owned by $(cat $lockfile)"
fi
################################################################################
