#!/usr/bin/env bash

  gitManagerRC=$HOME/.config/gitm/rc

# read from rc file
source $gitManagerRC || exit "could read configuration file"

[ -z $xmppUser -o -z $xmppPasswd -o -z $gitManagedList ] && \
  echo "Not all needed configuration options set"        && \
  exit 1;

#
# watch the listener for new messages
#   if the remote name is in our list file
#    cd to the local repo
#    try to pull
#

./xmppListener.py $xmppUser $xmppPasswd | 
while read bareName refBranch; do

  # e.g.  bareName=/home/git/gitManager.git 
  #      refBranch=refs/heads/master

  localDir="$(awk -v bn="$bareName" '($1 == bn ){print $2}' $gitManagedList)"

  if [ -n $localDir ]; then
    pushd $localDir
    git pull  || echo "error on $localDir pull from $bareName!!" # | sendxmpp will@reese 
    popd 
  fi

done
