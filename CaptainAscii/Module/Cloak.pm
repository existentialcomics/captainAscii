#!/usr/bin/perl
use strict; use warnings;
package CaptainAscii::Module::Cloak;
use parent 'CaptainAscii::Module';

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
