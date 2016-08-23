#!/usr/bin/perl
use strict;
use File::Spec;
use File::Basename;
my $path_curf = File::Spec->rel2abs(__FILE__);
my ($vol, $path, $file) = File::Spec->splitpath($path_curf);

if(scalar @ARGV <1){
	print "install.pl agent|server\n";
	exit;
}

my %hash = (
	'SERVER: Input the webroot path' => '/home/wwwroot/default',
	'SERVER: Input the IP of SMTP Server' => '192.168.6.100',
	'SERVER: Input the username of mail'  => 'linwei',
	'SERVER: Input the password of mailPass' => 'abcde',
	'SERVER: Input the DBType'  		=> 'mysql',
	'SERVER: Input the dbuser'		=> 'root',
	'SERVER: Input the dbpass'		=> 'root',
	'AGENT:  Input the ServerIP'		=> '192.168.6.1',
	'AGENT:  Input the port'		=> 1075,
	'AGENT:  Input the WEBSERVER'		=> 'github.com',
	'AGENT:  Input the Site'		=> 'test',
	'AGENT:  Input the LOOPADDRESS'		=> '127.0.0.1',
	'AGENT:  Input the ISPROXY'		=> 'NO',
	'AGENT:	 Input the Parent'		=> '192.168.6.1'
	);
LOOP:

foreach my $key (keys %hash){
	next if($key !~ /$ARGV[0]/i);
	print "$key\[$hash{$key}\]:";
	my $value = <STDIN>;
	chomp($value);
	if($value ne ''){
	     $hash{$key} = $value;
	}
}

print "========================================\n";
foreach my $key (keys %hash){
	next if($key !~ /$ARGV[0]/i);
	print "$key:    $hash{$key}\n";
}
print "========================================\n";

print "verify or not[Y]:";
my $isCheck = <STDIN>;
   chomp($isCheck);
   if($isCheck ne '' && $isCheck ne 'Y'){
	goto LOOP;
   }
if($ARGV[0] eq 'agent'){
	instAgent();
}else{
	instServer();
}

sub instServer{
	print "cp server $HOME/miops/";
	print "ln -s $HOME/miops/server $hash{'SERVER: Input the webroot path'}/miops/server\n";
	print "ln -s $HOME/miops/data $hash{'SERVER: Input the webroot path'}/miops/data \n";	
}
sub instAgent{
	`tar xvf agent.tar`;
	my $local = "";
	$local .= "our \$ISPROXY='$hash{'AGENT:  Input the ISPROXY'}';\n";
	$local .= "our \$SITE='$hash{'AGENT:  Input the Site'}';\n";
	$local .= "our \$LOOPADDRESS='$hash{'AGENT:  Input the LOOPADDRESS'}';\n";
	$local .= "our \$PARENT='$hash{'AGENT:   Input the Parent'}';\n";
	`echo $local > agent/conf/local.conf`;
}		
