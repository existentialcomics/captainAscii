#!/usr/bin/perl
use strict; use warnings;
package CaptainAscii::Module::AutoAim;
use parent 'CaptainAscii::Module';

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
