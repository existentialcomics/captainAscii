#!/usr/bin/perl
#
#
#
use strict; use warnings;
package SpaceShip;
use Term::ANSIColor 4.00 qw(RESET color :constants256);
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval nanosleep
		      clock_gettime clock_getres clock_nanosleep clock time);
use Data::Dumper;

my %parts = (
	'X' => {
		cost   => '0',
		type   => 'command',
		power  => 50,
		powergen => 5,
		weight => 10,
		thrust  => 100,
		shoots => "|",
		damage => 1.5,
		bulletspeed => 17,
		poweruse => 1,
		rate   => 0.9,
		lastShot => 0,
		'chr'  => 'X',
		health => 15
	},
	'/' => {
		cost   => '50',
		type   => 'thrust',
		poweruse => -0.45,
		weight => 1,
		thrust  => 90,
		'chr'  => '/',
		health => 3
	},
	'\\' => {
		cost   => '50',
		type   => 'thrust',
		weight => 1,
		thrust  => 90,
		'chr'  => '\\',
		health => 3
	},
	'^' => {
		cost   => '30',
		type   => 'thrust',
		weight => 1,
		thrust  => 60,
		'chr'  => '^',
		health => 2
	},
	'v' => {
		cost   => '30',
		'chr'  => 'v',
		type   => 'thrust',
		weight => 1,
		thrust  => 60,
		health => 2
	},
	'(' => {
		cost   => '70',
		'chr'  => '(',
		type   => 'thrust',
		weight => 2,
		thrust  => 100,
		health => 6
	},
	')' => {
		cost   => '70',
		'chr'  => ')',
		type   => 'thrust',
		weight => 2,
		thrust  => 100,
		health => 6
	},
	'O' => {
		cost   => '150',
		'chr' => 'O',
		type   => 'power',
		power  => 30,
		powergen => 3,
		weight => 5,
		health => 5
	},
	'0' => {
		cost   => '400',
		'chr'  => color('ON_GREY5 RGB530 BOLD') . '0' . color('ON_RGB000 RESET'),
		type   => 'power',
		power  => 50,
		powergen => 6,
		weight => 5,
		health => 5
	},
	'-' => {
		cost   => '10',
		type   => 'plate',
		weight => 2,
		'chr'  => color('white') . '—',
		health => 10
	},
	'[' => {
		cost   => '10',
		type   => 'plate',
		weight => 2,
		'chr'  => color('white') . '[',
		health => 10
	},
	']' => {
		cost   => '10',
		type   => 'plate',
		weight => 2,
		'chr'  => color('white') . ']',
		health => 10
	},
	'|' => {
		cost   => '100',
		type   => 'gun',
		weight => 2,
		poweruse => -1,
		damage => 0.7,
		shoots => color('RGB440') . "'" . color('white'),
		bulletspeed => 22,
		rate   => 0.3,
		'chr'  => '|',
		health => 5
	},
	'I' => {
		chr    => color('ON_GREY5 RGB530 BOLD') . "|" . color('reset'),
		cost   => '500',
		type   => 'gun',
		weight => 4,
		poweruse => -4,
		damage => 4,
		shoots => color('RGB551 bold') . "|" . color('reset'),
		bulletspeed => 22,
		rate   => 0.3,
		health => 10
	},
	'H' => {
		cost   => '125',
		'chr'  => 'H',
		type   => 'gun',
		weight => 2,
		poweruse => -1.5,
		damage => 1,
		shoots => color('RGB225') . ":" . color('white'),
		bulletspeed => 14,
		rate   => 0.6,
		health => 5
	},
	'U' => {
		cost   => '150',
		'chr'  => 'U',
		type   => 'gun',
		weight => 2,
		shipMomentum => 0.5,
		damage => 2,
		poweruse => -2,
		shoots => color('RGB522') . "*" . color('white'),
		bulletspeed => 14,
		rate   => 0.8,
		health => 5
	},
	'8' => {
		cost   => '150',
		type   => 'gun',
		poweruse => -3,
		shipMomentum => 1,
		weight => 6,
		damage => 4,
		shoots => "o",
		bulletspeed => 5,
		rate   => 1,
		'chr'  => '8',
		health => 5
	},
	'@' => {
		cost   => '200',
		type   => 'shield',
		powergen => -1,
		poweruse => -1.5,
		weight => 20,
		size => 'medium',
		shield => 5,
		shieldgen => 0.5,
		'chr'  => color('ON_GREY2 WHITE') . '@' . color('ON_RGB000 RESET'),
		health => 1
	},
	'$' => {
		cost   => '600',
		type   => 'shield',
		powergen => -2.5,
		poweruse => -4,
		weight => 40,
		size => 'large',
		shield => 12,
		shieldgen => 1,
		'chr'  => color('ON_GREY5 RGB530 BOLD') . '@' . color('ON_RGB000 RESET'),
		health => 1
	},
);

