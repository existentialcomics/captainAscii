#!/usr/bin/perl
#
#
#
use strict; use warnings;
package CaptainAscii::Ship;
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval nanosleep time);
use Data::Dumper;
use Config::IniFiles;
use Math::Trig ':radial';

use CaptainAscii::Module;
use CaptainAscii::Factions;

use constant {
	ASPECTRATIO => 0.66666666,
	PI => 3.1415
};

my $aspectRatio = 0.66666666;

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
	2 => {
		'b'  => '┃',
		't'  => '┃',
		'bt' => '┃',
     	'l'  => '━',
     	'r'  => '━',
     	'lr' => '━',
		'bl' => '┓',
		'br' => '┛',

		'rt' => '┗',
		'lt' => '┛',

		'lrt' => '┻',
		'blr' => '┳',

		'blt' => '┫',
		'brt' => '┣',

		'blrt' => '╋',
	},
	3 => {
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

	$self->{'statusChange'} = {}; #register changes in status to broadcast to clients
	$self->{'_shipMsgs'}    = []; #register any msg that needs to broadcas

	my @allowedColors = qw(red  green  yellow  blue  magenta  cyan  white RGB113);
	$self->{allowedColors} = \@allowedColors;

	$self->setStatus('color', (defined($options->{color}) ? $options->{color} : 'RGB113'));

	$self->{cash} = 0;
	$self->{debug} = 'ship debug msgs';
    $self->{zones} = {};

	$self->{'aspectRatio'} = $aspectRatio;

	$self->{'design'} = $shipDesign;
    $self->{'controls'} = (defined($options->{'controls'}) ? $options->{'controls'} : 'a');
 
	$self->setStatus('x', $x);
	$self->setStatus('y', $y);
	$self->setStatus('direction', PI);
	$self->{'id'} = $id;
	$self->{'lastTauntTime'} = 0;

	my $shipModule = CaptainAscii::Module->new();
	my @modules = $shipModule->plugins();
	$self->{'modules'} = [];
	foreach my $moduleName (@modules){
		push @{ $self->{'modules'} }, $moduleName->new();
	}

	$self->{'movingHoz'}   = 0;
	$self->{'movingVert'}   = 0;
	$self->{'movingHozPress'}   = 0;
	$self->{'movingVertPress'}   = 0;
	$self->{'shooting'} = 0;
	$self->{'aimingPress'} = 0;
	$self->{'aimingDir'} = 1;
	$self->{'parts'} = {};
	$self->{'idCount'} = 1;
	$self->{'radar'} = 0;
	$self->{'cloaked'} = 0;
	$self->{'aiTick'} = time();
	$self->{'isBot'} = 0;

	$self->setStatus('lastHit', time());
	$self->setStatus('lastShieldHit', time());

    $self->{'_spareParts'} = {};

	my $loaded = $self->_loadShip($shipDesign);
	if (!$loaded){ return 0; }
	
	$self->_calculatePower();
	$self->_recalculate();
	$self->orphanParts();
	$self->setStatus('shieldHealth', $self->{shield});
	$self->setStatus('currentHealth', $self->{health});
	$self->setStatus('shieldsOn', 1);
	$self->{empOn} = 0;
	$self->{'shieldStatus'} = 'full';
	return 1;
}

