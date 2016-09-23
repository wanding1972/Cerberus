#!/usr/bin/perl
##################################################################################
#  Copyright (c) 2016 Wan Ding.                                                  #
#  All rights reserved.                                                          #
#  THIS SOFTWARE IS ADOPTED THE BSD LICENSE.                                     #
#  Project: github.com/wanding1972/Cerberus                                      #
##################################################################################
use strict;
use File::Spec;
use Socket;
use Env;
my $path_curf = File::Spec->rel2abs(__FILE__);
my ($vol, $path, $file) = File::Spec->splitpath($path_curf);

require "$path/../conf/global.conf";
require "$path/../lib/funcs.pl";

my $app = "sender";
my $error = "";
dupProcess($file);
my ($site,$loopaddress,$server,$webServer,$webPort)=loadLocalConf();
my @eventLst = ();
my $isWrite = chkFileSystem();
if($isWrite != 0){
	my $desc = "error code: $isWrite; $error";
	push(@eventLst,"FSReadOnly,$app.isWrite,$HOME,$desc");
	print "$eventLst[0]\n";
	sendMsg("event",$eventLst[0]);
	exit;
}
my @dirs = ("event","perf","config","state","log");
foreach my $dir(@dirs){
	doDir($dir);
}

#msg header: type-agentversion-site-ip
#msg body:   $msg
#type:'ST':status; 'CO':config; 'EV':event; 'PE':perf;'LO':log
sub sendMsg{
	my($type,$body) = @_;
	my $port = $main::PORT;
	my $head = "$type|$main::VERSION|$site|$loopaddress";
	my $msg = "$head|$body";
	sendUDP($server,$port,$msg);
}

sub doDir{
	my ($base) = @_;
	my $dir = "$path/../../run/queue/$base";
        opendir(DIR,$dir);
        my @files = readdir(DIR);
        closedir(DIR);
	foreach my $file (@files){
		next if($file eq '.' || $file eq '..');
		my $path = "$dir/$file";
		my $size = -s $path;
		if($size > 5096000){
			print "rm $path\n";
			`rm $path`;
			next;
		}
		if(open(FILE,$path)){
			my @lines = <FILE>;
			foreach my $line (@lines){
				sendMsg($base,$line);
			}
			close(FILE);
			unlink($path);
		}	
	}	
}

sub chkFileSystem{
	$error = `touch $path/../../run/tmp/sender.tmp 2>&1`;
	return $?;
}
