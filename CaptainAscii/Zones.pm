#!/usr/bin/perl
use strict; use warnings;
package CaptainAscii::Zones;
#use CaptainAscii::Factions;

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
	my $options = shift;

	$self->{nodes} = [];
	$self->{offsetx} = (defined($options->{x}) ? $options->{x} : 0);
	$self->{offsety} = (defined($options->{y}) ? $options->{y} : 0);

	$self->_createNode(0, 0, $self->getRandomSize());

    return 1;
}

sub setSpawnRates {
	my $self = shift;
	$self->{primaryFaction} = $self->getRandomFaction();
	

}

sub getRandomFaction {
	return 'communist';
}

sub getRandomSize {
	return rand(100) + 100;
}

sub _createNode {
	my $self = shift;
	my ($x, $y, $size) = @_;
	push $self->{nodes}, { 'x' => $x, 'y' => $y, size => $size };
}

sub inZone {
	my $self = shift;
	my ($x, $y) = @_;
	$x += $self->{offsetx};
	$y += $self->{offsety};
	foreach my $node (@{$self->{nodes}}){
		if (sqrt(($x ** 2) + ($y ** 2)) < $node->{size}){
			return 1;
		}
	}
	return 0;
}
1;
