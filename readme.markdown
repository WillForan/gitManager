# gitm.sh #

small bash script to

* (-n) make bare repository on a remote host
* (-n) add it as a remote origin
* (-n) add hook on remote to send xmpp (TODO: configurabe user@host)
* (-n or -l) adds local commit hook to push to origin
* (-n or -l) adds bare repo and localdir to watch list
* (-g or -G)
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

###  "Status" ###
	gitm.sh  [-s]

* show remote repo (local and bare remote)
* show hooks       (local and bare remote)
* also provide clone uri

# Requires # 
* git
* sendxmpp and account
* sshd and host for remote bare repo

# Todo # 

* Jabber bot listener
* more configurable (esp. xmpp service)
