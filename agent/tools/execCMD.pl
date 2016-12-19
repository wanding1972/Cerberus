#!/usr/bin/perl
use strict;
use File::Spec;
use Socket;
my $path_curf = File::Spec->rel2abs(__FILE__);
my ($vol, $path, $file) = File::Spec->splitpath($path_curf);

require "$path/../lib/funcs.pl";
require "$path/../lib/command.pl";
my $option = argOption();
if($option =~ /v/){
        $main::LOGLEVEL=1;
        $|=1;
}else{
	dupProcess($file);
}

my $cmd = $ARGV[0];
my $strCmd = getCmd($cmd);
my @out = `$strCmd`;
foreach my $line (@out){
	chomp($line);
	debug($line);
}