sub new {
	my $class = shift;

	my $self = {};
	bless( $self, $class );

	$self->_init(@_);
	return $self;
}

sub _init {
	my $self = shift;
	my $shipDesign = shift;
	my $x = shift;
	my $y = shift;
	my $direction = shift;
	my $id = shift;
	my $options = shift;

    $self->{'controls'} = (defined($options->{'controls'}) ? $options->{'controls'} : 'a');
 
	$self->{'x'} = $x;	
	$self->{'y'} = $y;	
	$self->{'direction'} = $direction;
	$self->{'id'} = $id;

	$self->{'moving'}   = 0;
	$self->{'shooting'} = 0;

	$self->{'ship'} = {};

	$self->_loadShip($shipDesign);
	$self->_calculatePower();
	$self->_calculateWeight();
	$self->_calculateThrust();
	$self->_calculateCost();
	$self->_calculateSpeed();
	$self->_calculateShield();
}

sub shoot {
	my $self = shift;
	if (time() - $self->{shooting} > 0.5){ return []; }

	my $time = time();
	my @bullets = ();
	foreach my $part (@{$self->{ship}}){
		if (!defined($part->{'lastShot'})){ $part->{'lastShot'} = $time;}
		if (($part->{'part'}->{'type'} eq 'gun' || $part->{'part'}->{'type'} eq 'command') and abs($time - $part->{lastShot}) > $part->{'part'}->{rate}){
			$part->{'lastShot'} = $time;
			if ($self->{currentPower} < abs($part->{part}->{poweruse})){
				next;
			}
			$self->{currentPower} += $part->{'part'}->{poweruse};
			push @bullets, {
				id => $self->{'id'},
				damage => $part->{part}->{damage},
				y => ($self->{x} + $part->{x}),
				x => ($self->{y} + $part->{y} + $self->{direction}),
				'chr' => $part->{'part'}->{'shoots'},
				dx => $self->{direction} * $part->{'part'}->{'bulletspeed'},
				dy => (defined($part->{'part'}->{'shipMomentum'}) ? $self->{'moving'} * $self->{speed} * $part->{'part'}->{'shipMomentum'} : 0)
			};
		}
	}
	$self->_limitPower();
	return \@bullets;
}

sub _calculateThrust {
	my $self = shift;
	$self->{thrust} = 0;
	foreach my $part (@{ $self->{ship} }){
		if (defined($part->{part}->{thrust})){
			$self->{thrust} += $part->{part}->{thrust};
		}
	}
}

sub _calculateShield {
	my $self = shift;
	$self->{shield} = 0;
	foreach my $part (@{ $self->{ship} }){
		if (defined($part->{part}->{shield})){
			$self->{shield} += $part->{part}->{shield};
		}
	}
}

# when you lose a part
sub _recalculatePower {
	my $self = shift;
	my $current = $self->{currentPower};
	my $max = $self->{power};
	$self->_calculatePower();

	# reset current power
	$self->{currentPower} = $current;

	# subtract power for any lost generators
	if ($max > $self->{power}){
		$self->{currentPower} -= abs($max - $self->{power});
		if ($self->{currentPower} < 0){ $self->{currentPower} = 0 }
	}
}

sub _calculateCost {
	my $self = shift;
	$self->{cost} = 0;
	foreach my $part (@{ $self->{ship} }){
		$self->{cost} += $part->{part}->{cost};
	}
}

