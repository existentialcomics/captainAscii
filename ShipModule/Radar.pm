#!/usr/bin/perl
#
#
#
package ShipModule::Radar;
use parent ShipModule;

sub active {
	my $self = shift;
	my $ship = shift;
	if ($ship->{radar}){
		$ship->{radar} = 0;
		$self->{active}  = 1
	} else {
		$ship->{radar} = 1;
		$self->{active}  = 0
	}
}

sub power {
	my $self = shift;
	my $ship = shift;

	if ($self->{active} == 0){
		return 0;
	}
	if ($ship->{currentPower} < 2){
		$ship->{radar} = 0;
		return 1;
	}
	$ship->{radar} = 1;
	$ship->{currentPowerGen} -= 2;
}

sub getKeys {
	return ('r');
}

sub name {
	return 'Radar';
}

1;
