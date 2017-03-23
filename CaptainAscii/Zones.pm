#!/usr/bin/perl
use strict; use warnings;
package CaptainAscii::Zones;
use CaptainAscii::Factions;

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
    $self->{nodeSpawns} = [];

    $self->{power} = int(defined($options->{power}) ? $options->{power} : int((rand() ** 3) * 100000)  + 400);
    $self->{powerDiminish} = $self->{power};
	$self->{primaryFaction} = (defined($options->{faction}) ? $options->{faction} : CaptainAscii::Factions::getRandomFaction());
	$self->{secondaryFaction} = (defined($options->{secondfaction}) ? $options->{secondfaction} : CaptainAscii::Factions::getRandomFaction());

	$self->_createNode(0, 0, $self->getRandomSize());
	$self->_setSpawnRates();

	$self->{name} = $self->{primaryFaction} . '.' . $self->{secondaryFaction} . '.' . $self->{power} . ":" . int($self->{offsetx}) . '.' . int($self->{offsety});

    return 1;
}

sub _setSpawnRates {
	my $self = shift;
	my $ownSpawns = 5;
	my $secondSpawns = 3;
	if ($self->{power} > 10000){ $ownSpawns += 5; $secondSpawns += 3; }
	if ($self->{power} > 25000){ $ownSpawns += 5; $secondSpawns += 3; }
	if ($self->{power} > 50000){ $ownSpawns += 5; $secondSpawns += 3; }
	if ($self->{power} > 75000){ $ownSpawns += 5; $secondSpawns += 3; }
	if ($self->{power} > 100000){ $ownSpawns += 5; $secondSpawns += 3; }
	foreach (0 .. $ownSpawns){
		push(@{$self->{nodeSpawns}}, {
			'faction' => $self->{primaryFaction},
			'power'   => $self->{power} * rand()
			});
	}
	foreach (0 .. $secondSpawns){
		push(@{$self->{nodeSpawns}}, {
			'faction' => $self->{secondaryFaction},
			'power'   => $self->{power} * rand()
			});
	}
	foreach (0 .. 7){
		push(@{$self->{nodeSpawns}}, {
			'faction' => CaptainAscii::Factions::getRandomFaction(), 
			'power'   => $self->{power} * rand()
			});
	}
	$self->{spawnRate} = 10;
}

sub getRandomSize {
	return rand(100) + 100;
}

sub getSpawns {
	my $self = shift;
	return @{$self->{nodeSpawns}};
}

sub getSpawnRate {
	my $self = shift;
	return $self->{spawnRate};
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

sub getName {
	my $self = shift;
	return $self->{name};
}

sub getLeft {
    my $self = shift;
    return $self->{offsetx} - 100;
}
sub getRight {
    my $self = shift;
    return $self->{offsetx} + 100;
}
sub getTop {
    my $self = shift;
    return $self->{offsety} - 100;
}
sub getBottom {
    my $self = shift;
    return $self->{offsety} + 100;
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
