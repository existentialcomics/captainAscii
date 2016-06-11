use strict; use warnings;
package SpaceClient;
use Term::ANSIColor 4.00 qw(RESET color :constants256);
require Term::Screen;
use List::MoreUtils qw(zip);
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval nanosleep
		      clock_gettime clock_getres clock_nanosleep clock time);
use SpaceShip;
#use Storable;
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
	my $ship_file = shift;
	my $socket = shift;
	my $options = shift;
	print "socket: $socket \n";
	
	$self->_bindSocket($socket);
	$self->_loadShip($ship_file);

	$self->{socket}->blocking(0);

	$self->{ships}->{ $self->{ship}->{id} } = $self->{ship};
	$self->{bullets} = {};

	$self->{height} = 55;
	$self->{width}  = 130;

	$self->loop();

	return 1;
}

sub _loadShip {
	my $self = shift;
	my $ship_file = shift;
	$| = 1;

	open (my $fh, '<', $ship_file) or die "failed to open $ship_file\n";

	my $shipStr = "";

	# TODO don't send the ship until it successfully loads locally
	while(my $line = <$fh>){
		print $line;
		$shipStr .= $line;
		print {$self->{'socket'}} $line;
	}
	close ($fh);

	print {$self->{socket}} "DONE\n";
	select STDOUT;
	print "loaded\n";
	$self->{ship} = SpaceShip->new($shipStr, 5, 5, -1, 'self');
	$self->_addShip($self->{ship});
	
	return 1;
}

sub _getShips {
	my $self = shift;
	return values %{$self->{ships}};
}

sub _removeShip {
	my $self = shift;
	my $id = shift;
	delete $self->{ships}->{$id};
}

sub _addShip {
	my $self = shift;
	my $ship = shift;
	$self->{ships}->{$ship->{id}} = $ship;
}

sub _getShip {
	my $self = shift;
	my $id = shift;
	return $self->{ships}->{id};
}

sub loop {
	my $self = shift;

	#my $frame = 0;
	#my $lastFrame = 0;
	#my $fps = 20;
	#my $framesInSec;
	#my $lastTime = time();
	#my $time = time();

	my $height = 55;
	my $width = 130;

	my $scr = new Term::Screen;
	$scr->clrscr();
	$scr->noecho();

	my $playing = 1;
	while ($playing){
		$self->_getMessagesFromServer();

		$self->{lighting} = {};
		my $cenX = int($width / 2);
		my $cenY = int($height / 2);
		my $offx = $cenX - int($self->{ship}->{x});
		my $offy = $cenY - int($self->{ship}->{y});

		$self->_sendKeystrokesToServer($scr);
		$self->{'map'} = $self->_resetMap($width, $height);

		$self->_drawBullets($offx, $offy);
		$self->_drawShips($offx, $offy);

		$self->printScreen($scr);
		$self->printInfo($scr);
	}
}

sub printScreen {
	my $self = shift;
	my $scr = shift;
	
	my $height = $self->{height};
	my $width = $self->{width};
	my @map = @{ $self->{map} };

	### draw the screen to Term::Screen
	foreach my $i (0 .. $height){
		$scr->at($i + 1, 0);
		my $row = '';
		foreach my $j (0 .. $width){
			my $color = (defined($self->{lighting}->{$i}->{$j}) ? color('ON_GREY' . ($self->{lighting}->{$i}->{$j} <= 23 ? $self->{lighting}->{$i}->{$j} : 23 )) : color('ON_BLACK'));
			$row .= (defined($map[$i]->[$j]) ? $color . $map[$i]->[$j] : $color . " ");
		}
		$scr->puts($row);
	}
}

sub printInfo {
	my $self = shift;
	my $scr  = shift;

	my $ship = $self->{ship};
	my $height = $self->{height};
	my $width = $self->{width};

	#### ----- ship info ------ ####
	$scr->at($height + 2, 0);
	#$scr->puts("ships in game: " . ($#ships + 1) . " aim: " . $ship->getQuadrant());
	$scr->puts(sprintf('dir: %.2f  quad: %s   x: %s y: %s ', $ship->{direction}, $ship->getQuadrant(), int($ship->{x}), int($ship->{y})) );
	$scr->at($height + 3, 0);
	$scr->puts(
		"weight: " .  $ship->{weight} .
		"  thrust: " . $ship->{thrust} .
		"  speed: " . sprintf('%.1f', $ship->{speed}) . 
		"  cost: \$" . $ship->{cost} . 
		"  powergen: " . sprintf('%.2f', $ship->{currentPowerGen}) . "  "
		);
	# power
	$scr->at($height + 4, 0);
	$scr->puts(sprintf('%-10s|', $ship->{power} . ' / ' . int($ship->{currentPower})). 
	(color('ON_RGB' .
		5 . 
		(int(5 * ($ship->{currentPower} / $ship->{power}))) .
		0) . " "
		x ( 60 * ($ship->{currentPower} / $ship->{power})) . 
		color('RESET') . " " x (60 - ( 60 * ($ship->{currentPower} / $ship->{power}))) ) . "|"
	);
	# display shield
	if ($ship->{shield} > 0){
		$scr->at($height + 5, 0);
		$scr->puts(sprintf('%-10s|', $ship->{shield} . ' / ' . int($ship->{shieldHealth})). 
		(color('ON_RGB' .
			0 . 
			(int(5 * ($ship->{shieldHealth} / $ship->{shield}))) .
			5) . " "
			x ( 60 * ($ship->{shieldHealth} / $ship->{shield})) . 
			color('RESET') . " " x (60 - ( 60 * ($ship->{shieldHealth} / $ship->{shield}))) ) . "|"
		);
	}
	$scr->at($height + 6, 0);
	$scr->puts($self->{debug});
}

