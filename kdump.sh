#######configure-kdump file, remove this header lines######
#######set execute permission and then run the script######
#!/bin/bash
##--------- Written By:G@nesh L@d-----------------------------------##
##--------- Purpose : This script would performs various sanity checks,------## 
##---------          install package, set kernel parameters and other--------##
##---------          settings to enable kdump, and allow user to test.-------##
##--------- Requirement: Root or Sudo user ----------------------------------##
##--------- Date : Jan 2020---------------------------------------------##

TOTAL_MEM=$(free -g|grep Mem:|awk '{print $2}')
CRASH_VAR=0
CHANGED=No
ANS=N
uname -r |grep el7 1>&2 > /dev/null && REL=RHEL7 
uname -r |grep el6 1>&2 > /dev/null && REL=RHEL6 

#-----Install kexec-tools package if not installed-------#
kdump_install()
{
printf "Checking if kexec-tools package was installed........... "
rpm -q kexec-tools 2>&1 > /dev/null
if [ $? != 0 ]
then
{
  sleep 1
  yum install kexec-tools -y -q 2> /dev/null 
  rpm -q kexec-tools 2>&1 > /dev/null
  if [ $? == 0 ]
  then
   printf " Successfully installed now.\n" 
   CHANGED=Yes
  else
   printf " An error occured while installing the package, please check. Bye!\n"
  exit 1
  fi
}
else
 printf " Yes, installed.\n"
fi
}

#-------Crash memory calculations based on "RHEL version" and "Total RAM"-------#
case $REL in
 RHEL6)
  if [ $TOTAL_MEM -le 2 ]
  then
   CRASH_VAR=128M
  elif [[ $TOTAL_MEM -gt 2 && $TOTAL_MEM -le 6 ]]
  then
   CRASH_VAR=256M
  elif [[ $TOTAL_MEM -gt 6 && $TOTAL_MEM -le 8 ]]
  then
   CRASH_VAR=512M
  elif [[ $TOTAL_MEM -gt 8 && $TOTAL_MEM -le 16 ]]
  then
   CRASH_VAR=768M
  elif [[ $TOTAL_MEM -gt 16 && $TOTAL_MEM -le 32 ]]
  then
   CRASH_VAR=2G
  elif [[ $TOTAL_MEM -gt 32 && $TOTAL_MEM -le 128 ]]
  then
   CRASH_VAR=4G
  else
   CRASH_VAR=8G
  fi
  ;;

RHEL7)
  if [ $TOTAL_MEM -le 2 ]
  then
   CRASH_VAR=128M
  elif [[ $TOTAL_MEM -gt 2 && $TOTAL_MEM -le 6 ]]
  then
   CRASH_VAR=256M
  elif [[ $TOTAL_MEM -gt 6 && $TOTAL_MEM -le 8 ]]
  then
   CRASH_VAR=512M
  elif [[ $TOTAL_MEM -gt 8 && $TOTAL_MEM -le 16 ]]
  then
   CRASH_VAR=768M
  elif [[ $TOTAL_MEM -gt 16 && $TOTAL_MEM -le 32 ]]
  then
   CRASH_VAR=2G
  elif [[ $TOTAL_MEM -gt 32 && $TOTAL_MEM -le 128 ]]
  then
   CRASH_VAR=4G
  else
   CRASH_VAR=8G
  fi
  ;;
 *)
  if [ $TOTAL_MEM -lt 2 ]
  then
   CRASH_VAR=128M
  else
   CRASH_VAR=auto
  fi
  ;;
esac



#-----Check for minimum space requirement under /var -------#
printf "Checking space availability under /var file system........... "
if [ $(df -PTh /var |awk '{print $6}'|sed -e 's/%//g'|tail -1) -ge 90 ]
then
 echo "Not enough space for /var file system. Please fix this first and re-run the script. Terminating program. Bye!"
 exit 1
fi
printf " Passed. /var space available to configure kdump\n"

#-----Check if kdump is operational-----#
#----if kdump is operational then other parameters would be checked----#
if [[ $REL == RHEL6 ]]
then
 ## exit status would report Only zero if service is up.
 /sbin/service kdump status > /dev/null 2>&1 || kdump_install
else
 systemctl is-active kdump 2>&1 > /dev/null || kdump_install
fi

#------Check if default dump path is set, otherwise, set it ---------#
printf "Checking if /etc/kdump.conf was set with defaults........... "
if [[ $(grep ^path /etc/kdump.conf) && $(grep ^core_collector /etc/kdump.conf) ]]
then
  printf " Yes, already set.\n"
else
 {
 cp /etc/kdump.conf /etc/kdump.conf-$(date +%d%m%Y)
 sleep 1
 echo "#------Configure kdump with default settings------#" >> /etc/kdump.conf
 echo "path /var/crash" >> /etc/kdump.conf 
 echo "core_collector makedumpfile -c --message-level 1 -d 31" >> /etc/kdump.conf
 printf " Successfully configured. \n"
 CHANGED=Yes
 }
fi

