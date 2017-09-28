
# REPLACE A DISK IN A CORAID ZX/SRX POOL:
----
### 1. ON SRX: Offline & remove the disk
    SRX shelf X> offline ${disk}
    SRX shelf X> remove ${disk}

### 2. ON SRX: Locate the disk in the shelf
  #### 1. On CorOS previous to 6.2.1, locate the failed disk with:
    SRX shelf X> slotled ${disk} locate

  #### 2. On CorOS 6.2.1 and above, locate the failed disk with:
    SRX shelf X> setslotled locate ${disk}
----
### 3. Physically replace disk
----
### 4. ON SRX: Find the correct MASK for use when recreating the JBOD:

You may be able to copy the mask from another lun, using the `mask` command on the SRX:
    SRX shelf X> mask

| These MACs are what I had in old documentation from the NCMC installation:
|---------------------------------------------------------------------------------------------------
| HBA MACs for NCMC primary ZX Heads (zx1, and zx2) in mask format:
| +001004012e81 +001004012db9 +001004012e80 +001004012db8 +001004012db5 +001004012db3 +001004012db4 +001004012db2
| HBA MACs for NCMC replica ZX Head (zx3) in mask format:
| +001004012e7f +001004012db7 +001004012e7e +001004012db6
 

----
### 4. ON SRX: Make the new JBOD AoE lun, apply the masks, and online it (USE THE SAME SHELF.SLOT AS BEFORE):
    SRX shelf X> make ${disk} jbod ${shelf}.${slot}
    SRX shelf X> mask ${disk} ${mask-formatted-hba-macs-from-above}
    SRX shelf X> online ${disk}
----
### 5 ON ZX: Tell the ZX to rescan the AoE Drives and remove any stale device entries for the old drives
    echo flush > /proc/ethdrv/ctl
----
### 5 ON ZX: Tell ZFS you have replaced the disk (with "itself")
    zpool replace ${zpool} ${CTD} ${CTD}
----
### 6 ON ZX: Verify status
    zpool status ${zpool}
----
