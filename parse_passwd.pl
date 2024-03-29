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
#              v1.2       3/24/2022       Mod directory structure for CDP
#              v1.3       11/3/2022       Bug fixes for directory
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
my $dist="cdh";                   # Hadoop Distribution  - cdh|hwx|cdp
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
    print "Usage: parse_passwd.pl --passwd <filename> --group <filename> --hdfs_root <hdfs root directory> --zone <access zone>  --dist cdh|hwx|cdp\n\n";
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
#   First do the groups, they need to exist before the users
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
    isi_run -z $zone
isi hdfs proxyusers create flume --zone $zone
isi hdfs proxyusers modify flume --zone $zone --add-group hadoop
isi hdfs proxyusers create hdfs --zone $zone
isi hdfs proxyusers modify hdfs --zone $zone --add-group hadoop
isi hdfs proxyusers create hive --zone $zone
isi hdfs proxyusers modify hive --zone $zone --add-group hadoop 
isi hdfs proxyusers create hue --zone $zone
isi hdfs proxyusers modify hue --zone $zone --add-group hadoop 
isi hdfs proxyusers create impala --zone $zone
isi hdfs proxyusers modify impala --zone $zone --add-group hadoop 
isi hdfs proxyusers create mapred --zone $zone
isi hdfs proxyusers modify mapred --zone $zone --add-group hadoop 
isi hdfs proxyusers create oozie --zone $zone
isi hdfs proxyusers modify oozie --zone $zone --add-group hadoop 
isi hdfs proxyusers create spark --zone $zone
isi hdfs proxyusers modify spark --zone $zone --add-group hadoop 
isi hdfs proxyusers create yarn --zone $zone
isi hdfs proxyusers modify yarn --zone $zone --add-group hadoop 
cd $hdfs_root
chmod 755 .
chown hdfs:hadoop .
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
if ($dist =~ /cdh/) { 
    print OUT <<EOF;
    #
    # now do the directories...
    # start in hdfs_root, $hdfs_root
    # also in order to use the identities use isi_run -z <zone id> prior to these next commands.
    #
    isi_run -z $zone
	isi hdfs proxyusers create flume --zone $zone
	isi hdfs proxyusers modify flume --zone $zone --add-group hadoop
	isi hdfs proxyusers create hdfs --zone $zone
	isi hdfs proxyusers modify hdfs --zone $zone --add-group hadoop
	isi hdfs proxyusers create hive --zone $zone
	isi hdfs proxyusers modify hive --zone $zone --add-group hadoop 
	isi hdfs proxyusers create hue --zone $zone
	isi hdfs proxyusers modify hue --zone $zone --add-group hadoop 
	isi hdfs proxyusers create impala --zone $zone
	isi hdfs proxyusers modify impala --zone $zone --add-group hadoop 
	isi hdfs proxyusers create mapred --zone $zone
	isi hdfs proxyusers modify mapred --zone $zone --add-group hadoop 
	isi hdfs proxyusers create oozie --zone $zone
	isi hdfs proxyusers modify oozie --zone $zone --add-group hadoop 
	isi hdfs proxyusers create spark --zone $zone
	isi hdfs proxyusers modify spark --zone $zone --add-group hadoop 
	isi hdfs proxyusers create yarn --zone $zone
	isi hdfs proxyusers modify yarn --zone $zone --add-group hadoop 
    cd $hdfs_root
	chmod 755 .
	chown hdfs:hadoop .
	mkdir -p -m 755 hbase
	chown hbase:hbase hbase
	mkdir -p -m 755 solr
	chown solr:solr solr
	mkdir -p -m 1777 tmp
	chown hdfs:supergroup tmp
	mkdir -p -m 777 tmp/hive
	chown hive:supergroup tmp/hive
	mkdir -p -m 1777 tmp/logs
	chown mapred:hadoop tmp/logs
	mkdir -p -m 755 user
	chown hdfs:supergroup user
	mkdir -p -m 775 user/flume
	chown flume:flume user/flume
	mkdir -p -m 755 user/hdfs
	chown hdfs:hdfs user/hdfs
	mkdir -p -m 777 user/history
	chown mapred:hadoop user/history
	mkdir -p -m 775 user/hive
	chown hive:hive user/hive
	mkdir -p -m 1777 user/hive/warehouse
	chown hive:hive user/hive/warehouse
	mkdir -p -m 755 user/hue
	chown hue:hue user/hue
	mkdir -p -m 777 user/hue/.cloudera_manager_hive_metastore_canary
	chown hue:hue user/hue/.cloudera_manager_hive_metastore_canary
	mkdir -p -m 775 user/impala
	chown impala:impala user/impala
	mkdir -p -m 775 user/oozie
	chown oozie:oozie user/oozie
	mkdir -p -m 751 user/spark
	chown spark:spark user/spark
	mkdir -p -m 1777 user/spark/applicationHistory
	chown spark:spark user/spark user/spark/applicationHistory
	mkdir -p -m 775 user/sqoop2
	chown sqoop2:sqoop user/sqoop2
	mkdir -p -m 755 user/yarn
	chown yarn:yarn user/yarn
EOF
}
if ($dist =~ /cdp/) { 
    print OUT <<EOF;
    #
    # now do the directories...
    # start in hdfs_root, $hdfs_root
    # also in order to use the identities use isi_run -z <zone id> prior to these next commands.
    #
    isi_run -z $zone
	isi hdfs proxyusers create flume --zone $zone
	isi hdfs proxyusers modify flume --zone $zone --add-group hadoop
	isi hdfs proxyusers create hdfs --zone $zone
	isi hdfs proxyusers modify hdfs --zone $zone --add-group hadoop
	isi hdfs proxyusers create hive --zone $zone
	isi hdfs proxyusers modify hive --zone $zone --add-group hadoop 
	isi hdfs proxyusers create hue --zone $zone
	isi hdfs proxyusers modify hue --zone $zone --add-group hadoop 
	isi hdfs proxyusers create impala --zone $zone
	isi hdfs proxyusers modify impala --zone $zone --add-group hadoop 
	isi hdfs proxyusers create mapred --zone $zone
	isi hdfs proxyusers modify mapred --zone $zone --add-group hadoop 
	isi hdfs proxyusers create oozie --zone $zone
	isi hdfs proxyusers modify oozie --zone $zone --add-group hadoop 
	isi hdfs proxyusers create spark --zone $zone
	isi hdfs proxyusers modify spark --zone $zone --add-group hadoop 
	isi hdfs proxyusers create yarn --zone $zone
	isi hdfs proxyusers modify yarn --zone $zone --add-group hadoop 
    cd $hdfs_root
	chmod 755 .
	chown hdfs:hadoop .
	mkdir -p -m 755 hbase
	chown hbase:hbase hbase
	mkdir -p -m 755 ranger/audit
	chown -R hdfs:supergroup ranger
	mkdir -p -m 755 solr
	chown solr:solr solr
	mkdir -p -m 1777 tmp
	chown hdfs:supergroup tmp
	mkdir -p -m 777 tmp/hive
	chown hive:supergroup tmp/hive
	mkdir -p -m 1777 tmp/logs
	chown yarn:hadoop tmp/logs
	mkdir -p -m 755 user
	chown hdfs:supergroup user
	mkdir -p -m 775 user/flume
	chown flume:flume user/flume
	mkdir -p -m 755 user/hdfs
	chown hdfs:hdfs user/hdfs
	mkdir -p -m 777 user/history
	mkdir -p -m 1777 user/history/done_intermediate
	chown -R mapred:hadoop user/history
	mkdir -p -m 775 user/hive
	chown hive:hive user/hive
	mkdir -p -m 1777 user/hive/warehouse
	chown hive:hive user/hive/warehouse
	mkdir -p -m 755 user/hue
	chown hue:hue user/hue
	mkdir -p -m 777 user/hue/.cloudera_manager_hive_metastore_canary
	chown hue:hue user/hue/.cloudera_manager_hive_metastore_canary
	mkdir -p -m 775 user/impala
	chown impala:impala user/impala
	mkdir -p -m 775 user/livy
	chown livy:livy user/livy
	mkdir -p -m 775 user/oozie
	chown oozie:oozie user/oozie
	mkdir -p -m 751 user/spark
	chown spark:spark user/spark
	mkdir -p -m 1777 user/spark/applicationHistory
	chown spark:spark user/spark user/spark/applicationHistory
	mkdir -p -m 1777 user/spark/driverLogs
	chown spark:spark user/spark/driverLogs
	mkdir -p -m 775 user/sqoop
	chown sqoop:sqoop user/sqoop
	mkdir -p -m 775 user/sqoop2
	chown sqoop2:sqoop user/sqoop2
	mkdir -p -m775 user/tez
	chown hdfs:supergroup user/tez
	mkdir -p -m 755 user/yarn
	chown hdfs:supergroup user/yarn
	mkdir -p -m 775 user/yarn/mapreduce
	chown hdfs:supergroup user/yarn/mapreduce
	mkdir -p -m 775 user/yarn/mapreduce/mr-framework
	chown yarn:hadoop user/yarn/mapreduce/mr-framework
	mkdir -p -m 775 user/yarn/services
	chown hdfs:supergroup user/yarn/services
	mkdir -p -m 775 user/yarn/services/service-framework
	chown hdfs:supergroup user/yarn/services/service-framework
	mkdir -p -m 775 user/zeppelin
	chown zeppelin:zeppelin user/zeppelin
	mkdir -p -m 775 warehouse
	chown hdfs:supergroup warehouse
	mkdir -p -m 775 warehouse/tablespace
	chown hdfs:supergroup warehouse/tablespace
	mkdir -p -m 775 warehouse/tablespace/external
	chown hdfs:supergroup  warehouse/tablespace/external
	mkdir -p -m 775 warehouse/tablespace/managed
	chown hdfs:supergroup warehouse/tablespace/managed
	mkdir -p -m 1775 warehouse/tablespace/external/hive
	chown hive:hive warehouse/tablespace/external/hive
	mkdir -p -m 1775 warehouse/tablespace/managed/hive
	chown hive:hive  warehouse/tablespace/managed/hive
EOF
}
close OUT;
