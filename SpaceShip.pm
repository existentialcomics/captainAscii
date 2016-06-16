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
use Config::IniFiles;
#use Math::Trig;

use constant {
	ASPECTRATIO => 0.6,
	PI => 3.1415
};

my $aspectRatio = 0.6;

my %connectors= (
	1 => {
		'b'  => '│',
		't'  => '│',
		'bt' => '│',
     	'l'  => '─',
     	'r'  => '─',
     	'lr' => '─',
		'bl' => '┐',
		'br' => '┌',

		'rt' => '└',
		'lt' => '┘',

		'lrt' => '┴',
		'blr' => '┬',

		'blt' => '┤',
		'brt' => '├',

		'blrt' => '┼',
	},
);
my %connectors2 = (
	1 => {
		'b'  => '║',
		't'  => '║',
		'bt' => '║',
     	'l'  => '═',
     	'r'  => '═',
     	'lr' => '═',
		'bl' => '╗',
		'br' => '╔',

		'rt' => '╚',
		'lt' => '╝',

		'lrt' => '╩',
		'blr' => '╦',

		'blt' => '╣',
		'brt' => '╠',

		'blrt' => '╬',
	},
);

my %parts = (
#	'X' => {
#		cost   => '0',
#		type   => 'command',
#		power  => 50,
#		powergen => 5,
#		weight => 10,
#		thrust  => 100,
#		shoots => color('BRIGHT_BLUE') . "๏",
#		damage => 1.5,
#		bulletspeed => 17,
#		poweruse => -1,
#		quadrants => { 3 => 1, 7 => 1, 4 => 1, 5 => 1, 6 => 1, 1 => 1, 2 => 1, 8 => 1 }, # all directions
#		rate   => 0.8,
#		lastShot => 0,
#		'chr'  => color("BOLD") . 'X',
#		health => 8
#	},
	################## power cells ###################
#	'O' => {
#		cost   => '150',
#		'chr' => 'O',
#		type   => 'power',
#		power  => 30,
#		powergen => 4,
#		weight => 5,
#		health => 2
#	},
#	'0' => {
#		cost   => '500',
#		'chr'  => color('ON_GREY5 RGB530 BOLD') . '0' . color('ON_RGB000 RESET'),
#		type   => 'power',
#		power  => 60,
#		powergen => 10,
#		weight => 5,
#		health => 2
#	},
#	'o' => {
#		cost   => '2000',
#		'chr'  => '0',
#		'color'=> 'rainbow',
#		type   => 'power',
#		power  => 200,
#		powergen => 30,
#		weight => 5,
#		health => 2
#	},
	################## plates ###################
#	'-' => {
#		cost   => '10',
#		type   => 'plate',
#		weight => 2,
#		'chr'  => color('white') . '—',
#		health => 10
#	},
#	'+' => {
#		cost   => '20',
#		type   => 'plate',
#		weight => 3,
#		'chr'  => color('white BOLD') . '[',
#		health => 20
#	},
	################## weapons ###################
    #   quadrants
    #
    #       5
    #     6   4
    #   7   X   3
    #     8   2
    #       1  
    #
	#	quadrants => { 4 => 1, 5 => 1, 6 => 1, 1 => 1, 2 => 1, 8 => 1 }, # up/down
	#	quadrants => { 2 => 1, 3 => 1, 4 => 1, 6 => 1, 7 => 1, 8 => 1 }, # left/right
	#	quadrants => { 5 => 1, 1 => 1 }, # up/down tight
	#	quadrants => { 7 => 1, 3 => 1 }, # left/right tight
	#	quadrants => { 4 => 1, 8 => 1 }, # NE/SW tight
	#	quadrants => { 6 => 1, 3 => 1 }, # NW/SW tight
    ###################
#	'|' => {
#		cost   => '100',
#		type   => 'gun',
#		weight => 2,
#		poweruse => -1,
#		damage => 1,
#		shoots => color('RGB440') . "'" . color('white'),
#		quadrants => { 5 => 1, 1 => 1 }, # up/down tight
#		bulletspeed => 22,
#		rate   => 0.3,
#		'chr'  => '|',
#		health => 4,
#	},
#	'_' => {
#		'chr'  => '—',
#		cost   => '100',
#		type   => 'gun',
#		weight => 2,
#		poweruse => -1,
#		damage => 1,
#		shoots => color('RGB440') . "-" . color('white'),
#		quadrants => { 3 => 1, 7 => 1 }, # left/right
#		bulletspeed => 22,
#		rate   => 0.3,
#		health => 4,
#	},
#	'/' => {
#		'chr'  => '/',
#		cost   => '100',
#		type   => 'gun',
#		weight => 2,
#		poweruse => -1,
#		damage => 1,
#		shoots => color('RGB440') . "/" . color('white'),
#		quadrants => { 4 => 1, 8 => 1 }, # NE/SW tight
#		bulletspeed => 22,
#		rate   => 0.3,
#		health => 4,
#	},
#	'\\' => {
#		'chr'  => '\\',
#		cost   => '100',
#		type   => 'gun',
#		weight => 2,
#		poweruse => -1,
#		damage => 1,
#		shoots => color('RGB440') . "\\" . color('white'),
#		quadrants => { 6 => 1, 2 => 1 }, # NW/SW tight
#		bulletspeed => 22,
#		rate   => 0.3,
#		health => 4,
#	},
#	'I' => {
#		chr    => color('ON_GREY5 RGB530') . "|" . color('reset'),
#		cost   => '500',
#		type   => 'gun',
#		weight => 4,
#		poweruse => -4,
#		quadrants => { 4 => 1, 5 => 1, 6 => 1, 1 => 1, 2 => 1, 8 => 1 }, # up/down
#		damage => 4,
#		shoots => color('RGB551 bold') . "|" . color('reset'),
#		bulletspeed => 22,
#		rate   => 0.3,
#		health => 10
#	},
#	'l' => {
#		chr    => "|",
#		color  => 'rainbow',
#		cost   => '2000',
#		type   => 'gun',
#		weight => 4,
#		poweruse => -10,
#		quadrants => { 4 => 1, 5 => 1, 6 => 1, 1 => 1, 2 => 1, 8 => 1 }, # up/down
#		damage => 4,
#		shoots => color('RGB550 ON_GREY3 bold') . "|" . color('reset'),
#		bulletspeed => 22,
#		rate   => 0.3,
#		health => 10
#	},
#	'~' => {
#		chr    => color('ON_GREY5 RGB530') . "—" . color('reset'),
#		cost   => '500',
#		type   => 'gun',
#		weight => 4,
#		poweruse => -4,
#		quadrants => { 2 => 1, 3 => 1, 4 => 1, 6 => 1, 7 => 1, 8 => 1 }, # left/right
#		damage => 4,
#		shoots => color('RGB551 bold') . "—" . color('reset'),
#		bulletspeed => 22,
#		rate   => 0.3,
#		health => 10
#	},
#	'H' => {
#		cost   => '125',
#		'chr'  => 'H',
#		type   => 'gun',
#		weight => 2,
#		poweruse => -1.5,
#		damage => 1,
#		lifespan => 2.5,
#		shoots => color('RGB225') . ":" . color('reset'),
#		quadrants => { 4 => 1, 5 => 1, 6 => 1, 1 => 1, 2 => 1, 8 => 1 }, # up/down
#		spread => 1,
#		bulletspeed => 20,
#		rate   => 0.2,
#		health => 5
#	},
#	'U' => {
#		cost   => '150',
#		'chr'  => 'U',
#		quadrants => { 4 => 1, 5 => 1, 6 => 1, 1 => 1, 2 => 1, 8 => 1 }, # up/down loose
#		type   => 'gun',
#		weight => 2,
#		shipMomentum => 0.5,
#		damage => 2,
#		poweruse => -2,
#		shoots => color('RGB522') . "*" . color('white'),
#		bulletspeed => 14,
#		rate   => 0.8,
#		health => 5
#	},
#	'8' => {
#		cost   => '150',
#		type   => 'gun',
#		poweruse => -3,
#		quadrants => { 4 => 1, 5 => 1, 6 => 1, 1 => 1, 2 => 1, 8 => 1 }, # up/down loose
#		shipMomentum => 1,
#		lifespan => 5,
#		weight => 6,
#		damage => 5,
#		shoots => "o",
#		bulletspeed => 6,
#		rate   => 1,
#		'chr'  => '8',
#		health => 5
#	},
	####################### shields #############################
#	'@' => {
#		cost   => '200',
#		type   => 'shield',
#		powergen => -1,
#		poweruse => -1.5,
#		weight => 20,
#		size => 'medium',
#		shield => 5,
#		shieldgen => 0.5,
#		'chr'  => color('ON_GREY2 WHITE') . '@' . color('ON_RGB000 RESET'),
#		health => 1
#	},
#	'$' => {
#		cost   => '600',
#		type   => 'shield',
#		powergen => -2.5,
#		poweruse => -4,
#		weight => 40,
#		size => 'large',
#		shield => 12,
#		shieldgen => 1,
#		'chr'  => color('ON_GREY5 RGB530 BOLD') . '@' . color('ON_RGB000 RESET'),
#		health => 1
#	},
);

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
	my $shipDesign = shift;
	my $x = shift;
	my $y = shift;
	my $id = shift;
	my $options = shift;

	$self->_loadPartConfig('parts.ini');

	$self->{color} = color( (defined($options->{color}) ? $options->{color} : 'RGB113') );

	$self->{'design'} = $shipDesign;
    $self->{'controls'} = (defined($options->{'controls'}) ? $options->{'controls'} : 'a');
 
	$self->{'x'} = $x;	
	$self->{'y'} = $y;	
	$self->{'direction'} = PI;
	$self->{'id'} = $id;

	$self->{'movingHoz'}   = 0;
	$self->{'movingVert'}   = 0;
	$self->{'movingHozPress'}   = 0;
	$self->{'movingVertPress'}   = 0;
	$self->{'shooting'} = 0;
	$self->{'aimingPress'} = 0;
	$self->{'aimingDir'} = 1;
	$self->{lastHyperdrive} = 0;
	$self->{'parts'} = {};
	$self->{'idCount'} = 0;

	my $loaded = $self->_loadShip($shipDesign);
	if (!$loaded){ return 0; }
	$self->orphanParts();
	$self->_calculatePower();
	$self->_calculateWeight();
	$self->_calculateThrust();
	$self->_calculateCost();
	$self->_calculateSpeed();
	$self->_calculateShield();
	$self->_calculateHealth();
	$self->{shieldHealth} = $self->{shield};
	$self->{shieldsOn} = 1;
	$self->{empOn} = 1;
	$self->{'shieldStatus'} = 'full';
	
	return 1;
}

