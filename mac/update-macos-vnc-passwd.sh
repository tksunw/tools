#!/bin/bash

ARDAgent='/System/Library/CoreServices/RemoteManagement/ARDAgent.app'
kickstart="$ARDAgent/Contents/Resources/kickstart"
options='-configure -clientopts -setvnclegacy -vnclegacy yes -setvncpw'

if (( $# < 2 )); then
    echo "Usage: $0 <run|echo> [newpassword]"
    echo 
    echo "Then 'run' option will run the command, and the 'echo' option"
    echo "will output the command you need to run to STDOUT."
    exit 1
else
    # $1 is the command
    # $2 is the new password
    case $1 in
        'run')
            sudo ${kickstart} $options -vncpw $2
        ;;
        'echo') 
            echo sudo ${kickstart} $options -vncpw $2
        ;;
    esac
fi 
