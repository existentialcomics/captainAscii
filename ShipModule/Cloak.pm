#!/usr/bin/perl

package ShipModule::Cloak;
use parent ShipModule;

sub _init {
	my $self = shift;

	$self->SUPER::_init();
	$self->{powerActive} = 5;
	$self->{powerPerPart} = 1;
	return 1;
}

sub active {
	my $self = shift;
	my $ship = shift;
	return $self->_statusActive($ship, 'cloaked');
}

sub tick {
	my $self = shift;
	my $ship = shift;
	$self->_setTick();
	$self->_statusTick($ship, 'cloaked');
}

sub getKeys {
	return ('c');
}

sub name {
	return 'Cloaking';
}

1;
