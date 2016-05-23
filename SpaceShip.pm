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
		'chr'  => color("BOLD") . 'X',
		health => 15
	},
	################## thrusters ###################
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
	################## power cells ###################
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
	################## plates ###################
	'-' => {
		cost   => '10',
		type   => 'plate',
		weight => 2,
		'chr'  => color('white') . '—',
		health => 10
	},
	'+' => {
		cost   => '20',
		type   => 'plate',
		weight => 2,
		'chr'  => color('white') . '[',
		health => 10
	},
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
	'|' => {
		cost   => '100',
		type   => 'gun',
		weight => 2,
		poweruse => -1,
		damage => 0.7,
		shoots => color('RGB440') . "'" . color('white'),
		quadrants => { 5 => 1, 1 => 1 }, # up/down tight
		bulletspeed => 22,
		rate   => 0.3,
		'chr'  => '|',
		health => 5,
	},
	'_' => {
		'chr'  => '—',
		cost   => '100',
		type   => 'gun',
		weight => 2,
		poweruse => -1,
		damage => 0.7,
		shoots => color('RGB440') . "-" . color('white'),
		quadrants => { 3 => 1, 7 => 1 }, # left/right
		bulletspeed => 22,
		rate   => 0.3,
		health => 5,
	},
	'/' => {
		'chr'  => '/',
		cost   => '100',
		type   => 'gun',
		weight => 2,
		poweruse => -1,
		damage => 0.7,
		shoots => color('RGB440') . "/" . color('white'),
		quadrants => { 4 => 1, 8 => 1 }, # NE/SW tight
		bulletspeed => 22,
		rate   => 0.3,
		health => 5,
	},
	'\\' => {
		'chr'  => '\\',
		cost   => '100',
		type   => 'gun',
		weight => 2,
		poweruse => -1,
		damage => 0.7,
		shoots => color('RGB440') . "\\" . color('white'),
		quadrants => { 6 => 1, 2 => 1 }, # NW/SW tight
		bulletspeed => 22,
		rate   => 0.3,
		health => 5,
	},
	'I' => {
		chr    => color('ON_GREY5 RGB530 BOLD') . "|" . color('reset'),
		cost   => '500',
		type   => 'gun',
		weight => 4,
		poweruse => -4,
		quadrants => { 4 => 1, 5 => 1, 6 => 1, 1 => 1, 2 => 1, 8 => 1 }, # up/down
		damage => 4,
		shoots => color('RGB551 bold') . "|" . color('reset'),
		bulletspeed => 22,
		rate   => 0.3,
		health => 10
	},
	'~' => {
		chr    => color('ON_GREY5 RGB530 BOLD') . "—" . color('reset'),
		cost   => '500',
		type   => 'gun',
		weight => 4,
		poweruse => -4,
		quadrants => { 2 => 1, 3 => 1, 4 => 1, 6 => 1, 7 => 1, 8 => 1 }, # left/right
		damage => 4,
		shoots => color('RGB551 bold') . "—" . color('reset'),
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
		lifespan => 2.5,
		shoots => color('RGB225') . ":" . color('white'),
		quadrants => { 4 => 1, 5 => 1, 6 => 1, 1 => 1, 2 => 1, 8 => 1 }, # up/down
		bulletspeed => 20,
		rate   => 0.6,
		health => 5
	},
	'U' => {
		cost   => '150',
		'chr'  => 'U',
		quadrants => { 4 => 1, 5 => 1, 6 => 1, 1 => 1, 2 => 1, 8 => 1 }, # up/down loose
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
		quadrants => { 4 => 1, 5 => 1, 6 => 1, 1 => 1, 2 => 1, 8 => 1 }, # up/down loose
		shipMomentum => 1,
		lifespan => 5,
		weight => 6,
		damage => 4,
		shoots => "o",
		bulletspeed => 6,
		rate   => 1,
		'chr'  => '8',
		health => 5
	},
	####################### shields #############################
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

	if ($self->_init(@_)){
		return $self;
	}else {
		return undef;
	}
}

