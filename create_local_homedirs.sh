#!/bin/bash
#
#
# Now that the stub passwd and group files are created
# we need to make sure their home directories are created and owned by them.
#
# You need to use the passwd stub file created by the isilon_create_users.sh script
#
# usage: fix_local_dirs.sh --passwd <passwd file stub> 
#

declare -a ERRORLIST=()

function usage() {
   echo "$0 --passwd <passwd stubfile> --group <group stubfile>"
   exit 1
}

function fatal() {
   echo "FATAL:  $*"
   exit 1
}

function warn() {
   echo "ERROR:  $*"
   ERRORLIST[${#ERRORLIST[@]}]="$*"
}

function addError() {
   ERRORLIST+=("$*")
}
#
# Parse Command-Line Args
# Allow user to specify what functions to check
#
while [ "z$1" != "z" ] ; do
    case "$1" in
	"--passwd")
            shift
            PFILE="$1"
            echo "Info: Passwd file:  $PFILE"
            ;;
	"--group")
            shift
            GFILE="$1"
            echo "Info: Group file:  $GFILE"
            ;;
	*)
            echo "ERROR -- unknown arg $1"
            usage
            ;;
    esac
    shift;
done

#
#  install the stub passwd file where it belongs
#
cat $PFILE >> /etc/passwd
[ $? -ne 0 ] && addError "Error adding passwd stub to the passwd file"
#
#  install the stub group file where it belongs
#
cat $GFILE >> /etc/group
[ $? -ne 0 ] && addError "Error adding group stub to the group file"
#
#  Remove comments
#
sed -i.bak /#/d $PFILE
[ $? -ne 0 ] && addError "Error cutting out comments in passwd file"
USERS=`cat $PFILE | cut -d : -f 1`
[ $? -ne 0 ] && addError "Error finding users in the passwd file"
#
# echo $USERS
for index in $USERS; do
    HOMEDIR=`grep $index $PFILE | cut -d : -f 6`
    [ $? -ne 0 ] && addError "Error finding home directory <$HOMEDIR> in the passwd file"
    ID=`grep $index $PFILE | cut -d : -f 3-4`
    [ $? -ne 0 ] && addError "Error finding id <$ID> in the passwd file "
    mkdir $HOMEDIR
    [ $? -ne 0 ] && addError "Error creating home directory <$HOMEDIR> in the passwd file"
    chown $ID $HOMEDIR
    [ $? -ne 0 ] && addError "Error changing owner <$ID> on home directory <$HOMEDIR> in the passwd file"
done

### Deliver Results
if [ "${#ERRORLIST[@]}" != "0" ] ; then
   echo "ERRORS FOUND:"
   i=0
   while [ $i -lt ${#ERRORLIST[@]} ]; do
      echo "*  ERROR:  ${ERRORLIST[$i]}"
      i=$(( $i + 1 ))
   done
   fatal "ERRORS FOUND creating users or groups or directories  -- please fix before continuing"
   ls -l /home
   exit 1
else
   echo "SUCCESS -- Hadoop users created successfully!"
fi
#
echo "Done!"
