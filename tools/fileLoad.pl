use File::Spec;
my $path_curf = File::Spec->rel2abs(__FILE__);
my ($vol, $path, $file) = File::Spec->splitpath($path_curf);
my %proxyName = ();

sub loadHost{
        if(open(FILE,"$path/../data/host.csv")){
                my @lines = <FILE>;
                foreach my $line (@lines){
                        chomp($line);
                        next if($line =~ /^#/);
                        next if($line =~ /^$/);
                        my ($ip,$node,$user,$pass,$rootPass,$port,$connected) = split /,+/,$line;
                        next if($node ne $ARGV[1] && $ARGV[1] ne 'ALL');
                        my $key = $node.'-'.$ip;
                        if($line =~ /proxy/i){
                                $hostProxy{$node} = $ip;
                        }
                        $rootPass=defined $rootPass?$rootPass:' ';
                        $connected = defined $connected?$connected:'indirect';
                        if($connected =~ /proxy/i ){
                                $connected = 'direct';
                        	$hostInfos{"$key"}=[$user,$pass,$rootPass,$port,$connected];
                        }else{
				if (defined $ARGV[2]){
					if( $ARGV[2] eq $ip){
                        			$hostInfos{"$key"}=[$user,$pass,$rootPass,$port,$connected];
					}
				}else{
                        		$hostInfos{"$key"}=[$user,$pass,$rootPass,$port,$connected];
				}
			}
                }
                close(FILE);
        }
}

sub updateDeploy{
        my ($stat,$site,$ip) = @_;
        my ($dbh,$sth,$res,$sql);
        $dbh =DBI->connect("dbi:Oracle:$main::DBNAME",decode_base64($main::DBUSER),decode_base64($main::DBPASS));
        if (!defined $dbh ){
                print "connect db failed\n";
                exit(-1);
        }
        $sql = "update HOSTSTAT set checkstat=? where siteid=? and ipaddress=?";
        $sth = $dbh->prepare ($sql);
        if ( !defined $sth ) {
                        print "Cannot prepare statement for $0 <$sql>: $DBI::errstr\n";
                        exit(-1);
        }
        $res = $sth->execute($stat,$site,$ip);
        $sth->finish();
        $dbh->disconnect();
}

sub genConfig{
	if(open(FILE,">$path/config")){
	foreach my $key (keys %hostInfos){
		my $ref = $hostInfos{$key};
        	my ($user,$pass,$rootPass,$port,$role,$hostName) = @$ref;
		my ($node,$ipaddress) = split /-/,$key;
		my $configHost = "";
		$hostName = lc($hostName);
		$configHost .= "Host $hostName\n";
	        $configHost .= " User          $user\n";
	       	$configHost .= " HostName      $ipaddress\n";
       		$configHost .= " Port          $port\n";
        	$configHost .= " IdentityFile  ~/.ssh/id_rsa\n";
           	if($role eq 'indirect'){
               		my $proxy = lc($proxyName{$node});
                	$configHost .= "    ProxyCommand  ssh $proxy -q -W %h:%p \n";
          	}	
		print FILE $configHost;
	}
		close(FILE);
	}
}

1
