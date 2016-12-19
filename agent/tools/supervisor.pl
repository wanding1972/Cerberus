#!/usr/bin/perl
use strict;
use File::Spec;
my $path_curf = File::Spec->rel2abs(__FILE__);
my ($vol, $path, $file) = File::Spec->splitpath($path_curf);

$ENV{'LC_ALL'} = 'C';
require "$path/../lib/funcs.pl";
require "$path/../lib/command.pl";

my $option = argOption();
if($option =~ /v/){
        $main::LOGLEVEL=1;
        $|=1;
}else{
	dupProcess($file);
}

my $serviceConf = "$path/../conf/service.rule";
if( -e $serviceConf){
        require $serviceConf;
}
my $method = defined $ARGV[0]?$ARGV[0]:'status';

foreach my $servicename (keys(%main::serviceAuto)){
        next if (defined $ARGV[1] && $servicename !~ /$ARGV[1]/);
        my $ref = $main::serviceAuto{$servicename};
	my %cmds = %$ref;
	my $count = 0;
	my $num = 0;
	if($method eq 'stop'){
		while(($num = status($cmds{'status'},$method) >0) && $count <3){
        		$count++;
        		sleep(1);
        		debug("circle: $count");
		}
	}else{
		$num = status($cmds{'status'},$method);
	}
	if($num ==0 && $method eq 'start'){
		debug("$num start service: $servicename $cmds{'start'}");
		system($cmds{'start'});
	}elsif($num ==0 && $method eq 'status'){
		debug("no service $servicename running");
	}
}

sub status{
	my ($reg,$method) = @_;
        my @out = mycmds('ps');
	my $count = 0;
        foreach my $line (@out){
                my $line1 = trim($line);
                if($line1 =~ /$reg/){
                        my @tokens = split / +/,$line1;
			my $pid = $tokens[1];
			if($method eq 'stop'){
				my $cmd = "kill -9 $pid";
				`$cmd`;
				debug($cmd);	
			}else{
                        	debug($line1);
			}
			$count++;
                }
        }
	return $count;
}
