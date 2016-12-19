use File::Basename;
use File::Spec;
use Socket;
my $path_curf = File::Spec->rel2abs(__FILE__);
my ($vol, $path, $file) = File::Spec->splitpath($path_curf);
require "$path/command.pl";

sub chkFileTime{
	my ($mypath,$value) = @_;
	my @files = decodePath($mypath);
	my $isError = 0;
	my $error = "";
	foreach my $file (@files){
	 my @status = stat($file);
	 my $modtime = $status[9];
	 my $interval = int((time() - $modtime)/60+0.5);
	 my $spend = 24*3600*365*5;
	 my $expression = "$interval $value";
	 if (eval($expression) && ($modtime>(time()-$spend))){
		   $isError = 1;
		   $error .= $file.' noUpdate';
		   last;
	 }
	}
	if($isError){
		my $retval = $error."  for $value minutes";
		return $retval;
	}else{
		return 'ok';
	}
}


sub chkFileError{
	my ($mypath,$strErr) = @_;
        my @files = decodePath($mypath);
        my $isError = 0;
        my $error = "";
        foreach my $file (@files){
		if (open(LOGFILE,$file)){
			my $size = -s $file;
			my $l_record;
			seek(LOGFILE,-5000,2);
			while($l_record = <LOGFILE> ){
				if ( $l_record =~ /$strErr/ ){
		                   $isError = 1;
               			   $error .= " $file content has $strErr";
				   last;
				}
			}
			close(LOGFILE);
		}
	}	
        if($isError){
                my $retval = $error;
                return $retval;
        }else{
                return 'ok';
        }
}

sub chkFileSize{
	my ($mypath,$expr) = @_;
   	my @files = decodePath($mypath);
        my $isError = 0;
        my $error = "";
	foreach my $file( @files){
		my $size = -s $file;
		my $expression = "$size $expr";
	    	if (eval($expression)){
                   $isError = 1;
                   $error .= " $file size: $expression Bytes";
		   last;
		}
	}
        if($isError){
                my $retval = $error;
                return $retval;
        }else{
                return 'ok';
        }
}

sub chkDirFile{
	my ($mypath,$expr) = @_;
	my $NUM = 10;
	my @dirs = decodePath($mypath);
	my $dirNum = 0;
	foreach my $logDir (@dirs){
	  next if (!(-d $logDir)); 
	  $dirNum ++;
	  if(!opendir(DIR,$logDir)){
              return "Directory: $logDir failed to open";
	  }
	 my @files = readdir(DIR);
	 closedir(DIR);
	 my ($file,$modtime,$interval,$expression,@status);
	 my $count = 0;
	 foreach $file (@files){
		if(($file ne '.')&&($file ne '..')){
			my $filename = $logDir."/".$file;
			if( -d $filename){
				next;
			}
			@status = stat($filename);
			$modtime = $status[9];
			$interval = int((time() - $modtime)/60+0.5); 
			my $spend = 24*3600*365*10;
			if($modtime<$spend){     # exclude the very old file
				next;
			}
			$expression = "$interval $expr";
			if (eval($expression)) {
				$count ++;
				if($count > $NUM){
					return "In $logDir there are $count files expired $expr minutes";
				}
			}
		}
	 }
	}
	if($dirNum ==0){
		return "$mypath is not directory";
	}else{
		return "ok";
	}
}

sub chkProcess{
        my ($process,$value) = @_;
        my $cmd = getCmd('ps');
        my @result = `$cmd`;
        my $line;
        my $count = 0;
        foreach $line (@result) {
                chomp($line);
                if ($line =~ /\b$process/) {
                        $count++ ;
                }
        }
        my $expression = "$count $value";
        if (eval($expression)) {
                return " $process  $expression";
        }else{
                return 'ok';
        }
}

sub chkProcTimeout{
	my ($procName,$expr) = @_;
    	my $cmd = getCmd('ps');
	my @lines= `$cmd`;
	my @procidlist =();
	my $line;
	foreach $line (@lines){
		chomp($line);
		$line=~s/^\s*|\s*$//g;
		if($line =~/\b$procName/){
			my @token = split / +/,$line;
			push @procidlist,$token[1];
		}
	}
	$cmd = getCmd('psetime');
	@lines = `$cmd`;

	my $procid;
	foreach $procid (@procidlist){
		foreach $line (@lines){
			chomp($line);
			$line=~s/^\s*|\s*$//g;
			my @token = split / +/,$line;
			if($token[0] eq 'PID'){next;}
			if($token[0] == $procid){
				my $etime = $token[1];
				$etime =~s/^\s*|\s*$//g;
				my $minutes;
				if($etime =~ /(\d+)-(\d{2}):(\d{2}):\d{2}/){
					$minutes=$1*24*60+$2*60+$3;
				}elsif($etime =~ /(\d{2}):(\d{2}):\d{2}/){
					$minutes = $1*60+$2;
				}elsif($etime =~ /(\d{2}):\d{2}/){
					$minutes = $1*1;
				}
				my $expression = "$minutes $expr";
				if(eval($expression)){
					return "PID:$procid Process: $procName hangup for $expression minutes";
				}	
			}
		}
	}
	return 'ok';
	
}

