use strict; use warnings;
package SpaceClient;
use Term::ANSIColor 4.00 qw(RESET color :constants256 colorstrip);
require Term::Screen;
use List::MoreUtils qw(zip);
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval nanosleep time);
use SpaceShip;
use Data::Dumper;
use JSON::XS qw(encode_json decode_json);
use IO::Socket::UNIX;
use Math::Trig ':radial';

use ShipModule;

use constant {
	ASPECTRATIO => 0.66666666,
	PI => 3.1415
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
	my $ship_file = shift;
	my $socket = shift;
	my $color = shift;

	$self->{msg} = '';
	$self->{msgs} = ();
	$self->{chatWidth} = 80;
	#$self->{height} = 35;
	#$self->{width}  = 120;

	$self->resize();

	$self->{username} = getpwuid($<);

	$self->{debug} = "";
	$self->{maxFps} = 24;
	$self->{maxGackgroundFps} = 6;
	$self->{fps} = 24;
	$self->{mode} = 'drive';

	$self->{cursorx} = 0;
	$self->{cursory} = 0;

	open (my $fh, '<', $ship_file) or die "failed to open $ship_file\n";

	my $shipStr = "";

	# TODO don't send the ship until it successfully loads locally
	while(my $line = <$fh>){
		print $line;
		$shipStr .= $line;
	}
	close ($fh);

	#$shipStr = $self->designShip($shipStr);
	#print "socket: $socket \n";
	
	$self->_bindSocket($socket);
	$self->_loadShip($shipStr, $color);

	$self->{socket}->blocking(0);

	$self->{ships}->{ $self->{ship}->{id} } = $self->{ship};
	$self->{bullets} = {};
	$self->{items}   = {};

	$self->loop();

	return 1;
}

sub designShip {
	my $self = shift;
	my $inputDesign = shift;
	my $cash = 1500;
	my $scr = new Term::Screen;

	my $ship = new SpaceShip($inputDesign, 0, 0, 1);
	$self->{ship} = $ship;
	my @shipArr = @{ $ship->getDisplayArray(5, 5) };

	$scr->clrscr();
	$scr->noecho();
	my $designing = 1;
	my $shipDesign = $inputDesign;
	my $x = 15;
	my $y = 30;
	my @ship;
	foreach my $x (0 .. 30){
		foreach my $y (0 .. 60){
			$ship[$x][$y] = (defined($shipArr[$y][$x]) ? $shipArr[$y][$x] : ' ');
		}
	}

	while ($designing == 1){
		my $px = 0;
		$self->printInfo($scr);
		for my $row (@ship){
			$px++;
			$scr->at($px, 0);
			my $rowPrint = join "", @{$row};
			$scr->puts(color('ON_GREY3') . $rowPrint . color('RESET'));
			$scr->at($x, $y);
		}
		my $chr = undef;
		while (!defined($chr)){
			if ($scr->key_pressed()) { 
				$chr = $scr->getch();
				if ($chr eq 'a'){ $y--; }
				elsif ($chr eq 'd'){ $y++; }
				elsif ($chr eq 's'){ $x++; }
				elsif ($chr eq 'w'){ $x--; }
				elsif (defined($ship->getPartDef($chr))){
					$ship[$x - 1][$y] = $chr;	
				} elsif ($chr eq ' '){
					$ship[$x - 1][$y] = $chr;	
				} elsif ($chr eq 'r'){
					$shipDesign = "";
					for my $row (@ship){
						$shipDesign .= join "", @{$row};
						$shipDesign .= "\n";
					}
					$ship = SpaceShip->new($shipDesign, 0, 0, 'self');
					$self->{ship} = $ship;
				} elsif ($chr eq 'q'){
					$shipDesign = "";
					for my $row (@ship){
						$shipDesign .= join "", @{$row};
						$shipDesign .= "\n";
					}
					$ship = SpaceShip->new($shipDesign, 0, 0, 'self');
					$self->{ship} = $ship;
					$designing = 0;
				}
			}
			usleep(1000);
		}
	}
	return $shipDesign;
}


