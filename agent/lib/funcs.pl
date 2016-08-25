use POSIX 'setsid';
use File::Spec;
my $path_curf = File::Spec->rel2abs(__FILE__);
my ($vol, $path, $file) = File::Spec->splitpath($path_curf);

my %ps = (
                        'aix' => 'ps -ef 2>/dev/null',
                        'hp-ux' => 'ps -efx',
                        'linux' => 'ps -auxww 2>/dev/null',
                        'sunos' => '/usr/ucb/ps -auxww'
                );
sub curtime{
        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =localtime(time);
        $year+=1900;
        $mon += 1;
        my $curTime= sprintf("%04d%02d%02d%02d%02d%02d", $year,$mon,$mday,$hour,$min,$sec);
        return $curTime;
}

sub trim{
        my ($line) = @_;
        chomp($line);
        $line=~s/^\s*|\s*$//g;
        return $line;
}

sub debug{
        my ($msg) = @_;
        my $curTime = localtime(time);
        if($LOGLEVEL<2 &&$LOGLEVEL>0){
                print $curTime.' DEBUG: '.$msg."\n";
        }
}
sub error{
        my ($msg) = @_;
        my $curTime = localtime(time);
        if($LOGLEVEL<4 &&$LOGLEVEL>0){
                print $curTime.' ERROR: '.$msg."\n";
        }
}
sub info{
        my ($msg) = @_;
        my $curTime = localtime(time);
        if($LOGLEVEL<3 &&$LOGLEVEL>0){
                print $curTime.' INFO: '.$msg."\n";
        }
}
sub execCMD{
        my ($cmd) = @_;
        debug($cmd);
        `$cmd`;
}

