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
my $path_curf = File::Spec->rel2abs(__FILE__);
my ($vol, $path, $file) = File::Spec->splitpath($path_curf);

require "$path/../conf/global.conf";
require "$path/../lib/funcs.pl";

dupProcess($file);

# support
# format: msgType,agentVersion,node,ip,confvserion,agentHealth,pluginHealth,filterHealth,runSize
my $health = selfHealth();
my $confversion = confVersion();
my $diskSize = diskSize();
my $summary = "$confversion,$diskSize,$health";
isAlive($summary);
clean(8);
`echo $$ > $path/../../run/tmp/selfchk.pid`;
sub selfHealth{
	my @probes = ('disk','cpu','dskio','ping','net','swap','conps','netaudit','service');
	my $count = 0;
	my @errors=();
	my $summary = "";
	foreach my $probe (@probes){
			my $flag = 0;
			my $path = "$path/../../run/tmp/$probe.pid";
			if( -e $path){
					my $size = -s $path;
					my @status = stat($path);
					my $modTime = $status[9];
					my $elapse = time() - $modTime;
					if($elapse > $main::ALIVETIMEOUT){
						$flag = 1;
					}elsif($size == 0){
						$flag = 1;
					}else{
						$count ++;
					}
			}else{
				  $flag = 1;
			}
			if($flag == 1){
				  unshift @errors, $probe;
			}
	}
	if($count == $#probes+1){
			$summary = 'succeed:!';
	}else{
			$summary = join ',',@errors;
			$summary = 'failed:'.$summary;
	}
	return $summary;
}

sub isAlive{
	my ($str) = @_;
	my $dirData = "$path/../../run/queue/state";
	my $statFile = "$dirData/state".curtime().".q";
	my $syncTime = time - 3600*24*365*46;
   if(open(FILE,">$statFile")){
	print FILE  "$syncTime,$str";
	close(FILE);
   }
}

sub diskSize{
	my $out = `du -sk $path/../../run`;
	trim($out);
	my @tokens= split /[ \t]+/,$out;
	if($tokens[0] >0){
		return $tokens[0];
	}else{
		return 0;
	}
}

sub confVersion{
	my %hash = readHash("$path/../conf/conf.version");
	if(exists($hash{'confversion'})){
		return $hash{'confversion'};
	}else{
		return 0;
	}
}

sub clean{
        my @toDoList = ("$path/../../run/data/perf","$path/../../run/log");
        my %dirDone ;   
        my ($dir,$path);
        my $num = 0;
        while (scalar @toDoList > 0) {
                $dir = shift(@toDoList);
                $dirDone{$dir} = 1;
                if( ! -d $dir){ #нд╪Ч
                       $path = $dir;
                       my @status = stat($path);
                       my $modTime = $status[9];
                      if((time-$modTime)>$main::CLEANTIMEOUT){
				debug($path);
                             unlink($path);
                      }
                       $num++;
                       next;
                }
                opendir(DIR,$dir);
                my @files = readdir(DIR);
                closedir(DIR);
                foreach my $file (@files) {
                        if($file ne '..'&& $file ne '.' ){
                                $path = "$dir/$file";
                                next if( -l $path);     
                                if( -d $path){
                                        if(! exists $dirDone{$path} ){
                                               unshift(@toDoList,$path);
                                        }
                                }else{ 
                                        my @status = stat($path);
                                        my $modTime = $status[9];
                                        if((time-$modTime)>$main::CLEANTIMEOUT){
						debug($path);
                                                unlink($path);
                                        }
                                        $num++;
                                }
                        }       #end if
                }       #end foreach
        }
}


