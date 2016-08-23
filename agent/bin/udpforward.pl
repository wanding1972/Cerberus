#!/usr/bin/perl
##################################################################################
#  Copyright (c) 2016 Wan Ding.                                                  #
#  All rights reserved.                                                          #
#  THIS SOFTWARE IS ADOPTED THE BSD LICENSE.                                     #
#  Project: github.com/wanding1972/Cerberus                                      #
##################################################################################
use strict;
use Socket;
use File::Spec;
my $path_curf = File::Spec->rel2abs(__FILE__);
my ($vol, $path, $file) = File::Spec->splitpath($path_curf);
my $home="$path/..";

require "$home/conf/global.conf";
require "$home/lib/funcs.pl";

my $app = "udpforward";
if($#ARGV < 0 || $ARGV[0] !~ /start|stop|test/){
        print "Usage: $file start|stop|test\n";
        exit(-1);
}

my ($site,$loopaddress,$server,$webServer,$webPort)=loadLocalConf();

my $operation = $ARGV[0];
if($operation eq 'start') {
	dupProcess($file);
        daemon($app,"$path/../..");
        start();
}elsif($operation eq 'stop') {
        stop();
        exit(0);
}elsif($operation eq 'test') {
        start();
        exit(0);
}

sub stop{
        my $pidFile = "$path/../../run/tmp/$app.pid";
        if(-e "$pidFile") {
                        open PIDFILE,"$pidFile";
                        my $pid = <PIDFILE>;
                        close(PIDFILE);
                        chomp($pid);
                        `kill -9 $pid`;
                        my $ret = $?>>8;
                        if($ret == 0){
                                        unlink("$pidFile");
                                        info("kill -9 $pid : the process $file has stop");
                        }
        }else{
                        error("$pidFile not exist");
        }
}


#forwarder
sub start{
   my $port=$main::PORT;
   my $localhost=sockaddr_in($port,INADDR_ANY);
   socket(SERVER,AF_INET,SOCK_DGRAM,17);
   bind(SERVER,$localhost);
   my $ticks = 0;
   my %ipMap = ();
   while(1) {
        my $buff;
        next unless my $client=recv(SERVER,$buff,1024,0);
        my @tokens = split /\|/,$buff;
        my ($type,$version,$siteID,$ipaddr) = ($tokens[0],$tokens[1],$tokens[2],$tokens[3]);
        shift @tokens;
        shift @tokens;
                if(! exists $ipMap{$ipaddr}){
                        $ipMap{$ipaddr} = 1;
                }else{
                        $ipMap{$ipaddr} = $ipMap{$ipaddr}+1;
                }
        if($type eq 'perf'|| $type eq 'state' || $type eq 'event' ||$type eq 'config'||$type eq 'log'){
                sendUDP($server,$port,$buff);
        }
       $ticks++;
      if($ticks % 5 == 0){
		my $statFile = "$path/../../run/tmp/udpforward.stat";
		writeHash(\%ipMap,$statFile);
	}
  }
  close SERVER;
  exit 0;
}
