#!/usr/bin/perl
use strict;
use Env;
my %hash = ();
if(open(FILE,'authorized_keys')){
	my @lines = <FILE>;
	foreach my $line (@lines){
		chomp($line);
		my @tokens = split / +/,$line;
		$hash{"$tokens[0] $tokens[1]"} = $tokens[2];
	}
	close(FILE);
}

my ($type,$key,$host);
if(open(FILE,'/tmp/min_id_rsa.pub')){
	my @lines = <FILE>;
	chomp($lines[0]);
	my @tokens = split / +/,$lines[0];
	($type,$key,$host) = ($tokens[0],$tokens[1],$tokens[2]);
	$hash{"$type $key"} = $host;
	close(FILE);
}
my $authFile = "$HOME/.ssh/authorized_keys";
my $authTmp = "/tmp/authkeys";
if(open(FILE,">$authTmp")){
	foreach my $md5 (keys %hash){
		print FILE "$md5 $hash{$md5}\n";
	}
	close(FILE);
	`chmod 400 $authTmp`;
}
my $size = -s "$authTmp";
if($size >100){
	`mv $authTmp   $authFile`;
        print "install return value=5\n";
}else{
        print "install return value=0\n";
}
