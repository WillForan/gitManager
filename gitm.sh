#!/usr/bin/env bash

####
#   $0 -n -g # use current directory as as project, put on remote, put remote on github
#   $0 -s    # status of project
#   git pull
#   $0 -l # set local hooks and local watch directory
#
#   looks in $HOME/.config/gitm/rc for configuration
#
#   o make bare repository on a remote host
#   o add it as a remote origin
#   o adds local commit hook to push to origin
#   o add hook on remote to send xmpp (TODO: configurabe user@host)
#   o (optional (-g) -- can be run at any time) 
#        - create github repo 
#        - add github remote origin to bare repo
#        - add hook on bare to push to github
#  
#  -p  string   project name
#
#     if not provided, assume name is cwd
#     (even if using -W, should do the right thing)
#
#   ####### overide defults ###########
#  -H  string   host for git projects bare git repo
#  -R  string   root dir for git projects on host
#  -W  string   local project working directory
#      should instead be run in the working directory of the project
#
#  ######## flags ##########
#  -s  flag     get status

#  -g  flag     create github and add as remote hook
#  -G  flag     add github as remote hook (-gG same as -G)

#  -n  flag     is/create a new project
#  -c  flag     check dirname is expected
#
#  assumes bare git repo at ssh://host/rootdir/project
#  
#  intended to be run in root directory of current project (without -W)
#
#ENDHELP
####
#### SETUP  ######

function setup {

   configdir=$HOME/.config/gitm

   # make configuration directory
   mkdir -p $configdir 

   # are we in a good dir?
   # need xmppListener b/c gitd.sh relies on APPDIR to find it,
   #  APPDIR set to $(pwd)
   [ ! -r rc.sample -o ! -r xmppListener.py ]                             && \
     echo "setup should be in the same dir as rc.sample and xmppListener" && \
     exit 1

   # if there isn't a python2 binary, python2 is probably python
   python=$(which python2  2>/dev/null || which python)

   # but lets check that
   $python -V 2>&1 | grep " 2" 1>/dev/null || python=

   [ -z $python ]                                           && \
    echo "couldnt find python2; cannot listen for updates!" && \
    exit 1

   # check that xmpppy is installed, or try to install locally
   if ! $python -c "import xmpp" 2>/dev/null && [ ! -d xmpp ]; then
     # download and unpack xmpppy
     wget 'http://downloads.sourceforge.net/project/xmpppy/xmpppy/0.5.0-rc1/xmpppy-0.5.0rc1.tar.gz?r=http%3A%2F%2Fsourceforge.net%2Fprojects%2Fxmpppy%2Ffiles%2Fxmpppy%2F0.5.0-rc1%2F&ts=1331309526&use_mirror=voxel' -O xmpppy-0.5.0rc1.tar.gz
     tar -xvf xmpppy-0.5.0rc1.tar.gz
     
     # get the useful directory and discard the rest
     mv xmpppy-0.5.0rc1/xmpp ./
     rm -r xmpppy-0.5.0rc1 xmpppy-0.5.0rc1.tar.gz

     ! $python -c "import xmpp" 2>/dev/null && \
     echo "xmpppy local install failed"     && \
     exit 1

   fi

   # copy rc if we're not overwritting, return from function otherwise
   [ ! -r $configdir/rc ]  && cp rc.sample $configdir/rc  || return


   sed -i -e "s:PYTHONBIN=.*:PYTHONBIN=${python}:" $configdir/rc 
   echo "APPDIR=\"$(pwd)\"" >> $configdir/rc
   echo "set +a"            >> $configdir/rc

   # edit the created config file
   [ -n $EDITOR ] || EDITOR="$(which vim)"
   $EDITOR $configdir/rc
    
   source  $configFile
}








#### SETTINGS #####

configFile=$HOME/.config/gitm/rc

! source  $configFile   2>/dev/null                && \
  echo "Cannot source configuration: $configFile!" && \
  echo "Running Setup"                             && \
  setup






#### Functions #####

function dispHelp {
   echo "USAGE: $0"

   # use top of the file as the help
   sed -ne 's/^# //p; /#ENDHELP/q' $0;

   exit 1
}
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
   curl -u $githubUser:$githubPass -H -X POST -d "{\"name\": \"$project\"}" https://api.github.com/user/repos | 
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
function addPostHook {
 # write whatever $@ is to post-update git hook
 # create file with shabnag and correct permissions if DNE
 ssh $bareHost "cd $bareHostDir/$remoteProjName/hooks;
                  if [ ! -r post-update ]; then
                   echo '#!/bin/sh' > post-update
                   chmod +x post-update
                  fi 

                  echo '$@' >> post-update"

 return $?
}

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

   # get the url path whos base is the remote bare host
   # rather than use $remoteProjName -- this allows -l to work when -n wasn't used
   #  and provides a check that we can work on this git tree
   proj="$(perl -ne 's:/+:/:g; print $1 if /url.*$ENV{"bareHost"}:(.*)/' .git/config)"
  
   # addlocalhooks can be called before remote add
   [ -z "$proj" ] && \
     echo "no url matching $bareHost (should have been $remotePath$remoteProjName) in .git/config" && \
     return 1;

   # proj is in the file already OR  add it
   grep "^$proj" $gitManagedList 1>/dev/null 2>&1 || \
     echo "$proj $(pwd)" >> $gitManagedList;
}

####### PARSE INPUT OPTIONS ##########

# if no args, pretend it's -s
[ "x$1" == "x" ] && getStatus=1

