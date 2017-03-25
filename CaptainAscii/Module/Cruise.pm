#!/usr/bin/perl
use strict; use warnings;
package CaptainAscii::Module::Cruise;
use parent 'CaptainAscii::Module';

sub _init {
	my $self = shift;

	$self->SUPER::_init();
	#$self->{powerPassive} = 4;
	$self->{powerActive} = 5;
	$self->{status} = 'cruise';
	return 1;
}

sub getKeys {
	return ('f');
}

sub name {
	return  'Cruise';
}

sub getDisplay {
    return '[c]';
}

1;
