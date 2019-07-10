#!/system/bin/sh
##########################################################################################
# Functions
##########################################################################################

# Pure bash dirname implementation
getdir() {
  case "$1" in
    */*) dir=${1%/*}; [ -z $dir ] && echo "/" || echo $dir ;;
    *) echo "." ;;
  esac
}

##########################################################################################
# Initialization
##########################################################################################

if [ -z $SOURCEDMODE ]; then
  # Switch to the location of the script file
  cd "`getdir "${BASH_SOURCE:-$0}"`"
  # Load utility functions
  . ./util_functions.sh
fi

BOOTIMAGE="$1"
[ -e "$BOOTIMAGE" ] || abort "$BOOTIMAGE does not exist!"

chmod -R 755 .

##########################################################################################
# Unpack
##########################################################################################

CHROMEOS=false

ui_print "- Unpacking boot image"
./magiskboot unpack "$BOOTIMAGE"

case $? in
  1 )
    abort "! Unsupported/Unknown image format"
    ;;
  2 )
    ui_print "- ChromeOS boot image detected"
    CHROMEOS=true
    ;;
esac

##########################################################################################
# Ramdisk restores
##########################################################################################

# Test patch status and do restore
ui_print "- Checking ramdisk status"
if [ -e ramdisk.cpio ]; then
  ./magiskboot cpio ramdisk.cpio test
  STATUS=$?
else
  # Stock A only system-as-root
  STATUS=0
fi
case $((STATUS & 3)) in
  0 )  # Stock boot
    ui_print "- Stock boot image detected"
    abort "! Please install Magisk first"
    ;;
  1 )  # Magisk patched
    ui_print "- Magisk patched boot image detected"
	./magiskboot cpio ramdisk.cpio "exists sepolicy_custom"
    if [ $? -eq 0 ]; then
      ui_print "- Patch from existing sepolicy_custom"
      ./magiskboot cpio ramdisk.cpio "extract sepolicy_custom ./sepolicy_custom"
    else
      if [ -f /system/etc/selinux/plat_sepolicy.cil ]; then
        ui_print "- Creating new sepolicy_custom from split cil policies"
        ./magiskpolicy --load-split --save ./sepolicy_custom
      else
	    ./magiskboot cpio ramdisk.cpio "exists sepolicy"
        if [ $? -eq 0 ]; then
          ui_print "- Extracting sepolicy"
          ./magiskboot cpio ramdisk.cpio "extract sepolicy sepolicy_custom"
        fi
      fi
    fi
    ;;
  2 )  # Unsupported
    ui_print "! Boot image patched by unsupported programs"
    abort "! Please restore back to stock boot image and install Magisk"
    ;;
esac

##########################################################################################
# Ramdisk patches
##########################################################################################

[ -f ./sepolicy_custom ] || abort "! Failed to create sepolicy_custom"

ui_print "- Patching ramdisk"

while read -r LINE || [ -n "$LINE" ]; do
    [ -z $LINE ] && continue
    ui_print "- Custom policy: $LINE"
    ./magiskpolicy --load ./sepolicy_custom --save ./sepolicy_custom "$LINE"
done < ./policies.txt

./magiskboot cpio ramdisk.cpio \
"add 644 sepolicy_custom sepolicy_custom"

if [ $((STATUS & 4)) -ne 0 ]; then
  ui_print "- Compressing ramdisk"
  ./magiskboot --cpio ramdisk.cpio compress
fi

rm -f sepolicy_custom

##########################################################################################
# Repack and flash
##########################################################################################

ui_print "- Repacking boot image"
./magiskboot repack "$BOOTIMAGE" || abort "! Unable to repack boot image!"

# Sign chromeos boot
$CHROMEOS && sign_chromeos

# Reset any error code
true