sub _loadShip {
	my $self = shift;
	my $shipStr = shift;
	my $color = shift;
	$| = 1;

#	open (my $fh, '<', $ship_file) or die "failed to open $ship_file\n";
	# TODO don't send the ship until it successfully loads locally
#	while(my $line = <$fh>){
#		print $line;
#		$shipStr .= $line;
#		print {$self->{'socket'}} $line;
#	}
#	close ($fh);

	print {$self->{socket}} $shipStr;

	if ($color){
		print {$self->{socket}} "OPTION:color=$color\n";
	}
	print {$self->{socket}} "OPTION:name=" . getpwuid( $< ) . "\n";
	print {$self->{socket}} "DONE\n";
	select STDOUT;
	print "loaded\n";
	$self->{ship} = SpaceShip->new($shipStr, 5, 5, 'self', {color => $color});
	$self->_addShip($self->{ship});
	
	return 1;
}

sub _getShips {
	my $self = shift;
	return values %{$self->{ships}};
}

sub _getShipById {
    my $self = shift;
    my $id = shift;
    return $self->{ships}->{$id};
}

sub _getShipCount {
	my $self = shift;
	return scalar $self->_getShips();
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
	#$self->{debug} = $id;
	return $self->{ships}->{$id};
}

sub loop {
	my $self = shift;

	my $lastTime  = time();
	my $lastFrame = time();
	my $frames = 0;
	my $time = time();
	my $fps = $self->{maxFps};

	my $scr = new Term::Screen;
	$scr->clrscr();
	$scr->noecho();

	$self->{scr} = $scr;
	my $lastPing = time();

	$self->setHandlers();
	$self->printBorder($scr);

	my $playing = 1;
	while ($playing){
		if ((time() - $time) < (1 / $fps)){
			my $sleep = 1_000_000 * ((1 / $fps) - (time() - $time));
			if ($sleep > 0){
				usleep($sleep);
			}
			next;
		}
		$lastTime = $time;
		$time = time();
		$frames++;
		if ($time - $lastFrame > 1){
			$lastFrame = $time;
			$self->{fps} = $frames;
			$frames = 0;
		}

		if (time() - $lastPing > 1){
			print {$self->{socket}} "z\n";
		}

		$self->_sendKeystrokesToServer($scr);
		$self->_getMessagesFromServer();

		$self->{lighting} = {};
		my $cenX = int($self->{width} / 2);
		my $cenY = int($self->{height} / 2);
		my $offx = $cenX - int($self->{ship}->{x});
		my $offy = $cenY - int($self->{ship}->{y});

		$self->{'map'} = $self->_resetMap($self->{width}, $self->{height});

		$self->_drawBullets($offx, $offy);
		$self->_drawItems($offx, $offy);
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
		$scr->at($i + 1, 1);
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
	my $options = shift;

	my $ship = $self->{ship};
	my $height = (defined($options->{height}) ? $options->{height} : $self->{height} + 1);
	my $width = $self->{width};
	my $left = 2;

	#### ----- ship info ------ ####
	$scr->at($height + 2, $left);
	#$scr->puts("ships in game: " . ($#ships + 1) . " aim: " . $ship->getQuadrant());
    #$scr->puts(sprintf('dir: %.2f  quad: %s   x: %s y: %s, cx: %s, cy: %s, ships: %s  ', $ship->{direction}, $ship->getQuadrant(), int($ship->{x}), int($ship->{y}), $self->{cursorx}, $self->{cursory}, $self->_getShipCount()) );
	$scr->puts(sprintf('coordinates: %3s,%3s      ships detected: %-3s  ', int($ship->{x}), int($ship->{y}), $self->_getShipCount()) );
	$scr->at($height + 3, $left);
	$scr->puts(
		"fps: " . $self->{fps} . "  " . 
		"id "   . $self->{ship}->{id} . "  " . 
		"weight: " .  $ship->{weight} .
		"  thrust: " . $ship->{thrust} .
		"  speed: " . sprintf('%.1f', $ship->{speed}) . 
		"  cost: \$" . $ship->{cost} . 
		"  cash: \$" . $ship->{cash} . 
		"  powergen: " . sprintf('%.2f', $ship->{currentPowerGen}) . "  "
		);

	my $barWidth = 50;
	############ power
	$scr->at($height + 4, $left);
    $scr->puts( ' ' x 10 .'┌' . '─' x $barWidth . '┐');
	$scr->at($height + 5, $left);
	my $powerWidth = int( $barWidth * ($ship->{currentPower} / $ship->{power}));
	my $powerPad   = $barWidth - $powerWidth;
	$scr->puts(sprintf('%-10s│%s│',
	$ship->{power} . ' / ' . int($ship->{currentPower}) , 
	(color('ON_RGB' .
		5 . 
		(int(5 * ($ship->{currentPower} / $ship->{power}))) .
		0) . (" " x $powerWidth) . 
		color('RESET') . (' ' x $powerPad) )
	));
	############# display shield
	$scr->at($height + 6, $left);
	$scr->puts( ' ' x 10 .'├' . '─' x $barWidth . '┤');
	if ($ship->{shield} > 0){
        my $shieldWidth = int( $barWidth * ($ship->{shieldHealth} / $ship->{shield}));
        my $shieldPad   = $barWidth - $shieldWidth;
		$scr->at($height + 7, $left);
		my $shieldPercent = int($ship->{shieldHealth}) / ($ship->{shield});
		if ($shieldPercent > 1){ $shieldPercent = 1; }
		$scr->puts(sprintf('%-10s│%s│',
		int($ship->{shield}) . ' / ' . int($ship->{shieldHealth}),
		(color('ON_RGB' .
			0 . 
			(int(5 * $shieldPercent)) .
			5) . (" " x $shieldWidth) .
			color('RESET') . (" " x $shieldPad))
		));
	} 
	$scr->at($height + 8, $left);
	$scr->puts( ' ' x 10 .'└' . '─' x $barWidth . '┘');
	#$scr->at($height + 20, $left);
	#$scr->puts($self->{debug});
	$scr->at($height + 9, $left);
	#$scr->puts("Keys: w,s,a,d to move. @ to disable shields. space to fire. q/e or Q/E to aim. Backtick (`) to build, / to chat.\n");
	$scr->puts($self->{debug});
	$scr->at($height + 10, $left);
	$scr->puts($self->{ship}->{debug});

	########## modules #############
    my $mHeight = $height + 3;
	$scr->at($mHeight - 1, $width + 2);
    $scr->puts('┌────────────────────┬───────────┐');
	foreach my $module ( sort $ship->getModules){
	    $scr->at($mHeight, $width + 2);
        # TODO grey for you don't even have the module
		my $color = color($module->getColor($ship));
        $scr->puts(sprintf('│ ' . $color . '%-18s ' . color('reset') . '│ %-9s │', $module->name(), join (',', $module->getKeys())) );
        $mHeight++;
	}
    $scr->at($mHeight, $width + 2);
    $scr->puts('└────────────────────┴───────────┘');

	######### chat or parts #########
	if ($self->{mode} eq 'build'){ # parts
		my $sprintf = '%-3s │ %6s │ %6s │ %6s │ %5s │ %5s │ %5s';
		if (!defined($self->{partsDisplay})){
			my %parts = %{ $ship->getAllPartDefs() };
			$self->{partsDisplay} = [];
			foreach my $ref (
            sort {
                defined($parts{$a}->{damage}) <=> defined($parts{$b}->{damage}) ||
                defined($parts{$a}->{thrust}) <=> defined($parts{$b}->{thrust}) ||
                defined($parts{$a}->{power}) <=> defined($parts{$b}->{power}) ||
                defined($parts{$a}->{shield}) <=> defined($parts{$b}->{shield}) ||
                $parts{$a}->{cost} <=> $parts{$b}->{cost}
            }
            keys %parts){
				my $part = $parts{$ref};
				push(@{ $self->{partsDisplay} },
					sprintf($sprintf,
						$ref,
						'$' . $part->{cost},
						(defined($part->{thrust}) ? $part->{thrust} : ''),
						(defined($part->{power}) ? $part->{power} : ''),
						(defined($part->{damage}) ? $part->{damage} : ''),
						(defined($part->{rate}) ? $part->{rate} : ''),
						(defined($part->{shield}) ? $part->{shield} : ''),
					)
				);
			}
			$self->{partOffset} = 0;
		}

		$scr->at(1, $width + 3);
		$scr->puts(sprintf($sprintf,
			'chr', 'cost', 'thrust', 'power', 'dam', 'RoF', 'shield'));
		for my $line (3 .. $height){
			$scr->at($line, $width + 3);
			my $partLine = $self->{partsDisplay}->[$line - 3];
			$scr->puts(sprintf(' %-' . ($self->{chatWidth} - 4) . 's',
				(defined($partLine) ? $partLine : "")
				)
			);
		}
	} else { # chat
		for my $line (1 .. $height){
			$scr->at($line, $width + 3);
			$scr->puts(' ' x ($self->{chatWidth} - 4));
		}
		my $lastMsg = $#{ $self->{msgs} } + 1;
		my $term = $lastMsg - $height - 4;
		my $count = 2;
		if ($term < 0){ $term = 0; }
		while ($lastMsg > $term){
			$scr->at($height - $count, $width + 4);
			$count++;
			$lastMsg--;
			$scr->puts(sprintf('%-' . $self->{chatWidth} . 's', $self->{msgs}->[$lastMsg]));
		}
		my $boxColor = color('ON_BLACK');
		if ($self->{mode} eq 'type'){ $boxColor = color('ON_GREY4'); }
		$scr->at($height, $width + 4);
		$scr->puts(sprintf('%-' . $self->{chatWidth} . 's', $boxColor . "> " . $self->{'msg'} . color('reset')));
		$scr->at($height, $width + 4 + length($self->{'msg'}) + 2);
	}
}

sub _resetMap {
	my $self = shift;
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

sub _drawItems {
	my $self = shift;

	my $offx = shift;
	my $offy = shift;

	my %items = %{ $self->{items} };
	foreach my $itemK ( keys %items){
		my $item = $items{$itemK};
		if ($item->{expires} < time()){
			delete $items{$itemK};
			next;
		}
		my $spotX = $item->{x} + $offy;
		my $spotY = $item->{y} + $offx;
		if ($spotX > 0 && $spotY > 0){
			$self->setMap($spotX, $spotY, $item->{chr});
		}
	}
}

sub setHandlers {
	my $self = shift;
	$SIG{WINCH} = sub { $self->resize() };
}

sub resize {
	my $self = shift;
	use Term::ReadKey;
	my ($wchar, $hchar, $wpixels, $hpixels) = GetTerminalSize();
	$self->{width} = $wchar - $self->{chatWidth};
	$self->{height} = $hchar - 20;
	if (defined($self->{scr})){
		$self->{scr}->clrscr();
		$self->printBorder();
	}
}

sub printBorder {
	my $self = shift;
	my $scr = $self->{scr};
	$scr->at(0, 0);
	$scr->puts("╔" . "═" x ($self->{width} + 1) . "╦" . "═" x ($self->{chatWidth} - 4). "╗");
	$scr->at($self->{height} + 2, 0);
	$scr->puts("╚" . "═" x ($self->{width} + 1) . "╩" . "═" x ($self->{chatWidth} - 4). "╝");
	foreach my $i (1 .. $self->{height} + 1){
		$scr->at($i, 0);
		$scr->puts("║");
		$scr->at($i, $self->{width} + 2);
		$scr->puts("║");
		$scr->at($i, $self->{width} + $self->{chatWidth});
		$scr->puts("║");
	}
}


sub _drawShips {
	my $self = shift;	

	my $offx = shift;
	my $offy = shift;

	my $time = time();

	foreach my $ship ($self->_getShips()){
		foreach my $part ($ship->getParts()){
			my $highlight = ((time() - $part->{'healing'} < .3 ) ? color('ON_RGB020') : ((time() - $part->{'hit'} < .3) ? color('ON_RGB222') : ''));
			my $bold = '';
			if (defined($part->{lastShot})){
				$bold = (($time - $part->{'lastShot'} < .3) ? color('bold') : '');
			}
			my $timeRainbow = int($time * 2);
			my $rainbow = color("RGB" . abs( 5 - ($timeRainbow % 10)) . abs( 5 - (($timeRainbow + 3) % 10)) . abs( 5 - (($timeRainbow + 6) % 10)));

			my $partColor = ( $part->{'part'}->{'color'} ne 'ship' ?
				( $part->{'part'}->{color} eq 'rainbow' ? $rainbow : $part->{'part'}->{color} )
				: $ship->{color}
			);

			my $px = ($offy + int($ship->{y})) + $part->{'y'};
			my $py = ($offx + int($ship->{x})) + $part->{'x'};

			my $chr = $part->{chr};
			if ( (rand() - 0.3) > ($part->{'health'} / $part->{'part'}->{'health'} ) ){ $chr = ' '; }
			# TODO have it fade to black?
			if ($ship->{cloaked}){
				# remove coloring TODO change to color + chr

				if ($ship->{id} eq $self->{ship}->{id}){
					$self->setMap($px, $py, color('on_black GREY3') . $chr . color('reset'));
				} else {
					$self->setMap($px, $py, color('on_black GREY0') . $chr . color('reset'));
				}
			} else { 
				$self->setMap($px, $py, $highlight . $bold . $partColor . $chr . color('reset'));
			}
			#if (($part->{part}->{type} eq 'laser') && ($time - $part->{lastShot} < .3){
 #			if (($part->{part}->{type} eq 'laser')){
 #				#for (0 .. $part->{type}->{direction}){
 #				for (0 .. 6){
 #					$self->addLighting($px + $_, $py, 4); 
 #				}
 #			}
			if ($ship->{shieldsOn}){
				if ($part->{'part'}->{'type'} eq 'shield'){
					if ($part->{'shieldHealth'} > 0){
						my $shieldLevel = ($highlight ne '' ? $part->{part}->{shieldlight} + 3 : $part->{part}->{shieldlight});
                        if ($ship->getStatus('deflector')){ $shieldLevel += 2; }
						my $radius = $part->{'part'}->{'shieldsize'};
						foreach my $sh_x (-$radius * ASPECTRATIO .. $radius * ASPECTRATIO){
							foreach my $sh_y (-$radius .. $radius){
								if (sqrt((($sh_x / ASPECTRATIO ) ** 2) + ($sh_y ** 2)) <= $radius){
									$self->addLighting($px - $sh_x, $py + $sh_y, $shieldLevel);
								}
							}
						}
					}
				}
			} # end if shields are on
		}
		my ($aimx, $aimy) = $ship->getAimingCursor();
		my $px = ($offy + int($ship->{y})) + $aimx;
		my $py = ($offx + int($ship->{x})) + $aimy;
		if ($self->{ship}->{id} eq $ship->{id}){ # draw the aiming dot for yourself
			$self->setMap($px, $py, color('GREEN') . "+");
		} elsif ($self->{ship}->{radar}){ # if your radar is active
			($aimx, $aimy) = $self->{ship}->getRadar($ship);
			$px = ($offy + int($self->{ship}->{y})) + $aimx;
			$py = ($offx + int($self->{ship}->{x})) + $aimy;
			if (!$ship->{cloaked}){
				if ($ship->{isBot}){
					$self->setMap($px, $py, color('red') . "+");
				} else {
					$self->setMap($px, $py, color('BOLD BRIGHT_BLUE') . "+");
				}
			}
		}
		if (($self->{'mode'} eq "build") && ($self->{ship}->{id} eq $ship->{id})){
		#if (($self->{ship}->{id} eq $ship->{id})){
			my $cx = ($offy + int($ship->{y})) + $self->{'cursorx'};
			my $cy = ($offx + int($ship->{x})) + $self->{'cursory'};
			$self->setMap($cx, $cy, color("BLACK ON_WHITE") . '+');
		}
	}
}

sub _sendKeystrokesToServer {
	my $self = shift;	
	my $scr = shift;
	# send keystrokes
	if ($self->{mode} eq 'drive'){
		while ($scr->key_pressed()){ 
			my $chr = $scr->getch();
			if ($chr eq '`'){
				$self->{'mode'} = 'build';
				$self->{'cursorx'} = 0;
				$self->{'cursory'} = 0;
			} elsif ($chr eq '/'){
				$self->{'mode'} = 'type';
			} else {
				print {$self->{socket}} "$chr\n";
			}
		}
	} elsif($self->{mode} eq 'build') {
		while ($scr->key_pressed()){ 
			my $chr = $scr->getch();
			if ($chr eq '`'){
				$self->{'mode'} = 'drive';
			} elsif ($chr eq '/'){ $self->{mode} = 'type'; }
			elsif ($chr eq 'a'){ $self->{'cursory'}--; }
			elsif ($chr eq 'd'){ $self->{'cursory'}++; }
			elsif ($chr eq 's'){ $self->{'cursorx'}++; }
			elsif ($chr eq 'w'){ $self->{'cursorx'}--; }
			elsif (defined($self->{ship}->getPartDef($chr))){
				#add part
				print {$self->{socket}} "B:$self->{'cursorx'}:$self->{'cursory'}:$chr\n";
			} elsif ($chr eq ' '){
				#remove part
			}
		}
	} elsif($self->{mode} eq 'type'){
		while ($scr->key_pressed()){ 
			{
				local $/ = undef;
				my $chr = $scr->getch();
				if ($chr eq "\r"){
					print {$self->{socket}} "M:$self->{ship}->{color}$self->{username}:$self->{ship}->{color}$self->{'msg'}" . color('RESET') . "\n";
					$self->{'msg'} = '';
					$self->{mode} = 'drive';
				} elsif($chr eq "\b" || ord($chr) == 127){ # 127 is delete
					chop($self->{'msg'});
				} else {
					if (length($self->{'msg'}) < $self->{chatWidth} - 4){
						$self->{'msg'} .= $chr;
					}
				}
			}
		}
	}
}

# get messages from the server
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
				if (my $ship = $self->_getShip($data->{sid})){
					my $part = $ship->getPartById($data->{pid});
					$part->{'lastShot'} = time();
				} else {
					#$self->{debug} = "ship not found $data->{sid}";
				}
			}
			$self->{bullets}->{$key} = $data;
			$self->{bullets}->{$key}->{expires} = time() + $data->{ex}; # set absolute expire time
		} elsif ($msg->{c} eq 'item'){
			my $key = $data->{k};
			$self->{items}->{$key} = $data;
			$self->{items}->{$key}->{expires} = time() + $data->{ex}; # set absolute expire time
			$self->{debug} = "added item $key\n";
		} elsif ($msg->{c} eq 'itemdel'){
			my $key = $data->{k};
			delete $self->{items}->{$key};
		} elsif($msg->{c} eq 'exit'){
			$self->exitGame($data->{'msg'});
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
				$ship->{currentPowerGen} = $data->{powergen};
				$ship->{shieldHealth} = $data->{shieldHealth};
				$ship->{isBot} = $data->{isBot};
			}
		} elsif ($msg->{c} eq 'newship'){
			my $shipNew = SpaceShip->new($data->{design}, $data->{x}, $data->{y}, $data->{id}, $data->{options});
			if ($data->{'map'}){
				$shipNew->_loadShipByMap($data->{'map'});
			}
			if ($data->{'isBot'}){
				$shipNew->{'isBot'} = $data->{'isBot'};
			}
			$self->_addShip($shipNew);
		} elsif ($msg->{c} eq 'dam'){
			#$debug = $data->{bullet_del} . " - " . exists($bullets{$data->{bullet_del}});
			if (defined($data->{bullet_del})){
				delete $self->{bullets}->{$data->{bullet_del}};
			}
			foreach my $s ($self->_getShips()){
				if ($s->{id} eq $data->{ship_id}){
					if (defined($data->{shield})){
						$s->damageShield($data->{id}, $data->{shield});
						#$self->{debug} = 'damage shields ' . $data->{shield};
					}
					if (defined($data->{health})){
						$s->setPartHealth($data->{id}, $data->{health});
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
					$self->{ships}->{$data->{'new_id'}} = $self->{ships}->{$data->{'old_id'}};
					$s->{id} = $data->{'new_id'};
					#$self->{debug} = "$data->{'old_id'} to $data->{'new_id'}";
				}
			}
		} elsif ($msg->{c} eq 'shipstatus'){
			# TODO just get the ship by id
			foreach my $s ($self->_getShips()){
				$s->recieveShipStatusMsg($data);
			}
		} elsif ($msg->{c} eq 'msg'){
			push @{ $self->{msgs} }, "$data->{'user'}:  $data->{'msg'}";
        }
	}
}

sub exitGame {
	my $self = shift;
	my $msg = shift;
	$self->{scr}->clrscr();
	$self->{scr}->at( $self->{height} / 2, $self->{width} / 2);
	$self->{scr}->puts($msg);
	print "\r\n" . "\n" x ($self->{height} / 3);
	exit;
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

sub colorMap {
	my $self = shift;
	my ($x, $y, $color) = @_;
	if ( ! $self->onMap($x, $y) ){ return 0; }
	my $chr = color($color) . colorstrip($self->{map}->[$x]->[$y]);
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
