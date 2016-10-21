#!/usr/bin/perl
use strict;             
use File::Spec; 
my $path_curf = File::Spec->rel2abs(__FILE__);
my ($vol, $path, $file) = File::Spec->splitpath($path_curf);
                
require "$path/../../conf/global.conf";
require "$path/../../lib/funcs.pl";
require "$path/../../lib/command.pl";
$ENV{'LC_ALL'} = 'C';

dupProcess($file);
my $option = argOption();
if($option =~ /v/){
        $main::LOGLEVEL=1;
        $|=1;
}
my $user = loginUser();
if($user !~ /ora/){
	print "User $user is not oracle user\n";
	exit 0;
}
my %psSQLID = ();
my %psDetail = ();
my %psCPU = fetchPSCPU();
my $sql = "select 'TD',p.spid,s.sql_id,s.sid,s.blocking_session,s.event,s.program,s.status,s.username,to_char(logon_time,'YYYY-MM-DD HH24:MI:SS') mylogon from v\\\$process p,v\\\$session s where p.addr=s.paddr and s.sql_id is not null;";
my @lines = execSQL($sql);
foreach my $line (@lines){
        next if($line !~ /TD/);
	next if($line =~ /PROGRAM/);
        my $line1 = trim($line);
        my @tokens = split /[ \t]+/,$line1;
        $psSQLID{$tokens[1]}= $tokens[2];
        if($line1 =~ /TD (.+)$/){
                $psDetail{$tokens[1]} = $1;
        }
}

my @time1=localtime(time());
my $ss = $time1[0];
my $fileName = "$path/../../../run/tmp/sql$ss.log";

if(open(FILE3,">$fileName")){
foreach my $pid (keys %psSQLID){
        my $sqlid = $psSQLID{$pid};
        my @outs = execSQL (" select distinct 'TD',sql_text from v\\\$sql where sql_id='$sqlid' ;");
        foreach my $out (@outs){
                next if($out !~ /TD/);
                next if($out =~ /TEXT|SQL/);
                trim($out);
                if($out =~ /TD (.+)$/){
                        print FILE3 "$psCPU{$pid}    $psDetail{$pid}    $1\n";
                }
        }
}
close(FILE3);
}

print "snapSQL.pl is finished \n";

sub fetchPSCPU{
        my %psCPU = ();
        my @lines = mycmds('pscpu');
        foreach my $line (@lines){
                my $line1 = trim($line);
                my @tokens = split / +/,$line1;
                next if($tokens[3] eq '0.0');
                $psCPU{$tokens[1]} = $tokens[3];
        }
        return %psCPU;
}

