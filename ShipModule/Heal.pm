#!/usr/bin/perl

package ShipModule::Heal;
use parent ShipModule;

sub _init {
	my $self = shift;

	$self->SUPER::_init();
	$self->{powerActive} = 10;
	$self->{powerPerPart} = 4;
	$self->{status} = 'heal';
	return 1;
}

sub getKeys {
	return ('h');
}

sub name {
	return 'Heal';
}

sub getDisplay {
    return '[+]';
}

1;
