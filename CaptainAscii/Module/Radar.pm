#!/usr/bin/perl
use strict; use warnings;
package CaptainAscii::Module::Radar;
use parent 'CaptainAscii::Module';

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
	return  'Radar';
}

sub getDisplay {
    return '[።]';
}

1;
