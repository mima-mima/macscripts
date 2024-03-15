#!/bin/bash

current_hostname=$(hostname)

# added name check here, do not want csb cleaning accounts. -mima 18aug23
# Check if the hostname begins with "xyz123-"
if [[ $current_hostname == csb616-* ]]; then
  echo `date` >> /Library/UR/cleanchkCSB.txt
  tgtPCT=5
  tgtGB=50
  # target this percentage of free space  
  tot=`df -Pg . | sed 1d | awk '{ print $2 "\t" }'`
  tgt=$((tot * tgtPCT / 100))
  if (($((tgtGB > tgt)))); then
    tgt=$tgtGB
  fi
  free=`df -Pg . | sed 1d | awk '{ print $4 "\t" }'`  && echo "updated free space: "$free
  if [ $free -lt $tgt ]; then
    /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -configure -computerinfo -set1 -1 "LOW SPACE"
  fi

else
  echo `date` >> /Library/UR/cleanchkOTHER.txt

# cleanup users!
#  Modified 2024-02-08
#  delete_inactive_users.sh
# Forked at https://github.com/mima-mima/macscripts
# Customized for UR use by Michael Maskalans
#  Maintained at https://github.com/dankeller/macscripts
#  by Dan Keller
#
#  MIT License
#
#======================================
#
#  Script to delete local user data that has not been accessed in a given time
#  period.
#
#  This script scans the /Users folder for the date last updated (logged in)
#  and deletes the folder as well as the corresponding user account if it has
#  been longer than the tiome specified. You can specify user folders to keep as
#  well.
#
#  User data not stored in /Users is not effected.
#
#  Helpful for maintaing shared/lab Macs connected to an AD/OD/LDAP server.
#
#======================================

# ignore case on user dirs!
shopt -s nocasematch
  #----Variables----
  AGE=5	# Delete /User/ folders inactive longer than this many days
  tgtPCT=10 # target this percentage of free space
  tgtGB=25 # with a minimum of this absolute free space in gb
  KEEP=("/Users/.vscode" "/Users/.localized" "/Users/Shared" "/Users/ard_user" "/Users/Presenter" "/Users/theresolution" "/Users/theking" "/Users/thesituation")
   # User folders you would like to bypass. Typically local users or admin accounts.
  CACHELIST="/Library/Caches/*,/Library/Updates/*,/Users/ard_user,/Applications/MATLAB_R2022a.app,/Library/Managed\ Installs/Cache/*"
   # cache etc locations to clean up when space is low
  keepCleaning=1
  #--End variables--

  #determine target free space, greater of tgtPCT or tgtGB
  tot=`df -Pg . | sed 1d | awk '{ print $2 "\t" }'`
  tgt=$((tot * tgtPCT / 100))
  if (($((tgtGB > tgt)))); then
    tgt=$tgtGB
  fi

  ### Delete Inactive Users ###

  while [ $keepCleaning = 1 ]
  do
   echo "AGE at start of loop:" $AGE
    USERLIST=$(find /Users -type d -maxdepth 1 -mindepth 1 -atime +"$AGE" -exec printf '%s\n' {} + | sed 's/ /\\ /g')


   echo "Performing inactive user cleanup"

    for a in $USERLIST; do
      if ! [[ ${KEEP[*]} =~ "$a" ]]; then
        echo "Deleting inactive (over $AGE days) account and home directory:" $a
    
        # delete user
        /usr/bin/dscl . delete $a > /dev/null 2>&1
    
        # move & delete home folder
        # moving first in case any content is SIP-protected and undeletable, such as com.apple.LaunchServicesTemplateApp.dv 
        delPre=.delete-`date +"%s"`-
        mv $a $delPre$a
        /bin/rm -rf $delPre$a
        continue
      else
        echo "SKIPPING" $a
      fi
    done

    free=`df -Pg . | sed 1d | awk '{ print $4 "\t" }'` # && echo "updated free space: "$free
    if [ $free -gt $tgt ]; then
      echo "free" $free "greater than target" $tgt "keepCleaning set to 0"
      keepCleaning=0
    fi
    if [ $keepCleaning -eq 1 ]; then
      echo "free" $free "less than target" $tgt "at day" $AGE "keepCleaning still" $keepCleaning
      if [ $AGE -eq 2 ]; then
        echo "still too full at day" $AGE "cleaning caches"
        #reformat caches into array to work around spaces
        IFS=, read -ra LIST_ARRAY <<< "$CACHELIST"
        for b in "${LIST_ARRAY[@]}"; do
          echo "Deleting cache:" "$b"
          /bin/rm -rf "$b" > /dev/null 2>&1
          continue
        done
      fi
      if [ $AGE -eq 0 ]; then
        echo "still too full at" $AGE "days, end of run setting kickstart and ending loop"
        /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -configure -computerinfo -set1 -1 "LOW SPACE"
        keepCleaning=0
      fi
    fi
      AGE=$(expr $AGE - 1)
      echo "age after decrement: " $AGE
      echo "keepclean at end of loop " $keepCleaning
  done
  echo "Cleanup complete"
fi