sub randomBuild {
	my $self = shift;
	my $startCash = shift;
	if (!defined($self->{faction})){
		$self->{faction} = CaptainAscii::Factions::getRandomFaction();
	}
	my $type = $self->{faction};

	$self->{cash} = $startCash;
	
	my $config = CaptainAscii::Factions::getBuildConfig($self->{faction});

	my @trees = (
		{ x => 1, y => 0, dir => 'x', 'vector' => 1, 'continue' => 1 },
	);
	if (!$config->{reflectX}){
		push @trees, 
			{ x => -1, y => 0, dir => 'x', 'vector' => -1, 'continue' => 1 };
	}
	if (!$config->{reflectY}){
		push @trees, 
			{ x => 1, y => 1, dir => 'y', 'vector' => 1, 'continue' => 1 };
		push @trees, 
			{ x => -1, y => -1, dir => 'y', 'vector' => -1, 'continue' => 1 };
	}
	my $partLevel = 'parts1';
	if ($self->{cash} > 5000){
		$partLevel = 'parts2';
	}
	if($self->{cash} > 10000){
		$partLevel = 'parts3';
	}
	my @base   = @{$config->{$partLevel}->{base}};
	my @embedx = @{$config->{$partLevel}->{embedx}};
	my @embedy = @{$config->{$partLevel}->{embedy}};
	my @up     = @{$config->{$partLevel}->{up}};
	my @down   = @{$config->{$partLevel}->{down}};
	my @right  = @{$config->{$partLevel}->{right}};
	my @left   = @{$config->{$partLevel}->{left}};


	my $continue = 1;
	while($continue){
		# build structure;
		foreach my $tree (@trees){
			# end
            if (rand() < $config->{'endOdds'}){
				$tree->{continue} = 0;
				if (rand() < $config->{'capOdds'}){

					#$tree->{$tree->{dir}} += $tree->{vector};
					if ($tree->{dir} eq 'x'){
						my $chr = ($tree->{vector} == 1 ? $right[rand(@right)] : $left[rand(@left)]);
						$self->_loadRandomBuildPart($chr, $tree, $config);
					} else {
						my $chr = ($tree->{vector} == 1 ? $down[rand(@down)] : $up[rand(@up)]);
						$self->_loadRandomBuildPart($chr, $tree, $config);
                    }
                } else {
                }
				next;
			}
			my $chr = $base[rand(@base)];
			# inner fill chrs
			if (rand() < $config->{'pieceOdds'}){
				$chr = ($tree->{dir} eq 'x' ? $embedx[rand(@embedx)] : $embedy[rand(@embedy)]);
			}

			$self->_loadRandomBuildPart($chr, $tree, $config);
			$tree->{$tree->{dir}} += $tree->{vector};
			# change direction
			if (rand() < $config->{turnOdds}){
				$tree->{dir} = ($tree->{dir} eq 'x' ? 'y' : 'x');
			}
			## branch
			elsif (($tree->{dir} eq $config->{branchDir}) && (rand() < $config->{branchOdds})){
				push(@trees, 
					{ 
						x => $tree->{x},
						y => $tree->{y},
						dir => ($tree->{dir} eq 'x' ? 'y' : 'x'),
						'vector' => (rand() < .4 ? -1 : 1),
						'continue' => 1 }
				);
			}

			# TODO distinguish between inner and outer pieces (i.e, lasers on the outside, power on the inside)
			# up / right
			if (rand() < $config->{sideOdds}){
				my $dirMove = 1;
				if ($tree->{dir} eq 'x'){
					$tree->{y}+= $dirMove;
					my $chr = $up[rand(@up)];
					$self->_loadRandomBuildPart($chr, $tree, $config);
					$tree->{y}-=$dirMove;
				} else {
					$tree->{x}+= $dirMove;
					my $chr = $right[rand(@right)];
					$self->_loadRandomBuildPart($chr, $tree, $config);
					$tree->{x}-=$dirMove;
				}
			}
			if (rand() < $config->{sideOdds}){
				my $dirMove = -1;
				if ($tree->{dir} eq 'x'){
					$tree->{y}+= $dirMove;
					my $chr = $down[rand(@down)];
					$self->_loadRandomBuildPart($chr, $tree, $config);
					$tree->{y}-=$dirMove;
				} else {
					$tree->{x}+= $dirMove;
					my $chr = $left[rand(@left)];
					$self->_loadRandomBuildPart($chr, $tree, $config);
					$tree->{x}-=$dirMove;
				}
			}
			# down/left
		}
		@trees = grep { $_->{continue} } @trees;
		#print scalar @trees . "\n";
		if ($#trees == -1){ $continue = 0; }
	}
	$self->_calculateParts();
	$self->_recalculate();
}

sub _loadRandomBuildPart {
	my $self = shift;
	my ($chr, $tree, $config) = @_;

	my %reflectX = (
		')' => '(',
		'(' => ')',
		'\\' => '/',
		'/' => '\\',
		'{' => '}',
		'}' => '{',
		'[' => ']',
		']' => '[',
	);
	my %reflectY = (
		'v' => '^',
		'^' => 'v',
		'\\' => '/',
		'/' => '\\',
	);

	if ($self->purchasePart($chr)){
		$self->useSparePart($chr);
		$self->_loadPart($chr, $tree->{x}, $tree->{y});
		if ($config->{reflectX}){
			my $chrX = (defined($reflectX{$chr}) ? $reflectX{$chr} : $chr);
			$self->purchasePart($chrX);
			$self->useSparePart($chrX);
			$self->_loadPart($chrX, -$tree->{x}, $tree->{y});
		}
		if ($config->{reflectY}){
			my $chrY = (defined($reflectY{$chr}) ? $reflectY{$chr} : $chr);
			$self->purchasePart($chrY);
			$self->useSparePart($chrY);
			$self->_loadPart($chrY, $tree->{x}, -$tree->{y});

		}
		if ($config->{reflectX} && $config->{reflectY}){
			my $chrX = (defined($reflectX{$chr}) ? $reflectX{$chr} : $chr);
			my $chrXY = (defined($reflectY{$chrX}) ? $reflectY{$chrX} : $chrX);
			$self->purchasePart($chrXY);
			$self->useSparePart($chrXY);
			$self->_loadPart($chrXY, -$tree->{x}, -$tree->{y});
		}
		return 1;
	} else {
		$tree->{continue} = 0;
		return 0;
	}

}


sub resetZones {
    my $self = shift;
    $self->{oldZones} = $self->{zones};
    $self->{zones} = {};
}

### call resetZones first, finishZonesAdd after
sub addZone {
    my $self = shift;
    my $zone = shift;
    $self->{zones}->{$zone->{id}} = $zone;
    if (!defined($self->{oldZones}->{$zone->{id}})){
        $self->addServerInfoMsg("Entering into " . $zone->getName() . " zone.");
    }
}

sub finishZonesAdd {
    my $self = shift;
    foreach my $id (keys %{$self->{oldZones}}){
        if (!defined($self->{zones}->{$id})){
            my $zone = $self->{oldZones}->{$id};
			$self->addServerInfoMsg("Leaving the " . $zone->getName() . " zone.");
        }
    }
}

sub getZoneSpawns {
	my $self = shift;
	my @spawns = ();
	foreach my $zone (values %{$self->{zones}}){
		push @spawns, $zone->getSpawns();
	}
	return @spawns;
}

sub getZoneSpawnRate {
	my $self = shift;
	my $spawnRate = 0;
	foreach my $zone (values %{$self->{zones}}){
		$spawnRate += $zone->getSpawnRate();
	}
	return $spawnRate;
}

sub calculateDrops {
    my $self = shift;

    my %xy = ();

    my @drops = ();
    if (rand() < 0.3){
		my $cash = int($self->{cash} * rand());
		if ($cash == 0){ $cash = int(rand(20) + 3)};
		#print "cash : $cash, $self->{cash}\n";
        push @drops, {
            cash => $cash,
            'chr'  => '$',
            'col'  => 'green ON RGB121'
        };
    }
    if (rand() < 0.1){
        my @modules = $self->getModules();
        if (@modules){
            my $module = $modules[rand($#modules)];
            push @drops, {
                'module' => $module->name(),
                'chr'    => $module->getDisplay()
            };
        }
    }

	foreach my $part ($self->getParts()){
		if ($part->{health} / $part->{'part'}->{health} > 0.5){
			if (rand() < 0.5){
				push @drops, {
					'part' => $part->{defchr},
					'chr'  => $part->{chr},
				};
			}
		}
    }

    foreach my $drop (@drops){
		# TODO x and y switched
        my $x = ($self->{y} + (int(rand(6) - 3)));
        my $y = ($self->{x} + (int(rand(6) - 3)));
        while (( defined($xy{'x'}->{$x})) && (defined($xy{'y'}->{$y})) ){
            if (rand() < .5){
                $x += (rand() < .5 ? 1 : -1);
            } else { 
                $y += (rand() < .5 ? 1 : -1);
            }
        }
        $drop->{x} = $x;
        $drop->{y} = $y;
		$xy{x}->{$x} = 1;
		$xy{y}->{$y} = 1;
    }

    return @drops;
}

sub becomeAi {
	my $self = shift;
	my $faction = shift;
	$self->{aiMode} = 'explore';
	$self->{aiState} = 'random';
	$self->{aiModeChange} = 0;
	$self->{aiStateChange} = 0;
	$self->{aiTowardsShipId} = 0;
	$self->setStatus('isBot', 1);
    $self->{cash} = int($self->{cost} / 4);
	if (!defined($self->{faction})){
		$self->setStatus('faction', CaptainAscii::Factions::getRandomFaction());
	}
	$self->setAiColor();
}

sub getColorName {
	my $self = shift;
	return $self->{color};
}

sub isValidColor{
	my $self = shift;
	my $color = shift;
	foreach my $valid (@{$self->{allowedColors}}){
		if ($color eq $valid){ return 1; }
	}
	return 0;
}

sub getRadar {
	my $self = shift;
	my $ship = shift;
	my $y = ($ship->{x} - $self->{x});
	my $x = ($ship->{y} - $self->{y});
	my ($rho, $theta, $phi)   = cartesian_to_spherical($x, $y, 0);
	return(cos($theta) * 20 * ASPECTRATIO, sin($theta) * 20);
}

sub getAimingCursor {
	my $self = shift;
	return(cos($self->{direction}) * 12 * ASPECTRATIO, sin($self->{direction}) * 12);
}

sub shoot {
	my $self = shift;
	if (time() - $self->{shooting} > 0.4){ return []; }

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
			$self->addStatus('currentPower', $part->{'part'}->{poweruse});
			my $direction = $self->{direction};

			if ($part->{part}->{spread}){
				$direction += (rand($part->{part}->{spread}) - ($part->{part}->{spread} / 2));
			}
			push @bullets, {
				ship_id => $self->{'id'},
				partId => $part->{'id'},
				expires => time() + (defined($part->{'part'}->{'lifespan'}) ? $part->{'part'}->{'lifespan'} : 1.5),
				emp => $self->getStatus('emp'),
				damage => $part->{part}->{damage},
				y => ($self->{'x'} + $part->{'x'}),
				x => ($self->{'y'} + $part->{'y'}),
				'chr'   => $part->{'part'}->{'shotChr'},
				'col'   => ($self->getStatus('emp') ? 'bold blue' : $part->{'part'}->{'shotColor'}),
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

sub _calculateCost {
	my $self = shift;
	$self->{cost} = 0;
	foreach my $part ($self->getParts()){
		$self->{cost} += $part->{part}->{cost};
	}
}

# when you lose a part
sub _recalculatePower {
	my $self = shift;
	my $current = $self->{currentPower};
	my $max = $self->getStatus('power');
	$self->_calculatePower();

	# reset current power
	$self->setStatus('currentPower', $current);

	# subtract power for any lost generators
	if ($max > $self->{power}){
		$self->addStatus('currentPower', -abs($max - $self->{power}));
		if ($self->{currentPower} < 0){
			$self->setStatus('currentPower', 0);
		}
	}
}

sub _calculatePower {
	my $self = shift;
	my $power = 1;
	my $powergen = 0;

	foreach my $part ($self->getParts()){
		if (defined($part->{part}->{power})){
			$power += $part->{part}->{power};
		}
		if (defined($part->{part}->{powergen})){
			$powergen += $part->{part}->{powergen};
		}
	}

	$self->setStatus('power', $power);
	$self->setStatus('powergen', $powergen);
	$self->setStatus('currentPower', $self->{power});
	$self->setStatus('currentPowerGen', $self->{powergen});
}

sub _calculateSpeed {
	my $self = shift;
	if ($self->{weight} == 0){
		$self->{speed} = 0;
	} else {
		$self->{speed} = $self->{thrust} / $self->{weight} * 2;
	}
	if ($self->{speed} > 35){ $self->{speed} = 35; }
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
	my $health = 0;
	foreach my $part ($self->getParts()){
		$health += $part->{part}->{health};
	}
	$self->setStatus('health', $health);
}

sub _recalculate {
	my $self = shift;
	$self->_recalculateCollisionMap();
	$self->_recalculatePower();
	$self->_calculateWeight();
	$self->_calculateThrust();
	$self->_calculateSpeed();
	$self->_calculateShield();
	$self->_calculateCost();
	$self->_calculateHealth();
	#$self->_setPartConnections();
	$self->_removeBlockedGunQuadrants();
	$self->_calculateHitBox();
}

sub getShipLeft {
	my $self = shift;
	return $self->{x} + $self->{_xLow};
}
sub getShipRight {
	my $self = shift;
	return $self->{x} + $self->{_xHigh};
}
sub getShipTop {
	my $self = shift;
	return $self->{y} + $self->{_yLow};
}
sub getShipBottom {
	my $self = shift;
	return $self->{y} + $self->{_yHigh};
}

### highest and lowest x and y
sub _calculateHitBox {
	my $self = shift;
	$self->{_xLow}  = 0;
	$self->{_xHigh} = 0;
	$self->{_yLow}  = 0;
	$self->{_yHigh} = 0;
	$self->{_xLowShield}  = 0;
	$self->{_xHighShield} = 0;
	$self->{_yLowShield}  = 0;
	$self->{_yHighShield} = 0;

	foreach my $part ($self->getParts()){
		if ($part->{'x'} > $self->{'_xHigh'}){ $self->{'_xHigh'} = $part->{'x'}; }
		if ($part->{'y'} > $self->{'_yHigh'}){ $self->{'_yHigh'} = $part->{'y'}; }
		if ($part->{'x'} < $self->{'_xLow'}) { $self->{'_xLow'} = $part->{'x'}; }
		if ($part->{'y'} < $self->{'_yLow'}) { $self->{'_yLow'} = $part->{'y'}; }
		# TODO aspect ratio
		if (defined($part->{'part'}->{'shieldsize'})){
			if ($part->{'x'} + $part->{'part'}->{'shieldsize'} > $self->{'_xHighShield'}){
				$self->{'_xHighShield'} = $part->{'x'} + $part->{'part'}->{'shieldsize'};
			}
			if ($part->{'y'} + $part->{'part'}->{'shieldsize'} > $self->{'_yHighShield'}){
				$self->{'_yHighShield'} = $part->{'y'} + $part->{'part'}->{'shieldsize'};
			}
			if ($part->{'x'} - $part->{'part'}->{'shieldsize'} < $self->{'_xLowShield'}){
				$self->{'_xLowShield'} = $part->{'x'} - $part->{'part'}->{'shieldsize'};
			}
			if ($part->{'y'} - $part->{'part'}->{'shieldsize'} < $self->{'_yLowShield'}){
				$self->{'_yLowShield'} = $part->{'y'} - $part->{'part'}->{'shieldsize'};
			}
		}
	}
}

sub isInHitBox {
	my $self = shift;
	my ($x, $y) = @_;
	return (
		$x >= $self->{y} + $self->{'_yLow'} - 2 &&
		$x <= $self->{y} + $self->{'_yHigh'} + 2 &&
		$y >= $self->{x} + $self->{'_xLow'} - 2 &&
		$y <= $self->{x} + $self->{'_xHigh'} + 2
	);
}

sub isInShieldHitBox {
	my $self = shift;
	my ($x, $y) = @_;
	return (
		$x >= $self->{y} + $self->{'_yLowShield'} - 2 &&
		$x <= $self->{y} + $self->{'_yHighShield'} + 2 &&
		$y >= $self->{x} + $self->{'_xLowShield'} - 2 &&
		$y <= $self->{x} + $self->{'_xHighShield'} + 2
	);
}


sub resolveCollision {
	my $self = shift;
	my $bullet = shift;
	if ($bullet->{ship_id} == $self->{id}){ return 0; }

#	my $partId = $self->{partMap}->{$bx}->{$by};
#	if (!defined($partId)){ return 0; }
#	my $part = $self->getPartById($partId);
#	$part->{'health'} -= $bullet->{damage};
#	$part->{'hit'} = time();
#	return { id => $part->{id}, health => $part->{health} };

	my $partsRemoved = 0;

	if ($self->isInShieldHitBox($bullet->{x}, $bullet->{y})){
		### loop through shields first on their own
		foreach my $part ($self->getShieldParts()){
			#if (!($part->{'part'}->{'type'} eq 'shield')){
			if (!($part->{'part'}->{'shieldsize'})){
				next;
			}
			# x and y got mixed somehow, don't worry about it
			my $px = int($part->{y} + $self->{y});
			my $py = int($part->{x} + $self->{x});

			my $distance = sqrt(
				(( ($px - $bullet->{x}) / ASPECTRATIO) ** 2) +
				(($py - $bullet->{y}) ** 2)
			);

			if ($part->{'part'}->{'type'} eq 'shield'){
				if (($part->{'shieldHealth'} > 0 && $self->{shieldsOn}) &&
					($distance < $part->{part}->{shieldsize} + 1)
					){
						$part->{'hit'} = time();
						$part->{'shieldHealth'} -= $bullet->{damage};
						if ($part->{'shieldHealth'} < 0){
							$part->{'shieldHealth'} = 0 - ($part->{'part'}->{'shield'} / 3)
						}
						return { id => $part->{id}, shield => $part->{shieldHealth}, deflect => undef };
				}
			}
		}
	}

    if ($self->isInHitBox($bullet->{x}, $bullet->{y})){
		my $by = int($bullet->{x} - $self->{y});
		my $bx = int($bullet->{y} - $self->{x});
		my $part = undef;
		$part = $self->getPartByLocation($bx, $by);
		if (!$part){
			foreach my $checkX ($bx -1 .. $bx +1){
				foreach my $checkY ($by -1 .. $by +1){
					$part = $self->getPartByLocation($checkX, $checkY);
				}
			}
		}
		if ($part){
			# TODO make dodge status the odds of dogding
			if ($self->getStatus('dodge') && rand() < 0.3){
				return { 'deflect' => 1 }
			}
			if ($self->isBot()){
				$self->changeAiMode('attack', 'aggressive');
				$self->setAiVar('target', $bullet->{id});
			}
			$part->{'hit'} = time();
			if ($bullet->{emp}){
				$self->setStatus('currentPower', $self->{currentPower} - $bullet->{damage});
				$self->_limitPower();
			} else {
				$part->{'health'} -= $bullet->{damage};
				if ($part->{health} < 0){
					$self->_removePart($part->{id});
				}
				return { id => $part->{id}, health => $part->{health} };
			}
		}
    }
	return undef;
}

sub lightShip {
	my $self = shift;
	my $duration = shift;
	if (!defined($duration)){ $duration = 0; } # really add 0.5 seconds
	my @lights = ();
	foreach my $part ($self->getParts()){
		$part->{'hit'} = time() + $duration;
		$self->addServerMsg('light', 
			{
				'x' => int($part->{y} + $self->{y}),
				'y' => int($part->{x} + $self->{x}),
				'level' => int($duration * 3),
				'decay' => int($duration * 1),
			}
		);
	}
}

sub getAiModeState {
	my $self = shift;
	return ($self->{aiMode}, $self->{aiState});
}

# governs whether or not to take intermittent action
# pass in the time
sub aiStateRequest {
	my $self = shift;
	my $timeRequested = shift;
	my $action = shift;
	$action = "_action$action";
	if (! defined( $self->{_aiVars}->{$action})){
		$self->{_aiVars}->{$action} = time();
		return 1;
	} 
	if ((time() - $self->{_aiVars}->{$action}) > $timeRequested){
		$self->{_aiVars}->{$action} = time();
		return 1;
	}
	return 0;
}

sub changeAiMode {
	my $self = shift;
	my $mode = shift;
	my $state = shift;
	if (!defined($self->{aiMode})){
		print "mode not defined! $mode\n";
	}
	if ($mode ne $self->{aiMode}){
		$self->setStatus('taunt', CaptainAscii::Factions::getTaunt($self->{faction}, $mode));
		$self->{aiMode} = $mode;
		$self->{_aiVars} = {};
	}
	$self->{aiModeChange} = time();
	$self->{aiTick} = time();
	if (defined($state)){
		$self->{aiState} = $state;
	} else{
		if ($mode eq 'attack'){
			$self->{aiState} = 'aggressive';
		} elsif ($mode eq 'explore'){
			$self->{aiState} = 'random';
		}
	}
	$self->setAiColor();
}

sub setAiColor {
	my $self = shift;
	if (! $self->isBot()){ return 0; }
	my $newColor = $self->getColorName();
	if ($self->{aiMode} eq 'attack'){
		$newColor = 'red';
	} elsif ($self->{aiMode} eq 'explore'){
		$newColor = 'blue';
	} elsif ($self->{aiMode} eq 'flee'){
		$newColor = 'green';
	}
	if ($newColor ne $self->getColorName()){
		$self->setStatus('color', $newColor);
		return 1;
	}
	return 0;
}

sub isBot {
	my $self = shift;
	return $self->{isBot};
}

sub setAiVar {
	my $self = shift;
	my ($key, $value) = @_;
	$self->{_aiVars}->{$key} = $value;
}

sub getAiVar {
	my $self = shift;
	my $key = shift;
	return $self->{_aiVars}->{$key};
}

sub clearAiVar {
	my $self = shift;
	my $key = shift;
	delete $self->{_aiVars}->{$key};
}

### only called by client
sub setPartHealth {
	my $self = shift;
	my ($partId, $health) = @_;
	my $part = $self->getPartById($partId);
	if ($health < 0){
		$self->_removePart($partId);
		return undef;
	}
    if ($part->{health} > $health){
	    $part->{'hit'} = time();
		$self->setStatus('lastHit', time());
		$part->{health} = $health;
		return 
			{
				'x' => int($part->{y} + $self->{y}),
				'y' => int($part->{x} + $self->{x}),
				'level' => 5,
				'decay' => 17,
			};
    } elsif ($part->{health} < $health) {
	    $part->{'healing'} = time();
		$part->{health} = $health;
    }  
	return undef;
}

# TODO have server periodically send out shield health for regen
sub damageShield {
	my $self = shift;
	my ($partId, $health) = @_;
	my $part = $self->getPartById($partId);
	### it lost health, so it was hit
	if ($part->{shieldHealth} > $health){
		$part->{'hit'} = time();
		$self->setStatus('lastShieldHit', time());
	}
	$part->{shieldHealth} = $health;
	return $part->{shieldHealth};
}

####### new simpler algorithm
# begins at command modules and works its way out
# orphaned parts will never be reached, so deleted at the end
#
sub orphanParts {
	my $self = shift;
	my $preserve = shift;
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
			$self->_removePart($part->{id}, $preserve);
		}
	}
	return @parts;
}

sub removePartLocation {
	my $self = shift;
	my ($x, $y, $preserve) = @_;
	my $id = $self->getPartIdByLocation($x, $y);
	if (!defined($id)){ return 0; }
	$self->_removePart($id, $preserve);
}

sub getPartIdByLocation {
	my $self = shift;
	my ($x, $y, $preserve) = @_;
	return $self->{partMap}->{$x}->{$y};
}

sub getPartByLocation {
	my $self = shift;
	my ($x, $y) = @_;
	my $id = $self->{partMap}->{$x}->{$y};
	return undef if (!$id);
	return $self->getPartById($id);
}

### make sure to recalculate after, and possibly orphanParts
sub _removePart {
	my $self = shift;
	my $id = shift;
	my $preserve = shift;

	my $part = $self->getPartById($id);
	my $x = $part->{x};
	my $y = $part->{y};

	my @connections = $self->_getConnectedPartIds($part);
	foreach my $connection (@connections){
		my $part = $self->getPartById($connection);	
		$self->removeConnection($part, $id);
	}

	if ($preserve){
		$self->addSparePart($part->{defchr});
	}
	if (defined($part->{x}) && defined($part->{y})){
		delete $self->{collisionMap}->{$part->{x}}->{$part->{y}};
		delete $self->{partMap}->{$part->{x}}->{$part->{y}};
	} else {
		# TODO fix this
		#print "bad part: $id\n";
		#print Dumper($part);
	}
	delete $self->{parts}->{$id};
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
	return @ids;
}


#######################
# Resolve keypress
# returns:
# {
#    'msgType' => 'shipstatus',
#    'msg' => {
#		ship_id => $self->{id},
#		cloaked => $self->{cloaked}
#	 }
# }
# OR undef
sub keypress {
	my $self = shift;
	my $chr = shift;
	if ($chr eq 'a'){ $self->{movingHozPress} = time(); $self->{movingHoz} = -1; }
	if ($chr eq 'd'){ $self->{movingHozPress} = time(); $self->{movingHoz} = 1;  }
	if ($chr eq 'w'){ $self->{movingVertPress} = time(); $self->{movingVert} = -1; }
	if ($chr eq 's'){ $self->{movingVertPress} = time(); $self->{movingVert} = 1;  }
	if ($chr eq ' '){ $self->{shooting} = time();}
	if ($chr eq 'p'){ $self->_recalculate(); }
	if ($chr eq 'q' || $chr eq 'j'){ $self->{aimingPress} = time(); $self->{aimingDir} = 1}
	if ($chr eq 'e' || $chr eq 'k'){ $self->{aimingPress} = time(); $self->{aimingDir} = -1}
	if ($chr eq 'Q' || $chr eq 'J'){ $self->{aimingPress} = time(); $self->{aimingDir} = 5}
	if ($chr eq 'E' || $chr eq 'E'){ $self->{aimingPress} = time(); $self->{aimingDir} = -5}
	if ($chr eq 'l'){ $self->lightShip() }
	if ($chr eq '@'){ $self->toggleShield(); } 
	$self->_resolveModuleKeypress($chr);
	return undef
}

sub _resolveModuleKeypress {
	my $self = shift;
	my $chr = shift;
	foreach my $module ($self->getModules()){
		foreach my $mKey ($module->getKeys()){
			if ($chr eq $mKey){
				return $module->active($self, $chr);
			}
		}
	}
	return undef;
}

sub addStatus {
	my $self = shift;
	my $status = shift;
	my $value = shift;

	$self->setStatus($status, $self->getStatus($status) + $value);
}

sub setStatus {
	my $self = shift;
	my $status = shift;
	my $value = shift;

	if ($status eq 'taunt'){
		$self->{'lastTauntTime'} = time();
	}
	
	if ($status eq 'color'){ $value = uc($value); }
	#if ($status eq 'x'){ $value = int($value); }
	#if ($status eq 'y'){ $value = int($value); }
	if ($status eq 'warp'){
		if (ref($value) eq 'HASH'){
			$value->{end} = time() + $value->{'time'};
		}
	}

	if ($status eq 'light'){
		$self->lightShip($value);
	} elsif($status eq 'm_active'){
        foreach my $module ($self->getModules()){
            if ($module->name() eq $value->{name}){
                $module->setActive($value->{active});
            }
        }
	}

	# register status change for server mgs's
	if (!defined($self->{$status}) || $self->{$status} ne $value){
		$self->{$status} = $value;
		$self->{'statusChange'}->{$status} = $value;
	}
}

sub claimItem {
	my $self = shift;
	my $item = shift;
	if (defined($item->{cash})){
		my $cash = $self->getStatus('cash');
		$self->setStatus('cash', $cash + $item->{cash});
        $self->addServerInfoMsg("Found $item->{cash} credits.");
	}
	if (defined($item->{module})){
        foreach my $module ($self->getModules()){
            if ($module->name() eq $item->{module}){
				$module->enable();
                $self->addServerInfoMsg("Found " . $module->name() . " ship module.");
            }
        }
	}
    if (defined($item->{part})){
        $self->addServerInfoMsg("Found spare part $item->{part}.");
		$self->addSparePart($item->{'part'});
    }
}

sub addSparePart {
	my $self = shift;
	my $chr  = shift;
	$self->{_spareParts}->{$chr}++;
	$self->addServerMsg('sparepart',
		{ 'ship_id' => $self->{id}, 'part' => $chr, 'add' => 1}
	);
}

sub useSparePart {
	my $self = shift;
	my $chr = shift;
	if ($self->{_spareParts}->{$chr}-- < 1){
		$self->{_spareParts}->{$chr} = 0;
	} else {
		$self->addServerMsg('sparepart',
			{ 'ship_id' => $self->{id}, 'part' => $chr, 'use' => 1}
		);
	}
}

sub hasSparePart {
	my $self = shift;
	my $chr  = shift;
	return (defined($self->{_spareParts}->{$chr}) ? $self->{_spareParts}->{$chr} : 0);
}

sub getStatus {
	my $self = shift;
	my $status = shift;
#	if (defined($self->{'_status'}->{$status})){
#		return $self->{'_status'}->{$status};
#	}
	if (defined($self->{$status})){
		return $self->{$status};
	}
	return 0;
}


sub clearStatusMsgs {
	my $self = shift;
	$self->{'statusChange'} = {};
}

sub getStatusMsgs {
	my $self = shift;
	my @msgs = ();
	foreach my $key (keys %{ $self->{'statusChange'} }){
		push @msgs, {
			'ship_id' => $self->{id},
			$key => $self->{'statusChange'}->{$key}
		};
	}
	return @msgs;
}

### more generic getStatusMsgs()
sub getServerMsgs {
    my $self = shift;
    return @{ $self->{'_shipMsgs'} };
}

sub clearServerMsgs {
    my $self = shift;
    $self->{'_shipMsgs'} = [];
}

# wrapper for chat msgs, goes to the player only
sub addServerInfoMsg {
    my $self = shift;
    my $msgInfo = shift;
    $self->addServerMsg('msg', 
		{ 'user' => '<SYSTEM>', 'msg' => $msgInfo, 'color' => 'GREEN' },
		1  # send to this player only
	);
}

sub addServerMsg {
    my $self     = shift;
    my $category = shift;
    my $msg      = shift;
	my $playerOnly = shift;

    push @{ $self->{'_shipMsgs'} }, { 'category' => $category, 'msg' => $msg, '_playerOnly' => $playerOnly };
}

sub recieveShipStatusMsg {
	my $self = shift;
	my $data = shift;
	if ($data->{'ship_id'} ne $self->{'id'}){ return 0; }
	foreach my $status (keys %{$data}){
		if ($status eq 'ship_id'){ next; }
		$self->setStatus($status, $data->{$status});
	}
}

sub moduleTick {
	my $self = shift;
	foreach my $module (@{$self->{modules}}){
		$module->tick($self);
	}
}

sub _resolveModulePower {
	my $self = shift;
	my $powerUse = 0;
	foreach my $module (@{$self->{modules}}){
		$powerUse += $module->power($self);
	}
	return $powerUse;
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

sub power {
	my $self = shift;
	if (!defined($self->{lastPower})){ $self->{lastPower} = time();}
	#if ((time() - $self->{lastPower}) < 0.2){ return 0; }
	my $timeMod = time() - $self->{lastPower};

	my $shieldHealth = 0;
	my $currentHealth = 0;
	my $currentPowerGen = $self->getStatus('powergen');

	# if the thrusters are activated
	if ($self->{movingHoz} != 0 || $self->{movingVert} != 0){
		if (int($self->{currentPower} < $self->{thrust} / 100)){
			$self->{moving} = 0;
		} else {
			$currentPowerGen -= sprintf('%.2f', ($self->{thrust} / 100));
		}
	}

	$currentPowerGen += $self->_resolveModulePower();
	
	# if shields are regenerating
	foreach my $part ($self->getParts()){
		$currentHealth += ($part->{health} > 0 ? $part->{health} : 0);
		if ($part->{'part'}->{'type'} eq 'shield'){
			if (($self->{currentPower} / $self->{power} < 0.2) || !$self->{shieldsOn}){
				# drain shields if power is low and they are on
				if ($self->{shieldsOn}){
					$part->{shieldHealth} -= ($part->{'part'}->{shieldgen} * $timeMod);
				}
				# recover the passive part of shieldgen (substract because it is negative)
				$currentPowerGen -= $part->{'part'}->{powergen};
			} else { # shield is operational
				if ($part->{shieldHealth} < $part->{'part'}->{shield}){
					$currentPowerGen += $part->{'part'}->{'poweruse'};
					$part->{shieldHealth} += ($part->{'part'}->{shieldgen} * $timeMod);
					#TODO only send if it passes 0
					$self->addServerMsg('dam', { 
						'ship_id' => $self->{id},
						'id'      => $part->{id},
						'shield'  => $part->{shieldHealth}
						}
					);
				}
				if ($part->{shieldHealth} > $part->{'part'}->{shield}){
					$part->{shieldHealth} = $part->{'part'}->{shield};
				}
			}
			$shieldHealth += ($part->{shieldHealth} > 0 ? $part->{shieldHealth} : 0);
		}
	}

	$self->setStatus('shieldHealth', int($shieldHealth));
	$self->setStatus('currentHealth', $currentHealth);
	$self->setStatus('currentPowerGen', int($currentPowerGen));
	$self->addStatus('currentPower', ($currentPowerGen * $timeMod * 0.2));
	$self->_limitPower();
	$self->{lastPower} = time();
}

# TODO make a global list of statuses that are limited
sub _limitPower {
	my $self = shift;
	if ($self->{currentPower} > $self->{power}){
		$self->{currentPower} = $self->{power};
		$self->setStatus('currentPower', $self->{power});
	}
	if ($self->{currentPower} < 0){
		$self->setStatus('currentPower', 0);
	}
}

sub move {
	my $self = shift;
	if (!defined($self->{lastMove})){ $self->{lastMove} = time();}
	#if (time() - $self->{lastPower}) < 0.1)){ return 0; }
	my $time = time();
	my $timeMod = $time - $self->{lastMove};

	### paralyzed during warp
	if ($self->{warp}){ return 0; }

    my $xThrottle = 0;
    my $yThrottle = 0;

	if ($time - $self->{aimingPress} < 0.15){
		my $direction = $self->getStatus('direction') + (1 * $self->{aimingDir} * $timeMod);
		if ($direction > (PI * 2)){ $direction -= (PI * 2); }
		if ($direction < 0){ $direction += (PI * 2); }
		$self->setStatus('direction', $direction);
	}
    
    if ($time - $self->{movingHozPress} < 0.2){
        $xThrottle = $self->{movingHoz};
    } elsif ($self->getStatus('cruise')){
        $xThrottle = (sin($self->{direction}) * 0.7);
    }

    if ($time - $self->{movingVertPress} < 0.2){
        $yThrottle = $self->{movingVert};
    } elsif ($self->getStatus('cruise')){
        $yThrottle = (cos($self->{direction}) * 0.7);
    }

	$self->addStatus('x', $xThrottle * $self->{speed} * $timeMod);
	$self->addStatus('y', $yThrottle * $self->{speed} * $timeMod * $aspectRatio);
	$self->setStatus('movingHoz' , $xThrottle);
	$self->setStatus('movingVert', $yThrottle);

	$self->{lastMove} = $time;
}

sub purchasePart {
	my $self = shift;
	my $chr  = shift;
	if (!defined($parts{$chr})){
		return undef;
	}
	if ($parts{$chr}->{'cost'} > $self->getStatus('cash')){
		return undef;
	}
	$self->setStatus('cash', $self->getStatus('cash') - $parts{$chr}->{'cost'});
	$self->addSparePart($chr);
}

sub loadSparePart {
	my $self = shift;
	my ($chr, $x, $y) = @_;
	if (!$self->canLoadPart($chr, $x, $y)){
		return 0;
	}
	$self->useSparePart($chr);
	return $self->_loadPart($chr, $x, $y);
}

sub canLoadPart {
	my $self = shift;
	my ($chr, $x, $y) = @_;
	if (!$self->hasSparePart($chr)){ return 0; }
	return 1;
}

sub _loadPart {
	my $self = shift;
	my ($chr, $x, $y, $id) = @_;
	if ($x == 0 && $y == 0 && $chr ne 'X'){ return undef; } # cannot override command module
	$id = (defined($id) ? $id : $self->{idCount}++);
	$self->{parts}->{$id} = {
		'x' => $x,
		'y' => $y,
		'health' => $parts{$chr}->{health},
		'shieldHealth' => $parts{$chr}->{shield},
		'hit' => time(),
		'healing' => 0,
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
		push $self->{shieldsOnly}, $part;
	}
	return 1;
}

sub getParts {
	my $self = shift;
	return values %{ $self->{parts} };
}

sub getShieldParts {
	my $self = shift;
	return @{ $self->{shieldsOnly} };
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

### also build collision and part map here
sub _offsetByCommandModule {
	my $self = shift;
	# find command module and build new ship with connections
	my $cm = $self->getCommandModule();
	if (!$cm){ return 0; }

	my $offx = $cm->{x};
	my $offy = $cm->{y};
	foreach my $part ($self->getParts()){
		# ground parts to cm as 0,1
		$part->{x} -= $offx;
		$part->{y} -= $offy;
		$self->{collisionMap}->{$part->{x}}->{$part->{y}} = $part->{defchr};
		$self->{partMap}->{$part->{x}}->{$part->{y}} = $part->{id};
	}
}

sub _loadPartConfig {
	my $self = shift;
	my $config = shift;

	my $cfg = Config::IniFiles->new( -file => $config );
	my @sections = $cfg->Sections();
	### global options
	foreach my $section (@sections){
		my $chr = $cfg->val($section, 'ref');
		$parts{$chr}->{'chr'}    = $cfg->val($section, 'chr');
		if ($parts{$chr}->{'chr'} =~ m/^.+,/){
			my @aryChr = split(',', $parts{$chr}->{'chr'});
			$parts{$chr}->{'chr'} = \@aryChr;
		}
		$parts{$chr}->{'cost'}   = $cfg->val($section, 'cost', 0);
		$parts{$chr}->{'health'} = $cfg->val($section, 'health', 1);
		$parts{$chr}->{'weight'} = $cfg->val($section, 'weight', 1);
		$parts{$chr}->{'show'}   = $cfg->val($section, 'show', 1);
		my $color = $cfg->val($section, 'color', 'ship');
		$parts{$chr}->{'color'}  = ($color eq 'rainbow' || $color eq 'ship' ? $color : $color);
	}

	my @guns = $cfg->GroupMembers('gun');
	foreach my $section (@guns){
		my $chr = $cfg->val($section, 'ref');
		$parts{$chr}->{type} = 'gun';
		$parts{$chr}->{'poweruse'}    = $cfg->val($section, 'poweruse', -1);
		$parts{$chr}->{'damage'}      = $cfg->val($section, 'damage', 1);
		$parts{$chr}->{'bulletspeed'} = $cfg->val($section, 'bulletspeed', 20);
		$parts{$chr}->{'rate'}        = $cfg->val($section, 'rate', 0.3);
		$parts{$chr}->{'spread'}      = $cfg->val($section, 'spread', 0);
		$parts{$chr}->{'shotChr'}     = $cfg->val($section, 'shotChr', '.');
		if ($parts{$chr}->{'shotChr'} =~ m/^.+,/){
			my @aryChr = split(',', $parts{$chr}->{'shotChr'});
			$parts{$chr}->{'shotChr'} = \@aryChr;
		}
		$parts{$chr}->{'shotColor'}   = $cfg->val($section, 'shotColor', 'WHITE');
		$parts{$chr}->{'shipMomentum'}   = $cfg->val($section, 'shipMomentum', 0);
		my $quads = $cfg->val($section, 'quadrangs', '1,2,3,4,5,6,7,8');
		foreach my $q (split ',', $quads){
			$parts{$chr}->{'quadrants'}->{$q} = 1;
		}
	}

	my @lasers = $cfg->GroupMembers('laser');
	foreach my $section (@lasers){
		my $chr = $cfg->val($section, 'ref');
		$parts{$chr}->{type} = 'laser';
		$parts{$chr}->{'poweruse'}    = $cfg->val($section, 'poweruse', -1);
		$parts{$chr}->{'damage'}      = $cfg->val($section, 'damage', 1);
		$parts{$chr}->{'direction'}   = $cfg->val($section, 'direction', 4);
		$parts{$chr}->{'shotColor'}   = $cfg->val($section, 'shotColor', 'WHITE');
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
		$parts{$chr}->{'shield'}     = $cfg->val($section, 'shield', 10);
		$parts{$chr}->{'shieldgen'}  = $cfg->val($section, 'shieldgen', 0.5);
		$parts{$chr}->{'powergen'}   = $cfg->val($section, 'powergen', -2.5);
		$parts{$chr}->{'poweruse'}   = $cfg->val($section, 'poweruse', -4);
		$parts{$chr}->{'shieldsize'} = $cfg->val($section, 'shieldsize', 2);
		$parts{$chr}->{'shieldlight'} = $cfg->val($section, 'shieldlight', 2);
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

		# shield TODO poweruse needs to be seperated from gun poweruse
		$parts{$chr}->{'shieldsize'} = $cfg->val($section, 'shieldsize', undef);
		$parts{$chr}->{'shieldlight'} = $cfg->val($section, 'shieldlight', 2);
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
    #my ($shipParts, $shipModules) = split("MODULES\n", $ship);
    #my @shipLines = split("\n", $shipParts);
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

sub _installModule {
	my $self = shift;
	my $moduleName = shift;

	if ( $self->_hasModule($moduleName) ){
		return 0;
	}
	foreach my $module (@{$self->{modules}}){
		if ($module->name() eq $moduleName){

		}
	}
	return 1;
}

sub getModules {
	my $self = shift;
	return @{ $self->{modules} };
}

sub _hasModule {
	my $self = shift;
	my $moduleName = shift;

	foreach my $module (@{$self->{modules}}){
		if ($module->name() eq $moduleName){
			return 1;
		}
	}
	return 0;
}

sub _calculateParts {
	my $self = shift;
	$self->_offsetByCommandModule();
	$self->_setPartConnections();
	$self->_removeBlockedGunQuadrants();
}

sub _loadShipByMap {
	my $self  = shift;
	my $map   = shift;
    my $idMap = shift;
	$self->{parts} = {};
	$self->{collisionMap} = {};
	$self->{partMap} = {};
	
	foreach my $x (keys %{$map}){
		foreach my $y (keys %{$map->{$x}}){
			my $chr = $map->{$x}->{$y};
            if (defined($idMap)){
                my $id = $idMap->{$x}->{$y};
			    $self->_loadPart($chr, $x, $y, $id);
            } else {
			    $self->_loadPart($chr, $x, $y);
            }
		}
	}

	$self->_calculateParts();
	$self->_recalculate();
}

sub getPartDef {
	my $ship = shift;
	my $chr  = shift;
	return $parts{$chr};
}

sub getAllPartDefs {
	return \%parts;
}

sub _setPartConnections {
	my $self = shift;
	# TODO put command link calc here, start with command and work out
	foreach my $part ($self->getParts()){
		my $x = $part->{x};
		my $y = $part->{y};

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
			my $connectLevel = (defined($part->{'part'}->{boxtype}) ? $part->{'part'}->{boxtype} : 1);
			my $connectStr = 
				(defined($part->{connected}->{b}) ? 'b' : '') .
				(defined($part->{connected}->{l}) ? 'l' : '') .
				(defined($part->{connected}->{r}) ? 'r' : '') .
				(defined($part->{connected}->{t}) ? 't' : '') ;
			if ($connectors{$connectLevel}->{$connectStr}){
				$part->{'chr'} = $connectors{$connectLevel}->{$connectStr};
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
		# TODO do this here
		# calculate connections
#		if ($partInner->{x} == $x - 1 && $partInner->{y} == $y){
#			$part->{connected}->{l} = $partInner->{id};	
#		}
#		elsif ($partInner->{x} == $x + 1 && $partInner->{y} == $y){
#			$part->{connected}->{r} = $partInner->{id};	
#		}
#		elsif ($partInner->{x} == $x && $partInner->{y} - 1 == $y){
#			$part->{connected}->{b} = $partInner->{id};	
#		}
#		elsif ($partInner->{x} == $x && $partInner->{y} + 1 == $y){
#			$part->{connected}->{t} = $partInner->{id};	
#		}
#		if ($part->{'part'}->{'type'} eq 'plate'){
#			my $connectLevel = (defined($part->{'part'}->{boxtype}) ? $part->{'part'}->{boxtype} : 1);
#			my $connectStr = 
#				(defined($part->{connected}->{b}) ? 'b' : '') .
#				(defined($part->{connected}->{l}) ? 'l' : '') .
#				(defined($part->{connected}->{r}) ? 'r' : '') .
#				(defined($part->{connected}->{t}) ? 't' : '') ;
#			if ($connectors{$connectLevel}->{$connectStr}){
#				$part->{'chr'} = $connectors{$connectLevel}->{$connectStr};
#			}
#		}

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

sub getDisplayArray {
	my $self = shift;
	#my ($w, $h, $offset) = @_;
	my @shipArr;
	my $j = 5;
	foreach my $y ($self->{_yLow} - 3 .. $self->{_yHigh} + 3){
		my $i = 5;
		foreach my $x ($self->{_xLow} - 3 .. $self->{_xHigh} + 3){
			my $chr = $self->{collisionMap}->{$x}->{$y};
			if (!defined($chr)){ $chr = ' ';}
			$shipArr[$j][$i] = $chr;
			$i++;
		}
		$j++;
	}
	return \@shipArr;
}

# TODO VERY SLOW, redo with collision map
sub getShipDisplay {
	my $self = shift;	
	my $design = shift;
	my $shipStr = "";
    foreach my $x ($self->{_xLow} - 3 .. $self->{_xHigh} + 3){
	    foreach my $y ($self->{_yLow} - 3 .. $self->{_yHigh} + 3){
			my $chr = ' ';
				foreach my $part ($self->getParts()){
					if ($part->{x} == $y && $part->{y} == $x){
						if ($design){
							$chr = $part->{defchr};
						} else {
							$chr = (ref($part->{chr}) eq 'ARRAY' ? $part->{chr}->[0] : $part->{chr});
						}
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