#-------Check if crashkernel is already set, otherwise, set it-------#
printf "Check to see if crashkernel parameter was set ................ "
CURRENT_CRASH=$(grep -o crashkernel.* /proc/cmdline |awk '{print $1}'|awk -F= '{print $2}')
#-------for RHEL6 platform----------#
if [[ $REL == RHEL6 ]]
then
{
  if [[ $(grep vmlinuz-$(uname -r) /boot/grub/grub.conf|grep -o crashkernel.*|awk '{print $1}'|awk -F= '{print $2}') != $CRASH_VAR ]]
  then
   cp /boot/grub/grub.conf /boot/grub/grub.conf-$(date +%d%m%Y)
   grubby --args="crashkernel=$CRASH_VAR" --update-kernel=/boot/vmlinuz-$(uname -r) > /dev/null 2>&1
   printf " Configured Successfully.\n"
  elif [[ $CURRENT_CRASH != $CRASH_VAR ]]
  then
   printf " needs reboot. \n"
   CHANGED=Yes
  else
   printf "Yes, it was set. \n"
  fi
}
else
{
#-------for RHEL7 platform----------#
DEFAULT_CRASH=$(grep -w GRUB_CMDLINE_LINUX /etc/default/grub|grep -o crashkernel.*|awk '{print $1}'|awk -F= '{print $2}'|sed 's/"//')
 
 if [[ $DEFAULT_CRASH != $CRASH_VAR ]]
 then
 {
  cp /etc/default/grub /etc/default/grub-$(date +%d%m%Y)
  cp /boot/grub2/grub.cfg /boot/grub2/grub.cfg-$(date +%d%m%Y)
  
  if [[ $(grep -w GRUB_CMDLINE_LINUX /etc/default/grub|grep crashkernel) && -n $DEFAULT_CRASH ]]
  then
   sed -i 's/crashkernel='$DEFAULT_CRASH'/crashkernel='$CRASH_VAR'/' /etc/default/grub
  else
   #-----remove quotes at the end, then add crashkernel word with quotes-----#
   sed -i '/GRUB_CMDLINE_LINUX/ s/"$//' /etc/default/grub
   sed -i '/GRUB_CMDLINE_LINUX/ s/$/ crashkernel='$CRASH_VAR\"'/' /etc/default/grub
  fi
  grub2-mkconfig -o /boot/grub2/grub.cfg > /dev/null 2>&1
  printf " Configured Successfully.\n"
 }
 elif [[ $CURRENT_CRASH != $CRASH_VAR ]]
 then
  printf " needs reboot. \n"
  CHANGED=Yes
 else
  printf "Yes, it was set. \n"
 fi
}
fi

#------Add kernel.sysrq to sysctl.conf file if missing-------#
printf "Check if \"kernel.sysrq\" is enabled in /etc/sysctl.conf file ............."
sleep 1
if [ $(sysctl -n kernel.sysrq) != 1 ]
then
{
 grep ^kernel.sysrq /etc/sysctl.conf 2>&1 > /dev/null && \
 sed -i "s/kernel.sysrq.*/kernel.sysrq = 1/" /etc/sysctl.conf || \
 grep ^\#kernel.sysrq /etc/sysctl.conf 2>&1 > /dev/null && \
 sed -i "s/#kernel.sysrq.*/kernel.sysrq = 1/" /etc/sysctl.conf || \
 echo "kernel.sysrq = 1" >> /etc/sysctl.conf 
 printf " \"kernel.sysrq\" parameter has been set.\n"
 /sbin/sysctl kernel.sysrq=1 1>&2 > /dev/null
}
else
 printf "Yes, was enabled.\n"
fi

printf "Check if \"kernel.unknown_nmi_panic\" is enabled in sysctl.conf file ............."
#----This would enable NMI button use on hardware case, when server goes un-responsive------#
#------and doesn't respond to keyboard or magic keys.-------#

if [ $(sysctl -n kernel.unknown_nmi_panic) != 1 ]
then
{
 grep ^kernel.unknown_nmi_panic /etc/sysctl.conf 2>&1 > /dev/null && \
 sed -i "s/kernel.unknown_nmi_panic.*/kernel.unknown_nmi_panic = 1/" /etc/sysctl.conf || \
 grep ^\#kernel.unknown_nmi_panic /etc/sysctl.conf 2>&1 > /dev/null && \
 sed -i "s/#kernel.unknown_nmi_panic.*/kernel.unknown_nmi_panic = 1/" /etc/sysctl.conf || \
 echo "kernel.unknown_nmi_panic = 1" >> /etc/sysctl.conf 
 printf " \"kernel.unknown_nmi_panic\" parameter has been set.\n"
 /sbin/sysctl kernel.unknown_nmi_panic=1 1>&2 > /dev/null
}
else
 printf "Yes, was enabled.\n"
fi

#------Enable kdump service to start on boot-------#
printf "Checking to see if kdump service is enabled to start on boot............."
if [[ $REL == RHEL6 ]]
then 
{
KDUMP_ST=$(chkconfig --list kdump)

if [[ $(echo $KDUMP_ST|awk '{print $5}'|awk -F: '{print $2}') == off && \
$(echo $KDUMP_ST|awk '{print $7}'|awk -F: '{print $2}') == off ]]
then
 chkconfig kdump --level 35 on 1>&2 > /dev/null
 printf " Enabled successfully.\n"
 CHANGED=Yes
else
 printf " Yes, was enabled. \n"
fi
}
else
#-----for RHEL7 platform--------#
{
 if [ "$(systemctl is-enabled kdump)" != "enabled" ]
 then
   systemctl enable kdump > /dev/null 2>&1 && printf " Enabled successfully.\n"
   CHANGED=Yes
 else
   printf " Yes, was enabled. \n"
 fi
}
fi

#-----Check if something got changed, then a reboot is required----#
if [ $CHANGED == Yes ]
then
  echo -e "\nAll parameters are configured as recommended............. Please reboot the server." 
fi
