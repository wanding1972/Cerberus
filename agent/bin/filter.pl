#!/usr/bin/perl
##################################################################################
#  Copyright (c) 2016 Wan Ding.                                                  #
#  All rights reserved.                                                          #
#  THIS SOFTWARE IS ADOPTED THE BSD LICENSE.                                     #
#  Project: github.com/wanding1972/Cerberus                                      #
##################################################################################
use strict;
use File::Spec;
#collector->queue->sum->trigger->failrecover->encode->gzip->sender
my $path_curf = File::Spec->rel2abs(__FILE__);
my ($vol, $path, $file) = File::Spec->splitpath($path_curf);

require "$path/../conf/global.conf";
require "$path/../lib/funcs.pl";

if($#ARGV<0){
	print "Usage:  $file ticks\n";
	exit(0);
}
dupProcess($file);
my $ticks = $ARGV[0];

my $home="$path/..";
my $dir = "$home/filter";
opendir(DIR,$dir);
my @files = readdir(DIR);
closedir(DIR);
my @sortFiles = sort @files;
foreach my $file (@sortFiles) {
        next if($file eq '..' ||  $file eq '.' );
          my($prefix,$inter) = split /\./,$file;
        my $path = "$dir/$file";
        next if( -l $path);  
        if(($inter > 0)&&($ticks % $inter == 0)){
		debug($path);
       		 `$path`;
     		  # my $func = \&$file;
  	     # $func->();
       }
} 
`echo $$ > $path/../../run/tmp/filter.pid`;
