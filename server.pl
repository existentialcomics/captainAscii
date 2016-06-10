#!/usr/bin/perl
#
use SpaceServer;

my $socket = shift;
$socket = (defined($socket) ? $socket : '/tmp/captainAscii.sock');

if (-e $socket){
	unlink $socket;
}

$SIG{PIPE} = 'IGNORE';
#$SIG{PIPE} = \&catchSigPipe;
#sub catchSigPipe {
	#print "sig pipe error!\n";
#}

my $server = SpaceServer->new($socket);

$server->loop();

