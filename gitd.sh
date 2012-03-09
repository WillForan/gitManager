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

$PYTHONBIN $APPDIR/xmppListener.py $xmppUser $xmppPasswd | 
while read bareName refBranch; do

  # e.g.  bareName=/home/git/gitManager.git 
  #      refBranch=refs/heads/master
  
  echo -e "RECIEVED MSG $(date)\n $bareName $refBranch"
  echo


  # print the local file ($F[1]) pulled from $gitManagedList that matches the remote file comming in from xmpp
  localDir="$(perl -slane 'print $F[1] if $F[0] eq $ENV{bareName} && $ENV{bareName} =~ $ENV{bareHostDir}'  $gitManagedList)"

  #[[ ! $bareName =~ /$bareHost/ ]] && echo "bad message" && continue

  # if there is a local dir, update it
  if [ ! "x$localDir" == "x" ]; then
    ! pushd $localDir && echo "$localDir doesnt exist?" && continue
    git pull  || echo "error on $localDir pull from $bareName!!" # | sendxmpp will@reese 
    popd 
  fi

  echo
  echo

done
