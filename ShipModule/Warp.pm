#!/usr/bin/perl
#
#
#
package ShipModule::Warp;
use parent ShipModule;

sub active {
	my $self = shift;
	my $ship = shift;
	my $key  = shift;

	my $x = 0;
	my $y = 0;

	if ($key eq 'W'){ $y = -1.5; }
	if ($key eq 'S'){ $y = 1.5; }
	if ($key eq 'A'){ $x = -1.5; }
	if ($key eq 'D'){ $x = 1.5; }

	if ($ship->{currentPower} < $ship->{speed} || time() - $ship->{lastHyperdrive} < 15){
		return 0;
	}
	$ship->lightShip(1);
	$self->{'warp'} = {
		'time' => time() + 0.5,
		'x'    => $ship->{x} + ($ship->{speed} * $x * 2),
		'y'    => $ship->{y} + ($ship->{speed} * $y * 2 * $ship->{'aspectRatio'})
	};
	$ship->{currentPower} -= $ship->{speed};
	$ship->{lastHyperdrive} = time();

	return 1;
}

sub power {
	my $self = shift;
	my $ship = shift;
	if (!defined($self->{'warp'})){ return 0; }
	if ($self->{'warp'}->{'time'} < time()){
		$ship->{'x'} = $self->{'warp'}->{'x'};	
		$ship->{'y'} = $self->{'warp'}->{'y'};	
		delete $self->{'warp'};
	}
}

sub getKeys {
	return ('S', 'A', 'D', 'W');
}

sub name {
	return 'Warp';
}

1;