sub _init {
	my $self = shift;
	my $shipDesign = shift;
	my $x = shift;
	my $y = shift;
	my $direction = shift;
	my $id = shift;
	my $options = shift;

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
	my $id = -1;
	foreach my $part ($self->getParts()){
		$id += 1;
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
			push @bullets, {
				id => $self->{'id'},
				partId => $id,
				expires => time() + (defined($part->{'part'}->{'lifespan'}) ? $part->{'part'}->{'lifespan'} : 1.5),
				damage => $part->{part}->{damage},
				y => ($self->{'x'} + $part->{'x'}),
				x => ($self->{'y'} + $part->{'y'}),
				'chr' => $part->{'part'}->{'shoots'},
				dx => (defined($part->{'part'}->{'shipMomentum'}) ? $self->{'movingVert'} * $self->{speed} * $part->{'part'}->{'shipMomentum'} : 0)
					   + $part->{part}->{bulletspeed} * $aspectRatio * cos($self->{direction}),
				dy => (defined($part->{'part'}->{'shipMomentum'}) ? $self->{'movingHoz'}  * $self->{speed} * $part->{'part'}->{'shipMomentum'} : 0)
					   + $part->{part}->{bulletspeed} * sin($self->{direction}),
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
	$self->{power} = 0;
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
		$self->{speed} = $self->{thrust} / $self->{weight} * 5;
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
	$self->_resetPartIds();
	$self->orphanParts();
	$self->_recalculateCollisionMap();
	$self->_recalculatePower();
	$self->_calculateWeight();
	$self->_calculateThrust();
	$self->_calculateSpeed();
	$self->_calculateShield();
	$self->_calculateHealth();
	$self->_resetPartIds();
}


sub resolveCollision {
	my $self = shift;
	my $bullet = shift;
	if ($bullet->{id} == $self->{id}){ return 0; }
	my $i = 0;
	foreach my $part ($self->getParts()){
		# x and y got mixed somehow
		my $px = int($part->{y} + $self->{y});
		my $py = int($part->{x} + $self->{x});

		if ($part->{'part'}->{'type'} eq 'shield'){
			if (
				($part->{'shieldHealth'} > 0) &&
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
					return { id => $i, shield => $part->{shieldHealth} };
			}
		}
		if (int($bullet->{y}) == $py &&
		    int($bullet->{x}) == $px){
			$part->{'health'} -= $bullet->{damage};
			$part->{'hit'} = time();
			return { id => $i, health => $part->{health} };
		}
		$i++;
	}
	return undef;
}

sub damagePart {
	my $self = shift;
	my ($partId, $health) = @_;
	my $part = $self->getPartById($partId);
	$part->{'hit'} = time();
	$part->{health} = $health;
}

sub damageShield {
	my $self = shift;
	my ($partId, $health) = @_;
	my $part = $self->getPartById($partId);
	$part->{'hit'} = time();
	$part->{shieldHealth} = $health;
}

sub getPartDefs {
	my $self = shift;
}

sub setPartDefs {
	my $self = shift;
}

sub _resetPartIds {
	my $self = shift;
	my $id = -1;
	foreach my $part ($self->getParts()){
		$part->{id} = $id++;
	}
}

sub orphanParts {
	my $self = shift;
	my %matched  = ();
	my %bad = ();

	my $command = $self->getCommandModule();
	if (!$command){ return 0; }
	my $cid = $command->{id};
	$matched{$cid} = 1;
	foreach my $p ($self->getPartIds()){
		my %examined = ();
		my @toExamine = $self->_getConnectedPartIds($self->{parts}->{$p});
		my $pexam = $p;
		if (defined($bad{$pexam})){ next; }
		if (defined($matched{$pexam})){ next; }
		{
			do {
				if (defined($matched{$pexam})){ 
					$matched{$pexam} = 1;
					while (my $pleft = pop @toExamine){
						$matched{$pleft} = 1;
					}
					foreach my $k (keys %examined){
						$matched{$k} = 1;
					}
					last;
				} 
				if (! defined($examined{$pexam})){
					$examined{$pexam} = 1;
					push @toExamine, $self->_getConnectedPartIds($self->getPartById($pexam));
				}
			} while (defined($pexam = shift @toExamine));
			$bad{$p} = 1;
		} # empty block for last; to apply to
	}
	foreach my $bad (keys %bad){
		delete $self->{parts}->{$bad};
	}
}

sub _partCanReachCommand {
	my $self = shift;
	my $part = shift;
	my %examined = ();
	my $command = $self->getCommandModule();
	my $cid = $command->{id};
	if ($part->{id} eq $cid){ return 1; }
	#print "examine: $part->{id} $part->{chr}\n";

	my @toExamine = $self->_getConnectedPartIds($part);
	my $p = $part->{id};
	do {
		#print " matching $p\n";
		#print " stack : " . (join ",", @toExamine) . "\n";
		if (! defined($examined{$p})){
			$examined{$p} = 1;
			if ($p eq $cid){ 
				#print "matched $p\n";
				return 1;
			}
			push @toExamine, $self->_getConnectedPartIds($self->getPartById($p));
		}
		#print " stack : " . (join ",", @toExamine) . "\n";
	} while (defined($p = shift @toExamine));
	#print "can't connect: $part->{id}\n";
	return 0;
}

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

sub pruneParts {
	my $self = shift;
	my $deleted = 0;
	foreach my $key ($self->getPartIds()){
		if ($self->{parts}->{$key}->{'health'} < 0){
			$deleted++;
			delete $self->{parts}->{$key};
		}
	}
	# check if command module was destroyed!
	my $command = $self->getCommandModule();
	if (!$command){ return 1; }

	if ($deleted > 0){
		$self->_recalculate();
		return 1;
	}
	return 0;
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
}

sub power {
	my $self = shift;
	if (!defined($self->{lastPower})){ $self->{lastPower} = time();}
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

	$self->{shieldHealth} = 0;
	# if shields are regenerating
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
	$self->{collisionMap}->{$x}->{$y} = $chr;
	$self->{partMap}->{$x}->{$y} = $id;
	return $id;
}

sub _recalculateCollisionMap {
	my $self = shift;
	$self->{collisionMap} = {};
	foreach my $part ($self->getParts()){
		my $x = $part->{x};
		my $y = $part->{y};
		my $chr = $part->{defchr};
		$self->{collisionMap}->{$x}->{$y} = $chr;
		$self->{partMap}->{$x}->{$y} = $part->{id};
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

sub _offsetByCommandModule {
	my $self = shift;
	# find command module and build new ship with connections
	my $cm = $self->getCommandModule();

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
	}
}

sub _loadShip {
	my $self = shift;
	my $ship = shift;

	$self->{parts} = {};
	$self->{collisionMap} = {};
	$self->{partMap} = {};

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
	$self->pruneParts(); # will removed orphaned parts and recalc if necessary
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

sub setAllPartConnections {
	my $self = shift;
	return 0;
	foreach my $part ($self->getParts()){
		$self->setPartConnection($part);
	}
}

sub setPartConnection {
	my $self = shift;
	my $part = shift;
	my $x = $part->{x};
	my $y = $part->{y};
	if ($self->{partMap}->{$x}->{$y}){
		$part->{connected}->{l} = $self->{partMap}->{$x}->{$y};
	}
	if ($self->{partMap}->{$x}->{$y}){
		$part->{connected}->{r} = $self->{partMap}->{$x}->{$y};
	}
	if ($self->{partMap}->{$x}->{$y}){
		$part->{connected}->{b} = $self->{partMap}->{$x}->{$y};
	}
	if ($self->{partMap}->{$x}->{$y}){
		$part->{connected}->{t} = $self->{partMap}->{$x}->{$y};
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

sub _setPartConnections {
	my $self = shift;
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
			if    ($partInner->{x} == $x - 1 && $partInner->{y} == $y){
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
		my $y = $part->{x};
		my $x = $part->{y};
		if ($part->{part}->{type} eq 'gun'){
			if ($self->{collisionMap}->{ $x }->{ $y - 1 }){
				delete $part->{quadrants}->{5};
			}
			if ($self->{collisionMap}->{ $x + 1 }->{ $y - 1 }){
				delete $part->{quadrants}->{4};
			}
			if ($self->{collisionMap}->{ $x + 1 }->{ $y }){
				delete $part->{quadrants}->{3};
			}
			if ($self->{collisionMap}->{ $x + 1 }->{ $y + 1 }){
				delete $part->{quadrants}->{2};
			}
			if ($self->{collisionMap}->{ $x }->{ $y + 1 }){
				delete $part->{quadrants}->{1};
			}
			if ($self->{collisionMap}->{ $x - 1 }->{ $y + 1 }){
				delete $part->{quadrants}->{8};
			}
			if ($self->{collisionMap}->{ $x - 1 }->{ $y }){
				delete $part->{quadrants}->{7};
			}
			if ($self->{collisionMap}->{ $x - 1 }->{ $y - 1 }){
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

sub getShipDisplay {
	my $self = shift;	
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
