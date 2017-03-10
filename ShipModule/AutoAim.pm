#!/usr/bin/perl

package ShipModule::Radar;
use parent ShipModule;

sub _init {
	my $self = shift;

	$self->SUPER::_init();
	#$self->{powerPassive} = 4;
	$self->{powerActive} = 10;
	$self->{status} = 'autoaim';
	return 1;
}

sub getKeys {
	return (',');
}

sub name {
	return  'Auto Aim';
}

sub getDisplay {
    return '[⊕]';
}

1;
