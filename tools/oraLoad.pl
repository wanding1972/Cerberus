use File::Spec;
my $path_curf = File::Spec->rel2abs(__FILE__);
my ($vol, $path, $file) = File::Spec->splitpath($path_curf);

sub loadHost{
        my ($dbh,$sth,$res,$sql);

        $dbh =DBI->connect("dbi:Oracle:$main::DBNAME",decode_base64($main::DBUSER),decode_base64($main::DBPASS));
        if (!defined $dbh ){
                my $m_errmsg = "connect db failed\n";
                print $m_errmsg;
                exit(-1);
        }
                $sql = "select h.nodecode,ipaddress,username,decrypt_data(password,'beijingtiananmen'),decrypt_data(rocommunity,'beijingtiananmen'),port,clusterstatus,hostname from host h,node n where n.nodecode=h.nodecode  and n.nodefullcode like :1 and (h.ipaddress like :2 or h.clusterstatus ='proxy')";
                $sth = $dbh->prepare ($sql);
                if ( !defined $sth ) {
                        my $Detail = "Cannot prepare statement for $0 <$sql>: $DBI::errstr\n";
                        print $Detail;
                        exit(-1);
                }
                my $fullCode = '%'.$ARGV[1].'%';
		my $ipreg  = '%'.$ARGV[2].'%';
                $res = $sth->execute($fullCode,$ipreg);
                my ($node,$ipaddress,$key);
                while(my $ref = $sth->fetchrow_arrayref()){
                        $node = $ref->[0];
                        $ipaddress = $ref->[1];
                        my $user = $ref->[2];
                        my $pass = $ref->[3];
                        $pass = encode_base64($pass);
                        chomp($pass);
                        my $port = $ref->[5];
                        my $rootPass = $ref->[4];
                        $rootPass = encode_base64($rootPass);
                        chomp($rootPass);
                        my $connected = $ref->[6];
                        if(!defined $port || $port eq ''){$port = 22;}
                        if(!defined $connected || $connected eq '' || $connected eq 'indirect'){
                                $connected='indirect';
                        }else{
				if($connected eq 'proxy'){
                        		$hostProxy{$node}=$ipaddress;
					$main::proxyName{$node} = $ref->[7];
				}
                                $connected = 'direct';
				
                        }
                        $key = $node.'-'.$ipaddress;
                        $hostInfos{"$key"}=[$user,$pass,$rootPass,$port,$connected,$ref->[7]];
                }
	        $sth->finish();
        $dbh->disconnect;
}

sub updateDeploy{
        my ($stat,$site,$ip) = @_;
	print "($stat,$site,$ip)\n";
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

1
