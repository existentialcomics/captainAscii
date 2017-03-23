#!/usr/bin/perl
#
#
#
use strict; use warnings;
package SpaceServer;
use Term::ANSIColor 4.00 qw(RESET color :constants256);
require Term::Screen;
use List::MoreUtils qw(zip);
use SpaceShip;
use Storable;
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval nanosleep time);
use Data::Dumper;
use JSON::XS qw(encode_json decode_json);
use Math::Trig ':radial';
use CaptainAscii::Zones;
use CaptainAscii::Factions;

use IO::Socket::UNIX;
use constant {
	ASPECTRATIO => 0.66666666,
	PI          => 3.1415,
	LEFT        => -200,
	RIGHT       => 200,
	TOP         => -200,
	BOTTOM      => 200
};

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
	my $socket = shift;
	my $options = shift;
	print "socket: $socket \n";

	my @allowedColors = qw(red  green  yellow  blue  magenta  cyan  white);
	$self->{colors} = \@allowedColors;
	
	$self->_bindSocket($socket);
	$self->{ships} = [];
	$self->{shipIds} = 1;
	$self->{zoneIds} = 1;
	$self->{lastTime} = 0;
	$self->{bullets} = {};
	$self->setLevel(300);
	$self->{shipDensity} = 5;
	$self->{highestEnemy} = 1;
	if (defined($options->{maxInitialCost})){
		$self->{maxInitialCost} = $options->{maxInitialCost};
	}

	$self->{lastPlayerColor} = 'green';

	$self->{zones} = [];
	$self->_spawnZones();

	return 1;
}

sub _spawnZones {
	my $self = shift;
	if (!defined($self->{_leftmostZone})){ $self->{_leftmostZone} = 0; }
	if (!defined($self->{_rightmostZone})){ $self->{_rightmostZone} = 0; }
	if (!defined($self->{_topmostZone})){ $self->{_topmostZone} = 0; }
	if (!defined($self->{_bottommostZone})){ $self->{_bottommostZone} = 0; }

    foreach my $ship ($self->getHumanShips()){
        if ($ship->{x} > $self->{_rightmostZone}){
			print "$ship->{x} < $self->{_rightmostZone}\n";
            my $zoneX = $ship->{x} - 200;
            my $zoneY = $ship->{y};
			$self->addZone($zoneX, $zoneY);
        }
        if ($ship->{x} < $self->{_leftmostZone}){
			print "$ship->{x} < $self->{_leftmostZone}\n";
            my $zoneX = $ship->{x} + 200;
            my $zoneY = $ship->{y};
			$self->addZone($zoneX, $zoneY);
        }
        if ($ship->{y} < $self->{_topmostZone}){
			print "$ship->{y} < $self->{_topmostZone}\n";
            my $zoneX = $ship->{x};
            my $zoneY = $ship->{y} - 200;
			$self->addZone($zoneX, $zoneY);
        }
        if ($ship->{y} > $self->{_bottommostZone}){
			print "y: $ship->{y} < b:$self->{_bottommostZone}\n";
            my $zoneX = $ship->{x};
            my $zoneY = $ship->{y} + 200;
			$self->addZone($zoneX, $zoneY);
        }
    }
    $self->calculateZoneSpace();
}

sub addZone {
	my $self = shift;
	my ($zoneX, $zoneY) = @_;
	print " **** adding zone at $zoneX, $zoneY\n";
	$self->sendSystemMsg("adding zone at $zoneX, $zoneY");
	push $self->{zones}, CaptainAscii::Zones->new(
		{ 
			id => $self->{zoneIds}++ ,
			x => $zoneX,
			y => $zoneY
		});
}

sub calculateZoneSpace {
    my $self = shift;
    foreach my $zone ($self->getZones()){
        if ($zone->getLeft() < $self->{_leftmostZone}){ $self->{_leftmostZone} = $zone->getLeft(); }
        if ($zone->getRight() > $self->{_rightmostZone}){ $self->{_rightmostZone} = $zone->getRight(); }
        if ($zone->getTop() < $self->{_topmostZone}){ $self->{_topmostZone} = $zone->getTop(); }
        if ($zone->getBottom() > $self->{_bottommostZone}){ $self->{_bottommostZone} = $zone->getBottom(); }
    }
}

sub getZones {
    my $self = shift;
    return @{$self->{zones}};
}

sub getColorById {
	my $self = shift;
	my $id = shift;
	return $self->{colors}->[ $id % scalar @{$self->{colors}} ];
}

sub getNextPlayerColor {
	my $self = shift;
}

