#!/usr/bin/perl
#
#
#
package ShipModule::Warp;
use parent ShipModule;

my $warpTimeDelay = 1.7;      # seconds
my $lightLength   = 2.5;      # seconds
my $warpDistanceFactor = 1.5; # multiplied by ship speed
my $warpDistance = 12;        # minimum distance

sub active {
	my $self = shift;
	my $ship = shift;
	my $key  = shift;

	my $x = 0;
	my $y = 0;

	print "key: $key\n";
	if ($key eq 'W'){ $y = -1; }
	if ($key eq 'S'){ $y = 1; }
	if ($key eq 'A'){ $x = -1; }
	if ($key eq 'D'){ $x = 1; }

	#if ($ship->{currentPower} < $ship->{speed} || time() - $ship->{lastHyperdrive} < 15){
	if ($ship->{currentPower} < $self->_powerNeccesary($ship)){
		my $return = {
			'msgType' => 'shipstatus',
			'msg' => {
				'ship_id' => $ship->{id},
				'light'   => -0.2
			}
		};
		return $return;
	}
	$ship->{'warp'} = {
		'time' => time() + $warpTimeDelay,
		'x'    => $ship->{x} + ( ( $ship->{speed} * $x * $warpDistanceFactor ) + ($x * $warpDistance) ),
		'y'    => $ship->{y} + ( ( ( $ship->{speed} * $y * $warpDistanceFactor) + ($y * $warpDistance)) * $ship->{'aspectRatio'})
	};
	$ship->{currentPower} -= $self->_powerNeccesary($ship);
	$ship->{lastHyperdrive} = time();

	my $return = {
		'msgType' => 'shipstatus',
		'msg' => {
			'ship_id' => $ship->{id},
			'light'   => $lightLength
		}
	};
	return $return;
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