sub _resetMap {
	my $self = shift;
	#my ($height, $width) = @_;
	my ($width, $height) = @_;

	my @map;
	foreach my $x (0 .. $height){
		push @map, [];
		foreach my $y (0 .. $width){
			my $modVal = abs(cos(int($x + $self->{ship}->{y}) * int($y + $self->{ship}->{x}) * 53 ));
			my $chr = '.';
			my $col = "";
			if ($modVal < 0.03){
				if ($modVal < 0.0015){
					$col = color("ON_GREY1");
					$chr = '*';
				} elsif ($modVal < 0.0030){
					$col = color("GREY" . int(rand(22)));
				} elsif ($modVal < 0.0045){
					$col = color("yellow");
				} elsif ($modVal < 0.02){
					$col = color("GREY2");
				} else {
					$col = color("GREY5");
				}
			}
			if ($self->{ship}->{movingVert} && $self->{ship}->{movingHoz}){
				# TODO moving upleft = \, or /
			} elsif ($self->{ship}->{movingVert}){
				$chr = '|';
			} elsif ($self->{ship}->{movingHoz}){
				$chr = '–';
			}

			$map[$x][$y] = (($modVal < 0.03) ? $col . $chr . color("RESET") : ' ');
		}
	}
	return \@map;
}

sub _drawBullets {
	my $self = shift;

	my $offx = shift;
	my $offy = shift;

	my %bullets = %{ $self->{bullets} };
	foreach my $bulletK ( keys %bullets){
		my $bullet = $bullets{$bulletK};
		if ($bullet->{expires} < time()){
			delete $bullets{$bulletK};
			next;
		}
		my $spotX = $bullet->{x} + $offy;
		my $spotY = $bullet->{y} + $offx;
		if ($spotX > 0 && $spotY > 0){
			$self->setMap($spotX, $spotY, $bullet->{chr});
		}
	}
}

