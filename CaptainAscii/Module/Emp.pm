#!/usr/bin/perl
use strict; use warnings;
package CaptainAscii::Module::Emp;
use parent 'CaptainAscii::Module';

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
