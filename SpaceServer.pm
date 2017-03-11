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
	$self->{lastTime} = 0;
	$self->{bullets} = {};
	$self->{level} = 1;
	$self->{highestEnemy} = 1;
	if (defined($options->{maxInitialCost})){
		$self->{maxInitialCost} = $options->{maxInitialCost};
	}

	$self->{lastPlayerColor} = 'green';

	$self->loadEnemyDir('ships/enemy1', 1);
	$self->loadEnemyDir('ships/enemy2', 2);
	$self->loadEnemyDir('ships/enemy3', 3);

	return 1;
}

sub getColorById {
	my $self = shift;
	my $id = shift;
	return $self->{colors}->[ $id % scalar @{$self->{colors}} ];
}

sub getNextPlayerColor {
	my $self = shift;
}

sub loadEnemyDir {
	my $self  = shift;
	my $dir   = shift;
	my $level = shift;
	opendir(my $dh, $dir) or die "Failed to open enemy dir\n";
	my @ships = grep { /\.ascii$/ && -f "$dir/$_" } readdir($dh);
	foreach my $file (@ships){
		open my $fh, '<', "$dir/$file";
		my $shipDesign = "";
		while (<$fh>){
			$shipDesign .= $_;
		}
		$self->addEnemyDesign($level, $shipDesign);
	}

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
	my $fps = 20;
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
			#$self->{shipSend} = 0;
			$frames = 0;
		}

		$self->_ai();
		$self->_loadNewPlayers();
		$self->_calculateBullets();
		$self->_calculateItems();
		$self->_sendShipsToClients();
		$self->_calculatePowerAndMovement();
		$self->_recieveInputFromClients();
		$self->_sendShipStatuses();
		$self->_sendShipMsgs();
		$self->_spawnShips();
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
			$self->broadcastMsg($msg->{category}, $msg->{msg});
		}
		$ship->clearServerMsgs();
	}
}

# remove ships that are too far away from any player
sub _despawnShips {
	my $self = shift;
	foreach my $ship ($self->getShips()){
		next if (!$ship->{isBot});
	}
}

