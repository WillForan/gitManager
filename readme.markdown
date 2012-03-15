# gitd.sh #

watch for xmpp messages
match message to local directory watch list
git pull

	screen -dmS gitd-session ./gitd.sh

# gitm.sh #

small bash script to

* (-n) make bare repository on a remote host
* (-n) add it as a remote origin
* (-n) add hook on remote to send xmpp (TODO: configurabe user@host)
* (-n or -l) adds local commit hook to push to origin
* (-n or -l) adds bare repo and localdir to watch list
* also use github
	- (-g) create github repo
	- (-g or -G) add github remote origin to bare repo
	- (-g or -G) add hook on bare to push to github

## Usage cases ##

### start (to track) a project ###
working along in a directory, decided it should be tracked

	gitm.sh -n -g

will create a bare repo on remote host and hook commit to push to it
will create a github repo and add post-update hook on bare repo to push to github
post-update will also send xmpp message to bot@reese

###  cloning project  ###

	git clone ...
	cd ...
	gitm.sh -l

will put local hooks (post-commit: push to bare remote) on newly cloned 
and add to the watch list file

### Status ###
	gitm.sh  [-s]

* show remote repo (local and bare remote)
* show hooks       (local and bare remote)
* provide clone uri
* report if local dir is in the watchlist

### "Auto" install ###

invoking gitm.sh will test for ~/.config/gitm/rc
if this is not found, an attempt to install it will be run.
xmpp will also be pulled from sourceforge if not installed.

## Breakdown

variables defined in ~/.config/gitm/rc 

### local
.git/config -- adds remote $bareHost
.git/hooks/post-commit -- adds "git push"
.config/gitm/list      -- adds the local directory:remote directory pair

### bare repo remote ($bareHost)
.git/config -- adds git hub as remote if told to
.git/hooks/post-update -- adds sendxmpp $xmppUser, git push to github if told

## Requires 
* git
* xmpp account and python2 (on client)
* sshd and host for remote bare repo
* xmpp account access and sendxmpp on host

## Todo 

* more configurable (esp. xmpp service)

## ToFix
* host post-hook is sent in stone (change jabber bot, have to do it for every repo)

## Fanatasy

* per folder xmpp listener and remote and github webhook to sendxmpp or rss/twitter monitor
	* non-overlapping collaborations

