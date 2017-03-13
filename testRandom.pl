#!/usr/bin/perl
#
use strict; use warnings;
use SpaceShip;
use Data::Dumper;
use Term::ANSIColor 4.00 qw(RESET color :constants256);

my $ship = SpaceShip->new('X');

$ship->randomBuild(5000);

my $display = $ship->getDisplayArray();

foreach my $row (@$display){
	if (!defined($row)){ next; }
	foreach my $chr(@$row){
		print (defined($chr) ? $chr : ' ');
	}
	print "\n";
}
#print Dumper($display);

print color('reset');
print "\n-----------------------------------------------" . "\n\n";
