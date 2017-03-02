#!/usr/bin/perl

package ShipModule::Radar;
use parent ShipModule;

sub _init {
	my $self = shift;

	$self->SUPER::_init();
	#$self->{powerPassive} = 4;
	$self->{powerActive} = 5;
	$self->{status} = 'radar';
	return 1;
}

sub getKeys {
	return ('r');
}

sub name {
	return  '[O] Radar';
}

1;