sub getEnemyDesign {
	my $self = shift;
	my $level = shift;
	return $self->{enemies}->{$level}->[
		rand($#{ $self->{enemies}->{$level} } + 1)
		];
}

sub addEnemyDesign {
	my $self = shift;
	my $level = shift;
	if ($level > $self->{highestEnemy}){
		$self->{highestEnemy} = $level;
	}
	my $shipDesign = shift;
	push @{ $self->{enemies}->{$level} }, $shipDesign;
}

sub _bindSocket {
	my $self = shift;
	my $SOCK_PATH = shift;
	$self->{server} = IO::Socket::UNIX->new(
		Type => SOCK_STREAM(),
		Local => $SOCK_PATH,
		Listen => 1,
		Blocking => 0,
	) or die "failed to open socket $SOCK_PATH";

	chmod 0777, $SOCK_PATH;
	$self->{server}->blocking(0);

	return 1;
}

sub loop {
	my $self = shift;

	$self->{lastTime}  = time();
	my $lastFrame = time();
	my $frames = 0;
	my $time = time();
	my $fps = 50;
	$self->{shipSend} = 0;

	while (1){
		my $frametime = time() - $time;
		if ($frametime < (1 / $fps)){
			usleep(1_000_000 * ((1 / $fps) - $frametime));
			next;
		}
		$self->{lastTime} = $time;
		$time = time();
		$frames++;
		if ($time - $lastFrame > 1){
			$lastFrame = $time;
			#print "fps: $frames\n";
			#$self->{shipSend} = 0;
			$frames = 0;
		}

		$self->_ai();
		$self->_loadNewPlayers();
		$self->_calculateBullets();
		$self->_calculateItems();
        #TODO remove this, everything should be triggered
		$self->_sendShipsToClients();
		$self->_calculatePowerAndMovement();
		$self->_recieveInputFromClients();
		$self->_sendShipStatuses();
		$self->_sendShipMsgs();
        if ($self->timerCheck('spawn', 2)){
		    $self->_spawnShips();
		    $self->_despawnShips();
			$self->_spawnZones();
            $self->assignZones();
        }
	}
}

sub _sendShipStatuses {
	my $self = shift;

	foreach my $ship ($self->getShips()){
		foreach my $msg ($ship->getStatusMsgs()){
			$self->broadcastMsg('shipstatus', $msg);
		}
		$ship->clearStatusMsgs();
	}
}

sub _sendShipMsgs {
	my $self = shift;

	foreach my $ship ($self->getShips()){
		foreach my $msg ($ship->getServerMsgs()){
			if ($msg->{'_playerOnly'}){
				$self->sendMsg($ship, $msg->{category}, $msg->{msg});
			} else {
				$self->broadcastMsg($msg->{category}, $msg->{msg});
			}
		}
		$ship->clearServerMsgs();
	}
}

# remove ships that are too far away from any player
sub _despawnShips {
	my $self = shift;
	my @shipsToDespawn = ();
	foreach my $ship ($self->getShips()){
		next if(!$ship->isBot());
		my ($id, $distance, $dir) = $self->_findClosestShip(
			$ship->{'x'},
			$ship->{'y'},
			{ 'skipId' => $ship->{'id'}, isBot => 0 }
		);
		if ($distance > 200){
			print "$ship->{id} dis $distance\n";
			push(@shipsToDespawn, $ship->{id});
		}
	};

	foreach my $id (@shipsToDespawn){
		print "despawning $id\n"; 
		$self->broadcastMsg('shipdelete', { id => $id });
		$self->removeShip($id);
	}
}

### checks if a sub is ready to be run in the loop
sub timerCheck {
	my $self = shift;
    my $action = shift;
    my $time = shift;
    if (!defined($self->{_t}->{$action})){
        $self->{_t}->{$action} = time() + $time;
        return 1;
    }
    if (time() < $self->{_t}->{$action}){
        return 0;
    }
    $self->{_t}->{$action} = time() + $time;
    return 1;
}

sub assignZones {
    my $self = shift;
	foreach my $ship ($self->getHumanShips()){
        $ship->resetZones();
        foreach my $zone ($self->getZones()){
            if ($zone->inZone($ship->{x}, $ship->{y})){
                $ship->addZone($zone);
            }
        }
        $ship->finishZonesAdd();
    }
}

sub setLevel {
	my $self = shift;
	my $level = shift;
	$self->{level} = $level;
	$self->{defaultSpawns} = [
		{'faction' => 'imperialist' , 'power' => $level * 1},
		{'faction' => 'imperialist' , 'power' => $level * 1},
		{'faction' => 'imperialist' , 'power' => $level * 1.2},
		{'faction' => 'imperialist' , 'power' => $level * 3},
		{'faction' => 'communist' , 'power' => $level * 1},
		{'faction' => 'communist' , 'power' => $level * 1},
		{'faction' => 'communist' , 'power' => $level * 1},
		{'faction' => 'communist' , 'power' => $level * 2},
		{'faction' => 'nihilist' , 'power' => $level * 1},
		{'faction' => 'nihilist' , 'power' => $level * 1},
		{'faction' => 'nihilist' , 'power' => $level * 1},
		{'faction' => 'nihilist' , 'power' => $level * 1.5},
		{'faction' => 'nihilist' , 'power' => $level * 5},
		{'faction' => 'zealot' , 'power' => $level * 1.2},
		{'faction' => 'zealot' , 'power' => $level * 3},
		{'faction' => 'alien' , 'power' => $level * 5},
	];
}

### also sets the radar
sub _spawnShips {
	my $self = shift;

	foreach my $ship ($self->getHumanShips()){
		$self->setRadar($ship, 200);
		if ($ship->{radarCount} < $self->{shipDensity} + $ship->getZoneSpawnRate()){
			my $rand = rand();
			my $level = $self->{level};
			if ($rand < 0.2){
				$level *= 3;
			}
			my $newShipDesign = $self->getEnemyDesign($level);
			my $dir = rand(PI * 2);
			my $newX = $ship->{x} + (cos($dir) * 50);
			my $newY = $ship->{y} + (sin($dir) * 50);
			my $shipNew = SpaceShip->new('X', $newX, $newY, $self->{shipIds}++);

            my @spawnArray = @{$self->{defaultSpawns}};
            push @spawnArray, $ship->getZoneSpawns();

            my $spawn = $spawnArray[rand @spawnArray];
			print "Adding enemy $spawn->{faction} ($spawn->{power}), at $newX, $newY\n";

		    $shipNew->{faction} = $spawn->{faction};
			$shipNew->randomBuild($spawn->{power});
			$shipNew->becomeAi();
			$shipNew->{conn} = undef;
			$self->broadcastMsg('newship', {
				'design' => $newShipDesign,
				'x' => $shipNew->{x},
				'y' => $shipNew->{y},
				'id' => $shipNew->{id},
				'ai' => 1,
				#'map' => $oldShip->{collisionMap},
				'options' => { color => $shipNew->getColorName() }
			});
			$shipNew->_recalculate();
			my $chrMap  = $shipNew->{collisionMap};
			my $partMap = $shipNew->{partMap};
			my $msg = {
				'ship_id'  => $shipNew->{id},
				'chr_map'  => $chrMap,
				'part_map' => $partMap
			};
			$self->broadcastMsg('shipchange', $msg);

			$self->addShip($shipNew);
		}
	}
}

sub setRadar {
	my $self = shift;
	my $ship = shift;
	my $range = shift;

	$ship->{radar} = {};
	$ship->{radarCount} = 0;
	
	foreach my $innerShip ($self->getShips()){ 
		next if ($innerShip->{id} eq $ship->{id});
		my ($rho, $theta, $phi) = $self->_findShipDistanceDirection($ship->{x}, $ship->{y}, $innerShip, { ship_id => $ship->{id} });
		if ($rho < $range){
			$ship->{radar} = {
				'distance' => $rho,
				'dir'  => $theta,
				'ship' => $ship->{id},
				'bot'  => $ship->isBot(),
                'faction' => $ship->{faction}
			};
			$ship->{radarCount}++;
		}
	}
}

sub _ai {
	my $self = shift;
	my $time = time();
	foreach my $ship ($self->getShips()){
		next if (!$ship->{isBot});
		my ($mode, $state) = $ship->getAiModeState();
		my $modeDiff  = $time - $ship->{aiModeChange};
		my $tickDiff = $time  - $ship->{aiTick};
		
		my ($id, $distance, $dir);
		my $aiTargetId = $ship->getAiVar('target');
		#if ($aiTargetId){
		if (0 == 1){
			my $targetShip = $ship->getShipById($aiTargetId);
			if (defined($targetShip)){
				$id = $aiTargetId;
				my ($rho, $theta, $phi) = $self->_findShipDistanceDirection(
					$ship->{'x'},
					$ship->{'y'},
					$ship
				);
				$distance = $rho;
				$dir = $theta;
			} else {
				$ship->clearAiVar('target');
			}
		} else {
			($id, $distance, $dir) = $self->_findClosestShip(
				$ship->{'x'},
				$ship->{'y'},
				{ 'skipId' => $ship->{'id'} }
			);
		}
		if ($id eq '-1'){
			$ship->changeAiMode('explore');
		} else {
			if ($distance < 20){
				$ship->changeAiMode('attack', 'passive');
				$ship->setAiVar('target', $id);
			}
		}
		if ($mode eq 'explore'){
			if ($ship->aiStateRequest(4, 'directionChange')){
				my $move = rand(2 * PI);
				$ship->{movingHoz}  = sin($move) * .3;
				$ship->{movingVert} = cos($move) * .3;
			}
			$ship->{movingHozPress} = time();
			$ship->{movingVertPress} = time();
		} elsif ($mode eq 'attack'){
			if (!defined($ship->{aiState})){
				$ship->{aiState} = 'aggressive';
			}
			if ($modeDiff > 2 && $ship->{aiState} eq 'aggressive'){
				#print "changing $ship->{id} to passive\n";
				$ship->{aiState} = 'passive';
			}
			if ($modeDiff > 5){
				#print "changing $ship->{id} to explore\n";
				$ship->{aiModeChange} = $time;
				$ship->{aiMode} = 'explore';
			}
			if ($id ne '-1'){
				if ($distance < 30){
					$ship->{direction} = $dir + (rand(.3) - .15);
					if ($ship->{aiState} eq 'aggressive'){
						if ($ship->aiStateRequest(rand(), 'shoot')){
							$ship->{shooting} = time();
						}
					} else {
						if ($ship->aiStateRequest(2, 'shoot')){
							$ship->{shooting} = time();
						}
					}
					if ($ship->aiStateRequest(1, 'move')){
						my $move = $dir + (rand() < .5 ? (PI / 2) : -(PI / 2));
						my $factor = ($state eq 'aggressive' ? .4 : .1);
						$ship->{movingHoz}  = sin($move) * $factor;
						$ship->{movingVert} = cos($move) * $factor;
						if (rand() < .8){
							$ship->{movingHozPress} = time() + rand();
							$ship->{movingVertPress} = time() + rand();
						}
					}
				} else {
					if ($ship->aiStateRequest('1', 'pursue')){
						my $move = $dir + (rand(.3) - .15);
						my $factor = ($state eq 'aggressive' ? .7 : .2);
						$ship->{movingHoz}  = sin($move) * $factor;
						$ship->{movingVert} = cos($move) * $factor;
					}
					$ship->{movingHozPress} = time();
					$ship->{movingVertPress} = time();
				}
			}
		} elsif ($mode eq 'flee'){
			if ($ship->aiStateRequest('1', 'pursue')){
				my $move = $dir + (rand(.3) - .15);
				my $factor = 0.8;
				$ship->{movingHoz}  = -sin($move) * $factor;
				$ship->{movingVert} = -cos($move) * $factor;
			}
			$ship->{movingHozPress} = time();
			$ship->{movingVertPress} = time();
		} else {
			print "NULL ai mode\n";
		}
		#print "$ship->{id} - $id, $distance, $dir\n";
		#print "mode: $ship->{aiMode}\n";
	}
}

sub _aiDodge {
	my $self = shift;
	my $ship = shift;
	if (time() - $ship->{aiModeChange} > 2){
		$ship->{direction} = rand(2 * PI);
		$ship->{aiModeChange} = time();
	}
}

sub _findClosestShip {
	my $self = shift;
	my ($x, $y, $options) = @_;
	my $smallestDistance = 999999999;
	my $id = -1;
	my $dir = 0;

	my @skipFactions = ('store');
	if ($options->{skipFactions}){
		push @skipFactions, split(',', $options->{skipFactions});
	}

	foreach my $ship ($self->getShips()){
		if (defined($options->{skipId})){
			next if ($ship->{id} eq $options->{skipId});
		}
		if (defined($options->{isBot})){
			next if ($options->{isBot} ne $ship->isBot());
		}
		if ($options->{ignore_cloaked}){
			next if (
				$ship->{cloaked} 
				#&& !( $ship->{shieldsOn} && $ship->{shieldHealth} > 0) # TODO  uncomment
				&& (time() - $ship->{shooting} > 3)
			);
		}
		foreach my $skipFaction (@skipFactions){
			next if $ship->getStatus('faction') eq $skipFaction;
		}
		my ($rho, $theta, $phi) = $self->_findShipDistanceDirection($x, $y, $ship);
		if ($rho < $smallestDistance){
			$smallestDistance = $rho;
			$dir = $theta;
			$id = $ship->{id};
		}
	}
	return ($id, $smallestDistance, $dir);
}

sub _findShipDistanceDirection {
	my $self = shift;
	my ($x, $y, $ship) = @_;

	my $dy = ($ship->{x} - $x) * ASPECTRATIO;
	my $dx = ($ship->{y} - $y);
	my ($rho, $theta, $phi)   = cartesian_to_spherical($dx, $dy, 0);
	# rho is distance, theta is direction
	return ($rho, $theta, $phi);
}

sub getShips {
	my $self = shift;

	return @{ $self->{ships} };
}

sub getHumanShips {
	my $self = shift;

	return grep { !$_->isBot() } @{ $self->{ships} };
}

sub getBotShips {
	my $self = shift;

	return grep { $_->isBot() } @{ $self->{ships} };
}

sub getShipCount {
	my $self = shift;
	return scalar $self->getShips();
}

sub getShipById {
	my $self = shift;
	my $id = shift;
	foreach my $ship ($self->getShips){
		if ($ship->{id} eq $id){ return $ship }
	}
	return undef
}

sub removeShip {
	my $self = shift;
	my $id = shift;

    my @ships = grep { $_->{id} != $id } $self->getShips();
						
	$self->{ships} = \@ships; 
}

sub addShip {
	my $self = shift;
	my $ship = shift;
	$ship->{lastMsg} = time();

	push @{ $self->{ships} }, $ship;
	my $id = $#{ $self->{ships} } + 1;

	### this is so the connect stays alive after we remove the ship
	# so the client doesn't crash
	$self->{shipConn}->{$id} = $ship->{conn};
	return $id;
}

### transmit a msg to the clients
sub sendMsg {
	my $self = shift;
	my ($ship, $category, $data) = @_;
	if (!$ship->{conn}){ return 0; }
	my $msg = {
		c => $category,
		d => $data
	};
	syswrite($ship->{conn}, (JSON::XS::encode_json($msg)) . "\n");
}

sub broadcastMsg {
	my $self = shift;
	my ($category, $data) = @_;
	foreach my $ship ($self->getShips()){
        if (!$ship->isBot()){
		    $self->sendMsg($ship, $category, $data);
        }
	}
}

sub _loadNewPlayers {
	my $self = shift;

    if (defined( my $conntmp = $self->{server}->accept())){
		my $newShipDesign = '';
		my $waitShip = 1;
		print "new ship entering...\n";
		my %options = ();
		while ($waitShip){
			while(my $line = <$conntmp>){
				if ($line =~ /DONE/){
					$waitShip = 0;
					last;
				} elsif ($line =~ m/^OPTION:(.+)=(.+)$/){
					print "option: $1 = $2\n";
					$options{$1} = $2;
				} else {
					$newShipDesign .= $line;
				}
			}
		}
		print "$newShipDesign\n";
		#if (!defined($options{color})){
			$options{color} = $self->getColorById($self->{shipIds} + 1);
			print "color from id " . ($self->{shipIds} + 1 ) . ": $options{color}\n";
		#}

		my $shipNew = SpaceShip->new($newShipDesign, rand(100) - 50, rand(100) - 50, $self->{shipIds}++, \%options);
		foreach my $ship ($self->getShips()){
			$self->sendMsg($ship, 'newship', {
				design => $newShipDesign,
				x => $shipNew->{x},
				y => $shipNew->{y},
				id => $shipNew->{id},
				options => \%options,
			});
		}
		$conntmp->blocking(0);
		$conntmp->autoflush(1);
		$shipNew->{conn} = $conntmp;

		if (defined($self->{maxInitialCost})){
			if ($shipNew->{cost} > $self->{maxInitialCost}){
				$self->sendMsg($shipNew, 'exit', { msg => "Your ship exceeds the maximum cost of $self->{maxInitialCost}" });
				return 0;
			} else {
				$shipNew->setStatus('cash', $self->{maxInitialCost} - $shipNew->{cost});	
			}
		}

		# set the new ship's id
		$self->sendMsg($shipNew, 'setShipId', { old_id => 'self', new_id => $shipNew->{id} });
		# set the color
		$self->sendMsg($shipNew, 'shipstatus', { 'ship_id' => $shipNew->{id}, 'color' => $options{'color'} });

		# send it to the other ships
		foreach my $oldShip ($self->getShips()){
			$self->sendMsg($shipNew, 'newship', {
				design => $oldShip->{design},
				x => $oldShip->{x},
				y => $oldShip->{y},
				id => $oldShip->{id},
				#'map' => $oldShip->{collisionMap},
				options => { color => $oldShip->{colorDef} }
			});
			my $chrMap  = $oldShip->{collisionMap};
			my $partMap = $oldShip->{partMap};
			my $msg = {
				'ship_id'  => $oldShip->{id},
				'chr_map'  => $chrMap,
				'part_map' => $partMap
			};
			$self->sendMsg($shipNew, 'shipchange', $msg);
		}

		my $id = $self->addShip($shipNew);
		print "player loaded, " . $self->getShipCount() . " in game.\n";
		$shipNew->setStatus('name', $options{name});
		$self->sendSystemMsg("Player " . color($shipNew->{colorDef}) . "$options{name} " . color('green') . " has entered the game.");
		return $id;
	}
	return 0;
}

sub sendSystemMsg {
	my $self = shift;
	my $msg = shift;
	my $ship = shift;
	if (defined($ship)){
		$self->sendMsg($ship, 'msg', { 'user' => '<SYSTEM>', 'msg' => $msg, 'color' => 'green'});
	} else {
		$self->broadcastMsg('msg', { 'user' => '<SYSTEM>', 'msg' => $msg, 'color' => 'green'});
	}

}

sub _sendShipsToClients {
	my $self = shift;
	foreach my $ship ($self->getShips()){
		my $msg = {
			#id => 'self' ,
			id => $ship->{id} ,
			x => $ship->{x},
			y => $ship->{y},
			dx => $ship->{movingHoz},
			dy => $ship->{movingVert},
			shieldHealth => $ship->{shieldHealth},
			health       => $ship->{health},
			currentPower => $ship->{currentPower},
			currentHealth=> $ship->{currentHealth},
			powergen     => $ship->{currentPowerGen},
			direction    => $ship->{direction},
			cloaked      => $ship->{cloaked},
			shieldsOn    => $ship->{shieldsOn},
			isBot        => $ship->{isBot},
		};
		$self->broadcastMsg('s', $msg);
	}
}

sub sendFullShipStatus {
	my $self = shift;
	my $ship = shift;

	my $partMap = $ship->{partMap};

	$self->broadcastMsg('shipstatus', {
		ship_id => $ship->{id},
		cloaked => $ship->{cloaked},
		cash    => $ship->{cash},
		shieldsOn => $ship->{shieldsOn},
		isBot   => $ship->{isBot},
	});
}

sub sendLivingParts {
	my $self = shift;
	my $ship = shift;
	$self->broadcastMsg('partsleft', {
		ids => $ship->getPartIds(),
	});
}

sub addBullet {
	my $self = shift;
	my $bullet = shift;
	$self->{bullets}->{ rand(1000) . time() } = $bullet;
}

sub _calculatePowerAndMovement {
	my $self = shift;
	# calculate power and movement
	foreach my $ship ($self->getShips()){
		# power first because it disables move
		$ship->power();
		$ship->move();
		$ship->moduleTick();
        $self->_forceInBounds($ship);
        if ($ship->getStatus('autoaim')){
		    my ($id, $distance, $dir) = $self->_findClosestShip(
                $ship->{'x'},
                $ship->{'y'},
			    { skipId => $ship->{'id'} }
            );
			$ship->setStatus('direction', $dir);
        }
		foreach my $bul (@{ $ship->shoot() }){
			$self->addBullet($bul);
		}
	}
}

sub _forceInBounds {
	my $self = shift;
	my $ship = shift;
	return 0;
	if ($ship->{x} < LEFT){
		$ship->{x} = LEFT;
	}
	if ($ship->{x} > RIGHT){
		$ship->{x} = RIGHT;
	}
	if ($ship->{y} < TOP){
		$ship->{y} = TOP;
	}
	if ($ship->{y} > BOTTOM){
		$ship->{y} = BOTTOM;
	}
}

sub _recieveInputFromClients {
	my $self = shift;
	# recieve ship input
	foreach my $ship ($self->getShips()){
		next if ($ship->{isBot});
		my $socket = $ship->{conn};
		while (defined(my $in = <$socket>)){
			chomp($in);
			my $chr = $in;
			if ($chr =~ m/B:([\-\d]+?):([\-\d]+?):(.)/){
				my $chr = $3;
				my $x   = $2;
				my $y   = $1;
				my $id = undef;
				if ($chr eq ' '){
					print "removing part at $x, $y\n";
					$ship->removePartLocation($x, $y, 1);
					$ship->_recalculate();
					#print $ship->getShipDisplay();
					my $chrMap  = $ship->{collisionMap};
					my $partMap = $ship->{partMap};
					my $msg = {
						'ship_id'  => $ship->{id},
						'chr_map'  => $chrMap,
						'part_map' => $partMap
					};
					foreach my $s ($self->getShips()){
						$self->sendMsg($s, 'shipchange', $msg);
					}
				} else {
					if ($ship->hasSparePart($chr)){
						$id = $ship->loadSparePart($chr, $x, $y);
					} else {
						$ship->purchasePart($chr, $x, $y);
						$id = $ship->loadSparePart($chr, $x, $y);
					}
					if (defined($id)){
						#print "******** id: $id\n";
						$ship->_recalculate();
						#print $ship->getShipDisplay();
						if ($id != 0){
							my $chrMap  = $ship->{collisionMap};
							my $partMap = $ship->{partMap};
							my $msg = {
								'ship_id'  => $ship->{id},
								'chr_map'  => $chrMap,
								'part_map' => $partMap
							};
							foreach my $s ($self->getShips()){
								$self->sendMsg($s, 'shipchange', $msg);
							}
						}
					} else {
						print "Can't load part $chr, not enough money or not defined\n";	
					}
				}
				next;
			}
			if ($chr =~ m/M:(.+?):(.+)/){
				my ($user, $chat) = ($1, $2);
				if ($chat =~ m#^/(.+)#){
					$self->parseCommand($ship, $1);
				} else {
					$ship->setStatus('taunt', $chat);
					$self->broadcastMsg('msg', { 'user' => $user, 'msg' => $chat });
				} 
			}
			# ping message
			if ($chr eq 'z'){
				$ship->{lastMsg} = time();
				next;
			}
			my $return = $ship->keypress($chr);
			if (defined($return)){
				$self->broadcastMsg($return->{'msgType'}, $return->{'msg'})
			}
			if ($chr eq '@'){
				my $msg = {
					ship_id => $ship->{id},
					shieldsOn => $ship->{shieldsOn},
				};
				$self->broadcastMsg('shipstatus', $msg);
			}
			if ($chr eq '^'){
				my $map = $ship->{collisionMap};
				my $partMap = $ship->{partMap};
				my $msg = {
					ship_id => $ship->{id},
					'map' => $map,
					'partMap' => $partMap
				};
				foreach my $s ($self->getShips()){
					$self->sendMsg($s, 'shipchange', $msg);
				}
			}
		}
		if (! $ship->{isBot} && time() - $ship->{lastMsg} > 5){
			print "AI takeover of ship $ship->{id}!\n";
			$ship->becomeAi();
		}
	}
}

# player commands
sub parseCommand {
	my $self = shift;
	my ($ship, $commandString) = @_;
	my ($command, $arg) = split(' ', $commandString);
	if (!defined($arg)){ $arg = ''; };
	my $parsed = 0;
	if ($command eq 'shield'){
		if ($arg eq ''){
			$ship->toggleShield();
		} elsif ($arg eq 'on'){
			$ship->{shieldsOn} = 1;
			$self->sendSystemMsg("shields disabled.", $ship);
		} elsif ($arg eq 'off'){
			$ship->{shieldsOff} = 0;
			$self->sendSystemMsg("shields disabled.", $ship);
		} else {
		}
		my $msg = {
			ship_id => $ship->{id},
			shieldsOn => $ship->{shieldsOn},
		};
		$self->broadcastMsg('shipstatus', $msg);
	} elsif ($command eq 'spawns'){
		if ($arg =~ m/^\d+$/){
			$self->{shipDensity} = $arg;
			$self->sendSystemMsg("Ship density changed to $arg.");
			print "Ship density changed to $arg\n";
		}
	} elsif ($command eq 'level'){
		if ($arg =~ m/^\d+$/){
			$self->setLevel($arg);
			$self->sendSystemMsg("Difficulty level changed to $arg.");
			print "Level changed to $arg\n";
		} else {
			$self->sendSystemMsg("Invalid difficulty level.", $ship);
		}
	} elsif ($command eq 'color'){
		if ($ship->isValidColor($arg)){
			$ship->setStatus('color', $arg);	
			$self->sendSystemMsg($ship->{name} . " changed to color " . $ship->{color} . $arg . color('reset'));
		} else {
			$self->sendSystemMsg("Invalid color: $arg", $ship);
		}
	} elsif ($command eq 'status' || $command eq 's'){
		$self->sendSystemMsg("status $arg: " . $ship->getStatus($arg), $ship);
	} elsif ($command eq 'serverStatus' || $command eq 'ss'){
		$self->sendSystemMsg("server status $arg:\n" . $self->{$arg}, $ship);
	} elsif ($command eq 'serverStatusDump' || $command eq 'ssd'){
		$self->sendSystemMsg("server status $arg:\n" . Dumper($self->{$arg}), $ship);
	} elsif ($command eq 'statusDump' || $command eq 'sd'){
		$self->sendSystemMsg("status $arg:\n" . Dumper($ship->getStatus($arg)), $ship);
	} elsif ($command eq 'statusSet' || $command eq 'sset'){
		my ($stat, $val) = split('=', $arg);
		$ship->setStatus($stat, $val);
		$self->sendSystemMsg("set status $stat to $val", $ship);
	} elsif ($command eq 'help' || $command eq '?'){
		$self->sendSystemMsg(q(
List of commands:
color <red blue green cyan white yellow>
shields|sh <on|off>
level <difficulty level>
spawns <enemy ships nearby>), $ship);
	} else {
		my $matched = 0;
		foreach my $module ($ship->getModules()){
			if ($module->commandName() eq $command){
				$matched = 1;
				$module->command($arg, $ship);
				print "turning $command $arg\n";
			}
		}
		if ($matched == 0){
			$self->sendSystemMsg("Invalid command: $command, type /help for list of commands.", $ship);
		}
	}
}

sub getBullets {
	my $self = shift;
	return keys %{ $self->{bullets} };
}

sub getItems {
	my $self = shift;
	return keys %{ $self->{items} };
}


sub getBulletCount {
	my $self = shift;
	return scalar $self->getBullets();
}

sub addItem {
    my $self = shift;
    my $item = shift;

    my $key = rand(1000) . time();
    $item->{k} = $key;
    if (!defined($item->{expires})){
        $item->{ex} = 60;
    }
	$item->{expires} = time + $item->{ex};
	$self->{items}->{$key} = $item;
	if ($item->{ship_id}){
		my $ship = $self->getShipById($item->{ship_id});
		$self->sendMsg($ship, 'item', $item);
	} else { # global items
		$self->broadcastMsg('item', $item);
	}
}

sub _calculateItems {
	my $self = shift;
	foreach my $itemK ( $self->getItems() ){
		if ($self->{items}->{$itemK}->{expires} < time()){
			delete $self->{items}->{$itemK};
			$self->broadcastMsg('itemdel', { 'k' => $itemK });
		} else {
			my $item = $self->{items}->{$itemK};
			foreach my $ship ($self->getShips()){
				if (defined($item->{ship_id})){
					if ($item->{ship_id} ne $ship->{id}){
						next;
					}
				}
				if (abs($ship->{y} - $item->{x}) < 3 &&
					abs($ship->{x} - $item->{y}) < 3 ){

					$ship->claimItem($item);
					print "### claiming item for $ship->{id}\n";
					delete $self->{items}->{$itemK};
					$self->broadcastMsg('itemdel', { 'k' => $itemK });
				}
			}
		}
	}
}

sub _calculateBullets {
	my $self = shift;
	### calcuate bullets
	foreach my $bulletK ( $self->getBullets() ){
		if ($self->{bullets}->{$bulletK}->{expires} < time()){
			delete $self->{bullets}->{$bulletK};
		}
	}
	my $time = time();
	foreach my $bulletK ( $self->getBullets() ){
		my $bullet = $self->{bullets}->{$bulletK};
		$bullet->{x} += ($bullet->{dx} * ($time - $self->{lastTime}));
		$bullet->{y} += ($bullet->{dy} * ($time - $self->{lastTime}));

		# send the bullet data to clients
		foreach my $ship ($self->getShips()){
			# TODO only send once in a while, let client move in the meantime
			$self->sendMsg($ship, 'b', 
				{
					x => $bullet->{x},
					y => $bullet->{y},
					dx => $bullet->{dx},
					dy => $bullet->{dy},
					sid => $bullet->{ship_id}, 
					pid => $bullet->{partId},
					k => $bulletK,
					ex => ( $bullet->{expires} - time() ), # time left in case client clock differs
					chr => $bullet->{chr},
					col => $bullet->{col}
				}
			);
		}

		# detect and resolve bullet collisions
		foreach my $ship ($self->getShips()){
			if (my $data = $ship->resolveCollision($bullet)){
				if (defined($data->{deflect})){ # or dodge
					#$bullet->{dx} = (0 - $bullet->{dx});
					#$bullet->{dy} = (0 - $bullet->{dy});
					$bullet->{ship_id} = $ship->{id}; # convert it to our bullet
				} else { # normal hit
                    $data->{bullet_del} = $bulletK;
                    $data->{ship_id} = $ship->{id};
                    $self->broadcastMsg('dam', $data);
				    delete $self->{bullets}->{$bulletK};
				}

				if (!defined($data->{health})){
					last;
				}
				if ($data->{health} <= 0){
					#print "part killed $data->{id} from $ship->{id}\n";
					$ship->_removePart($data->{id});
					my @orphaned = $ship->orphanParts();
					#print "orphaned: $#orphaned\n";
					foreach my $partId (@orphaned){
						my %data = (
							ship_id => $ship->{id},
							id => $partId,
							health  => -1
						);
						$self->broadcastMsg('dam', \%data);
					}
					$ship->_recalculate();
					# TODO send ship status?
				}
				if (! $ship->getCommandModule() ){
					if (!$ship->isBot()){
						my $killShip = $self->getShipById($bullet->{ship_id});
						my $killName = '';
						if (!defined($killShip)){
							$killName = 'a stray bullet';
						} else {
							$killName = ($killShip->isBot() ? 'the computer' : $killShip->getStatus('name'));
						}
						$self->sendSystemMsg($ship->getStatus('name') . " has been killed by " . $killName . '.');
						$self->sendMsg($ship, 'exit', { msg => "You have died. Your deeds were few, and none will remember you." });
					}
					$self->removeShip($ship->{id});
					$self->broadcastMsg('shipdelete', { id => $ship->{id} });
                    foreach my $item ($ship->calculateDrops()){
						$item->{ship_id} = $bullet->{ship_id};
                        $self->addItem($item);
                    }

					print "ship $ship->{id}'s command module destroyed!\n";
					print "ships in game : " . $self->getShipCount() . "\n";
					next;
				}
				last;
			}
		}
	}
}

1;
