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
    $self->{id} = (defined($options->{id}) ? $options->{id} : int(rand(100000)));

    $self->{nodeCount} = 0;
    $self->{nodeSpawns} = {};

    $self->{power} = (defined($options->{power}) ? $options->{power} : int((rand() ** 3) * 100000)  + 400);
    $self->{powerDiminish} = $self->{power};
	$self->{primaryFaction} = (defined($options->{faction}) ? $options->{faction} : $self->getRandomFaction());

	$self->_createNode(0, 0, $self->getRandomSize());

    return 1;
}

sub setSpawnRates {
	my $self = shift;
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
    $self->{nodeCount}++;
	push $self->{nodes}, {
        'x' => $x,
        'y' => $y,
        'size' => $size,
        'id' => $self->{nodeCount}
    };
    $self->{powerDiminish} *= 0.8;
}

sub inZone {
	my $self = shift;
	my ($x, $y) = @_;
	$x += $self->{offsetx};
	$y += $self->{offsety};
	foreach my $node (@{$self->{nodes}}){
        print "$x, $y, vs $node->{size}";
		if (sqrt(($x ** 2) + ($y ** 2)) < $node->{size}){
			return 1;
		}
	}
	return 0;
}
1;
