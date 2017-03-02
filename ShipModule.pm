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
	$self->{powerPassive}  = 0;
	$self->{powerActive}   = 0;
	$self->{powerPerPart}  = 0;
	$self->{powerPerSpeed} = 0;
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

sub _powerRequired {
	my $self = shift;
	my $ship = shift;

	my $power = $self->{powerPassive};
	$power += ($self->isActive() ? $self->{powerActive} : 0);
	$power += ($self->isActive() ? $self->{powerPerPart} * $ship->getParts() : 0);
	$power += ($self->isActive() ? $self->{powerPerSpeed} * $ship->{speed} : 0);
	
	return $power;
}

sub power {
	my $self = shift;
	my $ship = shift;

	if ($self->{active}){
		return ($self->_hasPower($ship) ? -$self->_powerRequired($ship) : -$self->{powerPassive});
	}
	return -$self->{powerPassive};
}

sub isActive {
	my $self = shift;
	return $self->{active};
}

sub _hasPower {
	my $self = shift;
	my $ship = shift;
	
	return ($ship->{currentPower} > $self->_powerRequired($ship)); 
}

sub _setTick {
	my $self = shift;
	my $time = time();
	$self->{timeMod} = $time - $self->{lastTick};
	$self->{lastTick} = $time;
}

sub _statusActive {
	my $self = shift;
	my $ship = shift;
	my $status = shift;
	if ($self->{active} == 1){
		$ship->{$status} = 0;
		$self->{active}  = 0;
	} else {
		$ship->{$status} = ($self->_hasPower($ship) ? 1 : 0);
		$self->{active}  = 1;
	}
	my $return = {
		'msgType' => 'shipstatus',
		'msg' => {
			'ship_id' => $ship->{id},
			$status => $ship->{$status}
		}
	};
	return $return;
}

sub _statusTick {
	my $self = shift;
	my $ship = shift;
	my $status = shift;
	if (!$self->{active}){ return 0; }
	if (!$self->_hasPower($ship)){
		$ship->setStatus($status, 0);
		return 1;
	} else {
		$ship->setStatus($status, 1);
		return 0;
	}
	
}

sub tick {
	my $self = shift;
	my $ship = shift;
	if (defined($self->{status})){
		$self->_setTick();
		return $self->_statusTick($ship, $self->{status});
	}
	return 1;
}

sub getKeys {
	return ();
}

sub active {
	my $self = shift;
	my $ship = shift;
	if (defined($self->{status})){
		return $self->_statusActive($ship, $self->{status});
	}
	return 1;
}

1;
