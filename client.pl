#!/usr/bin/perl
#
use SpaceClient;

my $ship = shift;
my $socket = '/tmp/captainAscii.sock';
my $color = shift;

my @allowedColors = qw(red  green  yellow  blue  magenta  cyan  white);

if (!$ship){
	print "enter ship file\n";
	exit;
}

if ($color){
	if (! grep { $_ eq $color } @allowedColors){
		print "color $color not allowed\n";
		print "allowed colors: " . (join ", ", @allowedColors) . "\n";
		exit;
	}
}

if (! -f $ship){
	print "ship file $ship not a file\n";
	exit;
}

my $client = SpaceClient->new($ship, $socket, $color);


