#!/usr/bin/perl
#
#
#
use strict; use warnings;
package SpaceShip;
use Term::ANSIColor 4.00 qw(RESET color :constants256);
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval nanosleep time);
use Data::Dumper;
use Config::IniFiles;
use Math::Trig ':radial';
use ShipModule;
use Taunts;

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

	my @allowedColors = qw(red  green  yellow  blue  magenta  cyan  white);
	$self->{allowedColors} = \@allowedColors;

	$self->{color} = color((defined($options->{color}) ? $options->{color} : 'RGB113'));
	$self->{colorDef} = ((defined($options->{color}) ? $options->{color} : 'RGB113'));
	$self->{cash} = 0;
	$self->{debug} = 'ship debug msgs';

	$self->{'aspectRatio'} = $aspectRatio;

	$self->{'design'} = $shipDesign;
    $self->{'controls'} = (defined($options->{'controls'}) ? $options->{'controls'} : 'a');
 
	$self->{'x'} = $x;	
	$self->{'y'} = $y;	
	$self->{'direction'} = PI;
	$self->{'id'} = $id;
	$self->{'lastTauntTime'} = 0;

	my $shipModule = ShipModule->new();
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
	$self->{'idCount'} = 0;
	$self->{'radar'} = 0;
	$self->{'cloaked'} = 0;
	$self->{'aiTick'} = time();
	$self->{'isBot'} = 0;

    $self->{'_spareParts'} = {};

	$self->{'statusChange'} = {}; #register changes in status to broadcast to clients
	$self->{'_shipMsgs'}    = []; #register any msg that needs to broadcas

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
	$self->_calculateHitBox();
	$self->{shieldHealth} = $self->{shield};
	$self->{currentHealth} = $self->{health};
	$self->{shieldsOn} = 1;
	$self->{empOn} = 1;
	$self->{'shieldStatus'} = 'full';
	
	return 1;
}

sub randomBuild {
	my $self = shift;
	my $cash = shift;
	
	my @trees = (
		{ x => 1, y => 0, dir => 'x', 'vector' => 1 }
	);
	my $continue = 1;
	while($continue){
		# build structure;
		foreach my $tree (@trees){
			$self->_loadPart('-', $tree->{x}, $tree->{y});
			$self->_loadPart('-', -$tree->{x}, $tree->{y});
			$tree->{$tree->{dir}} += $tree->{vector};
			if (rand() < 0.3){
				$tree->{dir} = ($tree->{dir} eq 'x' ? 'y' : 'x');
				if (($tree->{dir} eq 'y') && (rand() < 0.5)){
					push(@trees, { x => $tree->{x}, y => $tree->{y}, dir => 'y', 'vector' => -$tree->{vector} });
				}
			}
		}
		if (rand() < 0.3){ $continue = 0; }
	}
	$self->_recalculate();
	
}