sub _calculatePower {
	my $self = shift;
	$self->{power} = 0;
	foreach my $part (@{ $self->{ship} }){
		if (defined($part->{part}->{power})){
			$self->{power} += $part->{part}->{power};
		}
	}
	$self->{powergen} = 0;
	foreach my $part (@{ $self->{ship} }){
		if (defined($part->{part}->{powergen})){
			$self->{powergen} += $part->{part}->{powergen};
		}
	}
	$self->{currentPower}    = $self->{power};
	$self->{currentPowerGen} = $self->{powergen};
}

sub _calculateSpeed {
	my $self = shift;
	$self->{speed} = $self->{thrust} / $self->{weight};
}

sub _calculateWeight {
	my $self = shift;
	$self->{weight} = 0.0;
	foreach my $part (@{ $self->{ship} }){
		$self->{weight} += $part->{part}->{weight};
	}
}

sub _recalculate {
	my $self = shift;
	$self->_recalculatePower();
	$self->_calculateWeight();
	$self->_calculateThrust();
	$self->_calculateSpeed();
	$self->_calculateShield();
	#TODO check for orphaned pieces
}


sub resolveCollision {
	my $self = shift;
	my $bullet = shift;
	if ($bullet->{id} == $self->{id}){ return 0; }
	foreach my $part (@{ $self->{ship} }){
		# x and y got mixed somehow
		my $px = int($part->{y} + $self->{y});
		my $py = int($part->{x} + $self->{x});

		if ($part->{'part'}->{'type'} eq 'shield'){
			if (
				($part->{'shieldHealth'} > 0) &&
				(
				(	($part->{'part'}->{'size'} eq 'medium') &&
					(
					(int($bullet->{x}) == $px - 2 &&
					int($bullet->{y}) >= $py - 1 && 
					int($bullet->{y}) <= $py + 1) ||

					(int($bullet->{x}) == $px - 1 &&
					int($bullet->{y}) >= $py - 3 && 
					int($bullet->{y}) <= $py + 3) ||

					(int($bullet->{x}) == $px + 0 &&
					int($bullet->{y}) >= $py - 4 && 
					int($bullet->{y}) <= $py + 4) ||

					(int($bullet->{x}) == $px + 1 &&
					int($bullet->{y}) >= $py - 3 && 
					int($bullet->{y}) <= $py + 3) || 

					(int($bullet->{x}) == $px + 2 &&
					int($bullet->{y}) >= $py - 1 && 
					int($bullet->{y}) <= $py + 1)
					)
				) ||
				(	($part->{'part'}->{'size'} eq 'large') &&
					(
					(int($bullet->{x}) == $px - 3 &&
					int($bullet->{y}) >= $py - 1 && 
					int($bullet->{y}) <= $py + 1) ||

					(int($bullet->{x}) == $px - 2 &&
					int($bullet->{y}) >= $py - 3 && 
					int($bullet->{y}) <= $py + 3) ||

					(int($bullet->{x}) == $px - 1 &&
					int($bullet->{y}) >= $py - 4 && 
					int($bullet->{y}) <= $py + 4) ||

					(int($bullet->{x}) == $px + 0 &&
					int($bullet->{y}) >= $py - 5 && 
					int($bullet->{y}) <= $py + 5) ||

					(int($bullet->{x}) == $px + 1 &&
					int($bullet->{y}) >= $py - 4 && 
					int($bullet->{y}) <= $py + 4) || 

					(int($bullet->{x}) == $px + 2 &&
					int($bullet->{y}) >= $py - 3 && 
					int($bullet->{y}) <= $py + 3) ||

					(int($bullet->{x}) == $px + 3 &&
					int($bullet->{y}) >= $py - 1 && 
					int($bullet->{y}) <= $py + 1)
					)
				)
				)
				){
					$part->{'hit'} = time();
					# TODO damage
					$part->{'shieldHealth'} -= $bullet->{damage};
					if ($part->{'shieldHealth'} < 0){
						$part->{'shieldHealth'} = 0 - ($part->{'part'}->{'shield'} / 3)
					}
					return 1;
			}
		}
		if (int($bullet->{y}) == $py &&
		    int($bullet->{x}) == $px){
			$part->{'health'} -= $bullet->{damage};
			$part->{'hit'} = time();
			return 1;
		}
	}
	return 0;
}

