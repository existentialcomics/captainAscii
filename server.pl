#!/usr/bin/perl
#
use SpaceServer;

my $socket = shift;
$socket = (defined($socket) ? $socket : '/tmp/captainAscii.sock');

if (-e $socket){
	unlink $socket;
}

my $server = SpaceServer->new($socket);

$server->loop();
