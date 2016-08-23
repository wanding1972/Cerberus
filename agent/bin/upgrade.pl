#!/usr/bin/perl
##################################################################################
#  Copyright (c) 2016 Wan Ding.                                                  #
#  All rights reserved.                                                          #
#  THIS SOFTWARE IS ADOPTED THE BSD LICENSE.                                     #
#  Project: github.com/wanding1972/Cerberus                                      #
##################################################################################
use strict;
use File::Spec;
use IO::Socket::INET;
use File::Basename;
use Env;
my $path_curf = File::Spec->rel2abs(__FILE__);
my ($vol, $path, $file) = File::Spec->splitpath($path_curf);

require "$path/../conf/global.conf";
require "$path/../lib/funcs.pl";
dupProcess($file);

my ($site,$loopaddress,$server,$webServer,$webPort)=loadLocalConf();

my $os = `uname -s`;
chomp($os);
$os = lc($os);
my %pluginHashCur = curPluginInterval();
my %pluginHashNew = ();
print "Get digest: http://$webServer:$webPort/miops/digest.php?os=$os\n";
my $digestNew = "$path/../../run/cfg/digest.new";
my $digestCur = "$path/../conf/digest";
if('false' eq httpGet($webServer,$webPort,"/miops/digest.php?os=$os","$digestNew")){
	print "get digest failed \n";
	exit ;
}

my %hashNew = readHash($digestNew);
my %hashCur = readHash($digestCur);

my $dldFlag = 'true';
my $isModified = 'false';
foreach my $file (keys %hashNew){
	if(exists $hashCur{$file} && $hashCur{$file} eq $hashNew{$file}){
	}else{
		$isModified = 'true';
		my $ret = httpGet($webServer,$webPort,"/miops/dld/$file","$HOME/miops/agent/$file");
		if($ret eq 'false'){
			$dldFlag = 'false';
			print "download $file failed\n";
		}else{	
			if($file =~ /(.+)\.(\d+)/){
				$pluginHashNew{$1} = $2;
			}
		}
	}
}
#change the interval of running plugin
foreach my $plugin (keys %pluginHashNew){
	if(exists $pluginHashCur{$plugin} && $pluginHashCur{$plugin} != $pluginHashNew{$plugin}){
		my $curFile = "$HOME/miops/agent/$plugin.$pluginHashCur{$plugin}";
		`rm $curFile`;	
	}
}

if($dldFlag eq 'true' && $isModified eq 'true'){
	`mv $digestNew $digestCur`;
}else{
	print "Upgrade Results: downloadFlag: $dldFlag or file isModified: $isModified\n";
}

`echo $$ > $path/../../run/tmp/upgrade.pid`;

sub httpGet{
	my ($host,$port,$uri,$outFile) = @_;
	my $tmpFile = "/tmp/dld$$.tmp";
	my $request = "GET $uri HTTP/1.0\r\n";
	$request .= "HOST: $host:$port\r\n";
	$request .= "Accept: */*\r\n";
	$request .= "User-Agent: agentUpgrade.pl\r\n";
	$request .= "Connection: close\r\n\r\n";
	eval{
             local $SIG{ALRM} = sub { die 'Timed Out'; };
             alarm $main::TIMEOUT;
	     my $socket = IO::Socket::INET->new(PeerAddr => $host,
				PeerPort  => $port,
				Proto => "tcp",
				Blocking => "1",
				Timeout=>"20",
				Type => SOCK_STREAM);
	     if(! $socket){
		die "Couldn't connect to $host:$port: \n";
             }else{
		$socket->send($request) or warn "send failed: $!, $@";
		$socket->autoflush(1);
		my $flag = 0;
		my $dir = dirname $outFile;
		if( ! -e $dir){ `mkdir -p $dir`;}	
		if(open(FILE,">$tmpFile")){
		   while (my $line = <$socket>){
			if($flag == 1){
				print FILE $line;
			}
			if($line =~ /^\r\n$/){ $flag = 1;	}
		   }
			close(FILE);
		}
	    	close($socket);
 	     }
		alarm 0;
	};
	alarm 0;
	if( -e $tmpFile){
        	my $size = -s $tmpFile;
        	if($size <1){
			`rm $tmpFile`;
               		 return 'false';
        	}
       		my $out = `cat $tmpFile`;
        	if($out =~ /404/ig){
			`rm $tmpFile`;
               		return 'false';
        	}else{
			`mv $tmpFile $outFile`;
			`chmod +x $outFile`;
               		return 'true';
        	}
	}else{
		return 'false';
	}
}

sub curPluginInterval{
	my %hash = ();
	my @plugins = ("plugin/$os","plugin/comm","plugin/oracle");
	foreach my $plugin (@plugins){
       		 my $pathdir = "$HOME/miops/agent/$plugin";
	        opendir(DIR,$pathdir);
       		 my @files = readdir(DIR);
	        closedir(DIR);
       	 	foreach my $file (@files){
               		 next if($file eq '.' || $file eq '..');
	                if($file =~ /(.+)\.(\d+)/){
       		                $hash{"$plugin/$1"} = $2; 
               		 }
        	}
	}
	return %hash;
}
