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
require "$path/../lib/service.pl";
dupProcess($file);

$ENV{'LC_ALL'} = 'C';
my $serviceConf = "$path/../conf/service.rule";
if( -e $serviceConf){
        require $serviceConf;
}
my %serviceReg = ();
my $regFile = "$path/../../run/cfg/service.reg";
if( -e "$regFile"){
	%serviceReg = readHash($regFile);
}
my @deleteKey = ();
foreach my $servicename (keys(%main::service)){
        my $hashref = $main::service{$servicename};
        my $paraname;
        my $checkResult='';
        
	my $index = "";
        #iterate the check item of each service
	my $retval = 'failed';
        foreach $paraname (keys(%$hashref)){
                my $arrayref = $$hashref{$paraname};
                my $value1 = $$arrayref[0];
                my $value2 = $$arrayref[1];
       		if($paraname =~ /ps_count/){
                        $retval = chkProcess($value1,$value2);
			last;
                }
	}
	if($retval eq 'ok'){
		if(exists $serviceReg{$servicename}){
			if($serviceReg{$servicename} =~ /(\d+)-/){
				$serviceReg{$servicename}=$1.'-'.time;
			}
		}else{
			$serviceReg{$servicename}=time.'-'.time;
		}
	}else{
		 if(exists $serviceReg{$servicename}){
                        if($serviceReg{$servicename} =~ /(\d+)-(\d+)/){
				my $interval = time-$2;
				my $ELAPSE = 60*60*24;
				if($interval > $ELAPSE){ 
					unshift(@deleteKey,$servicename);
				}
                        }
                }
	}
	
}
foreach my $key (@deleteKey){
	delete $serviceReg{$key};
}
writeHash(\%serviceReg,$regFile);
