use File::Basename;
use File::Spec;
use Socket;
my $path_curf = File::Spec->rel2abs(__FILE__);
my ($vol, $path, $file) = File::Spec->splitpath($path_curf);
require "$path/command.pl";

sub chkFileTime{
	my ($file,$value) = @_;
	$file = decodePath($file);
	my $dir = dirname($file);
	my $base = basename($file);
	my $isError = 0;
	my $error = "";
	if( ! -e $file){
		return "file $file not exists";
	}
				my @status = stat($file);
				my $modtime = $status[9];
				my $interval = int((time() - $modtime)/60+0.5);
				my $spend = 24*3600*365*5;
				my $expression = "$interval $value";
				if (eval($expression) && ($modtime>(time()-$spend))){
					   $isError = 1;
					   $error .= $file.' noUpdate , ';
				}
	if($isError){
		my $retval = $error."  for $value minutes";
		return $retval;
	}else{
		return 'ok';
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

sub chkFileError{
	my ($file,$strErr) = @_;
  	$file = decodePath($file);
	if (-e $file){
		if (!open(LOGFILE,$file)){
			return "fileName: $file failed to open";
		}else{
			my $size = -s $file;
			my $l_record;
			seek(LOGFILE,-5000,2);
			while($l_record = <LOGFILE> ){
				if ( $l_record =~ /$strErr/ ){
					return " $file content has $strErr";
				}
			}
			return 'ok';
		}	
	}else{
		return "fileName: $file not exist";
	}
}

sub chkFileSize{
	my ($file,$expr) = @_;
   	$file = decodePath($file);
	if (-e $file){
			my $size = -s $file;
			my $expression = "$size $expr";
		    	if (eval($expression)){
                        	return " $file size: $expression Bytes";
			}else{
				return 'ok';
			}
	}else{
		return "fileName: $file not exist";
	}
}

sub chkDirFile{
	my ($logDir,$expr) = @_;
	my $NUM = 20;
	$logDir = decodePath($logDir);
	if (!(-d $logDir)) {
		return "Directory: $logDir is not a directory";
	}
	if(!opendir(DIR,$logDir)){
              return "Directory: $logDir failed to open";
	}
	my @files = readdir(DIR);
	if($#files < $NUM){     
		return "ok";
	}
	my ($file,$modtime,$interval,$expression,@status);
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
			if($modtime<$spend){
				next;
			}
			$expression = "$interval $expr";
			if (eval($expression)) {
				return " $filename is too older: $expression minutes";
			}
		}
	}
	closedir(DIR);
	return "ok";
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
		if($line =~/\b$procName\b/){
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

sub chkCmd{
        my ($file,$value) = @_;
	my $out = `$file`;
	if($out =~ /$value/){
		return 'ok';
	}else{
		return "result of $file failed";
	}
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
	my ($path) = @_;
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);
	my $date;
	my ($offset,$prsid,$myHome);
	for(;;){
		if($path =~ /{YYYYMMDD-(\d)}/){
			$offset = $1;
			($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time()-24*3600*$offset);
			$date=sprintf("%d%02d%02d",$year+1900,$mon+1,$mday);
			$path =~ s/{YYYYMMDD-\d}/$date/g;
		}elsif($path =~ /{YYYYMM-(\d)}/){
			$offset = $1;
			($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time()-24*3600*$offset);
			$date=sprintf("%d%02d",$year+1900,$mon+1);
			$path =~ s/{YYYYMM-\d}/$date/g;
		}elsif($path =~/(\$[a-zA-Z_1-9]+)/){
        	$myHome = eval($1);
			$path =~ s/\$[a-zA-Z_1-9]+/$myHome/;
		}elsif($path =~ /{WEEK-(\d)}/){
			$offset = $1;
			($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time());
			 if($wday<$offset){
				$offset = 7-($offset-$wday);
			 }else{
				$offset = $wday-$offset;
			}
			($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time()-24*3600*$offset);
			$date=sprintf("%d%02d%02d",$year+1900,$mon+1,$mday);
			$path =~ s/{WEEK-\d}/$date/g;	
		}elsif($path =~ /{YYYYMMDD}/){
			($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time());
			$date=sprintf("%d%02d%02d",$year+1900,$mon+1,$mday);
			$path =~ s/{YYYYMMDD}/$date/g;	
		}else{
			return $path;
		}
	}
}


1;