sub chkCmd{
        my ($cmd,$value) = @_;
        my $out = `$cmd`;
        if($out =~ /($value.+)$/){
                $ret = $1;
                $cmd =~ s/\||,/_/g;
                return "result of ($cmd) failed: ($ret)";
        }else{
                return 'ok';
        }
}




sub chkCron{
	my ($user,$match) = @_;
	$user = `whoami`;
	chomp($user);
        my $os = `uname -s`;
        chomp($os);
	my $cmd = "";
	if($os eq 'Linux'){
		$cmd = "crontab -u %s -l";
	}else{
		$cmd = "crontab -l %s";
	}
	my $cmd1 = sprintf($cmd,$user);	
	if($user ne 'root'){
		$cmd1 = "crontab -l";
	}
	print $cmd1;
	my @lines = `$cmd1`;
	my $flag = "$match not exists";
	foreach my $line (@lines){
		chomp($line);
		if($line =~ /$match/ && $line !~ /^#/){
			$flag = 'ok';
			last;
		}
	}
	return $flag;
}

sub chkHTTP{
        my ($url,$pattern) = @_;
        my ($addr,$port,$path,$dest,$sock,$con,$buf);  
	if($url =~ /(\d+.\d+.\d+.\d+):(\d+)(\/[^ ]*)/){
		$addr = $1;
		$port = $2;
		$path = $3;
	}else{
		return 'url is not valid';
	}
        $dest = sockaddr_in($port, inet_aton($addr));
        $sock = socket(SOCK,PF_INET,SOCK_STREAM,6);
        if(!$sock){return 'failed';}
	eval{
		local $SIG{ALRM} = sub { die 'Timed Out'; };
		alarm $para::TCP_TIMEOUT;
        	$con = connect(SOCK,$dest) ;
        	if(!$con){return "can not connect $addr:$port";}

        	$buf = "GET $path HTTP/1.1\n";
        	syswrite(SOCK,$buf,length($buf));
        	$buf = "Host: $addr:$port\n\n";
        	syswrite(SOCK,$buf,length($buf));
        	my $bs = sysread(SOCK, $buf, 2048);
        	close SOCK;
		alarm 0;
	};
	alarm 0;
	if(!defined $buf){ return "failed to connect $addr:$port";}
        if($buf =~ /$pattern/){
                return 'ok';
        }else{
                return 'return value is not 200';
        }
}

sub chkTCP{
        my ($addr,$port) = @_;
	my ($dest,$sock,$con);	
        $dest = sockaddr_in($port, inet_aton($addr));
        $sock = socket(SOCK,PF_INET,SOCK_STREAM,6);
	if(!$sock){ return 'can not create socket';}
        eval{
                local $SIG{ALRM} = sub { 
					die 'Timed Out'; 
					};
                alarm $para::TCP_TIMEOUT;
        	$con = connect(SOCK,$dest);
		alarm 0;
	};
       		if($con){
                	close SOCK;
                	return 'ok';
        	}else{
               		return "can not connect $addr:$port";
        	}
}

sub decodePath{
	my ($mypath) = @_;
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);
	my $date;
	my ($offset,$prsid,$myHome);
	for(;;){
		if($mypath =~ /{YYYYMMDD-(\d)}/){
			$offset = $1;
			($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time()-24*3600*$offset);
			$date=sprintf("%d%02d%02d",$year+1900,$mon+1,$mday);
			$mypath =~ s/{YYYYMMDD-\d}/$date/g;
		}elsif($mypath =~ /{YYYYMM-(\d)}/){
			$offset = $1;
			($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time()-24*3600*$offset);
			$date=sprintf("%d%02d",$year+1900,$mon+1);
			$mypath =~ s/{YYYYMM-\d}/$date/g;
		}elsif($mypath =~/(\$[a-zA-Z_1-9]+)/){
        		$myHome = eval($1);
			$mypath =~ s/\$[a-zA-Z_1-9]+/$myHome/;
		}elsif($mypath =~ /{WEEK-(\d)}/){
			$offset = $1;
			($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time());
			 if($wday<$offset){
				$offset = 7-($offset-$wday);
			 }else{
				$offset = $wday-$offset;
			}
			($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time()-24*3600*$offset);
			$date=sprintf("%d%02d%02d",$year+1900,$mon+1,$mday);
			$mypath =~ s/{WEEK-\d}/$date/g;	
		}elsif($mypath =~ /{YYYYMMDD}/){
			($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time());
			$date=sprintf("%d%02d%02d",$year+1900,$mon+1,$mday);
			$mypath =~ s/{YYYYMMDD}/$date/g;	
		}elsif ($mypath =~ /\*/){ 
			my @filesArr = `ls $mypath`;
			return @filesArr;
		}elsif($mypath =~ /\?/){
			my @fileArr = `ls $mypath`;
			return @fileArr;
		}else{
			my @filesArr = ();
			push (@filesArr,$mypath);
			return @filesArr;
		}
	}
}

sub test{
print chkDirFile('/wanding/cerberus/bin','>1');
print "asda\n";
print chkFileError('service.pl','sub');
print "\n";
print chkFileSize('service.pl','>200');
print "\n";
print chkFileTime('funcs.pl','>200');
print "\n";
	my @arr = decodePath("/wanding/cerberus/bin");
	foreach my $ab (@arr){
		print "$ab\n";
	}
	print "----\n";
}

#test();
1;
