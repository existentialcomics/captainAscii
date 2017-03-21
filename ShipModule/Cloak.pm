#!/usr/bin/perl

package ShipModule::Cloak;
use parent 'ShipModule';

sub _init {
	my $self = shift;

	$self->SUPER::_init();
	$self->{powerActive} = 5;
	$self->{powerPerPart} = 1;
	$self->{status} = 'cloaked';
	return 1;
}

sub getKeys {
	return ('c');
}

sub name {
	return 'Cloaking';
}

sub getDisplay {
    return '[c]'   
}

1;
