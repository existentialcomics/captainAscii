#!/usr/bin/perl
#
#
#
use strict; use warnings;
package SpaceServer;
use Term::ANSIColor 4.00 qw(RESET color :constants256);
require Term::Screen;
use List::MoreUtils qw(zip);
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval nanosleep
		      clock_gettime clock_getres clock_nanosleep clock time);
use SpaceShip;
use Storable;
use Data::Dumper;
use JSON::XS qw(encode_json decode_json);

use IO::Socket::UNIX;

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
	$self->{fps} = 24;
	$self->{shipIds} = 1;
	$self->{lastTime} = 0;
	$self->{bullets} = {};

	return 1;
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
	my $fps = 60;

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
			print "fps: $frames\n";
			$frames = 0;
		}

		$self->_loadNewPlayers();
		$self->_calculateBullets();
		$self->_sendShipsToClients();
		$self->_calculatePowerAndMovement();
		$self->_recieveInputFromClients();
	}
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

	push @{ $self->{ships} }, $ship;
	my $id = $#{ $self->{ships} };
	return $id;
}
### transmit a msg to the clients
sub sendMsg {
	my $self = shift;
	my ($socket, $category, $data) = @_;
	my $msg = {
		c => $category,
		d => $data
	};
	print $socket (JSON::XS::encode_json($msg)) . "\n";
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
		while ($waitShip){
			while(my $line = <$conntmp>){
				if ($line =~ /DONE/){
					$waitShip = 0;
					last;
				} else {
					$newShipDesign .= $line;
				}
			}
		}
		print "$newShipDesign\n";
		my $shipNew = SpaceShip->new($newShipDesign, 5, 5, $self->{shipIds}++);
		foreach my $ship ($self->getShips()){
			$self->sendMsg($ship->{conn}, 'newship', {
				design => $newShipDesign,
				x => 5,
				y => 5,
				id => $shipNew->{id},
			});
		}
		$conntmp->blocking(0);
		$shipNew->{conn} = $conntmp;

		# set the new ship's id
		$self->sendMsg($shipNew->{conn}, 'setShipId', { old_id => 'self', new_id => $shipNew->{id} });
		# send it to the other ships
		foreach my $os ($self->getShips()){
			$self->sendMsg($shipNew->{conn}, 'newship', {
				design => $os->{design},
				x => $os->{x},
				y => $os->{y},
				id => $os->{id},
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
		foreach my $bul (@{ $ship->shoot() }){
			$self->addBullet($bul);
		}
	}
}

sub _recieveInputFromClients {
	my $self = shift;
	# recieve ship input
	foreach my $ship ($self->getShips()){
		my $socket = $ship->{conn};
		while (defined(my $in = <$socket>)){
			chomp($in);
			my $chr = $in;
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
		}
	}
}

sub getBullets {
	my $self = shift;
	return keys %{ $self->{bullets} };
}

sub _calculateBullets {
	my $self = shift;
	my $time = time();
	### calcuate bullets
	foreach my $bulletK ( $self->getBullets() ){
		my $bullet = $self->{bullets}->{$bulletK};
		if ($bullet->{expires} < time()){
			delete $self->{bullets}->{$bulletK};
			next;
		}
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
					print "part killed $data->{id} from $ship->{id}\n";
					$ship->_removePart($data->{id});
					my @orphaned = $ship->orphanParts();
					print "orphaned: $#orphaned\n";
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
