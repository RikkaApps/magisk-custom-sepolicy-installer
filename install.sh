#!/system/bin/sh
print_modname() {
  ui_print "*****************************************"
  ui_print "SELinux Rules Example"
  ui_print "*****************************************"
}

patch_policy() {
  while read -r LINE || [ -n "$LINE" ]; do
    [ -z $LINE ] && continue
    ui_print "- Custom policy: $LINE"
    ./magiskpolicy --load ./sepolicy_custom --save ./sepolicy_custom "$LINE"
  done < ./policies.txt
}