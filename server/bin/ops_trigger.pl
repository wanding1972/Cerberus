#!/usr/bin/perl
use strict;
use Encode;
use SendMail;
use POSIX 'setsid';
use File::Spec;
my $path_curf = File::Spec->rel2abs(__FILE__);
my ($vol, $path, $file) = File::Spec->splitpath($path_curf);
require "$path/min_funcs.pl";
require "$path/../conf/server.conf";

my $home = "$path/../..";
my $app = "trigger";
daemon($app,$home);

my %eventCur = ();
my @eventHis = ();
my %mapHost = readHash("$path/../../data/host.map");

my $fileCur = "$path/../../data/failure.cur";
my $fileHis = "$path/../../data/failure.his";
my $bpFile = "$path/../../data/event.BP";

loadCurEvent();

while(1){
	do "$path/../conf/mail.rule";
	my $fileLog = "$path/../../data/event.log";

  my $last_point = readBP($fileLog);
  if(open(FILE,$fileLog)){
       seek(FILE,$last_point,0);
       while(my $line = <FILE> ){
            processLine($line);
            if (my $last_point_tmp = tell(FILE)){
                   $last_point=$last_point_tmp ;
            }
        }
        close(FILE);
        writeBP($last_point);
  }
  triggerClean();
  output();
  sleep(5);
}

sub processLine{
        my ($line) = @_;
	foreach my $discard (@main::discards){
        	if($line =~ /$discard/){
			return;
		}
	}
        chomp($line);
        my @tokens = split /,/,$line;
        my $key = "$tokens[1],$tokens[2],$tokens[3],$tokens[5]";
        my ($siteID,$ip,$eventType,$index,$fac,$summary) = ($tokens[1],$tokens[2],$tokens[3],$tokens[4],$tokens[5],$tokens[6]);
        if(exists $eventCur{$key}){
                        my $ref = $eventCur{$key};
                        my $times = $ref->[6]+1;
                        my $last = time;
                        $eventCur{$key} = [$siteID,$ip,$eventType,$index,$fac,$summary,$times,$ref->[7],$last,$ref->[9]];
        }else{
                        my $times = 1;
                        my $start = time;
                        $eventCur{$key} = [$siteID,$ip,$eventType,$index,$fac,$summary,$times,$start,$start,0];
        }
}

sub triggerClean{
        my @cleanKeys = ();
        foreach my $key (keys %eventCur){
                        my $ref = $eventCur{$key};
			my $site = $ref->[0];
			my $ip = $ref->[1];
			my $hostname = trim(exists $mapHost{"$site-$ip"}? $mapHost{"$site-$ip"}:'');
                        my $lastTime = $ref->[8];
                        my $cleanTime = curtime();
			my $alarmType = trim($ref->[2]);
			my $times = $ref->[6];
                        if(exists $main::triggers{$alarmType} && $times >= $main::triggers{$alarmType} && $ref->[9] eq '0' ){
			    if(exists $main::mails{$site} || exists $main::mails{'ALL'}){ 
				 my $receivers = "";
				 my $subject   = "$site $ip $hostname $alarmType $ref->[4]";
				 my $start = curtime($ref->[7]);
				 my $end   = curtime($ref->[8]);
				 my $detail     = "$ref->[3],$ref->[4],$ref->[5], occur $times, start from $start, lasttime  occur $end";
				 if(exists $main::mails{$site}){
					$receivers .= $main::mails{$site}.','. $main::mails{"ALL"};	
				 }else{
				    $receivers = $main::mails{"ALL"};
				 }
				 mailReport('',$receivers,$subject,$detail);
				 sendMicroMsg($site,$ip,$alarmType,$hostname,$ref->[4]);
                                 print curtime()." mail $receivers:  $subject : $detail  \n";
                	    $eventCur{$key} = [$ref->[0],$ref->[1],$alarmType,$ref->[3],$ref->[4],$ref->[5],$times,$ref->[7],$ref->[8],'MAIL-'.$cleanTime];
			    }
                        }else{
			} 
                        if(exists $main::cleans{$alarmType} && time - $lastTime > $main::cleans{$alarmType} ){
                          unshift(@eventHis, [$cleanTime,$ref->[0],$ref->[1],$ref->[2],$ref->[3],$ref->[4],$ref->[5],$ref->[6],$ref->[7],$ref->[8],$ref->[9]]);
                          unshift(@cleanKeys, $key);
                        }elsif(! exists $main::cleans{$alarmType} && time - $lastTime > $main::EXPIRETIME){
                          unshift(@eventHis, [$cleanTime,$ref->[0],$ref->[1],$ref->[2],$ref->[3],$ref->[4],$ref->[5],$ref->[6],$ref->[7],$ref->[8],$ref->[9]]);
                          unshift(@cleanKeys, $key);
			}
        }
        foreach my $item (@cleanKeys){
                        delete $eventCur{$item};
        }
}


