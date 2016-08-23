#!/usr/bin/perl
##################################################################################
#  Copyright (c) 2016 Wan Ding.                                                  #
#  All rights reserved.                                                          #
#  THIS SOFTWARE IS ADOPTED THE BSD LICENSE.                                     #
#  Project: github.com/wanding1972/Cerberus                                      #
##################################################################################
use strict;
use File::Spec;
my $path_curf = File::Spec->rel2abs(__FILE__);
my ($vol, $path, $file) = File::Spec->splitpath($path_curf);

require "$path/../conf/global.conf";
if (-e "$path/../conf/local.conf"){
	require "$path/../conf/local.conf";
}
require "$path/../lib/command.pl";
require "$path/../lib/funcs.pl";
dupProcess($file);
chkDispatch();
my $cmd = getCmd('ps');
my @lines=readpipe("$cmd") or die ("ERROR!".$?);
my $isDispatch = 0;
my $isTcpForward = 0;
my $isUdpForward = 0;
foreach my $line (@lines){
	if($line =~ /dispatch.pl/){
		$isDispatch = 1;
	}
	if($line =~ /java.+TCPForward/){
		$isTcpForward = 1;
	}
	if($line =~ /udpforward.pl/){
		$isUdpForward = 1;
	}
}
if($isDispatch == 0){
	$cmd = "$path/dispatch.pl start";
	info($cmd);
	system($cmd);
}
if($isUdpForward == 0 && defined $main::ROLE && $main::ROLE eq 'PROXY'){
        $cmd = "$path/udpforward.pl start";
        info($cmd);
        system($cmd);
}
if($isTcpForward == 0 && defined $main::ROLE && $main::ROLE eq 'PROXY'){
	$cmd = "$path/TCPForward start";
	info($cmd);
	system($cmd);
}

sub chkDispatch{
    my $file = "$path/../../run/tmp/dispatch.stat";
    my @status = stat($file);
    my $modtime = $status[9];
    my $interval = int((time() - $modtime)/60+0.5);
    if($interval >2){
       my @lines = mycmds('ps');
       foreach my $line (@lines){
             if($line =~ /miops/ && $line !~ /watchdog/){
                        $line=~s/^\s*|\s*$//g;
                        my @tokens = split / +/,$line;
                        $cmd = "kill -9 $tokens[1]";
                        `$cmd`;
             }
       }
    }
}
