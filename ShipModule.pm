#!/usr/bin/perl
#
#
#
package ShipModule;
use strict; use warnings;
use Module::Pluggable search_path => [ 'ShipModule' ], require => 1;

sub new {
	my $class = shift;

	my $self = {};
	bless( $self, $class );

	if ($self->_init(@_)){
		return $self;
	} else {
		return undef;
	}
}

sub _init {
	my $self = shift;

	$self->{active} = 0;
	$self->{powerPassive} = 0;
	$self->{lastTick} = time();
	return 1;
}

sub getCost {
	return 0;
}

sub getDescription {
	return "Description goes here";
}

sub getName {
	return "Name goes here";
}

sub power {
	my $self = shift;
	my $ship = shift;

	if ($self->{active}){
		return ($self->_hasPower($ship) ? $self->{powerPassive} : 0);
	}
	return 0;
}

sub _hasPower {
	my $self = shift;
	my $ship = shift;
	
	if ($self->{powerPassive} > 0){ return 1; }
	return ($ship->{currentPower} > $self->{powerPassive}); 
}

sub _setTick {
	my $self = shift;
	my $time = time();
	$self->{timeMod} = $time - $self->{lastTick};
	$self->{lastTick} = $time;
}

sub tick {
	return undef;
}

sub getKeys {
	return ();
}

sub active {
	return undef;
}

1;
