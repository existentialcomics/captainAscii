#!/usr/bin/perl
#
#
#
package ShipModule::Cloak;
use parent ShipModule;

sub active {
	my $self = shift;
	my $ship = shift;
	if ($ship->{cloaked}){
		$ship->{cloaked} = 0;
		$self->{active}  = 1
	} else {
		$ship->{cloaked} = 1;
		$self->{active}  = 0
	}
}

sub power {
	my $self = shift;
	my $ship = shift;

	if ($self->{active} == 0){
		return 0;
	}
	if ($ship->{currentPower} < ($ship->getParts() / 3)){
		$ship->{cloaked} = 0;
		return 1;
	}
	$ship->{cloaked} = 1;
	$ship->{currentPowerGen} -= ($ship->getParts() / 3);
}

sub getKeys {
	return ('c');
}

sub name {
	return 'Cloaking';
}

1;
