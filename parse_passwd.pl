#!/usr/bin/perl
#
#  This script reads the passwd file and parses it for UIDs and GIDs 
#  to be used for the creating the users on the isilon array.  
#  
#  This comes into play when trying to map isilon to an existing installation.
#
#  IMPORTANT: Edit the passwd and group files and delete the unwanted users...
#             The hadoop service account users are usually grouped together.
#
#  Questions and inquiries:  Nicholas Ruggiero
#                            nicholas.ruggiero@emc.com
#  
#  Warnings:  This is not bullet proof, please review the resulting isi commands
#             file to ensure desired result.  best practice is to cut and paste
#             the commands on the isilon command line.
#
#  Version History:
#             v. 0.91      3/28/15         Initial Version
#             v. 0.92      8/4/15          input defaults updated
#             v. 0.93      4/21/16         removed dist parameter, and force add of supergroup
#
#
use strict;
use Getopt::Long;
#
#   input section
#
my $passwd="";              # local file name
my $group="";                # local file name of /etc/group
my $isi_cmds="isi_commands.txt";  # Output file for the isi commands
my $zone="system";                      # Access zone on the isilon system for this hadoop
my $hdfs_root="/ifs/";            # HDFS Root for the above access zone
#my $dist="";                   # Hadoop Distribution  - cdh|hwx|phd|ibm
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
my @file;
#
#  for getopt
#
my $help=0;
my $version="0.93";
#
GetOptions ('passwd=s' => \$passwd, 
	    'group=s' => \$group, 
	    'hdfs_root=s' => \$hdfs_root, 
	    'zone=s' => \$zone, 
	    'help' => \$help);
if ($help) {
    print "\nTo the rescue...BTW, this is version $version\n\n";
    print "Usage: parse_passwd.pl --passwd <filename> --group <filename> --hdfs_root <hdfs root directory> --zone <access zone> \n\n";
    exit;
}
#
#  Okie dokie here we go....
#
print "...and begin\n";
print "passwd file \t$passwd\n";
print "group file  \t$group\n";
print "Using Access Zone: \t$zone\nHDFS_ROOT set to \t$hdfs_root\n";
#
#   First do the groups they need to exist before the users
#
open (CMD,$group) || die "Problem with the group file. Error $!\n";
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
	    push @commands,"isi auth groups modify $grpname --add-user $u --provider local --zone $zone \n";
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
	push @commands, "isi auth users create $name --uid $uid --primary-group-gid $def_gid --zone $zone --provider local --home-directory $hdfs_root/user/$name\n";
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
@file = grep (/users create/, @commands);
foreach (@file) { 
    print OUT $_   ;
}
#
@file = grep (/groups modify/, @commands);
foreach (@file) { 
    print OUT $_   ;
}
close OUT;