sub getAimingCursor {
	my $self = shift;
	return(cos($self->{direction}) * 12 * ASPECTRATIO, sin($self->{direction}) * 12);
}

sub shoot {
	my $self = shift;
	if (time() - $self->{shooting} > 0.5){ return []; }

	my $quad = $self->getQuadrant();

	my $time = time();
	my @bullets = ();
	foreach my $part ($self->getParts()){
		if (!defined($part->{'lastShot'})){ $part->{'lastShot'} = $time;}
		if (($part->{'part'}->{'type'} eq 'gun' || $part->{'part'}->{'type'} eq 'command') and abs($time - $part->{lastShot}) > $part->{'part'}->{rate}){
			$part->{'lastShot'} = $time;
			# not enough power
			if ($self->{currentPower} < abs($part->{part}->{poweruse})){
				next;
			}
			# can't fire in this dir
			if (! defined($part->{quadrants}->{$quad})){
				next;
			}
			$self->{currentPower} += $part->{'part'}->{poweruse};
			my $direction = $self->{direction};

			if (defined($self->{autoaim})){
				foreach my $shipLoc ($self->getNearShipLocs()){
					#TODO calc direction from part to ship
				}
			}

			if (defined($part->{part}->{spread})){
				$direction += (rand($part->{part}->{spread}) - ($part->{part}->{spread} / 2));
			}
			push @bullets, {
				id => $self->{'id'},
				partId => $part->{'id'},
				expires => time() + (defined($part->{'part'}->{'lifespan'}) ? $part->{'part'}->{'lifespan'} : 1.5),
				emp => $self->{empOn},
				damage => $part->{part}->{damage},
				y => ($self->{'x'} + $part->{'x'}),
				x => ($self->{'y'} + $part->{'y'}),
				'chr'   => color($part->{'part'}->{'shotColor'})
						. $part->{'part'}->{'shotChr'},
				dx => (defined($part->{'part'}->{'shipMomentum'}) ? $self->{'movingVert'} * $self->{speed} * $part->{'part'}->{'shipMomentum'} : 0)
					   + $part->{part}->{bulletspeed} * 2 * $aspectRatio * cos($direction),
				dy => (defined($part->{'part'}->{'shipMomentum'}) ? $self->{'movingHoz'}  * $self->{speed} * $part->{'part'}->{'shipMomentum'} : 0)
					   + $part->{part}->{bulletspeed} * 2 * sin($direction),
			};
		}
	}
	$self->_limitPower();
	return \@bullets;
}

