#!/usr/bin/perl
use strict;
use File::Spec;
use Time::Local;
my $path_curf = File::Spec->rel2abs(__FILE__);
my ($vol, $path, $file) = File::Spec->splitpath($path_curf);

require "$path/../lib/funcs.pl";
dupProcess($file);

my $option = argOption();
if($option =~ /v/){
        $main::LOGLEVEL=1;
        $|=1;
}
my $datapath = "$path/../../run/data/perf/";
my @nameArr = ('cpu','swap','net','conps');

foreach my $type(@nameArr) {
	my $newdate = gettime();
        my $filepath = $datapath.$type.'.'.$newdate.'*';
        my $cmd = "ls -t $filepath |head -80";
        my @fileArr = `$cmd`;
        my $result = $type.'=>';
        foreach my $dataname(@fileArr) {
                my $onevalue = getdata($type,$dataname);
                $result .= $onevalue;
        }
        print"$result\n";
}


sub gettime{
	my ($sec,$min,$hour,$day,$mon,$year)=localtime();
        my $newyear = $year+1900;
        my $newmon = $mon +1;
	if($newmon < 10){
		$newmon = '0'.$newmon;
	}
	if($day < 10){
                $day = '0'.$day;
        }
        my $newdate = $newyear.$newmon.$day;
	return $newdate;
}

sub getdata{
        my ($type,$dataname) = @_;
        open(DATAFILE,$dataname)||die("$!,Can't open the file!");
        my @newdata = <DATAFILE>;
        close DATAFILE;

        my $date;
        my $value = 0;
        my $key;

        if($type eq 'cpu'){
                $key = 'cpu_idle';
        }elsif ($type eq 'swap') {
                $key = 'swap_ratio';
        }elsif ($type eq 'conps') {
                $key = 'ps_count';
        }elsif ($type eq 'net') {
                $key = 'net,rx';
        }   
            
        if ($dataname =~ /.(\d{14})./) {
                $date = $1;
        } 
              
        foreach (@newdata) {
                if($_ =~ $key){
                        my @onedata = (split',',$_);
                        $value += $onedata[$#onedata];
                }
        } 

        my $result = $date.','.$value.';';
        return $result;
} 
