#!/usr/bin/perl
#
#  This script reads the passwd file and parses it for UIDs and GIDs 
#  to be used for the creating the users on the isilon array.  
#  
#  This comes into play when trying to map isilon to an existing installation.
#
#  IMPORTANT: Edit the passwd and group files and delete the unwanted users...
#             These users are usually grouped together.
#
#  Questions and inquiries:  Nicholas Ruggiero
#                            nicholas.ruggiero@emc.com
#  
#  Warnings:  This is not bullet proof, please review the resulting isi commands
#             file to ensure desired result.
#
#  Version History:
#             v. 0.1      3/28/15         Initial Version
#             v. 1.1      7/27/2020       Added --enabled = true as required since 8.2
#                                         fixed issue with modify groups coming before 
#                                         the user was created.
#
use strict;
use Getopt::Long;
#
#   input section
#
my $passwd="passwd";              # local file name
my $group="group";                # local file name of /etc/group
my $isi_cmds="isi_commands.txt";  # Output file for the isi commands
my $zone="";                      # Access zone on the isilon system for this hadoop cluster
my $hdfs_root="/ifs/";            # HDFS Root for the above access zone 
my $dist="cdh";                   # Hadoop Distribution  - cdh|hwx|phd
#
#
#  Variable declaration
#
my $name="";
my $uid="";
my $def_gid="";
my $p="";
my $grpname="";
my $got_super="TRUE";
my $gid="";
my $users="";
my @commands;
my @mod_commands;
my @file;
my $ier;
#
#  for getopt
#
my $help=0;
my $version="1.2";
#
$ier=GetOptions ('passwd=s' => \$passwd, 
	    'group=s' => \$group, 
	    'hdfs_root=s' => \$hdfs_root, 
	    'zone=s' => \$zone, 
	    'dist=s' =>\$dist,
	    'help' => \$help);
#
if ($help || $ier != 1 ) {
    print "Usage: parse_passwd.pl --passwd <filename> --group <filename> --hdfs_root <hdfs root directory> --zone <access zone>  --dist cdh|hwx|phd\n\n";
    exit;
}
#
#  Okie dokie here we go....
#
print "Version: $version\n";
print "passwd file $passwd\n";
print "group file $group\n";
print "Using Access Zone: $zone with HDFS ROOT set to $hdfs_root\n";
print "The distribution is: $dist\n\n";
if ($dist =~ /cdh/) { 
    $got_super = "FALSE";
}
#
#   First do the groups they need to exist before the users
#
open (CMD,$group) || die "ERROR opening $group <$!>";
while (<CMD>) {
    chomp;
    ($grpname,$p,$gid,$users)= split /\:/,$_;
    print "Group: $grpname,\t\tGID: $gid,\tusers: $users\n";
    if ($grpname) {
      push @commands ,"isi auth groups create $grpname --gid $gid  --provider local --zone $zone\n" ;
    }
    #
    #  so if there are multiple users in a group pick them up here.
    #
    if ($users) {
	my @super = split /\,/,$users;
	foreach my $u (@super){
	    push @mod_commands,"isi auth groups modify $grpname --add-user $u --provider local --zone $zone \n";
	}
    }
}
close CMD;
#
#   Now do the users
#
open (CMD,$passwd) || die "ERROR opening $passwd <$!>";
while (<CMD>) {
    chomp;
    ($name,$p,$uid,$def_gid)= split /\:/,$_;
    if ($name){
	print "User: $name,\t\tUID: $uid,\tGID: $def_gid\n";
	push @commands, "isi auth users create $name --uid $uid --primary-group-gid $def_gid --zone $zone --enabled true  --provider local --home-directory $hdfs_root/user/$name\n";
    }
}
close CMD;
#
#  open the command file for writing
#
$isi_cmds="isi" . "_" . $zone . "_local_users.sh";
print "Writing isi commands to $isi_cmds\n";
open (OUT,">", $isi_cmds) || die "ERROR creating file $isi_cmds <$!>";
#
print OUT "#!/bin/bash\n";
print OUT "#\n#\n# This script can be used to cut and paste (recommended) or just run it.\n#\n";
#
#
#
@file = grep (/groups create/, @commands);
foreach (@file) { 
    print OUT $_   ;
}
#
@file = grep (/users/, @commands);
foreach (@file) { 
    print OUT $_   ;
}
#
@file = grep (/groups modify/, @mod_commands);
foreach (@file) { 
    print OUT $_   ;
}
#
#  Now write out the commands to create directories
#
if ($dist =~ /hdp/) { 
    print OUT <<EOF;
#
# now do the directories...
# start in hdfs_root, $hdfs_root
# also in order to use the identities use isi_run -z <zone id> prior to these next commands.
#
cd $hdfs_root
chmod 755 $hdfs_root
chown hdfs:hadoop $hdfs_root
mkdir -p -m 1777 app-logs
chown yarn:hadoop app-logs
mkdir -p -m 770  app-logs/ambari-qa
chown ambari-qa:hadoop  app-logs/ambari-qa
mkdir -p -m 770 app-logs/ambari-qa/logs
chown ambari-qa:hadoop  app-logs/ambari-qa/logs
mkdir -m 755 apps  
chown hdfs:hadoop apps
mkdir -p -m 750 apps/accumulo
chown accumulo:hadoop apps/accumulo
mkdir -p -m 777 apps/falcon
chown falcon:hdfs apps/falcon
mkdir -p -m 755 apps/hbase
chown hdfs:hadoop apps/hbase
mkdir -p -m 775 apps/hbase/data
chown hbase:hadoop apps/hbase/data
mkdir -p -m 711 apps/hbase/staging
chown hbase:hadoop apps/hbase/staging
mkdir -p -m 755 apps/hive
chown hdfs:hdfs apps/hive
mkdir -p -m 777 apps/hive/warehouse
chown hive:hdfs apps/hive/warehouse
mkdir -p -m 755 apps/tez
chown tez:hdfs apps/tez
mkdir -p -m 755 apps/webhcat
chown hcat:hdfs apps/webhcat
mkdir -p -m 755 ats
chown yarn:hadoop ats
mkdir -p -m 775 ats/done
chown yarn:hadoop ats/done
mkdir -p -m 755 atsv2
chown yarn-ats:hadoop atsv2
mkdir -p -m 755 mapred
chown mapred:hadoop mapred
mkdir -p -m 755 mapred/system
chown mapred:hadoop mapred/system
mkdir -p -m 755 system
mkdir -p -m 755 system/yarn
mkdir -p -m 700 system/yarn/node-labels
chown -R yarn:hadoop system
mkdir -m 1777 tmp
chown hdfs:hdfs tmp
mkdir -p -m 777 tmp/hive
chown ambari-qa:hadoop tmp/hive
chmod 755 user
chown hdfs:hdfs user
chmod 755 user/ambari-qa
chmod 755 user/hcat
chmod 755 user/hdfs
chmod 700 user/hive
chmod 755 user/hue
chmod 775 user/oozie
chmod 755 user/yarn
EOF
}
close OUT;