sub _drawShips {
	my $self = shift;	

	my $offx = shift;
	my $offy = shift;


	foreach my $ship ($self->_getShips()){
		foreach my $part ($ship->getParts()){
			my $highlight = ((time() - $part->{'hit'} < .3) ? color('ON_RGB222') : '');
			my $bold = '';
			if (defined($part->{lastShot})){
				$bold = ((time() - $part->{'lastShot'} < .3) ? color('bold') : '');
			}
			my $px = ($offy + int($ship->{y})) + $part->{'y'};
			my $py = ($offx + int($ship->{x})) + $part->{'x'};
			if (! defined ($part->{x})){ $self->{debug} = Dumper($part); next; }
			# TODO have it fade to black?
			if ($ship->{cloaked}){
						my $chr = $part->{chr};
						$chr =~ s/\e\[\d+(?>(;\d+)*)m//g;
				$self->setMap($px, $py, color('on_black GREY0') . $chr . color('reset'));
			} else { 
				$self->setMap($px, $py, $highlight . $bold . $ship->{color} . $part->{'chr'} . color('reset'));

			}
			if ($ship->{shieldsOn}){
				if ($part->{'part'}->{'type'} eq 'shield'){
					if ($part->{'shieldHealth'} > 0){
						my $shieldLevel = ($highlight ne '' ? 5 : 2);
						### TODO add more lighting if shields in deflector mode, maybe just on the borders
						if ($part->{'part'}->{'size'} eq 'medium'){
							$self->addLighting($px - 2, $py + $_, $shieldLevel) foreach (-1 .. 1);
							$self->addLighting($px - 1, $py + $_, $shieldLevel) foreach (-3 .. 3);
							$self->addLighting($px + 0, $py + $_, $shieldLevel) foreach (-4 .. 4);
							$self->addLighting($px + 1, $py + $_, $shieldLevel) foreach (-3 .. 3);
							$self->addLighting($px + 2, $py + $_, $shieldLevel) foreach (-1 .. 1);
						} elsif ($part->{'part'}->{'size'} eq 'large'){
							$self->addLighting($px - 3, $py + $_, $shieldLevel) foreach (-1 .. 1);
							$self->addLighting($px - 2, $py + $_, $shieldLevel) foreach (-3 .. 3);
							$self->addLighting($px - 1, $py + $_, $shieldLevel) foreach (-4 .. 4);
							$self->addLighting($px + 0, $py + $_, $shieldLevel) foreach (-5 .. 5);
							$self->addLighting($px + 1, $py + $_, $shieldLevel) foreach (-4 .. 4);
							$self->addLighting($px + 2, $py + $_, $shieldLevel) foreach (-3 .. 3);
							$self->addLighting($px + 3, $py + $_, $shieldLevel) foreach (-1 .. 1);
						}
					}
				}
			}
		}
		my ($aimx, $aimy) = $ship->getAimingCursor();
		my $px = ($offy + int($ship->{y})) + $aimx;
		my $py = ($offx + int($ship->{x})) + $aimy;
		$self->setMap($px, $py, color('GREEN') . "+");
	}
}

sub _sendKeystrokesToServer {
	my $self = shift;	
	my $scr = shift;
	# send keystrokes
	if ($scr->key_pressed()) { 
		my $chr = $scr->getch();
		print {$self->{socket}} "$chr\n";
	}
}

sub _getMessagesFromServer {
	my $self = shift;
	my $socket = $self->{socket};
	my $bullets = $self->{bullets};
	while (my $msgjson = <$socket>){
		my $msg;
		eval {
			$msg = decode_json($msgjson);
		};
		if (! defined($msg)){ next; }
		my $data = $msg->{d};
		if ($msg->{c} eq 'b'){ # bullet msg
			my $key = $data->{k};
			# new bullet
			if (!defined($self->{bullets}->{$key})){
				#$ships{$data->{sid}}->{ship}->[$data->{pid}]->{'hit'} = time();
				#$ships{'self'}->{parts}->{$data->{pid}}->{'hit'} = time();
				if (my $ship = $self->_getShip($data->{sid})){
					my $part = $ship->getPartById($data->{pid});
					$part->{'lastShot'} = time();
				} else {
					#$self->{debug} = "ship not found $data->{sid}";
				}
			}
			$self->{bullets}->{$key} = $data;
			$self->{bullets}->{$key}->{expires} = time() + $data->{ex}; # set absolute expire time
		} elsif ($msg->{c} eq 's'){
			foreach my $ship ($self->_getShips()){
				next if ($ship->{id} ne $data->{id});
				$ship->{x} = $data->{x};
				$ship->{y} = $data->{y};
				$ship->{movingVert} = $data->{dy},
				$ship->{movingHoz} = $data->{dx},
				$ship->{powergen} = $data->{powergen};
				$ship->{direction} = $data->{direction};
				$ship->{currentPower} = $data->{currentPower};
			}
		} elsif ($msg->{c} eq 'newship'){
			my $shipNew = SpaceShip->new($data->{design}, $data->{x}, $data->{y}, -1, $data->{id});
			$self->_addShip($shipNew);
		} elsif ($msg->{c} eq 'dam'){
			#$debug = $data->{bullet_del} . " - " . exists($bullets{$data->{bullet_del}});
			delete $self->{bullets}->{$data->{bullet_del}};
			foreach my $s ($self->_getShips()){
					#$self->{debug} = Dumper($data);
				if ($s->{id} eq $data->{ship_id}){
					if (defined($data->{shield})){
						$s->damageShield($data->{id}, $data->{shield});
						$self->{debug} = 'damage shields ' . $data->{shield};
					}
					if (defined($data->{health})){
						$s->damagePart($data->{id}, $data->{health});
					}
				}
			}
		} elsif ($msg->{c} eq 'shipdelete'){
			$self->_removeShip($data->{id});
		} elsif ($msg->{c} eq 'shipchange'){
			foreach my $s ($self->_getShips()){
				if ($s->{id} eq $data->{'ship_id'}){
					$s->_loadShipByMap($data->{'map'});
				}
			}
		} elsif ($msg->{c} eq 'setShipId'){
			foreach my $s ($self->_getShips()){
				if ($s->{id} eq $data->{'old_id'}){
					$s->{id} = $data->{'new_id'};
					$self->{debug} = "$data->{'old_id'} to $data->{'new_id'}";
				}
			}
		}
	}

}

sub _bindSocket {
	my $self = shift;
	my $socket_path = shift;
	my $socket = IO::Socket::UNIX->new(
		Type => SOCK_STREAM(),
		Peer => $socket_path,
	) or die "failed to open socket $socket_path\n";
	$self->{socket} = $socket;
}

sub setMap {
	my $self = shift;
	my ($x, $y, $chr) = @_;
	if ( ! $self->onMap($x, $y) ){ return 0; }
	$self->{map}->[$x]->[$y] = $chr;
}

sub addLighting {
	my $self = shift;
	my ($x, $y, $level) = @_;
	if ( ! $self->onMap($x, $y) ){ return 0; }
	$self->{lighting}->{$x}->{$y} += $level;
}

sub onMap {
	my $self = shift;
	my ($x, $y) = @_;
	return ($x > 0 && $y > 0 && $x < $self->{height} && $y < $self->{width});
}

1;