while getopts "cglnspG:H:R:W:" opt; do
   case $opt in
    n) # create a new project on remote host
      newProject=1
    ;;
    g) # create a new project on remote hostB
      github=1
    ;;
    l) # local hooks only
      localHooks=1
    ;;
    p) # project name on remote host
      project=$OPTARG
    ;;
    c) # dont care about known convetions
      dontcheck=1
    ;;
    s) # dont care about known convetions
      getStatus=1
    ;;


    H) # (Host)  what machine to add bare project to
      bareHost=$OPTARG
    ;;
    R)  # (Root) where to put projects on the host
      bareHostDir=$OPTARG
    ;;
    W)  # working root for project is elsewhere, cd to it
      cd $OPTARG || exit 1
    ;;
    G) # add github post-update hook for project that already exists
      github=1
      githubcreated=1
    ;;
    *)
      dispHelp
    ;;
   esac
done

#### CHECKS and SETUP ######

# check that the cwd is where we expect projects to be
# when we arn't simily checking status and there isn't alrady a .git folder
# give a chance to quit if it isn't (overide interative-ness with -c [for no check])
[ -z $dontcheck ] && [[ ! $(dirname $(pwd)) =~ "/$expectToBeIn" ]]        && \
 [ ! -d .git ]    && [ -z $getStatus ]                                    && \
   echo "are you sure you want to start a project in $(pwd)? (^C for no)" && \
   read

# project is cwd name if not provided with p
[ -n "$project" ] || project=$(basename $(pwd));

remoteProjName=$project.git


#### DO WORK ######
if [ $localHooks ]; then
 # clear the options that do things
 newProject=
 github=
 addlocalhooks
 addProjectToWatchlist
fi

# create a new project
if [ $newProject ]; then

   # create remote with hooks if its not there
   if ! ssh $bareHost "ls $bareHostDir/$remoteProjName"  1>/dev/null 2>&1; then

      # create bare repo on host 
      ! ssh $bareHost "cd $bareHostDir; git init --bare $remoteProjName" && \
         echo "could not create bare $project"                           && \
         exit 1

      # add post-update  xmpp message sending to remote server
      # or exit with message (maybe don't have to die for this error?)
      ! addPostHook 'echo "$(pwd) $@" |' " /usr/bin/site_perl/sendxmpp $xmppUser"  && \
         echo "post-update hook creation failed"                                   && \
         echo "This shouldn't happen - Im quitting"                                && \
         exit 1

   else
      echo "$remoteProjName already exists on $bareHost"
   fi

   # if there is a git repo
   # make sure there isn't already a remote section
   if [ -r .git ]; then
      grep remote .git/config  1>/dev/null 2>&1              && \
         echo "You already have a remote in your .git/conf." && \
         echo "I'm not touching that"                        && \
         exit 1;

      # repo exists but doesn't talk to anything else yet
      echo youve already started a local git repo here, thats cool


   # if there isn't a git repo 
   # make current directory a git repo
   else
      # if we can't create a rep exit with explination
      ! git init  && echo "can't make $(pwd) a repo, not pushing to host" && exit 1
   fi

      # if there is no log need to make a commit
      # only happens if git init is run, but no commit
      # e.g. we just created the git repo
   if ! git log 1>/dev/null 2>&1 ; then

      # everything should have a readme
      vim README
      git add README

      # commit changes
      git commit -m 'initial, via gitm.sh'
   fi

   # set remote origin and push to it
   git remote add origin "$bareHost:$bareHostDir/$project.git" && \ 
      git push -u origin master 

   # add local hooks
   # - push to bareHost on commit
   addlocalhooks

   # add bareHostDir <-> local dir to to xmpp message watch list
   addProjectToWatchlist
fi

if [ $github ]; then

 # if we don't think a github repos been created already 
 # try creating one
 # if that fails exit with an error message
  [ -z "$githubcreated" ]                              && \
   ! newGitHub                                         && \
   echo "github for $project already exists (use -G) " && \
   echo "or bad user/token"                            && \
   exit 1


 # check remote exists, and doesn't have it's own remote in config yet
 # add github to remote or exit with error message
 ! ssh $bareHost "cd $bareHostDir/$remoteProjName                           && \
                 ! grep remote config                                       && \
                 git remote add origin git@github.com:$githubUser/$project  && \
                 git push -u origin master"   1>/dev/null 2>&1              && \
    echo "could not add git@github.com:$githubUser/$project as remote"      && \
    echo "either remote already exists or push failed"                      && \
    exit 1;

 # add hook to update to github
 addPostHook 'git push origin master'

fi 

if [ $getStatus ]; then
  
  # is git (cwd is set by -W or is project dir)
  echo "LOCAL"

  [ ! -d .git ] && echo "$project is not tracked by git" && \
     exit

  echo " REMOTE"
  sed -ne '/^\[remote/,+2 s/^/	/p' .git/config 2>/dev/null

  echo " POST-COMMIT"
  sed -e 's/^/	/' .git/hooks/post-commit 2>/dev/null || echo -e "	NONE"


  # is it on the bare remote host?
  ! ssh $bareHost "ls $bareHostDir/$remoteProjName"  1>/dev/null 2>&1&& \
     echo "$bareHost:$bareHostDir/$remoteProjName  does not exist "  && \
     exit

  echo 
  echo "BARE: git clone $bareHost:$bareHostDir/$remoteProjName"
  echo " REMOTE"
  (ssh $bareHost "grep -A2 '\[remote' $bareHostDir/$remoteProjName/config"        || echo "NONE") | 
     sed -e 's/^/	/' 

  echo " POST-UPDATE"
  (ssh $bareHost "cat $bareHostDir/$remoteProjName/hooks/post-update 2>/dev/null" || echo -e "NONE")  | 
    sed -e 's/^/	/' 


  # and are we watching this for changes? 

  echo
  echo "WATCHED ($gitManagedList)"
  echo $(grep "$(pwd)" $gitManagedList || echo "no") | sed -e 's/^/	/'
fi

