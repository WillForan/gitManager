#!/usr/bin/env bash

####
#   $0 -n -g # use current directory as as project, put on remote, put remote on github
#  
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
#  -n  flag     is/create a new project
#  -c  flag     check dirname is expected
#  -g  flag     create github and add as remote hook
#  -G  flag     add github as remote hook (-gG same as -G)
#
#  assumes bare git repo at ssh://host/rootdir/project
#  
#  intended to be run in root directory of current project (without -W)
#
#ENDHELP
####

#### SETTINGS #####

  githubconf=$(dirname $0)/github.conf
    bareHost='git@reese'
 bareHostDir='/home/git/'
expectToBeIn='src'      # most projects start in ....src/project -- warn if thats not the case

#### Functions #####

function dispHelp {
   echo "USAGE: $0"

   # use top of the file as the help
   sed -ne 's/^# //p; /#ENDHELP/q' $0;

   exit 1
}
function newGitHub {

   # return if we can't read
   [ ! -r "$githubconf" ] && echo "Cannot read $githubconf" && return 1

   # get user and token from githubconf
   read user token < $githubconf

   # use github API to create new repo
   curl -F "login=$user"   \
        -F "token=$token"  \
        -F "name=$project" \
        https://github.com/api/v2/yaml/repos/create |
    grep created_at 2>&1 2>/dev/null

   return $? # return true if curl has created_at in response
}


while getopts "cgnp:H:R:W:" opt; do
   case $opt in
    n) # create a new project on remote host
      newProject=1
    ;;
    g) # create a new project on remote hostB
      github=1
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
    G) # create a new project on remote hostB
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
# give a chance to quit if it isn't (overide interative-ness with -c [for no check])
[ -z $dontcheck ] && [[ ! $(dirname $(pwd)) =~ "/$expectToBeIn" ]]        &&  \
   echo "are you sure you want to start a project in $(pwd)? (^C for no)" &&  \
   read

# project is cwd name if not provided with p
[ -n "$project" ] || project=$(basename $(pwd));

remoteProjName=$project.git


#### DO WORK ######

# create a new project
if [ $newProject ]; then

   # make sure it's actually new to the host
   ssh $bareHost "ls $bareHostDir/$remoteProjName" 2>&1 1>/dev/null   && \
      echo "$remoteProjName already exists on $bareHost"              && \
      exit 1

   # create bare repo on host 
   ! ssh $bareHost "cd $bareHostDir; git init --bare $remoteProjName" && \
      echo "could not create bare $project"                           && \
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


 # check remote exists, and doesn't have a remote in config
 #ssh $bareHost  'cd $bareHostDir/$remoteProjName && ! grep remote .git/config '  2>&1 1>/dev/null
 # git remote add origin git@github.com:WillForan/gitManager.git
 # git push -u origin master
 # add remote
 # add hook
fi 