sub pruneParts {
	my $self = shift;
	my $size = $#{ $self->{ship} };
	$self->{ship} = [ grep { $_->{'health'} > 0 }  @{ $self->{ship} } ];
	if ($#{ $self->{ship} } < $size){
		$self->_recalculate();
	}
}

sub keypress {
	my $self = shift;
	my $chr = shift;
	if ($self->{'controls'} eq 'a'){
		if ($chr eq 'a'){ $self->{moving} = -1; }
		if ($chr eq 'd'){ $self->{moving} = 1;  }
		if ($chr eq 's'){ $self->{moving} = 0;  }
		if ($chr eq 'w'){ $self->{shooting} = time();}
	} else {
		if ($chr eq 'j'){ $self->{moving} = -1; }
		if ($chr eq 'l'){ $self->{moving} = 1;  }
		if ($chr eq 'k'){ $self->{moving} = 0;  }
		if ($chr eq 'i'){ $self->{shooting} = time();}
	}
}

sub power {
	my $self = shift;
	if (!defined($self->{lastPower})){ $self->{lastPower} = time();}
	my $timeMod = time() - $self->{lastPower};

	# if the thrusters are activated
	if ($self->{moving} != 0){
		if (int($self->{currentPower} < 2)){
			$self->{currentPowerGen} = $self->{powergen};
			$self->{moving} = 0;
		} else {
			$self->{currentPowerGen} = $self->{powergen} - sprintf('%.2f', ($self->{thrust} / 100));
		}
	} else {
		$self->{currentPowerGen} = $self->{powergen};
	}

	$self->{shieldHealth} = 0;
	# if shields are regenerating
	foreach my $part (@{ $self->{'ship'} }){
		if ($part->{'part'}->{'type'} eq 'shield'){
			# if you are below 20% power you can't gen shields
			if ($self->{currentPower} / $self->{power} < 0.2){
				$part->{shieldHealth} -= ($part->{'part'}->{shieldgen} * $timeMod);
				# recover the passive part of shieldgen (substract because it is negative)
				$self->{currentPowerGen} -= $part->{'part'}->{powergen};
			} else {
				if ($part->{shieldHealth} < $part->{'part'}->{shield}){
					$self->{currentPowerGen} += $part->{'part'}->{'poweruse'};
					$part->{shieldHealth} += ($part->{'part'}->{shieldgen} * $timeMod);
				}
				if ($part->{shieldHealth} > $part->{'part'}->{shield}){
					$part->{shieldHealth} = $part->{'part'}->{shield};
				}
			}
			# calculate total shield health;
			$self->{shieldHealth} += ($part->{shieldHealth} > 0 ? $part->{shieldHealth} : 0);
		}
	}

	my $powerFactor = $self->{currentPowerGen};
	$self->{currentPower} += ($powerFactor * $timeMod * 0.2);
	$self->_limitPower();
	$self->{lastPower} = time();
}

sub _limitPower {
	my $self = shift;
	if ($self->{currentPower} > $self->{power}){
		$self->{currentPower} = $self->{power};
	}
	if ($self->{currentPower} < 0){
		$self->{currentPower} = 0;
	}
}

sub move {
	my $self = shift;
	if (!defined($self->{lastMove})){ $self->{lastMove} = time();}
	my $timeMod = time() - $self->{lastMove};
	$self->{x} += ($self->{moving} * $self->{speed} * $timeMod);
	#$self->{x} += (1 * $self->{speed} * $timeMod);
	$self->{lastMove} = time();
}

sub _loadShip {
	my $self = shift;
	my $file = shift;

	open(my $fh, '<', $file) or die "failed to open $file\n";
	my @ship;
	my $y = 0;
	while (<$fh>){
		chomp;
		my $line = $_;
		my @chrs = split('', $line);
		$y++;
		my $x = 0;
		foreach my $chr (@chrs){
			$x++;
			if ($chr ne ' '){
				if (defined($parts{$chr})){
					print "$x, $y, $chr\n";
					push @ship, {
						'x' => $x,
						'y' => $y,
						'health' => $parts{$chr}->{health},
						'shieldHealth' => $parts{$chr}->{shield},
						'hit' => time(),
						'part' => $parts{$chr}
					}
				}
			}		
		}
	}
	$self->{ship} = \@ship;
}

1;
