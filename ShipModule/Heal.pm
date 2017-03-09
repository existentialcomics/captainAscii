#!/usr/bin/perl

package ShipModule::Heal;
use parent ShipModule;
use strict; use warnings;

sub _init {
	my $self = shift;

	$self->SUPER::_init();
    $self->{powerActive} = 10;
    $self->{powerPerPart} = 4;
	$self->{status} = 'heal';
	$self->{healRate} = 0.4;
	return 1;
}

sub getKeys {
	return ('h');
}

sub name {
	return 'Heal';
}

sub getDisplay {
    return '[+]';
}

sub tick {
    my $self = shift;
    my $ship = shift;
    $self->SUPER::tick($ship);
    if (! $self->isActive()   ){ return 0; }
    if (! $self->_shouldTick() ){ return 0; }
    foreach my $part ($ship->getParts()){
        if ($part->{health} < $part->{part}->{health}){
            $part->{health} += ($self->{healRate} * $self->_getTimeMod());
            print "$part->{health} vs $part->{part}->{health}\n";
            if ($part->{health} > $part->{part}->{health}){
                $part->{health} = $part->{part}->{health};
            }
            $ship->addServerMsg('dam', { 
                'ship_id' => $ship->{id},
                'id'      => $part->{id},
                'health'  => $part->{health}
                }
            )
        } 
    }
}

1;
