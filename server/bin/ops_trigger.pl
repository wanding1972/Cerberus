#!/usr/bin/perl
use strict;
use Encode;
#use SendMail;
use POSIX 'setsid';
use File::Spec;
my $path_curf = File::Spec->rel2abs(__FILE__);
my ($vol, $path, $file) = File::Spec->splitpath($path_curf);
require "$path/min_funcs.pl";
require "$path/../conf/server.conf";

my $home = "$path/../..";
my $app = "trigger";
dupProcess($file);
daemon($app,$home);

my %eventCur = ();
my @eventHis = ();
my %mapHost = ();

my $fileCur = "$path/../../data/failure.cur";
my $fileHis = "$path/../../data/failure.his";
my $bpFile = "$path/../../data/event.BP";

loadCurEvent();

my %regEvents = ();
my $counter = 0;
while(1){
	do "$path/../conf/mail.rule";
	my $fileLog = "$path/../../data/event.log";
	if($counter % 12 == 0){
		%mapHost = readHash("$path/../../data/host.map");
		my $statLog = "$path/../../data/stat.log";
		my @status = stat($statLog);
                my $modtime = $status[9];
                my $interval = int((time() - $modtime)/60+0.5);
		my $evtKey = "NoNewEvents,event.log";
		if($interval > 10){
			my $msgEvt = curtime().",NOD999,127.0.0.1,NoNewEvents,$app.mtime,event.log,hasnot received new events for $interval minutes OCCUR";
			processLine($msgEvt);
			print "$msgEvt \n";
			if(!exists($regEvents{$evtKey})){
				$regEvents{$evtKey} = 1;	
			}
		}else{
			if(exists($regEvents{$evtKey})){
				my $msgEvt = curtime().",NOD999,127.0.0.1,NoNewEvents,$app.mtime,event.log,hasnot received new events for $interval minutes RECOVER";
				processLine($msgEvt);
				delete $regEvents{$evtKey};
			}
		}
	}
  	my $last_point = readBP($fileLog);
	my $cur_point = -s $fileLog;
    	if ($cur_point > $last_point){
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
	}
  	triggerClean();
  	output();
  	$counter++;
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
			if($summary !~ /RECOVER/){
                        	my $times = $ref->[6]+1;
                        	my $last = time;
                        	$eventCur{$key} = [$siteID,$ip,$eventType,$index,$fac,$summary,$times,$ref->[7],$last,$ref->[9],$ref->[10],$ref->[11]];
			}else{
				my $times = defined $ref->[11]? $ref->[11]+1:1;
				my $close = time;
                        	$eventCur{$key} = [$siteID,$ip,$eventType,$index,$fac,$summary,$ref->[6],$ref->[7],$ref->[8],$ref->[9],$close,$times];
			}
        }else{
                        my $times = 1;
                        my $start = time;
                        $eventCur{$key} = [$siteID,$ip,$eventType,$index,$fac,$summary,$times,$start,$start,0,0,0];
        }
}