sub loadCurEvent{
        if(open(FILE,$fileCur)){
                my @lines = <FILE>;
                foreach my $line (@lines) {
                        chomp($line);
                        my @tokens = split /,/,$line;
                        my $key = "$tokens[0],$tokens[1],$tokens[2],$tokens[4]";
                        $eventCur{$key} = \@tokens;
                }
                close(FILE);
        }
}

sub output{
        if(open(FILE,">$fileCur")){
                foreach my $key (keys %eventCur) {
                        my $ref = $eventCur{$key};
                        print FILE "$ref->[0],$ref->[1],$ref->[2],$ref->[3],$ref->[4],$ref->[5],$ref->[6],$ref->[7],$ref->[8],$ref->[9]\n";
                }
                close(FILE);
        }

        if(open(FILE,">>$fileHis")){
                foreach my $ref (@eventHis) {
                        print FILE "$ref->[0],$ref->[1],$ref->[2],$ref->[3],$ref->[4],$ref->[5],$ref->[6],$ref->[7],$ref->[8],$ref->[9],$ref->[10]\n";
                }
                close(FILE);
        }
	@eventHis = ();
}


sub readBP{
	my ($fileLog ) = @_;
        my $last_point = 0;
        if( -e $bpFile){
                my $str = `cat $bpFile`;
                $last_point = defined $str?$str:0;
                chomp($last_point);
                if($last_point eq ''){
                        $last_point = 0;
                }
        }
    my $cur_point = -s $fileLog;
    if ($cur_point == $last_point){
              next;
    }elsif ($cur_point < $last_point){ 
           $last_point = 0 ;
    }
        return $last_point;
}

sub writeBP{
        my ($last_point) = @_;
        `echo $last_point > $bpFile`;
}


#my $test = decode("gb2312",'caaaa网管巡检报告');
#my $title = encode("gb2312",$test);
sub mailReport($$$$){
        my ($RptName,$mailaddrs,$headers,$mailcontent)=@_;
        my ($mailserver,$mailuser,$mailpasswd);
        $mailserver = $main::mailserver;
        $mailuser   = $main::mailuser;
        $mailpasswd = $main::mailpasswd;
        if ((!defined $mailaddrs) || ($mailaddrs eq "" ) || ($mailaddrs eq "NULL" ) || ($mailaddrs eq "-1" )){
                return 0;
        }
        if($headers eq '' || not defined $headers){
                $headers="alarm of miops";
        }
        my @mailaddr = split /\,/,$mailaddrs;
        my $file =$RptName;
        my $sm = new SendMail($mailserver);
        my ($mail1, $mails) = split /\@/, $mailuser;
        $sm->setAuth($sm->AUTHLOGIN, $mail1, $mailpasswd);
        $sm->From($mailuser);
        $sm->Subject($headers);
        $sm->To(@mailaddr);
        $sm->setMailBody($mailcontent);
        $sm->Attach($file);
        if ($sm->sendMail() != 0) {
                my $Detail = "Mail send to @mailaddr error, " . $sm->{'error'} . "\n";
                return(-1);
        }
        return 0;
}

sub sendMicroMsg($$$$$){
	my ($site,$ip,$alarmType,$hostname,$fac) = @_;
	if(exists $main::MicroMsgs{$site} || exists $main::MicroMsgs{'ALL'}){
	      my $receivers = "";
	   if(exists $main::MicroMsgs{$site}){
              $receivers .= $main::MicroMsgs{$site}.'|'. $main::MicroMsgs{"ALL"};
           }else{
              $receivers = $main::MicroMsgs{"ALL"};
           }
	   my $msg = "$alarmType $hostname $fac";
           my $body =  '{"userlist":"'.$receivers.'","site":"'.$site.'","ip":"'.$ip.'","msg":"'.$msg.'"}';
           my $cmd  = "curl -XPOST http://192.168.6.229/miops/weixin/send.php  -d '$body'";
           my $out  = `$cmd`;
	   print "$body $out\n";	
	}		
}

sub daemon{
        my ($app,$home) = @_;
        my $pidFile = "$home/data/$app.pid";
        my $logFile = "$home/data/$app.log";
        defined (my $pid = fork()) or die "Can't fork: $!\n";
        if ($pid) {     #父进程退出
                info("daemon $app started. pid: $pid");
                if(open(FILE,">$pidFile")){
                                print FILE $pid;
                                close(FILE);
                }
                exit(0);
        }else{
                POSIX::setsid() or die "Can't start a new session: $!\n";
                chdir '/';
                if ( -t STDIN ) {
                                close STDIN;
                                open STDIN, '/dev/null' or die "Can't reopen STDIN to /dev/null: $!\n";
                }
                if ( -t STDOUT ) {
                                close STDOUT;
                                open STDOUT, '>', "$logFile" or die "Can't reopen STDOUT to $logFile: $!\n";
                }
                if ( -t STDERR ) {
                                close STDERR;
                                open STDERR, '>', "$logFile" or die "Can't reopen STDERR to $logFile: $!\n";
                }
    }
}

