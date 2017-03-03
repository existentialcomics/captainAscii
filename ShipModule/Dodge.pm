#!/usr/bin/perl

package ShipModule::Dodge;
use parent ShipModule;

sub _init {
	my $self = shift;

	$self->SUPER::_init();
	$self->{powerActive} = 3;
	$self->{powerPerPart} = 1;
	$self->{status} = 'dodge';
	return 1;
}

sub getKeys {
	return ('g');
}

sub name {
	return 'Dodge';
}

sub getDisplay {
    return '[⚔]'
}

1;
