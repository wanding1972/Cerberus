#!/usr/bin/perl
use strict;
use Env;
use File::Spec;
my $path_curf = File::Spec->rel2abs(__FILE__);
my ($vol, $path, $file) = File::Spec->splitpath($path_curf);
require "$path/min_funcs.pl";
if(scalar(@ARGV)<3){
        print "install.pl action site ip role\n";
        exit 0;
}
my $action = $ARGV[0];
my $site = $ARGV[1];
my $ip   = $ARGV[2];
my $proxy = getSrcIP();
my $home = "$HOME/miops";

if($action eq 'deploy'){
	killAgent();
	unpkg();
	genLocalConf("$home/agent/conf/local.conf");
	startAgent();
	regCron("$home/agent/bin/miops_watchdog.pl");
	checkAgent();
	if(-e "/tmp/min_$ip.lst"){
		`mv /tmp/min_$ip.lst  $home/agent/conf/host.lst`;
	}
}elsif($action eq 'undeploy'){
	killAgent();
	unregCron("$home/agent/bin/watchdog.pl");
	if($home =~ /miops/){
	   `rm -r $home`;
	}
}

sub genLocalConf{
	my ($localFile) = @_;
        open(LOCALCONF,">$localFile")||die "can't open file $localFile";
	my $role = defined $ARGV[3]? $ARGV[3]:'INDIRECT';
        my $content = "our \$SITE = \"$site\";\n";
        $content .= "our \$LOOPADDRESS = \"$ip\";\n";
        $content .= "our \$PARENT = \"$proxy\";\n";
        $content .= "our \$ROLE = \"$role\";\n";
        $content .= "1;\n";
        print LOCALCONF $content;
        close(LOCALCONF);
	return $localFile;
}

sub unpkg{
	`rm -r $HOME/miops/agent`;
	`mkdir -p $home`;
        my $pkgName = "min_agent.tar";
        my $cmd = "cp -f $path/$pkgName $home";
        execCMD($cmd);
        chdir($home);
        $cmd = "tar xvf $pkgName";
        execCMD($cmd);
        $cmd = "rm $pkgName";
        execCMD($cmd);
}

sub startAgent{
        my $cmd = "$home/agent/bin/dispatch.pl start";
        system($cmd);
}

sub checkAgent{
        my $retVal = 0;
        my @entrys = execCMD("crontab -l");
    	foreach my $entry (@entrys){
       		  if(($entry =~ /miops.+watchdog.pl/) ){
                          $retVal = 5;
                          last;
         }
    	}

        @entrys = lsps();
        foreach my $entry (@entrys){
         if(($entry =~ /miops.+dispatch.pl/) ){
                        $retVal = 6;
                         last;
         }
    }
	if($retVal >0){
        	print "install return value=5\n";
	}else{
        	print "install return value=0\n";
	}
}
sub killAgent{
        killAll("miops/");
        sleep(1);
        killAll("miops/");
}

sub uninstall{
my $loginUser = loginUser();
my $procUser = "";
    my @lines = lsps();
foreach my $line (@lines) {
        chomp($line);
        if($line =~ /zy_agentctl/){
                  $line=~s/^\s*|\s*$//g;
                  my @tokens = split / +/,$line;
                  $procUser = $tokens[0];
        }
}

if($procUser ne '' && $procUser ne $loginUser){
        print "the proceed zy_agent's owner $procUser is diffrent from $loginUser\n";
        exit 0;
}

my $PROBE_BASE;
if($loginUser eq 'root'){
        $PROBE_BASE="/opt/testprobe";
}else{
        $PROBE_BASE="/oracle/lsyhms";
}
my $PROBE_HOME = $PROBE_BASE."/agent";

my ($dir,$cmd);
$dir = $PROBE_BASE;
debug("... begin to install $dir");

if(!((-e $dir)&&(-d $dir))){
        $cmd = "mkdir -p $dir";
        execCMD($cmd);
}else{
        $cmd = "rm -r $PROBE_HOME/ext-lib/*";
        execCMD($cmd);
}
}

