#!/usr/bin/env bash

####
#   $0 
#ENDHELP
####

#### SETTINGS #####
configFile=$HOME/.config/gitm/rc
! source  $configFile   2>/dev/null                && \
  echo "Cannot source configuration: $configFile!" && \
  exit 1


# project name
[ -z "$project" ] &&   project="$(perl -ne 's:/+:/:g; print $1 if /url.*github.com:$ENV{githubUser}\/(.*)/' .git/config)"
[ -z "$project" ] && project=$(basename $(pwd))

echo project is $project

#### Functions #####

# whats up
function dispHelp {
   echo "USAGE: $0"

   # use top of the file as the help
   sed -ne 's/^# //p; /#ENDHELP/q' $0;

   exit 1
}

# create repo
function newGitHub {

   ## get this from RC file now
   ### exit if we can't read  (maybe should just return?)
   ##[ ! -r "$githubconf" ] && echo "Cannot read $githubconf" && exit 1

   ### get user and token from githubconf and export them
   ##set -a
   ##sed -e 's/\s*#.*//;/^$/d' $githubconf | read githubUser token
   ##set +a

   [ -z $githubUser -o -z $token -o "$githubUser" == "fillMeIn" ] && \
    echo "Github settings are not set in $configFile"             && \
    exit 1

   # use new github API to create new repo
   curl -u $githubUser:$githubPass -X POST -d "{\"name\": \"$project\"}" https://api.github.com/user/repos |
    grep created_at 1>/dev/null 2>&1 

   # OLD API
   #curl -k                       \
   #     -F "login=$githubUser"   \
   #     -F "token=$token"        \
   #     -F "name=$project"       \
   #     https://github.com/api/v2/yaml/repos/create |
   # grep created_at 1>/dev/null 2>&1 

   return $? # return true if curl has created_at in response
}

# show github hooks
function dispGitHook {
 curl -u $githubUser:$githubPass -X GET https://api.github.com/repos/$githubUser/$project/hooks
}

# send jabber IM as push hook with github
function addGitHook {
  
  # test with dispGitHook
  # add if not there

  jabberhook=$(
cat <<HEREDOC
   {
      "name": "jabber",
         "active": true,
         "config": {
            "user": "lncdbot@jabber.org"
         }
   }
HEREDOC
)

   curl -u $githubUser:$githubPass -X POST \
        -d "$jabberhook" https://api.github.com/repos/$githubUser/$project/hooks
}

#
# local hook is just to push on commit
function addlocalhooks {
   # check we have a git dir or exit
   [ ! -d .git ] && echo "Not a git repo" && return 1

   #
   # add push for commit if it's not already there
   
   # create file if DNE
   ls .git/hooks/post-commit 1>/dev/null 2>&1 || \
      ( echo '#!/bin/sh' > .git/hooks/post-commit && \
        chmod +x           .git/hooks/post-commit)

   #add push if DNE
   grep '^git push$'   .git/hooks/post-commit 1>/dev/null || \
    echo 'git push' >> .git/hooks/post-commit
}

function addProjectToWatchlist {
   # proj is in the file already OR  add it
   grep "^$project" $gitManagedList 1>/dev/null 2>&1 || \
     echo "$project $(pwd)" >> $gitManagedList;
}

function addGitHub {
  if ! grep '^\[remote' .git/config; then
     git remote add origin git@github.com:$githubUser/$project && \
     git push -u origin master
  else
     echo "already have remote"
     return 1
  fi
}



### show what's configured
function gitStatus {
  echo "LOCAL"

  [ ! -d .git ] && echo "$project is not tracked by git" && \
     return 1

  echo " REMOTE"
  sed -ne '/^\[remote/,+2 s/^/	/p' .git/config 2>/dev/null

  echo " POST-COMMIT"
  sed -e 's/^/	/' .git/hooks/post-commit 2>/dev/null || echo -e "	NONE"

  echo
  echo "WATCHED ($gitManagedList)"
  echo $(grep "$(pwd)" $gitManagedList || echo "no") | sed -e 's/^/	/'

  echo "GITHUB"
  echo " HOOKS"
  dispGitHook
}

