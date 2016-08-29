#!/usr/bin/perl
use IO::Socket::INET;
if(scalar(@ARGV)<3){
        print "Usage: sendUDP.pl <ip> <port> <data>\n";
        exit 0;
}

$| = 1;

my ($socket,$data);
my $peerAddr = $ARGV[0].':'.$ARGV[1];
$socket = new IO::Socket::INET (
PeerAddr   => $peerAddr,
Proto        => 'udp'
) or die "ERROR in Socket Creation : $!\n";

$data = $ARGV[2];
$socket->send($data);
print "Data send to socket : $data\n ";

$socket->close();
