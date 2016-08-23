our %linuxCmd = (
	'dfk' 	=> 'df -Pkl 2>/dev/null',
	'dfi' 	=> 'df -Pil 2>/dev/null',
	'ps' 	=> 'ps -auxww 2>/dev/null',
	'psetime' => 'ps -eo pid,etime,stime,args',
	'pscpu'	  => 'ps -e -o "user,pid,ppid,pcpu,vsz,stime,args"',
	'vmstat' => '/usr/bin/vmstat 1 2',
	'iostat' => '/usr/bin/iostat -dx 1 2',
	'ping' => '/bin/ping  -c 2 -i 1 -s 512 -W 3 Gateway',
	'netio' => "netstat -i",
	'swap'	=> 'free -m'
);
our %hpuxCmd = (
	'dfk' => 'bdf -l',
	'dfi' => 'bdf -li',
	'ps' => 'ps -efx',
	'psetime' => 'UNIX95= ps -eo pid,etime,stime,args',
	'pscpu'	  => 'UNIX95= ps -e -o "user,pid,ppid,pcpu,vsz,stime,args"',
	'vmstat' => 'vmstat 3 2',
	'iostat' => 'sar -d 1 2',
	'ping' =>   "/usr/sbin/ping -I 1 Gateway 512 -n 2 -m 3",
	'netio' => "netstat -i",
	'swap'	 => 'swapinfo'
);

our %aixCmd = (
	'dfk' => '/usr/sysv/bin/df -lv',
	'dfi' => '/usr/sysv/bin/df -li',
	'ps' => 'ps -ef 2>/dev/null',
	'psetime' => 'ps -eo pid,etime,stime,args',
	'pscpu'   => 'ps -e -o "user,pid,ppid,pcpu,vsz,stime,args"',
	'vmstat' => 'vmstat 1 2',
	'iostat' => 'sar -d 1 1',
	'ping' => "/usr/sbin/ping  -c 2 -i 1 -s 512 -w 3 Gateway",
	'netio' => "netstat -i",
	'swap'	  => 'lsps -a'
);

our %sunosCmd = (
	'dfk' => 'df -lk',
	'dfi' => 'df -F ufs -oi',
	'ps' => '/usr/ucb/ps -auxww',
	'psetime' => 'ps -eo pid,etime,stime,args',
	'pscpu'	  => 'ps -e -o "user,pid,ppid,pcpu,vsz,stime,args"',	
	'vmstat' => 'vmstat 1 2',
	'iostat' => 'iostat -xn 1 2',
	'ping'   => "/usr/sbin/ping -s -I 1 Gateway 512 2",
	'netio' => "netstat -i",
	'swap'	  =>	'swap -s'
);

sub mycmds{
        my ($key) = @_;
        my $os = lc(`uname -s`);
        chomp($os);
	my $cmd = "";
        if($os eq 'hp-ux'){
                $cmd = $hpuxCmd{$key};
        }elsif($os eq 'linux'){
                $cmd = $linuxCmd{$key};
        }elsif($os eq 'sunos'){
                $cmd = $sunosCmd{$key};
        }elsif($os eq 'aix'){
                $cmd = $aixCmd{$key};
        }
	my @outs = `$cmd`;
	return @outs
}

sub getCmd{
       my ($key) = @_;
        my $os = lc(`uname -s`);
        chomp($os);
        my $cmd = "";
        if($os eq 'hp-ux'){
                $cmd = $hpuxCmd{$key};
        }elsif($os eq 'linux'){
                $cmd = $linuxCmd{$key};
        }elsif($os eq 'sunos'){
                $cmd = $sunosCmd{$key};
        }elsif($os eq 'aix'){
                $cmd = $aixCmd{$key};
        }
	return $cmd;
}

1;
