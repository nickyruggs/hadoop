# Hadoop
Scripts for working with hadoop and Isilon.

I have created this git to share my scripts with the commnuity that help integrate Dell PowerScale platform with Hadoop.
## Scripts
> parse_passwd.pl - use this to create the isilon commands to create users and directories from existing passwd and group files.
>>Version 1.2 - Updated for CDP, creates directroy structure on PowerScale.

> create_local_homedirs.sh - use this script to create the local directories that were in the passwd stub file from the isilon create users script.
>>Deprecated - PowerScale scripts provide this now.

## Usage

This script will start with the passwd and group files from existing linux clients in the Hadoop cluster.  You should remove all of the non-hadoop service accounts or other users.  If you are using the passwd file for your end users feel free to include them in this and the script will create the identites for them in the Local Provider of the PowerScale cluster.
### parse_passwd.pl --passwd <filename> --group <filename> --hdfs_root <hdfs root directory> --zone <access zone>  --dist cdh|hwx|cdp
- **passwd** - This is the fliename, including path, if not in the cwd, of the passwd stub file.
- **group** - This is the filename, including path if not in the cwd, of the group stub file.
- **zone** - the name of the OneFS access zone being configured for Hadoop.
- **hdfs_root** - this is the root of the hdfs directory structure as referenced from /ifs, it can be seen with the command ***isi hdfs settings view --zone <zone>*** where zone is the name of the Access zone being confgured.
- **dist** - the distribution of Hadoop being configured, each distro has different list of users and directories.  For Apache use 'hdp'

The script will create a shell script file called *isilon_<zone>_local_users.sh* to execute on PowerScale with the commands t ocreate users, groups and directory structure. 


