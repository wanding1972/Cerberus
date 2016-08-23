#!/usr/bin/perl
use strict;
use warnings;
use Socket;
use Expect;
use MIME::Base64;

use File::Spec;
my $path_curf = File::Spec->rel2abs(__FILE__);
my ($vol, $path, $file) = File::Spec->splitpath($path_curf);
require "$path/min_funcs.pl";

my $script = "min_deploy.pl";
my $start = time();
my $elapse = 0;
my $PROMPT = '[\#\$\>\%\]]\s*$'; # 远程系统的命令提示符模式
my $regPass = "[Pp]assword:|护:|口令";
if(scalar @ARGV <4){
        print "Usage: $0 action ip[:port] user passwd siteID [rootPass] \n";
        print "Example: $0 prog 192.168.6.131:2002  user slpass SITEID rootPass\n";
        print "Example: $0 unprog 192.168.6.131:2002  user slpass rootPass\n";
        print "Example: $0 check  192.168.6.131:2002  user slpass rootPass\n";
        exit 0;
}
my $action = $ARGV[0];
my $host = $ARGV[1];
my $port = 22;
if($host =~/(.+):(\d+)/){
	$port = $2;
	$host = $1;
}

my ($user,$pass,$node,$rootPass);
my $retVal;

$user = $ARGV[2];
$pass = $ARGV[3];
$pass = decode_base64($pass);
$node = $ARGV[4];
$rootPass = $ARGV[5];
$rootPass = defined $rootPass?decode_base64($rootPass):'';

$|=1;

if($action eq 'unprog' ){
		$retVal = undeploy($host,$user,$pass,$rootPass,$port);
}elsif($action eq 'check' ){
		my $status = check($host,$user,$pass,$rootPass,$port);
		$retVal = $status;
}elsif($action eq 'prog' ){
	$retVal = deploy($node,$host,$user,$pass,$rootPass,$port);
}

$elapse = time()-$start;
print "$script $action finished! return value=$retVal spend $elapse seconds \n";


sub check{
        my ($host,$user,$passwd,$rootPass,$port) = @_;
        my ($sess,$sessTmp);
        debug("check: $node $host:$port");
        my $retVal = 0; 
        my $ret = 0;    
	$ret = testTCPPort($host,$port);
	if($ret == 0){
		debug('connect failed');
		return 0;
	}
        ($ret,$sess) = login('ssh',$user,$passwd,$host,$port);
        if($ret == 0){
		debug('userPass error');
                return 1;
        }
        ($ret,$sessTmp) = su($sess,$rootPass);
        if($ret == 0){
		debug('su failed');
		return 2;
	}
        logout($sess);
        return 3;
}

sub undeploy{
        my ($host,$user,$passwd,$rootPass,$port) = @_;
        my ($sess,$sessTmp);
        debug("undeploy: $node $host");
	my $retVal = 0;
	my $ret = 0;
	($ret,$sess) = login('ssh',$user,$passwd,$host,$port);
	if($ret == 1){
		$retVal = 2;
	}
	#卸载
	$sess->send("/tmp/min_instAgent.pl undeploy $node $host\r");
	$sess->expect(10,'-re',$PROMPT);
	my $out = $sess->before();
	logout($sess);
	return $retVal;
}
sub deploy{
        my ($node,$host,$user,$passwd,$rootPass,$port) = @_;
        my ($sess,$sessTmp);
	my $role = defined $ARGV[6]? $ARGV[6]:'INDIRECT';
        	debug("deploy: $node $host");
		my $retVal = 0;
		my $ret = 0;
		$ret = rcopy($host,$port,$user,$passwd,"$path/min_*.*",'/tmp/');
		if($ret == 0){
			return $ret;
		}
		($ret,$sess) = login('ssh',$user,$passwd,$host,$port);
		if($ret == 1){
			$retVal = 2;
		}
		#测试拷贝成功
		$sess->send("ls -l /tmp/min_*\r");
		$sess->expect(10,'-re',$PROMPT);
		my $out = $sess->before();
		if($out =~ /min_funcs.pl/){
			$retVal = 4;
		}
		#测试安装成功
		$out = "";
		my $cmd = "/tmp/min_instAgent.pl deploy $node $host $role\r";
		#$cmd = "/tmp/min_instPubKey.pl\r";
		$sess->send($cmd);
		$sess->expect(10,'-re',$PROMPT);
		$out = $sess->before();
		if($out =~ /return value=(\d)/){
			$retVal = $1;
		}
		verbose($sess,0);
		logout($sess);
		return $retVal;
}

