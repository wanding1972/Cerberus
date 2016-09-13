#!/usr/bin/perl

use strict;
use Env;
my %hash = ();
my $authFile = "$HOME/.ssh/authorized_keys";
my $authBak  = "$HOME/.ssh/authorized_keys.bk";
if(open(FILE,"$authFile")){
        my @lines = <FILE>;
        foreach my $line (@lines){
                chomp($line);
                my @tokens = split / +/,$line;
                my $key = "$tokens[0] $tokens[1]";
                $hash{$key} = $tokens[2];
        }
        close(FILE);
}
my ($type,$key,$host);
if(open(FILE,'/tmp/min_id_rsa.pub')){
        my @lines = <FILE>;
        chomp($lines[0]);
        my @tokens = split / +/,$lines[0];
        my $key = "$tokens[0] $tokens[1]";
        $hash{"$key"} = $tokens[2];
        close(FILE);
}
my $authTmp = "/tmp/authkeys";
`chmod 600 $authTmp`;
if(open(FILE,">$authTmp")){
        foreach my $md5 (keys %hash){
                print FILE "$md5 $hash{$md5}\n";
        }
        close(FILE);
        `chmod 400 $authTmp`;
}
my $size = -s "$authTmp";
if($size >100){
	`mv -f $authFile  $authBak`;
        `mv -f $authTmp   $authFile`;
        print "install return value=5\n";
}else{
        print "install return value=0\n";
}
