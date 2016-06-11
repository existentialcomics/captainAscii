#!/usr/bin/perl
#
use SpaceClient;

my $ship = shift;
my $socket = '/tmp/captainAscii.sock';
my $name = shift;

if (!$ship){
	print "enter ship file\n";
	exit;
}

if (! -f $ship){
	print "ship file $ship not a file\n";
	exit;
}

my $client = SpaceClient->new($ship, $socket);


