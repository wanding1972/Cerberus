use File::Spec;
my $path_curf = File::Spec->rel2abs(__FILE__);
my ($vol, $path, $file) = File::Spec->splitpath($path_curf);

sub loadHost{
        if(open(FILE,"$path/../data/host.csv")){
                my @lines = <FILE>;
                foreach my $line (@lines){
                        chomp($line);
                        next if($line =~ /^#/);
                        next if($line =~ /^$/);
                        my ($ip,$node,$user,$pass,$rootPass,$port,$connected) = split /,+/,$line;
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
                        	$hostInfos{"$key"}=[$user,$pass,$rootPass,$port,$connected];
			}
                }
                close(FILE);
        }
}

sub updateDeploy{
        my ($stat,$site,$ip) = @_;
	print "($stat,$site,$ip) \n";
}

1
