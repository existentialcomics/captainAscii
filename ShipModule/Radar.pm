#!/usr/bin/perl

package ShipModule::Radar;
use parent ShipModule;

sub _init {
	my $self = shift;

	$self->SUPER::_init();
	#$self->{powerPassive} = 4;
	$self->{powerActive} = 5;
	return 1;
}

sub active {
	my $self = shift;
	my $ship = shift;
	return $self->_statusActive($ship, 'radar');
}

sub tick {
	my $self = shift;
	my $ship = shift;
	$self->_setTick();
	$self->_statusTick($ship, 'radar');
}

sub getKeys {
	return ('r');
}

sub name {
	return 'Radar';
}

1;