sub _spawnShips {
	my $self = shift;
	if ($self->getShipCount() < 8){
		my $rand = rand();
		my $level = $self->{level};
		if ($rand < 0.2){
			$level++;
		}
		if ($level > $self->{highestEnemy}){
			$level = $self->{highestEnemy};
		}
		my $newShipDesign = $self->getEnemyDesign($level);
		print "adding enemy:\n$newShipDesign\n";
		my $shipNew = SpaceShip->new($newShipDesign, rand(200) - 100, rand(200) - 100, $self->{shipIds}++, { color => 'red'});
		$shipNew->{conn} = undef;
		$shipNew->becomeAi();
		$self->broadcastMsg('newship', {
			'design' => $newShipDesign,
			'x' => $shipNew->{x},
			'y' => $shipNew->{y},
			'id' => $shipNew->{id},
			'ai' => 1,
			#'map' => $oldShip->{collisionMap},
			'options' => { color => $shipNew->getColorName() }
		});
		$self->addShip($shipNew);
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
		my ($id, $distance, $dir) = $self->_findClosestShip(
			$ship->{'x'},
			$ship->{'y'},
			$ship->{'id'}
			);
		if ($id eq '-1'){
			$ship->changeAiMode('explore');
		} else {
			if ($distance < 20){
				$ship->changeAiMode('attack', 'passive');
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
							$ship->{movingHozPress} = time();
							$ship->{movingVertPress} = time();
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
		if ($ship->setAiColor()){
			$self->broadcastMsg('shipstatus', { 'ship_id' => $ship->{id}, 'color' => $ship->getColorName() });
		}
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
	my ($x, $y, $skipId) = @_;
	my $smallestDistance = 999999999;
	my $id = -1;
	my $dir = 0;
	foreach my $ship ($self->getShips()){
		next if ($ship->{id} eq $skipId);
		next if (
			$ship->{cloaked} 
			#&& !( $ship->{shieldsOn} && $ship->{shieldHealth} > 0)
			&& (time() - $ship->{shooting} > 3)
		);
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
	my $id = $#{ $self->{ships} };

	### this is so the connect stays alive after we remove the ship
	# so the client doesn't crash
	$self->{shipConn}->{$id} = $ship->{conn};
	return $id;
}

### transmit a msg to the clients
sub sendMsg {
	my $self = shift;
	my ($socket, $category, $data) = @_;
	if (!$socket){ return 0; }
	my $msg = {
		c => $category,
		d => $data
	};
	#print $socket (JSON::XS::encode_json($msg)) . "\n";
	syswrite($socket, (JSON::XS::encode_json($msg)) . "\n");
}

sub broadcastMsg {
	my $self = shift;
	my ($category, $data) = @_;
	foreach my $ship ($self->getShips()){
        if (!$ship->isBot()){
		    $self->sendMsg($ship->{conn}, $category, $data);
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
			$self->sendMsg($ship->{conn}, 'newship', {
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
				$self->sendMsg($shipNew->{conn}, 'exit', { msg => "Your ship exceeds the maximum cost of $self->{maxInitialCost}" });
			} else {
				$shipNew->setStatus('cash', $self->{maxInitialCost} - $shipNew->{cost});	
			}
		}

		# set the new ship's id
		$self->sendMsg($shipNew->{conn}, 'setShipId', { old_id => 'self', new_id => $shipNew->{id} });
		# set the color
		$self->sendMsg($shipNew->{conn}, 'shipstatus', { 'ship_id' => $shipNew->{id}, 'color' => $options{'color'} });

		# send it to the other ships
		foreach my $oldShip ($self->getShips()){
			$self->sendMsg($shipNew->{conn}, 'newship', {
				design => $oldShip->{design},
				x => $oldShip->{x},
				y => $oldShip->{y},
				id => $oldShip->{id},
				#'map' => $oldShip->{collisionMap},
				options => { color => $oldShip->{colorDef} }
			});
		}

		my $id = $self->addShip($shipNew);
		print "player loaded, " . $self->getShipCount() . " in game.\n";
		$self->broadcastMsg('msg', { 'user' => '<SYSTEM>', 'msg' => "Player " . color($shipNew->{colorDef}) . "$options{name} " . color('reset') . " has entered the game\n"});
		return $id;
	}
	return 0;
}

sub _sendShipsToClients {
	my $self = shift;
	foreach my $ship ($self->getShips()){
		foreach my $shipInner ($self->getShips()) {
			# send the inner loop ship the info of the outer loop ship
			my $msg = {};
			#$self->{shipSend}++;
			if ($ship->{id} eq $shipInner->{id}){
				$msg = {
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
				$self->sendMsg($shipInner->{conn}, 's', $msg);
			} else {
				$msg = {
					id => $ship->{id} ,
					x => $ship->{x},
					y => $ship->{y},
					dx => $ship->{movingHoz},
					dy => $ship->{movingVert},
					shieldHealth => $ship->{shieldHealth},
					health       => $ship->{health},
					currentHealth=> $ship->{currentHealth},
					currentPower => $ship->{currentPower},
					powergen     => $ship->{currentPowerGen},
					direction    => $ship->{direction},
					cloaked      => $ship->{cloaked},
					shieldsOn    => $ship->{shieldsOn},
					isBot        => $ship->{isBot},
				};
				$self->sendMsg($shipInner->{conn}, 's', $msg);
				# we only need to know location
			}
		}
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
			    $ship->{'id'}
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
				#print "******** loading part: $3, $1, $2\n";
				my $chr = $3;
				my $x   = $2;
				my $y   = $1;
				my $id = $ship->purchasePart($chr, $x, $y);
				if (defined($id)){
					#print "******** id: $id\n";
					$ship->_recalculate();
					print $ship->getShipDisplay();
					if ($id != 0){
						my $chrMap  = $ship->{collisionMap};
						my $partMap = $ship->{partMap};
						#print Dumper($map);
						my $msg = {
							'ship_id'  => $ship->{id},
							'chr_map'  => $chrMap,
                            'part_map' => $partMap
						};
						foreach my $s ($self->getShips()){
							$self->sendMsg($s->{conn}, 'shipchange', $msg);
						}
					}
				} else {
					print "Can't load part $chr, not enough money or not defined\n";	
				}
				next;
			}
			if ($chr =~ m/M:(.+?):(.+)/){
				$self->broadcastMsg('msg', { 'user' => $1, 'msg' => $2 });
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
				#print Dumper($map);
				my $msg = {
					ship_id => $ship->{id},
					'map' => $map,
					'partMap' => $partMap
				};
				foreach my $s ($self->getShips()){
					$self->sendMsg($s->{conn}, 'shipchange', $msg);
				}
			}
			if ($chr eq '+'){
				$self->{level}++;
				print "level changed to $self->{level}\n";
			}
			if ($chr eq '-'){
				$self->{level}--;
				print "level changed to $self->{level}\n";
			}
		}
		if (! $ship->{isBot} && time() - $ship->{lastMsg} > 5){
			print "AI takeover of ship $ship->{id}!\n";
			$ship->becomeAi();
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
	if ($item->{sid}){
		my $ship = $self->getShipById($item->{sid});
		$self->sendMsg($ship->{conn}, 'item', $item);
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
				if (defined($item->{sid})){
					if ($item->{sid} ne $ship->{id}){
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
			$self->sendMsg($ship->{conn}, 'b', 
				{
					x => $bullet->{x},
					y => $bullet->{y},
					dx => $bullet->{dx},
					dy => $bullet->{dy},
					sid => $bullet->{id}, 
					pid => $bullet->{partId},
					k => $bulletK,
					ex => ( $bullet->{expires} - time() ), # time left in case client clock differs
					chr => $bullet->{chr}
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
				}
				if (! $ship->getCommandModule() ){
                    $self->sendMsg($ship->{conn}, 'exit', { msg => "You have died. Your deeds were few, and none will remember you." });
					$self->removeShip($ship->{id});
					$self->broadcastMsg('shipdelete', { id => $ship->{id} });
                    foreach my $item ($ship->calculateDrops()){
                        $self->addItem($item);
                    }

					print "ship $ship->{id}'s command module destroyed!\n";
					print "ships in game : " . $self->getShipCount() . "\n";
					next;
				}
				$ship->_recalculate();
				last;
			}
		}
	}
}

1;
