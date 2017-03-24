#!/usr/bin/perl
#
#
#
package CaptainAscii::Module;
use strict; use warnings;
use Module::Pluggable search_path => [ 'CaptainAscii::Module' ], require => 1;

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
	$self->{enabled} = 0;
	$self->{powerPassive}  = 0;
	$self->{powerActive}   = 0;
	$self->{powerPerPart}  = 0;
	$self->{powerPerSpeed} = 0;
	$self->{lastTick} = time();
    $self->{tickRate} = 0.1;    # time in seconds to tick
	return 1;
}

sub enable {
	my $self = shift;
	$self->{enabled} = 1;
}

sub disable {
	my $self = shift;
	$self->{enabled} = 0;
}

sub getCost {
	return 0;
}

sub getDescription {
	return "Description goes here";
}

sub name {
	return "Name goes here";
}

sub getDisplay {
    return "[M]";
}

sub getFullDisplay {
    my $self = shift;
    return $self->getDisplay() . " " . $self->name();
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

sub setActive {
	my $self = shift;
	my $active = shift;
	$self->{active} = $active;
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
    return $self->{timeMod};
}

sub _getTimeMod {
	my $self = shift;
    return $self->{timeMod};
}

sub _shouldTick {
    my $self = shift;
    return 1;
    return ((time() - $self->{lastTick}) > $self->{tickRate});
}

sub _statusActive {
	my $self = shift;
	my ($ship, $statusValue) = @_;
	my $statusName = $self->{status};
	
	my $statusSet = 0;
	if ($statusValue eq 'on'){ $statusSet = 1; }
	elsif ($statusValue eq 'off'){ $statusSet = 0; }
	elsif ($statusValue eq 'toggle'){
		$statusSet = ($self->{active} == 1 ? 0 : 1);
	} else { $statusSet = $statusValue; }


	if ($statusSet == 0){
		$ship->setStatus($statusName, 0);
		$ship->setStatus('m_active', { name => $self->name(), active => 0 });
		$self->{active}  = 0;
		$ship->addServerInfoMsg($self->name() . ' set to off.');
	} else {
		if ($self->_hasPower($ship)){
			$ship->setStatus($statusName, 1);
			$ship->addServerInfoMsg($self->name() . ' set to on.');
		} else {
			$ship->setStatus($statusName, 0);
			$ship->addServerInfoMsg($self->name() . ' set to on (WARNING ' . $self->_powerRequired($ship) . ' power required).');
		}
		$ship->setStatus('m_active', { name => $self->name(), active => 1 });
		$self->{active}  = 1;
	}
	return undef;
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

sub getColor {
    my $self = shift;
    my $ship = shift;
    if (!defined($self->{status})){ return "white"; }
    if (!$self->isActive()       ){ return "grey10" }
    if ($self->_hasPower($ship)){
        return 'green';
    } else {
        return 'red';
    }
}

sub commandName {
	my $self = shift;
	my $cmd = $self->name();
	$cmd =~ s/ing$//;
	$cmd =~ s/ //g;
	return lc($cmd);
}

sub command {
	my $self = shift;
	my $arg  = shift;
	my $ship = shift;
	if (defined($self->{status})){
		if ($arg =~ m/^on|off|toggle$/){
			return $self->_statusActive($ship, $arg);
		} else {
			return 0;
		}
	}

}

sub tick {
	my $self = shift;
	my $ship = shift;
    if (! $self->_shouldTick() ){ return 0; }
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
		return $self->_statusActive($ship, 'toggle');
	}
	return 1;
}

1;
