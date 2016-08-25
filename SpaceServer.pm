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
	
	$self->_bindSocket($socket);
	$self->{ships} = [];
	$self->{shipIds} = 1;
	$self->{lastTime} = 0;
	$self->{bullets} = {};
	$self->{level} = 1;
	$self->{highestEnemy} = 1;

	$self->loadEnemyDir('ships/enemy1', 1);
	$self->loadEnemyDir('ships/enemy2', 2);
	$self->loadEnemyDir('ships/enemy3', 3);

	return 1;
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
#			print "fps: $frames\n";
#			print "  bullets:";
#			print $self->getBulletCount(0);
#			print "\n";
			#print "shipSend: $self->{shipSend}\n";
			#$self->{shipSend} = 0;
			$frames = 0;
		}

		$self->_ai();
		$self->_loadNewPlayers();
		$self->_calculateBullets();
		$self->_sendShipsToClients();
		$self->_calculatePowerAndMovement();
		$self->_recieveInputFromClients();
		$self->_spawnShips();
	}
}

sub _spawnShips {
	my $self = shift;
	if ($self->getShipCount() < 4){
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
			design => $newShipDesign,
			x => $shipNew->{x},
			y => $shipNew->{y},
			id => $shipNew->{id},
			#'map' => $oldShip->{collisionMap},
			options => { color => 'red' }
		});
		$self->addShip($shipNew);
	}
}

sub _ai {
	my $self = shift;
	my $time = time();
	foreach my $ship ($self->getShips()){
		next if (!$ship->{isBot});
		my $modeDiff  = $time - $ship->{aiModeChange};
		my $stateDiff = $time - $ship->{aiStateChange};
		#if ($ship->{ai}){
		my ($id, $distance, $dir) = $self->_findClosestShip(
			$ship->{'x'},
			$ship->{'y'},
			$ship->{'id'}
			);
		#}
		if ($id eq '-1'){
			$ship->{aiMode} = 'explore';
		} else {
			if ($distance < 20){
				$ship->{aiMode} = 'attack';	
			}
		}
		if ($ship->{aiMode} eq 'explore'){
			if ($stateDiff > 6){
				my $move = rand(2 * PI);
				$ship->{movingHoz}  = sin($move) * .3;
				$ship->{movingVert} = cos($move) * .3;
				$ship->{aiStateChange} = $time;
			}
			$ship->{movingHozPress} = time();
			$ship->{movingVertPress} = time();
		} elsif ($ship->{aiMode} eq 'attack'){
			if ($id ne '-1'){
				if ($distance < 30){
					$ship->{direction} = $dir + (rand(.3) - .15);
					$ship->{shooting} = time();
					if ($stateDiff > 0.7){
						my $move = $dir + (rand() < .5 ? (PI / 2) : -(PI / 2));
						$ship->{movingHoz}  = sin($move) * .3;
						$ship->{movingVert} = cos($move) * .3;
						$ship->{aiStateChange} = $time;
						if (rand() < .8){
							$ship->{movingHozPress} = time();
							$ship->{movingVertPress} = time();
						}
					}
				} else {
					if ($stateDiff > 0.5){
						my $move = $dir + (rand(.3) - .15);
						$ship->{movingHoz}  = sin($move) * .7;
						$ship->{movingVert} = cos($move) * .7;
						$ship->{aiStateChange} = $time;
					}
					$ship->{movingHozPress} = time();
					$ship->{movingVertPress} = time();
				}
			}
		} elsif ($ship->{aiMode} eq 'flee'){

		} else {

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
	my ($x, $y, $skipId, $onlyId) = @_;
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
		my $dy = ($ship->{x} - $x) * ASPECTRATIO;
		my $dx = ($ship->{y} - $y);
		my ($rho, $theta, $phi)   = cartesian_to_spherical($dx, $dy, 0);
		if ($rho < $smallestDistance){
			$smallestDistance = $rho;
			$dir = $theta;
			$id = $ship->{id};
		}
	}
	return ($id, $smallestDistance, $dir);
}

sub getShips {
	my $self = shift;

	return @{ $self->{ships} };
}

sub getShipCount {
	my $self = shift;
	return scalar $self->getShips();
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
		$self->sendMsg($ship->{conn}, $category, $data);
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

		# set the new ship's id
		$self->sendMsg($shipNew->{conn}, 'setShipId', { old_id => 'self', new_id => $shipNew->{id} });
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
					currentPower => $ship->{currentPower},
					powergen     => $ship->{currentPowerGen},
					direction    => $ship->{direction},
					cloaked      => $ship->{cloaked},
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
					currentPower => $ship->{currentPower},
					powergen     => $ship->{currentPowerGen},
					direction    => $ship->{direction},
					cloaked      => $ship->{cloaked},
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
	my $time = time();
	# calculate power and movement
	foreach my $ship ($self->getShips()){
		# power first because it disables move
		$ship->power($time - $self->{lastTime});
		$ship->move($time - $self->{lastTime});
		$self->_forceInBounds($ship);
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
			if ($chr =~ m/B:(\d+?):(\d+?):(.)/){
				print "******** loading part: $3, $1, $2\n";
				my $id = $ship->_loadPart($3, $2, $1);
				print "******** id: $id\n";
				$ship->_recalculate();
				print $ship->getShipDisplay();
				if ($id != 0){
					my $map = $ship->{collisionMap};
					#print Dumper($map);
					my $msg = {
						ship_id => $ship->{id},
						'map' => $map
					};
					foreach my $s ($self->getShips()){
						$self->sendMsg($s->{conn}, 'shipchange', $msg);
					}
				}
				next;

			}
			# ping message
			if ($chr eq 'z'){
				$ship->{lastMsg} = time();
				next;
			}
			$ship->keypress($chr);
			if ($chr eq 'c'){
				my $msg = {
					ship_id => $ship->{id},
					cloaked => $ship->{cloaked},
				};
				$self->broadcastMsg('shipstatus', $msg);
			}
			if ($chr eq '@'){
				my $msg = {
					ship_id => $ship->{id},
					shieldsOn => $ship->{shieldsOn},
				};
				$self->broadcastMsg('shipstatus', $msg);
			}
			if ($chr eq 'p'){
				my $map = $ship->{collisionMap};
				#print Dumper($map);
				my $msg = {
					ship_id => $ship->{id},
					'map' => $map
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

sub getBulletCount {
	my $self = shift;
	return scalar $self->getBullets();
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
				#if (! defined($data->{deflect})) {
				$data->{bullet_del} = $bulletK;
				$data->{ship_id} = $ship->{id};
				$self->broadcastMsg('dam', $data);
				if (defined($data->{deflect})){
					#$bullet->{dx} = (0 - $bullet->{dx});
				# probably only hit a shield
					#$bullet->{dy} = (0 - $bullet->{dy});
					#$bullet->{ship_id} = -1;
				}
				#} else {
				delete $self->{bullets}->{$bulletK};
				#}

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
					foreach my $claimShip ($self->getShips){
						if ($claimShip->{id} eq $bullet->{id}){
							$claimShip->{cash} += '500';
							$self->sendFullShipStatus($claimShip);
							print "$claimShip->{id} granted \$500\n";

						}

					}
					$self->removeShip($ship->{id});
					$self->broadcastMsg('shipdelete', { id => $ship->{id} });
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
