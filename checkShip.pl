#!/usr/bin/perl
use Data::Dumper;
use SpaceShip;
use Term::ANSIColor 4.00 qw(RESET color :constants256);


my $ship_file1 = shift;
open (my $fh1, "<", $ship_file1) or die "failed to open $ship_file1\n";
my $ship_str1 = "";
while (<$fh1>){
	$ship_str1 .= $_;
}
close $fh1;

print "---------------------" . " ship input" . "---------------------" . "\n\n";
print $ship_str1;
print "\n---------------------" . " ship output" . "--------------------" . "\n\n";

my $ship = SpaceShip->new($ship_str1, 5, 5, 1, 1);
my @display;
foreach my $x ($ship->{bottommost} .. $ship->{topmost}){
	foreach my $y ($ship->{leftmost} .. $ship->{rightmost}){
		my $chr = ' ';
		#print "\nx: $x, y: $y\n";
		foreach my $part (@{$ship->{ship}}){
			#print "  c $part->{chr} x: $part->{x}, y: $part->{y}\n";
			if ($part->{x} == $y && $part->{y} == $x){
				#print "matched \n";
				$chr = color('RGB033') . $part->{chr} . color('reset');
				last;
			}
		}
		print "$chr";
	}
	print "\n";
}

print "\n-----------------------------------------------" . "\n\n";

print 'cost:    $'.$ship->{cost}."\n";
print 'powergen: '.$ship->{powergen}."\n";
print 'power:   '.$ship->{power}."\n";
print 'thrust:  '.$ship->{thrust}."\n";
print 'speed:   '.$ship->{speed}."\n";
print 'weight:  '.$ship->{weight}."\n";
print 'health:  '.$ship->{health}."\n";
print 'shield:  '.$ship->{shield}."\n";

#print "left:" . $ship->{leftmost} . "\n";
#print "right:" . $ship->{rightmost} . "\n";
#print "top:" . $ship->{topmost} . "\n";
#print "bottom:" . $ship->{bottommost} . "\n";



#print Dumper($ship->{ship});