sub calculateDrops {
    my $self = shift;

    my %xy = ();

    my @drops = ();
    if (rand() < 0.5){
        push @drops, {
            cash => int($self->{cash}),
            'chr'  => color('green ON_RGB121') . '$' . color('reset')
        };
    }
    if (rand() < 0.1){
        my @modules = $self->getModules();
        my $module = $modules[rand($#modules)];
        push @drops, {
            'module' => $module->name(),
            'chr'    => $module->getDisplay()
        };
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
	$self->{aiMode} = 'explore';
	$self->{aiState} = 'random';
	$self->{aiModeChange} = 0;
	$self->{aiStateChange} = 0;
	$self->{aiTowardsShipId} = 0;
	$self->{isBot} = 1;
    $self->{cash} = int($self->{cost} * rand() / 8);
	$self->{faction} = $self->getRandomFaction();
	$self->setAiColor();
}

sub getRandomFaction {
	my $self = shift;
	my @factions = (
		'communist',
		'nihilist',
		'imperialist',
		'zealot'
	);
	return $factions[rand @factions];
}

sub _setColor {
	my $self = shift;
	my $color = shift;
	if (!$self->isValidColor($color)){ return 0; }
	$self->{'colorDef'} = $color;
	$self->{'color'} = color($color);
	return 1;
}

sub getColorName {
	my $self = shift;
	return $self->{colorDef};
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
			$self->{currentPower} += $part->{'part'}->{poweruse};
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
				'chr'   => ($self->getStatus('emp') ? color('bold blue') : color($part->{'part'}->{'shotColor'}))
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
	$self->_setPartConnections();
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
		if ($part->{'x'} < $self->{'_xLow'}){ $self->{'_xLow'} = $part->{'x'}; }
		if ($part->{'y'} < $self->{'_yLow'}){ $self->{'_yLow'} = $part->{'y'}; }
		# TODO aspect ratio
		if (defined($part->{'shieldsize'})){
			if ($part->{'x'} > $self->{'_xHighShield'} + $part->{'shieldsize'}){ $self->{'_xHighShield'} = $part->{'x'}; }
			if ($part->{'y'} > $self->{'_yHighShield'} + $part->{'shieldsize'}){ $self->{'_yHighShield'} = $part->{'y'}; }
			if ($part->{'x'} < $self->{'_xLowShield'} - $part->{'shieldsize'} ){ $self->{'_xLowShield'} = $part->{'x'}; }
			if ($part->{'y'} < $self->{'_yLowShield'} - $part->{'shieldsize'} ){ $self->{'_yLowShield'} = $part->{'y'}; }
		}
	}

}

sub isInHitBox {
	my $self = shift;
	my ($x, $y) = @_;
	return ($y >= $self->{'_yLow'} && $y <= $self->{'yHigh'} && $y >= $self->{'_yLow'} && $y <= $self->{'yHigh'});
}

sub isInShieldHitBox {
	my $self = shift;
	my ($x, $y) = @_;
	return ($y >= $self->{'_yLowShield'} && $y <= $self->{'yHighShield'} && $y >= $self->{'_yLowShield'} && $y <= $self->{'yHighShield'});
}


sub resolveCollision {
	my $self = shift;
	my $bullet = shift;
	if ($bullet->{ship_id} == $self->{id}){ return 0; }

#	my $bx = int($bullet->{x} - $self->{y});
#	my $by = int($bullet->{y} - $self->{x});
#	my $partId = $self->{partMap}->{$bx}->{$by};
#	if (!defined($partId)){ return 0; }
#	my $part = $self->getPartById($partId);
#	$part->{'health'} -= $bullet->{damage};
#	$part->{'hit'} = time();
#	return { id => $part->{id}, health => $part->{health} };

	my $partsRemoved = 0;

	### loop through shields first on their own
	foreach my $part ($self->getParts()){
		if (!($part->{'part'}->{'type'} eq 'shield')){
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

	### now to damage any part
	foreach my $part ($self->getParts()){
		# x and y got mixed somehow, don't worry about it
		my $px = int($part->{y} + $self->{y});
		my $py = int($part->{x} + $self->{x});

		my $distance = sqrt(
			(( ($px - $bullet->{x}) / ASPECTRATIO) ** 2) +
			(($py - $bullet->{y}) ** 2)
		);

		if ((abs($bullet->{y} - $py) < 1.5 ) &&
		    (abs($bullet->{x} - $px) < 1.5 )){
            if ($self->getStatus('dodge') && rand() < 0.3){
                return { 'deflect' => 1 }
            }
            if ($self->isBot()){
                $self->changeAiMode('attack', 'aggressive');
                $self->setAiTarget($bullet->{id});
            }
			$part->{'hit'} = time();
            if ($bullet->{emp}){
                $self->{currentPower} -= $bullet->{damage};
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
	foreach my $part ($self->getParts()){
		$part->{'hit'} = time() + $duration;
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
		$self->setStatus('taunt', Taunts::getTaunt($self->{faction}, $mode));
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

sub setAiTarget {
	my $self = shift;
	my $targetId = shift;

	$self->{_aiVars}->{target} = $targetId;
}

sub getAiTarget {
	my $self = shift;

	return $self->{_aiVars}->{target};
}

sub clearAiTarget {
	my $self = shift;
	delete $self->{_aiVars}->{target};
}

sub setPartHealth {
	my $self = shift;
	my ($partId, $health) = @_;
	my $part = $self->getPartById($partId);
	if ($health < 0){
		$self->_removePart($partId);
		return 1;
	}
    if ($part->{health} > $health){
	    $part->{'hit'} = time();
    } elsif ($part->{health} < $health) {
	    $part->{'healing'} = time();
    }  
	$part->{health} = $health;
	return 0;
}

# TODO have server periodically send out shield health for regen
sub damageShield {
	my $self = shift;
	my ($partId, $health) = @_;
	my $part = $self->getPartById($partId);
	### it lost health, so it was hit
	if ($part->{shieldHealth} > $health){
		$part->{'hit'} = time();
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
	print "Remove part id $id\n";
	$self->_removePart($id, $preserve);
}

sub getPartIdByLocation {
	my $self = shift;
	my ($x, $y, $preserve) = @_;
	return $self->{partMap}->{$x}->{$y};
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

sub setStatus {
	my $self = shift;
	my $status = shift;
	my $value = shift;

	if ($status eq 'taunt'){
		$self->{'lastTauntTime'} = time();
	}

	if ($status eq 'light'){
		$self->lightShip($value);
	} elsif($status eq 'color'){
		if ($self->_setColor($value)){
			$self->{'statusChange'}->{$status} = $value;
		}
		return 1; # do not let default change {color}, which is color($color)
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
        $self->addServerInfoMsg("Found $cash credits.");
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
	$self->{_spareParts}->{$chr}--;
	$self->addServerMsg('sparepart',
		{ 'ship_id' => $self->{id}, 'part' => $chr, 'use' => 1}
	);
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
		{ 'user' => '<SYSTEM>', 'msg' => $msgInfo, 'color' => 'green' },
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

	# if the thrusters are activated
	if ($self->{movingHoz} != 0 || $self->{movingVert} != 0){
		if (int($self->{currentPower} < 2)){
			$self->{currentPowerGen} = $self->{powergen};
			$self->{moving} = 0;
		} else {
			$self->{currentPowerGen} = $self->{powergen} - sprintf('%.2f', ($self->{thrust} / 100));
		}
	} else {
		$self->{currentPowerGen} = $self->{powergen};
	}

	$self->{currentPowerGen} += $self->_resolveModulePower();
	
	$self->{shieldHealth} = 0;
	$self->{currentHealth} = 0;
	# if shields are regenerating
	foreach my $part ($self->getParts()){
		$self->{currentHealth} += ($part->{health} > 0 ? $part->{health} : 0);
		if ($part->{'part'}->{'type'} eq 'shield'){
			if (($self->{currentPower} / $self->{power} < 0.2) || !$self->{shieldsOn}){
				# drain shields if power is low and they are on
				if ($self->{shieldsOn}){
					$part->{shieldHealth} -= ($part->{'part'}->{shieldgen} * $timeMod);
				}
				# recover the passive part of shieldgen (substract because it is negative)
				$self->{currentPowerGen} -= $part->{'part'}->{powergen};
			} else { # shield is operational
				if ($part->{shieldHealth} < $part->{'part'}->{shield}){
					$self->{currentPowerGen} += $part->{'part'}->{'poweruse'};
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
			$self->{shieldHealth} += ($part->{shieldHealth} > 0 ? $part->{shieldHealth} : 0);
		}
	}

	$self->{currentPower} += ($self->{currentPowerGen} * $timeMod * 0.2);
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
	my $time = time();
	my $timeMod = $time - $self->{lastMove};

	if ($time - $self->{aimingPress} < 0.15){
		$self->{direction} += (1 * $self->{aimingDir} * $timeMod);
		if ($self->{direction} > (PI * 2)){ $self->{direction} -= (PI * 2); }
		if ($self->{direction} < 0){ $self->{direction} += (PI * 2); }
	}
	
	if ($time - $self->{movingHozPress} < 0.2){
		$self->{x} += ($self->{movingHoz} * $self->{speed} * $timeMod);
	} else {
		$self->{movingHoz} = 0;
	}
	if ($time - $self->{movingVertPress} < 0.2){
		$self->{y} += ($self->{movingVert} * $self->{speed} * $timeMod * $aspectRatio);
	} else {
		$self->{movingVert} = 0;
	}
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
		#push $self->{shieldsOnly}, $part->{id};
	}
	return 1;
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
		$self->{collisionMap}->{$part->{x}}->{$part->{y}} = $part->{defchr};
		$self->{partMap}->{$part->{x}}->{$part->{y}} = $part->{id};
	}
}

sub _loadPartConfig {
	my $self = shift;
	my $config = shift;

	my $cfg = Config::IniFiles->new( -file => $config );
	my @sections = $cfg->Sections();
	foreach my $section (@sections){
		my $chr = $cfg->val($section, 'ref');
		$parts{$chr}->{'chr'}    = $cfg->val($section, 'chr');
		$parts{$chr}->{'cost'}   = $cfg->val($section, 'cost', 0);
		$parts{$chr}->{'health'} = $cfg->val($section, 'health', 1);
		$parts{$chr}->{'weight'} = $cfg->val($section, 'weight', 1);
		my $color = $cfg->val($section, 'color', 'ship');
		$parts{$chr}->{'color'}  = ($color eq 'rainbow' || $color eq 'ship' ? $color : color($color));
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
		$parts{$chr}->{'size'}       = $cfg->val($section, 'size', 'medium');
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
	my ($shipParts, $shipModules) = split("MODULES\n", $ship);
	my @shipLines = split("\n", $shipParts);
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
				$part->{'chr'} = $connectors{1}->{$connectStr};
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
	foreach my $y ($self->{bottommost} - 3 .. $self->{topmost} + 3){
		my $i = 5;
		foreach my $x ($self->{leftmost} - 3 .. $self->{rightmost} + 3){
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
	foreach my $x ($self->{bottommost} .. $self->{topmost}){
		foreach my $y ($self->{leftmost} .. $self->{rightmost}){
			my $chr = ' ';
				foreach my $part ($self->getParts()){
					if ($part->{x} == $y && $part->{y} == $x){
						if ($design){
							$chr = $part->{defchr};
						} else {
							my $partcolor = ($part->{part}->{color} eq 'rainbow' ? color('MAGENTA ON_RGB112') : $part->{part}->{color});
							#$chr = $self->{color} . $partcolor . $part->{chr} . color('reset');
							$chr = $part->{chr} . color('reset');
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
