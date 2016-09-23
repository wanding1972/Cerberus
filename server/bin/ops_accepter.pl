#!/usr/bin/perl
use strict;
use File::Spec;
my $path_curf = File::Spec->rel2abs(__FILE__);
my ($vol, $path, $file) = File::Spec->splitpath($path_curf);
use Socket;
use POSIX 'setsid';

require "$path/../conf/server.conf";
require "$path/min_funcs.pl";


dupProcess($file);

my $statusFile = "$path/../../data/host.status";
my $lstFile    = "$path/../../data/host.csv";
my %hosts;              #key=time

#memory cache
my %failedHosts = ();
my %proxys = ();
my %hostStatus;        
my @eventList = ();
my @perfList = ();
my @logList = ();
my @configList = ();
my $dirData = "$path/../../data";
if(! -e $dirData){
 `mkdir -p $dirData`;
}

load();

my $sockpid = fork;
if($sockpid > 0) {      #father process
        print "parent:$sockpid\n";
        my $timeoutpid = fork;
        if($timeoutpid == 0) {
                #??¨???
                &setsid();
                chdir '/';
                umask 022;
                open STDIN, "/dev/null";
                open STDOUT,"/dev/null";
                open STDERR,"/dev/null";
                $SIG{'CHLD'}='IGNORE';
                while(1) {
                        sleep 180;
                        kill 'USR1',$sockpid;
                }
        }
        print "child:$timeoutpid\n";
        exit 0;
}
&setsid();
chdir '/';
umask 022;
open STDIN,'/dev/null';
open STDOUT,"/dev/null";
open STDERR,"/dev/null";

$SIG{'CHLD'}='IGNORE';
$SIG{'USR1'}=sub{
        load();
        output();
};

my $localhost=sockaddr_in($main::PORT,INADDR_ANY);
socket(SERVER,AF_INET,SOCK_DGRAM,17);
bind(SERVER,$localhost);
#?????|-
my $ticks = 0;
while(1) {
        my $buff;
        next unless my $client=recv(SERVER,$buff,1024,0);
        #???ello-NOD999-2.2.0-1367049175-127.0.0.1-linux5.6-PRC
        my ($type,$version,$site,$ip,$msg) = split /\|/,$buff;
        my $key = "$site,$ip";
        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =localtime(time);
        my $strTime= sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year+1900,$mon+1,$mday,$hour,$min,$sec);
        ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =localtime(time-24*3600);
        my $tag = sprintf("%04d%02d%02d",$year+1900,$mon+1,$mday);
        if($type eq 'event'){
                push(@eventList,"$strTime,$key,$msg");
                if($ticks % 100 ==0 && $#eventList>0){
			my $eventLog = "$path/../../data/event.$tag.log";
			if( ! -e $eventLog){
				`mv $path/../../data/event.log  $eventLog`;
			}
                   if(open(HELLO,">>$path/../../data/event.log")){
                        foreach my $event (@eventList){
                                print HELLO $event;
                        }
			my @failedList = ();
			foreach my $key1 (keys %failedHosts){
				if(exists $proxys{$key1}){
					print HELLO "$strTime,$key1,AGENT_CRASH,acceptor.health,-,agent may be crashed\n";
					unshift(@failedList,$key1);
				}
			}
			foreach my $key1 (@failedList){
				delete $failedHosts{$key1};
			}
                        close(HELLO);
                   }
                   @eventList = ();
                }
        }elsif($type eq 'state'){
                $hosts{$key}=time;
                $hostStatus{$key} = $version.','.$msg;
		my $stateLog = "$path/../../data/state.$tag.log"; 
		if( ! -e $stateLog){
			`mv $path/../../data/state.log $stateLog`;
		}
                if(open(HELLO,">>$path/../../data/stat.log")){
			print HELLO "$strTime,$key,$msg\n";
                        close(HELLO);
                }
        }elsif($type eq 'config'){
                push(@configList,"$strTime,$key,$msg");
                if($ticks % 100 ==0 && $#configList>0){
			my $configLog = "$path/../../data/config.$tag.log";
                       if( ! -e $configLog){
                                `mv $path/../../data/config.log  $configLog`;
                        }
                   if(open(HELLO,">>$path/../../data/config.log")){
                        foreach my $config (@configList){
                                print HELLO $config;
                        }
                        close(HELLO);
                   }
                   @configList = ();
                }
        }elsif($type eq 'perf'){
                push(@perfList,"$key,$msg");
                if($ticks % 100 ==0 && $#perfList>0){
		       my $perfLog = "$path/../../data/perf.$tag.log";
                       if( ! -e $perfLog){
                                `mv $path/../../data/perf.log  $perfLog`;
                        }
                   if(open(HELLO,">>$path/../../data/perf.log")){
                        foreach my $perf (@perfList){
                                print HELLO $perf;
                        }
                        close(HELLO);
                   }
                   @perfList = ();
                }
        }elsif($type eq 'log'){
                push(@logList,"$site $ip $msg");
                if($ticks % 100 ==0 && $#logList>0){
                   my $logFile = "$path/../../data/log.$tag.log";
                   if( ! -e $logFile){
                       `mv $path/../../data/log.log  $logFile`;
                   }
                   if(open(HELLO,">>$path/../../data/log.log")){
                        foreach my $log (@logList){
                                print HELLO $log;
                        }
                        close(HELLO);
                   }
                   @logList = ();
                }
        }
        $ticks++;
}
close SERVER;
exit 0;



#update the list of host
sub load(){
        if(open(FILE,$lstFile)){
                my @lines = <FILE>;
                foreach my $line (@lines) {
                   chomp($line);
                   next if($line =~ /^$/);
                   next if($line =~ /^#/);
                   my ($ip,$node) = split /,/,$line;
                   my $key = "$node,$ip";
                   if(! exists $hosts{$key}){
                        $hosts{$key} = time;
                   }
		   if($line =~ /proxy/i){
		   	$proxys{$key} = 1;
		   }
                }
                close(FILE);
        }
}

#output the status of host
sub output(){
        my @keys = keys %hostStatus;
        return if($#keys <0);
        if(open(TMPFILE,">$statusFile")){
                foreach my $key (@keys) {
                        my $hellotime = $hosts{$key};
                        my $now = time;
                        my $elapse = $now-$hellotime;
                        my @tokens = split /,/,$key;
                        my $node = $tokens[0];
                        my $ipaddress = $tokens[1];

                        my $status = 'ONLINE';
                        if($elapse > $main::OFFLINE_TIMEOUT) {
                                $status = 'OFFLINE';
				$failedHosts{$key} = 1;
                        }
                        $now = $now - 3600*24*365*46;
                        $hellotime = $hellotime - 3600*24*365*46;
                        print TMPFILE "$node,$ipaddress,$status,$hostStatus{$key},$now,$hellotime\n";
        }
        close(TMPFILE);
   }
}
