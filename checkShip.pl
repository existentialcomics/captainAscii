#!/usr/bin/perl
use Data::Dumper;
use SpaceShip;

my $ship_file1 = shift;
open (my $fh1, "<", $ship_file1) or die "failed to open $ship_file1\n";
my $ship_str1 = "";
while (<$fh1>){
	$ship_str1 .= $_;
}
close $fh1;

print "---------------------" . " ship " . "---------------------" . "\n\n";
print $ship_str1;
print "\n---------------------" . " ship " . "---------------------" . "\n\n";

my $ship = SpaceShip->new($ship_str1, 5, 5, 1, 1);


print 'cost:    $'.$ship->{cost}."\n";
print 'powergen: '.$ship->{powergen}."\n";
print 'power:   '.$ship->{power}."\n";
print 'thrust:  '.$ship->{thrust}."\n";
print 'speed:   '.$ship->{speed}."\n";
print 'weight:  '.$ship->{weight}."\n";
print 'health:  '.$ship->{health}."\n";
print 'shield:  '.$ship->{shield}."\n";

#print Dumper($ship);