sub readHash{
	my ($file) = @_;
	my %hash = ();
	if(open(FILE,$file)){
		my @lines = <FILE>;
		foreach my $line (@lines){
			chomp($line);
			next if($line =~ /^#/);
			my @tokens = split /=/,$line;
			$hash{$tokens[0]} = $tokens[1];
		}
		close(FILE);
	}
	return %hash;
}

sub writeHash{
	my ($hashRef,$file) = @_;
	my %hash = %$hashRef;
	my @list = keys %hash;
	if(open(FILE,">$file")){
		foreach my $key (keys %hash) {
			my $value = $hash{$key};
			print FILE "$key=$value\n";
		}
		close(FILE);
	}
}

#my %hash  = diffHash(\%oldHash,\%newHash);
sub diffHash{
	my ($srcMap,$dstMap)=@_;
	my %results = ();
	my $count = 0;
	foreach my $key (keys(%$dstMap)){
		if (!exists( $$srcMap{$key})){
			$results{$key} = $$dstMap{$key};
		}else{
			if($$srcMap{$key} eq $$dstMap{$key}){
				$count++;
			}else{
			   $results{$key} = $$dstMap{$key};
			}
		}
	}
	return %results;
}

sub sendUDP{
        my ($server,$port,$msg) = @_;
        my $packhost=inet_aton($server);
        my $address=sockaddr_in($port,$packhost);
        socket(CLIENT,AF_INET,SOCK_DGRAM,17);
        send(CLIENT,$msg,0,$address);
        close CLIENT;
}
sub chkOS{
        $os = `uname -s`;
        chomp($os);
        return lc($os);
}

sub killAll{
        my ($prog) = @_;
	my $os = chkOS();
        my $cmd = $ps{$os};
        my @lines = `$cmd`;
        foreach my $line (@lines){
             if($line =~ /$prog/){
                        $line=~s/^\s*|\s*$//g;
                        my @tokens = split / +/,$line;
                        $cmd = "kill -9 $tokens[1]";
                        `$cmd`;
             }
    }
}

sub dupProcess{
        my ($processName) = @_;
       $os = chkOS();
        my $cmd = $ps{$os};
        my @pslist = `$cmd`;
        my $count = 0;
        foreach my $line (@pslist){
                if($line =~ /$processName/){
                        $count++;
                }
        }
	if($processName =~ /miops_watchdog/){
		if($count>2){
	            print "$processName is running\n";
       		    exit(-1);
		}
	}else{
		if($count>1){
			print "$processName is running\n";
			exit(-1);
		}
	}
}

sub daemon{
	my ($app,$home) = @_;
	my $pidFile = "$home/run/tmp/$app.pid";
	my $logFile = "$home/run/log/$app.log";
	
	defined (my $pid = fork()) or die "Can't fork: $!\n";
	if ($pid) { 
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

#flush the perfdata to file
sub writeArray{
	my ($file,$ref) = @_;
	if(open(FILE,">$file")){
		foreach my $refa (@$ref){
			#app,$item,$fac,$value
			print FILE "$refa->[0],$refa->[1],$refa->[2],$refa->[3]\n";
		}
		close(FILE);
	}
	return $file;
}

sub getGW{
        my $cmd = "netstat -rn";
        my @lines = `$cmd`;
        my @hosts = ();
        foreach my $line (@lines){
			chomp($line);
			if($line =~ /^[default|0.0.0.0].+UG/){
				my @tokens = split / +/,$line;
				my $gw = $tokens[1];
				return $gw;
			}
        }
	return '127.0.0.1';
}
sub extract{
        my ($line,$pattern) = @_;
        if ($line =~ /$pattern/){
                return $1 ;
        }else{
                return '' ;
        }
}

sub snapPS{
        my ($dir) = @_;
        my @time1=localtime(time());
        my $hh = $time1[2];
        my $mm = $time1[1];
        my $ss = $time1[0];
        my $fileName = "$dir/ps$mm$ss.log";
        my %cmd = (
                'linux' => 'ps -eo "user,pid,ppid,pcpu,vsz,stime,etime,args"',
                'aix'   => 'ps -e -o "user,pid,ppid,pcpu,vsz,stime,args"',
                'hp-ux' => 'UNIX95= ps -e -o "user,pid,ppid,pcpu,vsz,stime,args"',
                'sunos' => 'ps -e -o "user,pid,ppid,pcpu,vsz,stime,args"'
                );
        my $os = chkOS();
        if(open(FILE1,">$fileName")){
                my $cmd = $cmd{$os};
                my @lines = `$cmd`;
                my $line;
                foreach $line (@lines){
                        print FILE1 $line;
                }
                close(FILE1);
        }
}

sub loadLocalConf{
	my $localConf = "$path/../conf/local.conf";
	if( -e $localConf){
		require $localConf;
	}
	require "$path/../conf/global.conf";
	my ($site,$ip,$server,$webserver,$webport);
	if(defined $SITE){
		$site = $SITE;
	}else{
		$site = 'default';
	}
	if(defined $LOOPADDRESS){
		$ip = $LOOPADDRESS;
	}else{
		$ip = `hostname`;
		chomp($ip);
	}
	if(defined $PARENT && $ROLE eq 'INDIRECT'){
		$server = $PARENT;
		$webserver = $PARENT;
		$webport = $PORT;
	}else{
		$server = $SERVER;
		$webserver = $WEBSERVER;
		$webport = $WEBPORT;
	}
	return ($site,$ip,$server,$webserver,$webport);
}

			print "---------- $REG_TIMEOUT";
sub hasService{
        my ($service) = @_;
        my %hash = readHash("$path/../../run/cfg/service.reg");
        if(exists $hash{$service}){
                if($hash{$service} =~ /(\d+)-(\d+)/){
                        my $interval = $2-$1;
                        if($interval > $REG_TIMEOUT){
                                return 1;
                        }
                }
        }
        return 0;
}

sub execSQL{
        my ($sql) = @_;
        my $file = "$path/execSQL$$.sh";
        my $content = "sqlplus  << EOF\n";
           $content .= "connect / as sysdba\n";
           $content .= "set linesize 2000;\n";
           $content .= "set pagesize 500;\n";
           $content .= "set wrap off;\n";
           $content .= "set trimspool on;\n";
           $content .= "$sql\n";
           $content .= "exit;\n";
           $content .= "EOF\n";
        if(open(FILE,">$file")){
                print FILE $content;
                close(FILE);
        }
        my $cmd = "sh $file";
        my  @lines = `$cmd`;
        `rm $file`;
        return @lines;
}

sub loginUser{
        my %cmdWho = (
                        'sunos' => '/usr/ucb/whoami',
                        'other' => 'whoami'
        );
        my $os = lc(`uname -s`);
        chomp($os);

        my $loginUser = '';
        if($os eq 'sunos'){
                        $loginUser = `$cmdWho{$os}`;
        }else{
                        $loginUser = `$cmdWho{'other'}`;
        }
	chomp($loginUser);
        return $loginUser;
}

1;
