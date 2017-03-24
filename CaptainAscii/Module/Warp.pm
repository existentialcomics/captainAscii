#!/usr/bin/perl
use strict; use warnings;
package CaptainAscii::Module::Warp;
use parent 'CaptainAscii::Module';

my $warpTimeDelay = 1.7;      # seconds
my $lightLength   = 2.5;      # seconds
my $warpDistanceFactor = 1.5; # multiplied by ship speed
my $warpDistance = 15;        # minimum distance

sub command {
	my $self = shift;
	my $arg  = shift;
	my $ship = shift;
	my ($wX, $wY) = split(',', $arg);
	if ($wX =~ m/^\d+$/ && $wY =~ m/^\d+$/){
		foreach my $module ($ship->getModules()){
			if ($module->name() eq 'Warp'){
				$ship->addServerInfoMsg("Warping to $wX, $wY");
				$module->active($ship, undef, $wX, $wY);
			}
		}
	} else {
		$ship->addServerInfoMsg("Invalid coordinates");
	}
}

sub active {
	my $self = shift;
	my $ship = shift;
	my $key  = shift;
	my $warpXArg = shift;
	my $warpYArg = shift;

	my $x = 0;
	my $y = 0;

	if (defined($key)){
		if ($key eq 'W'){ $y = -1; }
		if ($key eq 'S'){ $y = 1; }
		if ($key eq 'A'){ $x = -1; }
		if ($key eq 'D'){ $x = 1; }
	}

	if ($ship->{currentPower} < $self->_powerNeccesary($ship)){
		$ship->setStatus('light' => -0.2);
		return 0;
	}

	my $warpToX = ($warpXArg ? $warpXArg : $ship->{x} + ( ( $ship->{speed} * $x * $warpDistanceFactor ) + ($x * $warpDistance) ));
	my $warpToY = ($warpYArg ? $warpYArg : $ship->{y} + ( ( $ship->{speed} * $y * $warpDistanceFactor ) + ($y * $warpDistance) ));
	$ship->{'warp'} = {
		'time' => time() + $warpTimeDelay,
		'x'    => $warpToX,
		'y'    => $warpToY
	};
	$ship->{currentPower} -= $self->_powerNeccesary($ship);
	$ship->{lastHyperdrive} = time();

	$ship->setStatus('light' => $lightLength);
	return 1;
}

sub _powerNeccesary{
	my $self = shift;
	my $ship = shift;
	return ($ship->{weight} * 0.8);
}

sub tick {
	my $self = shift;
	my $ship = shift;
	if (!defined($ship->{'warp'})){ return 0; }
	if ($ship->{'warp'}->{'time'} < time()){
		$ship->{'x'} = $ship->{'warp'}->{'x'};	
		$ship->{'y'} = $ship->{'warp'}->{'y'};	
		delete $ship->{'warp'};
	}
}

sub getKeys {
	return ('S', 'A', 'D', 'W');
}

sub name {
	return 'Warp';
}

sub getDisplay {
    return '[▒]';
}

1;
