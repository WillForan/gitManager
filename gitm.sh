#!/usr/bin/env bash

####
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
#  -n  flag     is/create a new project
#  -c  flag     check dirname is expected
#
#  assumes bare git repo at ssh://host/rootdir/project
#  
#  intended to be run in root directory of current project (without -W)
#
#ENDHELP
####
function dispHelp {
   echo "USAGE: $0"

   # use top of the file as the help
   sed -ne 's/^# //p; /#ENDHELP/q' $0;

   exit 1
}

   dontcheck=

    bareHost='git@reese'
 bareHostDir='/home/git/'

expectToBeIn='src'      # most projects start in ....src/project -- warn if thats not the case
while getopts "ncp:H:R:W:" opt; do
   case $opt in
    n) # create a new project on remote host
      newProject=1
    ;;
    p) # project name on remote host
      project=$OPTARG
    ;;
    c) # dont care about known convetions
      dontcheck=1
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
    *)
      dispHelp
    ;;
   esac
done

# check that the cwd is where we expect projects to be
# give a chance to quit if it isn't (overide interative-ness with -c [for no check])
[ -z $dontcheck ] && [[ ! $(dirname $(pwd)) =~ "/$expectToBeIn" ]]        &&  \
   echo "are you sure you want to start a project in $(pwd)? (^C for no)" &&  \
   read

# project is cwd name if not provided with p
[ -n "$project" ] || project=$(basename $(pwd));

# create a new project
if [ $newProject ]; then

   # make sure it's actually new to the host
   ssh $bareHost "ls $bareHostDir/$project.git" 2>&1 1>/dev/null  && \
      echo "$project.git already exists on $bareHost"             && \
      exit 1

   # create bare repo on host 
   ! ssh $bareHost "cd $bareHostDir; git init --bare $project.git" && \
      echo "could not create bare $project"                        && \
      exit 1


   # if there is a git repo
   # make sure there isn't already a remote section
   if [ -r .git ]; then
      grep remote .git/config 2>&1 1>/dev/null               && \
         echo "You already have a remote in your .git/conf." && \
         echo "I'm not touching that"                        && \
         exit 1;
      echo youve already started a local git repo here, thats cool

   # if there isn't a git repo 
   # make current directory a git repo
   else
      # if we can't create a rep exit with explination
      ! git init  && echo "can't make $(pwd) a repo, not pushing to host" && exit 1

      # everything should have a readme
      vim README
      git add README

      # commit changes
      git commit -m 'initial, via gitm.sh'
   fi



   # set remote origin
   git remote add origin $bareHost:$bareHostDir/$project.git

   # push to it
   git push origin master

else
 echo "I don't do anyting without -n option yet"
fi

