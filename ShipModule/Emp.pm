#!/usr/bin/perl

package ShipModule::Emp;
use parent ShipModule;

sub _init {
	my $self = shift;

	$self->SUPER::_init();
	$self->{powerActive} = 3;
	$self->{status} = 'emp';
	return 1;
}

sub getKeys {
	return ('p');
}

sub name {
	return 'Emp';
}

sub getDisplay {
    return '[⁂]'   
}

1;
