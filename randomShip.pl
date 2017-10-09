#!/usr/bin/perl
#
use strict; use warnings;
use CaptainAscii::Ship;
use Data::Dumper;
use Term::ANSIColor 4.00 qw(RESET color :constants256);

my $ship = CaptainAscii::Ship->new('X', 0, 0, 1);
my $cash = shift;
my $type = shift;

$ship->becomeAi();
if (defined($type)){
	$ship->{faction} = $type;
}
$ship->randomBuild($cash, $type);

my $display = $ship->getDisplayArray();

foreach my $row (@$display){
	if (!defined($row)){ next; }
	foreach my $chr(@$row){
		print (defined($chr) ? $chr : ' ');
	}
	print "\n";
}
#print Dumper($display);