sub _calculateThrust {
	my $self = shift;
	$self->{thrust} = 0;
	foreach my $part ($self->getParts()){
		if (defined($part->{part}->{thrust})){
			$self->{thrust} += $part->{part}->{thrust};
		}
	}
}

sub _calculateShield {
	my $self = shift;
	$self->{shield} = 0;
	foreach my $part ($self->getParts()){
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
	foreach my $part ($self->getParts()){
		$self->{cost} += $part->{part}->{cost};
	}
}

sub _calculatePower {
	my $self = shift;
	$self->{power} = 1;
	foreach my $part ($self->getParts()){
		if (defined($part->{part}->{power})){
			$self->{power} += $part->{part}->{power};
		}
	}
	$self->{powergen} = 0;
	foreach my $part ($self->getParts()){
		if (defined($part->{part}->{powergen})){
			$self->{powergen} += $part->{part}->{powergen};
		}
	}
	$self->{currentPower}    = $self->{power};
	$self->{currentPowerGen} = $self->{powergen};
}

sub _calculateSpeed {
	my $self = shift;
	if ($self->{weight} == 0){
		$self->{speed} = 0;
	} else {
		$self->{speed} = $self->{thrust} / $self->{weight} * 2;
	}
}

sub _calculateWeight {
	my $self = shift;
	$self->{weight} = 0.0;
	foreach my $part ($self->getParts()){
		$self->{weight} += $part->{part}->{weight};
	}
}

sub _calculateHealth {
	my $self = shift;
	$self->{health} = 0.0;
	foreach my $part ($self->getParts()){
		$self->{health} += $part->{part}->{health};
	}
}

sub _recalculate {
	my $self = shift;
	$self->_recalculateCollisionMap();
	$self->_recalculatePower();
	$self->_calculateWeight();
	$self->_calculateThrust();
	$self->_calculateSpeed();
	$self->_calculateShield();
	$self->_calculateHealth();
}


sub resolveCollision {
	my $self = shift;
	my $bullet = shift;
	if ($bullet->{id} == $self->{id}){ return 0; }

#	my $bx = int($bullet->{x} - $self->{y});
#	my $by = int($bullet->{y} - $self->{x});
#	my $partId = $self->{partMap}->{$bx}->{$by};
#	if (!defined($partId)){ return 0; }
#	my $part = $self->getPartById($partId);
#	$part->{'health'} -= $bullet->{damage};
#	$part->{'hit'} = time();
#	return { id => $part->{id}, health => $part->{health} };

	my $partsRemoved = 0;

	foreach my $part ($self->getParts()){
		# x and y got mixed somehow
		my $px = int($part->{y} + $self->{y});
		my $py = int($part->{x} + $self->{x});

		if ($part->{'part'}->{'type'} eq 'shield'){
			if (
				($part->{'shieldHealth'} > 0) && $self->{shieldsOn} &&
				(
				(	($part->{'part'}->{'size'} eq 'medium') &&
					(
					 (
						int($bullet->{x}) == $px - 2 &&
						int($bullet->{y}) >= $py - 1 && 
						int($bullet->{y}) <= $py + 1
#						($this->{shieldStatus} eq 'rear' ||
#						 $this->{shieldStatus} eq 'full'
#						 )
					 ) ||

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
					$part->{'shieldHealth'} -= $bullet->{damage};
					if ($part->{'shieldHealth'} < 0){
						$part->{'shieldHealth'} = 0 - ($part->{'part'}->{'shield'} / 3)
					}
					return { id => $part->{id}, shield => $part->{shieldHealth}, deflect => undef };
			}
		}
		if (int($bullet->{y}) == $py &&
		    int($bullet->{x}) == $px){
			$part->{'health'} -= $bullet->{damage};
			$part->{'hit'} = time();
			if ($part->{health} < 0){
				$self->_removePart($part->{id});
			}
			return { id => $part->{id}, health => $part->{health} };
		}
	}
	return undef;
}

sub damagePart {
	my $self = shift;
	my ($partId, $health) = @_;
	my $part = $self->getPartById($partId);
	if ($health < 0){
		$self->_removePart($partId);
		return 1;
	}
	$part->{'hit'} = time();
	$part->{health} = $health;
	return 0;
}

# TODO have server periodically send out shield health for regen
sub damageShield {
	my $self = shift;
	my ($partId, $health) = @_;
	my $part = $self->getPartById($partId);
	$part->{'hit'} = time();
	$part->{shieldHealth} = $health;
	return $part->{shieldHealth};
}

sub getPartDefs {
	my $self = shift;
}

sub setPartDefs {
	my $self = shift;
}

####### new simpler algorithm
# begins at command modules and works its way out
# orphaned parts will never be reached, so deleted at the end
#
sub orphanParts {
	my $self = shift;
	my %matched  = ();

	my $command = $self->getCommandModule();
	if (!$command){ return 0; }

	my $cid = $command->{id};
	my @next = $self->_getConnectedPartIds($self->{parts}->{$cid});

	my $pexam = $cid;

	do {
		$matched{$pexam} = 1;
		foreach my $np ($self->_getConnectedPartIds($self->getPartById($pexam))){
			if (! defined($matched{$np})){
				$matched{$np} = 1;
				push @next, $np;
			}
		}
	} while (defined($pexam = shift @next));

	my @parts;
	foreach my $part ($self->getParts()){
		if (!defined($matched{$part->{id}})){
			push @parts, $part->{id};
			$self->_removePart($part->{id});
		}
	}
	return @parts;
}

sub _removePart {
	my $self = shift;
	my $id = shift;

	my $part = $self->getPartById($id);
	my $x = $part->{x};
	my $y = $part->{y};

	my @connections = $self->_getConnectedPartIds($part);
	foreach my $connection (@connections){
		my $part = $self->getPartById($connection);	
		$self->removeConnection($part, $id);
	}

	delete $self->{parts}->{$id};
	#if (defined($x) && defined($x)
	#delete $self->{collisionMap}->{$x}->{$y};
	#delete $self->{partMap}->{$x}->{$y};
}

sub removeConnection {
	my $self = shift;
	my $part = shift;
	my $connectionId = shift;
	foreach my $k (keys %{$part->{connected}}){
		if ($part->{connected}->{$k} == $connectionId){
			delete $part->{connection}->{$k};
		}
	}
}

# part->{connected} = 
# { l => id,
#   r => id,
#   t => id,
#   b => id
#   };
sub _getConnectedPartIds {
	my $self = shift;
	my $part = shift;
	my @ids;
	foreach my $k (keys %{$part->{connected}}){
		push @ids, $part->{connected}->{$k};
	}
	#print "  $part->{id} $part->{chr} ids: " . (join ",", @ids) . "\n";
	return @ids;
}

sub keypress {
	my $self = shift;
	my $chr = shift;
	if ($chr eq 'a'){ $self->{movingHozPress} = time(); $self->{movingHoz} = -1; }
	if ($chr eq 'd'){ $self->{movingHozPress} = time(); $self->{movingHoz} = 1;  }
	if ($chr eq 'w'){ $self->{movingVertPress} = time(); $self->{movingVert} = -1; }
	if ($chr eq 's'){ $self->{movingVertPress} = time(); $self->{movingVert} = 1;  }
	if ($chr eq ' '){ $self->{shooting} = time();}
	if ($chr eq 'p'){ $self->_recalculate(); }
	if ($chr eq 'q'){ $self->{aimingPress} = time(); $self->{aimingDir} = 1}
	if ($chr eq 'e'){ $self->{aimingPress} = time(); $self->{aimingDir} = -1}
	if ($chr eq 'Q'){ $self->{aimingPress} = time(); $self->{aimingDir} = 5}
	if ($chr eq 'E'){ $self->{aimingPress} = time(); $self->{aimingDir} = -5}
	if ($chr eq 'S'){ $self->hyperdrive(0, 1); } 
	if ($chr eq 'A'){ $self->hyperdrive(-1, 0); } 
	if ($chr eq 'D'){ $self->hyperdrive(1, 0); } 
	if ($chr eq 'W'){ $self->hyperdrive(0, -1); } 
	if ($chr eq 'c'){ $self->cloak(); } 
	if ($chr eq '@'){ $self->toggleShield(); } 
}

sub cloak {
	my $self = shift;
	if ($self->{cloaked}){
		$self->{cloaked} = 0;
	} else {
		$self->{cloaked} = 1;
	}
}

sub toggleShield {
	my $self = shift;
	if ($self->{shieldsOn}){
		$self->{shieldsOn} = 0;
	} else {
		# TODO shields must regenerate from scratch!
		$self->{shieldsOn} = 1;
	}

}

sub hyperdrive {
	my $self = shift;
	my $x = shift;
	my $y = shift;
	if ($self->{currentPower} < $self->{speed} || time() - $self->{lastHyperdrive} < 15){
		return 0;
	}
	$self->{x} += ($self->{speed} * $x * 2);
	$self->{y} += ($self->{speed} * $y * 2 * $aspectRatio);
	$self->{currentPower} -= $self->{speed};
	$self->{lastHyperdrive} = time();
	return 1;
}

sub power {
	my $self = shift;
	if (!defined($self->{lastPower})){ $self->{lastPower} = time();}
	#if ((time() - $self->{lastPower}) < 0.2){ return 0; }
	my $timeMod = time() - $self->{lastPower};

	# if the thrusters are activated
	if ($self->{movingHoz} != 0 && $self->{movingVert} != 0){
		if (int($self->{currentPower} < 2)){
			$self->{currentPowerGen} = $self->{powergen};
			$self->{moving} = 0;
		} else {
			$self->{currentPowerGen} = $self->{powergen} - sprintf('%.2f', ($self->{thrust} / 100));
		}
	} else {
		$self->{currentPowerGen} = $self->{powergen};
	}
	
	if ($self->{cloaked}){
		$self->{currentPowerGen} -= ($self->getParts() / 3);
	}

	$self->{shieldHealth} = 0;
	# if shields are regenerating
	if ($self->{shieldsOn}){
		foreach my $part ($self->getParts()){
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
	} else {
		foreach my $part ($self->getParts()){
			if ($part->{'part'}->{'type'} eq 'shield'){
				# recover the passive part of shieldgen (substract because it is negative)
				$self->{currentPowerGen} -= $part->{'part'}->{powergen};
			}
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
	#if (time() - $self->{lastPower}) < 0.1)){ return 0; }
	my $timeMod = time() - $self->{lastMove};

	if (time - $self->{aimingPress} < 0.15){
		$self->{direction} += (1 * $self->{aimingDir} * $timeMod);
		if ($self->{direction} > (PI * 2)){ $self->{direction} -= (PI * 2); }
		if ($self->{direction} < 0){ $self->{direction} += (PI * 2); }
	}
	
	if (time - $self->{movingHozPress} < 0.2){
		$self->{x} += ($self->{movingHoz} * $self->{speed} * $timeMod);
	} else {
		$self->{movingHoz} = 0;
	}
	if (time - $self->{movingVertPress} < 0.2){
		$self->{y} += ($self->{movingVert} * $self->{speed} * $timeMod * $aspectRatio);
	} else {
		$self->{movingVert} = 0;
	}
	$self->{lastMove} = time();
}

sub _loadPart {
	my $self = shift;
	my ($chr, $x, $y) = @_;
	my $id = $self->{idCount}++;
	$self->{parts}->{$id} = {
		'x' => $x,
		'y' => $y,
		'health' => $parts{$chr}->{health},
		'shieldHealth' => $parts{$chr}->{shield},
		'hit' => time(),
		'id'  => $id,
		'defchr' => $chr,
		'chr' => $parts{$chr}->{'chr'},
		'connected' => {},
		'part' => $parts{$chr}
	};
	return $id;
}

sub _recalculateCollisionMap {
	my $self = shift;
	$self->{collisionMap} = {};
	$self->{partMap} = {};
	$self->{shieldOnly} = [];
	foreach my $part ($self->getParts()){
		my $x = $part->{x};
		my $y = $part->{y};
		my $chr = $part->{defchr};
		$self->{collisionMap}->{$x}->{$y} = $chr;
		$self->{partMap}->{$x}->{$y} = $part->{id};
		#push $self->{shieldsOnly}, $part->{id};
	}
}

sub getParts {
	my $self = shift;
	return values %{ $self->{parts} };
}

sub getPartIds {
	my $self = shift;
	return keys %{ $self->{parts} };
}

sub getPartById {
	my $self = shift;
	my $id = shift;
	return $self->{parts}->{$id};
}

sub getCommandModule {
	my $self = shift;
	foreach my $part ($self->getParts()){
		if ($part->{part}->{type} eq "command"){
			return $part;
		}
	}
	return 0;
}

### build collision and part map here
sub _offsetByCommandModule {
	my $self = shift;
	# find command module and build new ship with connections
	my $cm = $self->getCommandModule();
	if (!$cm){ return 0; }

	my $offx = $cm->{x};
	my $offy = $cm->{y};
	$self->{leftmost}  = -1;
	$self->{rightmost} = 1;
	$self->{topmost}   = 1;
	$self->{bottommost} = -1;
	foreach my $part ($self->getParts()){
		# ground parts to cm as 0,1
		$part->{x} -= $offx;
		$part->{y} -= $offy;
		$self->{collisionMap}->{$part->{x}}->{$part->{y}} = $part->{chr};
		$self->{partMap}->{$part->{x}}->{$part->{y}} = $part->{id};
	}
}

sub _loadPartConfig {
	my $self = shift;
	my $config = shift;
	print "loading config...\n";

	my $cfg = Config::IniFiles->new( -file => $config );
	my @sections = $cfg->Sections();
	foreach my $section (@sections){
		my $chr = $cfg->val($section, 'ref');
		$parts{$chr}->{'chr'}    = $cfg->val($section, 'chr');
		$parts{$chr}->{'cost'}   = $cfg->val($section, 'cost', 0);
		$parts{$chr}->{'health'} = $cfg->val($section, 'health', 1);
		$parts{$chr}->{'weight'} = $cfg->val($section, 'weight', 1);
		my $color = $cfg->val($section, 'color', 'WHITE');
		$parts{$chr}->{'color'}  = ($color eq 'rainbow' ? 'rainbow' : color($color));
	}

	my @guns = $cfg->GroupMembers('gun');
	foreach my $section (@guns){
		my $chr = $cfg->val($section, 'ref');
		$parts{$chr}->{type} = 'gun';
		$parts{$chr}->{'poweruse'}    = $cfg->val($section, 'poweruse', -1);
		$parts{$chr}->{'damage'}      = $cfg->val($section, 'damage', 1);
		$parts{$chr}->{'bulletspeed'} = $cfg->val($section, 'bulletspeed', 20);
		$parts{$chr}->{'rate'}        = $cfg->val($section, 'rate', 0.3);
		$parts{$chr}->{'shotChr'}     = $cfg->val($section, 'shotChr', '.');
		$parts{$chr}->{'shotColor'}   = $cfg->val($section, 'shotColor', 'WHITE');
		$parts{$chr}->{'shipMomentum'}   = $cfg->val($section, 'shipMomentum', 0);
		my $quads = $cfg->val($section, 'quadrangs', '1,2,3,4,5,6,7,8');
		foreach my $q (split ',', $quads){
			$parts{$chr}->{'quadrants'}->{$q} = 1;
		}
	}

	my @thrusters = $cfg->GroupMembers('thruster');
	foreach my $section (@thrusters){
		my $chr = $cfg->val($section, 'ref');
		$parts{$chr}->{type} = 'thruster';
		$parts{$chr}->{'thrust'}  = $cfg->val($section, 'thrust', 100);
	}

	my @plates = $cfg->GroupMembers('plate');
	foreach my $section (@plates){
		my $chr = $cfg->val($section, 'ref');
		$parts{$chr}->{type} = 'plate';
	}

	my @shields = $cfg->GroupMembers('shield');
	foreach my $section (@shields){
		my $chr = $cfg->val($section, 'ref');
		$parts{$chr}->{type} = 'shield';
		$parts{$chr}->{'shield'}    = $cfg->val($section, 'shield', 10);
		$parts{$chr}->{'shieldgen'} = $cfg->val($section, 'shieldgen', 0.5);
		$parts{$chr}->{'powergen'}  = $cfg->val($section, 'powergen', -2.5);
		$parts{$chr}->{'poweruse'}  = $cfg->val($section, 'poweruse', -4);
		$parts{$chr}->{'size'}      = $cfg->val($section, 'size', 'medium');
	}

	my @powers = $cfg->GroupMembers('power');
	foreach my $section (@powers){
		my $chr = $cfg->val($section, 'ref');
		$parts{$chr}->{type} = 'power';
		$parts{$chr}->{'power'}     = $cfg->val($section, 'power', 30);
		$parts{$chr}->{'powergen'}  = $cfg->val($section, 'powergen', 5);
	}

	my @commands = $cfg->GroupMembers('command');
	foreach my $section (@commands){
		my $chr = $cfg->val($section, 'ref');
		$parts{$chr}->{type} = 'command';

		$parts{$chr}->{'power'}     = $cfg->val($section, 'power', 30);
		$parts{$chr}->{'powergen'}  = $cfg->val($section, 'powergen', 5);
		
		$parts{$chr}->{'thrust'}  = $cfg->val($section, 'thrust', 100);

		$parts{$chr}->{'poweruse'}    = $cfg->val($section, 'poweruse', -1);
		$parts{$chr}->{'damage'}      = $cfg->val($section, 'damage', 1);
		$parts{$chr}->{'bulletspeed'} = $cfg->val($section, 'bulletspeed', 20);
		$parts{$chr}->{'rate'}        = $cfg->val($section, 'rate', 0.3);
		$parts{$chr}->{'shotChr'}     = $cfg->val($section, 'shotChr', '.');
		$parts{$chr}->{'shotColor'}   = $cfg->val($section, 'shotColor', 'WHITE');
		$parts{$chr}->{'shipMomentum'}   = $cfg->val($section, 'shipMomentum', 0);
		my $quads = $cfg->val($section, 'quadrangs', '1,2,3,4,5,6,7,8');
		foreach my $q (split ',', $quads){
			$parts{$chr}->{'quadrants'}->{$q} = 1;
		}
	}

}

sub _loadShip {
	my $self = shift;
	my $ship = shift;

	$self->{parts} = {};
	$self->{collisionMap} = {};
	$self->{partMap} = {};
	$self->{shieldsOnly} = [];

	my $command = undef;
	my @shipLines = split("\n", $ship);
	my $y = 0;
	foreach my $line (@shipLines){
		my @chrs = split('', $line);
		$y++;
		my $x = 0;
		foreach my $chr (@chrs){
			$x++;
			if (defined($parts{$chr})){
				my $id = $self->_loadPart($chr, $x, $y);
			}
		}
	}

	$self->_calculateParts();
	return 1;
}

sub _calculateParts {
	my $self = shift;
	$self->_offsetByCommandModule();
	$self->_setPartConnections();
	$self->_removeBlockedGunQuadrants();
}

sub _loadShipByMap {
	my $self = shift;
	my $map = shift;
	$self->{parts} = {};
	$self->{collisionMap} = {};
	$self->{partMap} = {};
	
	foreach my $x (keys %{$map}){
		foreach my $y (keys %{$map->{$x}}){
			my $chr = $map->{$x}->{$y};
			my $id = $self->_loadPart($chr, $x, $y);
		}
	}

	$self->_calculateParts();
}

sub _setPartConnections {
	my $self = shift;
	# TODO put command link calc here, start with command and work out
	foreach my $part ($self->getParts()){
		my $x = $part->{x};
		my $y = $part->{y};
		# find box dimensions of the ship
		if ($x > $self->{rightmost})  { $self->{rightmost} = $x;  }
		if ($x < $self->{leftmost})   { $self->{leftmost}  = $x;  }
		if ($y > $self->{topmost})    { $self->{topmost}   = $y;  }
		if ($y < $self->{bottommost}) { $self->{bottommost} = $y; }

		# calculate connections
		foreach my $partInner ($self->getParts()){
			if ($partInner->{x} == $x - 1 && $partInner->{y} == $y){
				$part->{connected}->{l} = $partInner->{id};	
			}
			elsif ($partInner->{x} == $x + 1 && $partInner->{y} == $y){
				$part->{connected}->{r} = $partInner->{id};	
			}
			elsif ($partInner->{x} == $x && $partInner->{y} - 1 == $y){
				$part->{connected}->{b} = $partInner->{id};	
			}
			elsif ($partInner->{x} == $x && $partInner->{y} + 1 == $y){
				$part->{connected}->{t} = $partInner->{id};	
			}
		}
		if ($part->{'part'}->{'type'} eq 'plate'){
			my $connectStr = 
				(defined($part->{connected}->{b}) ? 'b' : '') .
				(defined($part->{connected}->{l}) ? 'l' : '') .
				(defined($part->{connected}->{r}) ? 'r' : '') .
				(defined($part->{connected}->{t}) ? 't' : '') ;
			if ($connectors{1}->{$connectStr}){
				$part->{'chr'} = color('white') . $connectors{1}->{$connectStr};
			}
		}
	}
}

sub _setPartConnection {
	my $part = shift;
}

### find the angles each gun can shoot
#   quadrants
#
#       5
#     6   4
#   7   X   3
#     8   2
#       1  
#
sub _removeBlockedGunQuadrants {
	my $self = shift;
	foreach my $part ($self->getParts()){
		foreach my $k (keys %{$part->{part}->{quadrants}}){
			$part->{quadrants}->{$k} = $part->{part}->{quadrants}->{$k};
		}
		my $y = $part->{y};
		my $x = $part->{x};

		if (1){
			if ($self->{collisionMap}->{ $x }->{ $y - 1 }){
				#print "removing 5\n";
				delete $part->{quadrants}->{5};
			}
			if ($self->{collisionMap}->{ $x + 1 }->{ $y - 1 }){
				#print "removing 4\n";
				delete $part->{quadrants}->{4};
			}
			if ($self->{collisionMap}->{ $x + 1 }->{ $y }){
				#print "removing 3\n";
				delete $part->{quadrants}->{3};
			}
			if ($self->{collisionMap}->{ $x + 1 }->{ $y + 1 }){
				#print "removing 2\n";
				delete $part->{quadrants}->{2};
			}
			if ($self->{collisionMap}->{ $x }->{ $y + 1 }){
				#print "removing 1\n";
				delete $part->{quadrants}->{1};
			}
			if ($self->{collisionMap}->{ $x - 1 }->{ $y + 1 }){
				#print "removing 8\n";
				delete $part->{quadrants}->{8};
			}
			if ($self->{collisionMap}->{ $x - 1 }->{ $y }){
				#print "removing 7\n";
				delete $part->{quadrants}->{7};
			}
			if ($self->{collisionMap}->{ $x - 1 }->{ $y - 1 }){
				#print "removing 6\n";
				delete $part->{quadrants}->{6};
			}
		}
	}

}

sub getQuadrant {
	my $self = shift;
	my $dir = shift;
	$dir = (defined($dir) ? $dir : $self->{direction});
	if ($dir > 15/8 * PI || $dir <= 1/8 * PI){
		return 1;
	} elsif ($dir > 1/8 * PI && $dir <= 3/8 * PI){
		return 2;
	} elsif ($dir > 3/8 * PI && $dir <= 5/8 * PI){
		return 3;
	} elsif ($dir > 5/8 * PI && $dir <= 7/8 * PI){
		return 4;
	} elsif ($dir > 7/8 * PI && $dir <= 9/8 * PI){
		return 5;
	} elsif ($dir > 9/8 * PI && $dir <= 11/8 * PI){
		return 6;
	} elsif ($dir > 11/8 * PI && $dir <= 13/8 * PI){
		return 7;
	} elsif ($dir > 13/8 * PI && $dir <= 15/8 * PI){
		return 8;
	}
	return undef;
}

# TODO VERY SLOW, redo with collision map
sub getShipDisplay {
	my $self = shift;	
	my $cloaked = shift;
	my $shipStr = "";
	foreach my $x ($self->{bottommost} .. $self->{topmost}){
		foreach my $y ($self->{leftmost} .. $self->{rightmost}){
			my $chr = ' ';
				foreach my $part ($self->getParts()){
					if ($part->{x} == $y && $part->{y} == $x){
						$chr = $self->{color} . $part->{chr} . color('reset');
						last;
					}
				}
			$shipStr .= "$chr";
		}
		$shipStr .= "\n";
	}
	return $shipStr;
}

1;
