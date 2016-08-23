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

require "$path/../lib/funcs.pl";
require "$path/../lib/command.pl";
$ENV{'LC_ALL'} = 'C';

dupProcess($file);

my @time1=localtime(time());
my $ss = $time1[0];
my $fileName = "$path/../../run/tmp/ps$ss.log";

my @out = mycmds('pscpu');
if(open(FILE,">$fileName")){
	foreach my $line (@out){
		print FILE $line;
	}
	close(FILE);
}

my $cmd = "$path/../plugin/oracle/snapSQL.pl";
print $cmd."\n";
`$cmd`;
