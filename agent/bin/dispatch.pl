#!/usr/bin/perl
##################################################################################
#  Copyright (c) 2016 Wan Ding.		                                         #
#  All rights reserved.				                                 #
#  THIS SOFTWARE IS ADOPTED THE BSD LICENSE.	                                 #
#  Project: github.com/wanding1972/Cerberus                                      #
##################################################################################
use strict;
use File::Spec;
my $path_curf = File::Spec->rel2abs(__FILE__);
my ($vol, $path, $file) = File::Spec->splitpath($path_curf);

require "$path/../conf/global.conf";
require "$path/../lib/funcs.pl";

my $app = "dispatch";
my $option = argOption();
if($option =~ /v/){
        $main::LOGLEVEL=1;
        $|=1;
}
if($#ARGV < 0 || $ARGV[0] !~ /start|stop|test/){
        print "Usage: $app.pl start|stop|test\n";
        exit(-1);
}
createStruc();
my $operation = $ARGV[0];
if($operation eq 'start') {
	dupProcess($file);
	$SIG{CHLD} = 'IGNORE';  # recycle the zomebie process.
	daemon($app,"$path/../..");
	start();	
}elsif($operation eq 'stop') {
	stop();
	exit(0);
}elsif($operation eq 'test') {
	test(0);
    	exit(0);
}

	my @pidlist = ();
sub stop{
	my $pidFile = "$path/../../run/tmp/$app.pid";
	if(-e "$pidFile") {
			open PIDFILE,"$pidFile";
			my $pid = <PIDFILE>;
			close(PIDFILE);
			chomp($pid);
			`kill -9 $pid`;
			info("kill -9 $pid : the process dispatch has stop");
			my $ret = $?>>8;
			if($ret == 0){
			unlink("$pidFile");
			}
	}else{
			error("$pidFile not exist");
	}
}
sub test{
	my($ticks) = @_;
	my %tasks = readHash("$path/../conf/task.conf");
	#### iterator tasks
	foreach my $task (keys(%tasks)){
			my $interval = $tasks{$task};
			if(($interval > 0)&&($ticks % $interval == 0)){
				my $pid = fork();
				if($pid == 0){  #child process
					my $procName = "$path/../$task $ticks";
					debug("task: $ticks   $procName");
					if(!exec($procName)){
						exit(-1);
					}
				}else{  #parent process
				   push(@pidlist, $pid);
				}
			}
	}
	#iterator plugins
	my $os = chkOS();
	my $dir = "$path/../plugin/$os";
	execPlugin($dir,$ticks);
	execPlugin("$path/../plugin/comm",$ticks);
	execPlugin("$path/../plugin/oracle",$ticks);
	#recycle the handle
	foreach my $pid (@pidlist){
		waitpid($pid,0);
	}
	@pidlist = ();
}

sub execPlugin{
	my($dir,$ticks,@pidlist) = @_;
        opendir(DIR,$dir);
        my @files = readdir(DIR);
        closedir(DIR);
        foreach my $file (@files) {
                my($prefix,$inter) = split /\./,$file;
                my $path = $dir.'/'.$file;
                next if($file eq '.' || $file eq '..');
                if(($inter > 0)&&($ticks % $inter == 0)){
                      my $pid = fork();
                      if($pid == 0){  #child process
                         debug("plugin:  $ticks  $path");
                         if(!exec($path)){
                                exit(-1);
                         }
                      }else{  #parent process
                          push(@pidlist, $pid);
                      }
                 }
#               my $func = \&$file;
#               $func->();
        }       #end foreach
}

sub start{
	my $ticks = 0;
	while(1){
		test($ticks);
		sleep(1);
		$ticks++;
		`echo $ticks > $path/../../run/tmp/dispatch.stat`;
	}
}

sub createStruc{
	my $home = "$path/../..";
        my @dirs = (
                'run',
                'run/tmp',
		'run/cfg',
                'run/data',
                'run/data/stat',
                'run/data/config',
                'run/data/log',
                'run/data/event',
                'run/data/perf',
                'run/log',
                'run/queue',
                'run/queue/config',
                'run/queue/state',
                'run/queue/log',
                'run/queue/event',
                'run/queue/perf',
                'run/queue/current',
                'run/queue/1',
                'run/queue/2',
                'run/queue/3',
		'run/queue/evt1',
		'data'
        );
        foreach my $dir (@dirs){
                my $path = "$home/$dir";
                if(! -e $path){
                        `mkdir -p $path`;
                }
        }
}
