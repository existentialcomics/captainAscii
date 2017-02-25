#!/usr/bin/perl

package ShipModule::Heal;
use parent ShipModule;

sub _init {
	my $self = shift;

	$self->SUPER::_init();
	$self->{activeActive} = 40;
	return 1;
}

sub tick {
	my $self = shift;
	my $ship = shift;
	$self->_setTick();
	$self->_statusTick($ship, 'heal');
	return undef;
}

sub getKeys {
	return ('h');
}

sub name {
	return 'Heal';
}

1;
