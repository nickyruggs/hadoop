# Hadoop
Scripts for working with hadoop and Isilon.

I have created this git to share my scripts with the commnuity that help integrate EMC's Isilon platform with Hadoop.

parse_passwd.pl - use this to create the isilon commands to create users and directories from existing passwd and group files.  Very helpful in a rebuild.
	-Updates:  	set --enabled flag for user creation
			added a second script to create hadoop directory structure.	

create_local_homedirs.sh - use this script to create the local directories that were in the passwd stub file from the isilon create users script.

Check back later for more.
