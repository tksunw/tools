### ddtcalc.sh
* A script to calculate how much dedup you can have in a zpool for a given amount of RAM
* Once your DDT exceeds RAM and falls back to disk, your performance will plummet.
* Better yet, don't use dedup in zfs, just make the most of compression=on

-------

### propacls.sh
* This script will take a set of ZFS ACLs and recursively propagate them down through a filesystem.
* Usefull when you're making significant ACL changes and need to apply them to deep filesystems.