sub triggerClean{
        my @cleanKeys = ();
        foreach my $key (keys %eventCur){
                        my $ref = $eventCur{$key};
			my $site = $ref->[0];
			my $ip = $ref->[1];
			my $alarmType = trim($ref->[2]);
			my $times = $ref->[6];
                        
                        my $lastTime = $ref->[8];
			my $closeTime = $ref->[10];
			my $flapTimes = $ref->[11];

			#notify alarm( mail | WeChat)
                        if(exists $main::triggers{$alarmType} && $times >= $main::triggers{$alarmType} && $flapTimes < $main::FLAP_TIMES  && ($ref->[9] eq '0' || $ref->[9] < time()-$main::MAIL_TIMEOUT) ){
				notifyAlarm($site,$ip,$alarmType,$ref->[4],'OCCUR');
                	    	$eventCur{$key} = [$ref->[0],$ref->[1],$alarmType,$ref->[3],$ref->[4],$ref->[5],$times,$ref->[7],$ref->[8],time(),$ref->[10],$ref->[11]];
                        }
			
			#clean to alarmHis 
			my $cleanTime = curtime();
			my $start = curtime($ref->[7]);
			my $end   = curtime($ref->[8]);
			my $mailTime = curtime($ref->[9]);
			my $closeTag = curtime($closeTime);
			if($closeTime > $lastTime && $closeTime < time-$main::FLAP_TIMEOUT){
			 	if($ref->[9] > 0){
			  		notifyAlarm($site,$ip,$alarmType,$ref->[4],'RECOVER');
				}
                          unshift(@eventHis, [$cleanTime,$ref->[0],$ref->[1],$ref->[2],$ref->[3],$ref->[4],$ref->[5],$ref->[6],$start,$end,$mailTime,$closeTag,$ref->[11]]);
                          unshift(@cleanKeys, $key);
			}elsif(exists $main::cleans{$alarmType} && time - $lastTime > $main::cleans{$alarmType} ){
			 	if($ref->[9] > 0){
			  		notifyAlarm($site,$ip,$alarmType,$ref->[4],'RECOVER');
				}
                          unshift(@eventHis, [$cleanTime,$ref->[0],$ref->[1],$ref->[2],$ref->[3],$ref->[4],$ref->[5],$ref->[6],$start,$end,$mailTime,$closeTag,$ref->[11]]);
                          unshift(@cleanKeys, $key);
                        }elsif(! exists $main::cleans{$alarmType} && time - $lastTime > $main::CLEAN_TIMEOUT){
			 	if($ref->[9] > 0){
			  		notifyAlarm($site,$ip,$alarmType,$ref->[4],'RECOVER');
				}
                          unshift(@eventHis, [$cleanTime,$ref->[0],$ref->[1],$ref->[2],$ref->[3],$ref->[4],$ref->[5],$ref->[6],$start,$end,$mailTime,$closeTag,$ref->[11]]);
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
			$tokens[10] = defined $tokens[10]? $tokens[10]:0;
			$tokens[11] = defined $tokens[10]? $tokens[11]:0;
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
                        print FILE "$ref->[0],$ref->[1],$ref->[2],$ref->[3],$ref->[4],$ref->[5],$ref->[6],$ref->[7],$ref->[8],$ref->[9],$ref->[10],$ref->[11]\n";
                }
                close(FILE);
        }

        if(open(FILE,">>$fileHis")){
                foreach my $ref (@eventHis) {
                        print FILE "$ref->[0],$ref->[1],$ref->[2],$ref->[3],$ref->[4],$ref->[5],$ref->[6],$ref->[7],$ref->[8],$ref->[9],$ref->[10],$ref->[11],$ref->[12]\n";
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
    if ($cur_point < $last_point){ 
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
	my $out = "";
        if ($sm->sendMail() != 0) {
             	$out = " error, " . $sm->{'error'} ;
        }else{
		$out = " suceed!";
	}
	print "mail: $headers $mailaddrs $out\n"; 
}

sub sendMicroMsg($$$$$){
	my ($site,$ip,$alarmType,$hostname,$fac) = @_;
        my $receivers = getNotifier('wechat',$site);
	return if($receivers eq '');
	my $msg = "$alarmType $hostname $fac test";
        my $body =  '{"userlist":"'.$receivers.'","site":"'.$site.'","ip":"'.$ip.'","msg":"'.$msg.'"}';
        my $cmd  = "curl -XPOST $main::urlWechat -d '$body' 2>/dev/null";
        my $out  = `$cmd`;
	my $cleanTime = curtime();
	print "wechat: $cleanTime $body $out\n";	
}

sub notifyAlarm{
	my ($site,$ip,$alarmType,$fac,$action) = @_;
	my $key = "$site,$ip,$alarmType,$fac";
	my $ref = $eventCur{$key};

        my $hostname = trim(exists $mapHost{"$site-$ip"}? $mapHost{"$site-$ip"}:$ip);
        my $subject   = "$site $hostname $ref->[4] $alarmType $action";

	my $times    = $ref->[6];
        my $start = curtime($ref->[7]);
        my $end   = curtime($ref->[8]);
        my $detail     = "$ref->[3],$ref->[4],$ref->[5], occur $times, start from $start, lasttime  occur $end";
	if($action eq 'RECOVER'){
		my $closeTag = curtime($ref->[10]);
        	$detail     = "$ref->[3],$ref->[4],$ref->[5], occur/recover $ref->[11], start from $start, closetime $closeTag";
	}
        sendMicroMsg($site,$ip,$alarmType,$hostname,$ref->[4]);
        my $receivers = getNotifier('mail',$site);
	if($receivers ne ''){
        #        mailReport('',$receivers,$subject,$detail);
        }

}

sub getNotifier {
	my ($type,$site) = @_;
	my %hash = readHash("$path/../conf/notify.dic");
	my %hashUser = readHash("$path/../conf/user.dic");
	my %users = ();
	if(exists $hash{$site}){
		my @users = split /,/, $hash{$site};
		foreach my $user (@users){
			$users{$user} = 1;
		}	
	}
	if(exists $hash{'ALL'}){
		my @users = split /,/,$hash{'ALL'};
		foreach my $user (@users){
			$users{$user} = 1;
		}
	}
	my @wechats = ();
	my @mails = ();
	foreach my $key (keys %users){
		my @tokens = split /,/,$hashUser{$key};
			if(defined $tokens[1] && $tokens[1] ne ''){
				push(@wechats ,$tokens[1]);
			}
			if(defined $tokens[0] && $tokens[0] ne ''){
				push(@mails ,$tokens[0]);
			}
	}
	my $strWechat = join ('|', @wechats);
	my $strMail   = join (',', @mails);
	if($type eq 'wechat'){
		return $strWechat;
	}else{
		return $strMail;
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

