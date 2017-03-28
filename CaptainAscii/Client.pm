use strict; use warnings;
package CaptainAscii::Client;

BEGIN {
	#$Curses::OldCurses = 1;
	#$Curses::UI::utf8 = 1;
}
use Term::ANSIColor 4.00 qw(RESET color :constants256 colorstrip);
require Term::Screen;
use List::MoreUtils qw(zip);
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval nanosleep time);
use Data::Dumper;
use JSON::XS qw(encode_json decode_json);
use IO::Socket::UNIX;
use Math::Trig ':radial';
use Text::Wrap;
use Curses;

use CaptainAscii::Ship;

use constant {
	ASPECTRATIO => 0.66666666,
	PI => 3.1415
};

my %colors = ();
my $starMapSize = 0;
my @starMap;
my @starMapStr;
my @lighting;

my $useCurses = 1;

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

	$self->_generateStarMap();

	$self->{msg} = '';
	$self->{msgs} = ();
	$self->{chatWidth} = 80;
	$self->{chatOffset} = 0;

	$self->{zoom} = 1;

	$self->resizeScr();

	$self->{lastFrame} = time();
	$self->{lastInfoPrint} = time();

	$self->{username} = getpwuid($<);

	$self->{debug} = "";
	$self->{maxFps} = 400;
	$self->{maxBackgroundFps} = 6;
	$self->{maxInfoFps} = 6;
	$self->{fps} = 400;
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

sub _generateStarMap {
	my $self = shift;
	my $size = shift;
	if (!defined($size)){ $size = 1000; }

	$starMapSize = $size;

	foreach my $x (0 .. $size){
		push @starMap, [ (' ') x $size ];
		push @starMapStr, '';
		foreach my $y (0 .. $size){
			my $rand = rand();
			if ($rand > 0.03){
				$starMapStr[$x] .= ' ';
				next;
			}
			my $starRand = rand();
			my $chr = '.';
			my $col = "";
			if ($starRand < 0.02){
				$chr = '*';
				if ($starRand < 0.1){
					$col = getColor("YELLOW");
				}
			} elsif ($starRand < 0.5){
				$col = getColor("GREY" . int(rand(22)));
			} elsif ($starRand < 0.10){
				$col = getColor("YELLOW");
			} elsif ($starRand < 0.30){
				$col = getColor("GREY2");
			} else {
				$col = getColor("GREY5");
			}
			$starMap[$x]->[$y] = $col . $chr;
			$starMapStr[$x] .= $chr;
		}
	}
}

sub sprite {
	my $self = shift;
	my $array = shift;
	my $length = time() - $self->{lastFrame};
	if ($length > 1){ $length = 1 }
	if ($length < 0){ $length = 0 }
	my $chr = $array->[$length * @{$array}];
	if (!$chr){ $chr = $array->[0] }
	return $chr;
}

sub designShip {
	my $self = shift;
	my $inputDesign = shift;
	my $cash = 1500;
	my $scr = new Term::Screen;

	my $ship = new CaptainAscii::Ship($inputDesign, 0, 0, 1);
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
		$self->printInfo();
		for my $row (@ship){
			$px++;
			my $rowPrint = join "", @{$row};
			$self->putStr(
                $px, 0,
                getColor('ON_GREY3') . $rowPrint . getColor('RESET')
            );
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
					$ship = CaptainAscii::Ship->new($shipDesign, 0, 0, 'self');
					$self->{ship} = $ship;
				} elsif ($chr eq 'q'){
					$shipDesign = "";
					for my $row (@ship){
						$shipDesign .= join "", @{$row};
						$shipDesign .= "\n";
					}
					$ship = CaptainAscii::Ship->new($shipDesign, 0, 0, 'self');
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
	$self->{ship} = CaptainAscii::Ship->new($shipStr, 5, 5, 'self', {color => $color});
	$self->_addShip($self->{ship});
	
	return 1;
}

sub _getShips {
	my $self = shift;
	return values %{$self->{ships}};
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
    #
	$self->{scr} = $scr;

    $self->{win} = Curses->new();
    initscr();
	start_color();
	noecho();


	my $lastPing = time();

	$self->setHandlers();
	$self->printBorder();

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
			$self->{lastFrame} = $time;
		}

		if (time() - $lastPing > 1){
			print {$self->{socket}} "z\n";
		}

		$self->_sendKeystrokesToServer($scr);
		$self->_getMessagesFromServer();

		my $cenX = int(($self->{width} * $self->{zoom})  / 2);
		my $cenY = int(($self->{height} * $self->{zoom}) / 2);
		my $offx = $cenX - int($self->{ship}->{x});
		my $offy = $cenY - int($self->{ship}->{y});

		$self->{'map'} = $self->_resetMap($self->{width} * $self->{zoom}, $self->{height} * $self->{zoom});

		$self->_drawBullets($offx, $offy);
		$self->_drawItems($offx, $offy);
		$self->_drawShips($offx, $offy);

		if ($self->{mode} eq 'zonemap'){
			$self->printZoneScreen($scr);
		} else {
			$self->printScreen($scr);
		}
		$self->printInfo();
        $self->{win}->refresh;
	}
}

sub printZoneScreen {
	my $self = shift;
	my $scr = shift;
	
	my $map = $self->{map};

	### draw the screen to Term::Screen
	foreach my $i (0 .. $self->{height}){
		my $iZ = (int($i * $self->{zoom}));
		my $row = '';
		foreach my $j (0 .. $self->{width}){
			my $jZ = (int($j * $self->{zoom}));
		}
	}
}

sub printScreen {
	if($useCurses){ return 0; }
	my $self = shift;
	my $scr = shift;
	my $map = $self->{map};

	### draw the screen to Term::Screen
	foreach my $i (0 .. $self->{height}){
		my $iZ = (int($i * $self->{zoom}));
		my $row = '';
		foreach (0 .. $self->{width}){
			my $jZ = (int($_ * $self->{zoom}));
			my $lighting = $lighting[$iZ]->[$jZ];
			my $color = getColor('ON_GREY' . ($lighting <= 23 ? $lighting : 23 ));
			if ($useCurses){
				$self->putStr(
					$i + 1, $_,
					(defined($map->[$iZ]->[$jZ]) ? $map->[$iZ]->[$jZ] : $self->getStar($i, $_)),
					$color
				);
			} else {
				$row .= (defined($map->[$iZ]->[$jZ]) ? $color . $map->[$iZ]->[$jZ] : $color . $self->getStar($i, $_));
			}
		}
		if (!$useCurses){
			$self->putStr(
				$i + 1, 1,
				$row
			);
		}
	}
}

sub getStar {
    #my $self = shift;
    #my ($x, $y) = @_;
	# Do not assign variables for performance
#	return $starMap[
#		int($_[1] + $_[0]->{ship}->{y}) % $starMapSize]->[
#		int($_[2] + $_[0]->{ship}->{x}) % $starMapSize];
	return substr($starMapStr[
		int($_[1] + $_[0]->{ship}->{y}) % $starMapSize],
		int($_[2] + $_[0]->{ship}->{x}) % $starMapSize,
		1); 
}

sub printStatusBar {
    my $self = shift;
    my $scr = shift;
    my ($name, $value, $max, $width, $col, $row, $r, $g, $b) = @_;

    my $statBar = '';
    if ($max < 1000){
        $statBar = sprintf(' ' x int($width / 3) . '%3d' . ' ' x int($width / 3) . '%3d' . ' ' x int($width / 3), $max * 0.33, $max * 0.66);
    } else {
        $statBar = sprintf(' ' x int($width / 3) . '%3d' . ' ' x int($width / 3) . '%3d' . ' ' x int($width / 3), $max * 0.33, $max * 0.66);
    }
    
    my $widthStatus = $width - length($name);
    $self->putStr(
        $col, $row,
        '╭' . '─' x ($widthStatus / 2) . $name . '-' x ($widthStatus / 2) . '╮'
    );
    $self->putStr(
        $col + 1, $row,
        $statBar
    );
    $self->putStr(
        $col + 2, $row,
        '╰' . '─' x $width . '╯'
    );
}

sub putStr {
    my $self = shift;
    my ($col, $row, $str, $color, $colorBack) = @_;

	if ($useCurses){
		$self->{win}->addstr($col, $row, $str);
	} else {
		if (!defined($color)){ $color = 'WHITE'; }
		if (!defined($colorBack)){ $colorBack = 'ON_BLACK'; }
		$self->{scr}->at($col, $row);
		$self->{scr}->puts(getColor($color) . getColor($colorBack) . $str);
	}

}

sub printInfo {
	my $self = shift;
	my $options = shift;

	if ((time() - $self->{lastInfoPrint}) < (1 / $self->{maxInfoFps})){
		return;
	}
    $self->printBorder();

	my $ship = $self->{ship};
	#my $height = (defined($options->{height}) ? $options->{height} : $self->{height} + 1);
	my $height = $self->{height} + 1;
	my $width = $self->{width};
	my $left = 2;

	#### ----- ship info ------ ####
    $self->putStr(
        $height + 2, $left, 
	    sprintf('coordinates: %3s,%3s      ships detected: %-3s  h:%s,w:%s ', int($ship->{x}), int($ship->{y}), $self->_getShipCount(), $height, $width)
    );

	$self->putStr(
        $height + 3, $left,
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
	############ health
#	$scr->at($height + 4, $left);
#    $scr->puts(
#        ' ' x 10 .'┌' . '─' x $barWidth . '┐'
#    );
#	$scr->at($height + 5, $left);
    #
	#TODO investigate why this goes above one
#	my $healthRatio = ($ship->{currentHealth} / $ship->{health});
#	if ($healthRatio > 1){ $healthRatio = 1 };
#	my $healthWidth = int( $barWidth * $healthRatio);
#	my $healthPad   = $barWidth - $healthWidth;
#	$scr->puts(sprintf('%-10s│%s│',
#		int($ship->{currentHealth}) . ' / ' . int($ship->{health}) , 
#	(getColor('ON_RGB' .
#		0 .
#		#(5 - int(5 * ($ship->{currentHealth} / $ship->{health}))) .
#		(int(5 * $healthRatio)) .
#		0
#		) . (" " x $healthWidth) . 
#		getColor('RESET') . (' ' x $healthPad) )
#	));
#	
#	############ power
#	$scr->at($height + 6, $left);
#	$scr->puts( ' ' x 10 .'├' . '─' x $barWidth . '┤');
#	$scr->at($height + 7, $left);
#	my $powerWidth = int( $barWidth * ($ship->{currentPower} / $ship->{power}));
#	my $powerPad   = $barWidth - $powerWidth;
#	$scr->puts(sprintf('%-10s│%s│',
#		int($ship->{currentPower}) . ' / ' . int($ship->{power}) , 
#	(getColor('ON_RGB' .
#		5 . 
#		(int(5 * ($ship->{currentPower} / $ship->{power}))) .
#		0) . (" " x $powerWidth) . 
#		getColor('RESET') . (' ' x $powerPad) )
#	));
    #
#	############# display shield
#	$scr->at($height + 8, $left);
#	$scr->puts( ' ' x 10 .'├' . '─' x $barWidth . '┤');
#	$scr->at($height + 9, $left);
#	if ($ship->{shield} > 0){
#        my $shieldWidth = int( $barWidth * ($ship->{shieldHealth} / $ship->{shield}));
#        my $shieldPad   = $barWidth - $shieldWidth;
#		my $shieldPercent = int($ship->{shieldHealth}) / ($ship->{shield});
#		if ($shieldPercent > 1){ $shieldPercent = 1; }
#		$scr->puts(sprintf('%-10s│%s│',
#		int($ship->{shield}) . ' / ' . int($ship->{shieldHealth}),
#		(getColor('ON_RGB' .
#			0 . 
#			(int(5 * $shieldPercent)) .
#			5) . (" " x $shieldWidth) .
#			getColor('RESET') . (" " x $shieldPad))
#		));
#	} else {
#		$scr->puts( ' ' x 10 .'│' . ' ' x $barWidth . '│');
#		$scr->at($height + 9, $left);
#	}
#	$scr->at($height + 10, $left);
#	$scr->puts( ' ' x 10 .'└' . '─' x $barWidth . '┘');

	########## modules #############
    my $mHeight = $height + 3;
    $self->putStr(
        $mHeight - 1, $width + 2,
        '┌────────────────────┬───────────┐'
    );

	foreach my $module ( sort $ship->getModules){
        # TODO grey for you don't even have the module
		my $color = $module->getColor($ship);
        $self->putStr(
            $mHeight, $width + 2,
            sprintf('│ %-18s │ %-9s │', $module->name(), join (',', $module->getKeys())),
			$color
        );
        $mHeight++;
	}
    $self->putStr(
        $mHeight - 1, $width + 2,
        '└────────────────────┴───────────┘'
    );

	######### chat or parts #########
	if ($self->{mode} eq 'build'){ # parts
		my $sprintf = '%3s │ %5s │ %6s │ %6s │ %6s │ %5s │ %5s │ %5s';
		if (!defined($self->{partsDisplay})){
			my %parts = %{ $ship->getAllPartDefs() };
			$self->{partsDisplay} = [];
			foreach my $ref (
            sort {
                defined($parts{$a}->{damage}) <=> defined($parts{$b}->{damage}) ||
                defined($parts{$a}->{thrust}) <=> defined($parts{$b}->{thrust}) ||
                defined($parts{$a}->{power})  <=> defined($parts{$b}->{power}) ||
                defined($parts{$a}->{shield}) <=> defined($parts{$b}->{shield}) ||
                $parts{$a}->{cost} <=> $parts{$b}->{cost}
            }
            keys %parts){
				my $part = $parts{$ref};
				if (defined($part->{show})){
					next if ($part->{show} eq 'no');
				}
				push(@{ $self->{partsDisplay} },
					($ship->hasSparePart($ref) > 0 ? getColor('white') : getColor('grey10')) .
					sprintf($sprintf,
						$ref,
						'x' . $ship->hasSparePart($ref),
						'$' . $part->{cost},
						(defined($part->{thrust}) ? $part->{thrust} : ''),
						(defined($part->{power}) ? $part->{power} : ''),
						(defined($part->{damage}) ? $part->{damage} : ''),
						(defined($part->{rate}) ? $part->{rate} : ''),
						(defined($part->{shield}) ? $part->{shield} : ''),
					) . getColor('reset')
				);
			}
			$self->{partOffset} = 0;
		}

		$self->putStr(
            2, $width + 3,
            sprintf($sprintf,
			'chr', 'owned', 'cost', 'thrust', 'power', 'dam', 'RoF', 'shield')
        );
		$self->putStr(
            3, $width + 3,
            '────┼───────┼────────┼────────┼────────┼───────┼───────┼───────'
        );
		for my $line (4 .. $height){
			my $partLine = $self->{partsDisplay}->[$line - 3];
			$self->putStr(
                $line, $width + 3,
                sprintf('%-' . ($self->{chatWidth} - 4) . 's',
				    (defined($partLine) ? $partLine : "")
				)
			);
		}
	} else { # chat
		for my $line (1 .. $height){
			$self->putStr(
                $line, $width + 3,
                ' ' x ($self->{chatWidth} - 4)
            );
		}
		my $lastMsg = $#{ $self->{msgs} } + 1 + $self->{chatOffset};
		my $term = $lastMsg - $height - 4;
		my $count = 2;
		if ($term < 0){ $term = 0; }
		while ($lastMsg > $term){
			$count++;
			$lastMsg--;
			my $msgLine = $self->{msgs}->[$lastMsg];
			if ($msgLine){
				$self->putStr(
                    $height - $count, $width + 4,
                    sprintf('%-' . $self->{chatWidth} . 's', $msgLine)
                );
			}
		}
		my $boxColor = 'ON_BLACK';
		if ($self->{mode} eq 'type'){ $boxColor = 'ON_GREY4'; }
		$self->putStr(
            $height, $width + 4,
            sprintf('%-' . $self->{chatWidth} . 's', $boxColor . "> " . substr($self->{'msg'}, -($self->{chatWidth} -3))),
			$boxColor
        );
        $self->putStr($height, $width + 4 + length($self->{'msg'}) + 2, 'ON_WHITE');
	}
}

sub _resetMap {
	my $self = shift;
	my ($width, $height) = @_;
	my @map = ();

	if ($useCurses){
		$self->{win}->erase();
		my $offset = int($self->{ship}->{x}) % $starMapSize;
		foreach my $x (0 .. $height){
			my $length = $width;
			if ($offset + $width > $starMapSize){
				$length = $starMapSize - $offset;
			}
			$self->putStr($x, 1, substr($starMapStr[
				int($x + $self->{ship}->{y}) % $starMapSize],
				$offset,
				$length)
			); 
			$self->putStr($x, 1, substr($starMapStr[
				int($x + $self->{ship}->{y}) % $starMapSize],
				$length,
				$width - $length)
			); 
		}
		return [];
	}

	foreach my $x (0 .. $height){
		push @map, [(undef) x $width];
	}

	@lighting = ();
	foreach my $x (0 .. $height + 1){
		push @lighting, [(0) x ($width + 1)];
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
            $self->setMap($spotX, $spotY, $bullet->{chr}, $bullet->{col});
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
	$SIG{WINCH} = sub { $self->resizeScr() };
}

sub resizeScr {
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

	my $color = $self->borderColor();

	$self->putStr(
        0, 0,
        "╔" . "═" x ($self->{width} + 1) . "╦" . "═" x ($self->{chatWidth} - 4). "╗",
		$color
    );
	$self->putStr(
        $self->{height} + 2, 0,
        "╚" . "═" x ($self->{width} + 1) . "╩" . "═" x ($self->{chatWidth} - 4). "╝",
		$color
    );
	foreach my $i (1 .. $self->{height} + 1){
		$self->putStr(
            $i, 0,
            "║",
			$color
        );
		$self->putStr(
            $i, $self->{width} + 2,
            "║",
			$color
        );
		$self->putStr(
            $i, $self->{width} + $self->{chatWidth},
		    "║",
			$color
        );
	}
}

sub borderColor {
	my $self = shift;
    if (time() - $self->{'ship'}->getStatus('lastHit') < 0.2){
        return 'RED ON_BLACK';
    } elsif (time() - $self->{ship}->getStatus('lastShieldHit') < 0.2){
        return 'BLUE ON_BLACK';
    } else {
        return 'WHITE ON_BLACK';
    }
}

sub setMapString {
	my $self = shift;
	my ($string, $x, $y, $color) = @_;
	my @ar = split("", $string);
	my $dy = 0;
	foreach my $chr (@ar){
		$self->setMap($x, $y + $dy, $chr, $color);
		$dy++;
	}
}

sub _drawShips {
	my $self = shift;	

	my $offx = shift;
	my $offy = shift;

	my $time = time();

	foreach my $ship ($self->_getShips()){
		my $taunt = $ship->getStatus('taunt');
		#if ($taunt && (time() - $ship->{lastTauntTime} > 8)){
		if ($taunt && (time() - $ship->{lastTauntTime} < 8)){
			my $tx = $offy + int($ship->getShipTop() - 2);
			my $ty = $offx + int($ship->getShipLeft());
			$self->setMapString($taunt, $tx, $ty);
		}
		foreach my $part ($ship->getParts()){
			my $highlight = ((time() - $part->{'healing'} < .3 ) ? 'ON_RGB020' : ((time() - $part->{'hit'} < .3) ? 'ON_RGB222' : ''));
			my $bold = '';
			if (defined($part->{lastShot})){
				$bold = (($time - $part->{'lastShot'} < .3) ? 'bold' : 'clear');
			}
			my $timeRainbow = int($time * 2);
			my $rainbow = "RGB" . abs( 5 - ($timeRainbow % 10)) . abs( 5 - (($timeRainbow + 3) % 10)) . abs( 5 - (($timeRainbow + 6) % 10));

			my $partColor = $part->{'part'}->{'color'} ne 'ship' ?
				( $part->{'part'}->{color} eq 'rainbow' ? $rainbow : $part->{'part'}->{color} )
				: $ship->{color};

			# TODO x and y switched
			my $px = ($offy + int($ship->{y})) + $part->{'y'};
			my $py = ($offx + int($ship->{x})) + $part->{'x'};

			my $chr = $part->{chr};
			if ( (rand() - 0.3) > ($part->{'health'} / $part->{'part'}->{'health'} ) ){ $chr = ' '; }
			
			# TODO have it fade to black?
			if ($ship->{cloaked}){
				# remove coloring TODO change to color + chr

				if ($ship->{id} eq $self->{ship}->{id}){
					$self->setMap($px, $py, $chr, 'GREY3');
				} else {
					$self->setMap($px, $py, $chr, 'GREY0');
				}
			} else { 
				$self->setMap($px, $py, $chr, "$highlight $bold $partColor");
			}
			#if (($part->{part}->{type} eq 'laser') && ($time - $part->{lastShot} < .3){
 #			if (($part->{part}->{type} eq 'laser')){
 #				#for (0 .. $part->{type}->{direction}){
 #				for (0 .. 6){
 #					$self->addLighting($px + $_, $py, 4); 
 #				}
 #			}
			if ($ship->{shieldsOn} && !($self->{mode} eq 'build' && $ship->{id} eq $self->{ship}->{id})){
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
			$self->setMap($px, $py, '+','GREEN');
		} elsif ($self->{ship}->{radar}){ # if your radar is active
			($aimx, $aimy) = $self->{ship}->getRadar($ship);
			$px = ($offy + int($self->{ship}->{y})) + $aimx;
			$py = ($offx + int($self->{ship}->{x})) + $aimy;
			if (!$ship->{cloaked}){
				if ($ship->{isBot}){
					$self->setMap($px, $py, "+", 'RED');
				} else {
					$self->setMap($px, $py, "+", 'BOLD BRIGHT_BLUE');
				}
			}
		}
		if (($self->{'mode'} eq "build") && ($self->{ship}->{id} eq $ship->{id})){
		#if (($self->{ship}->{id} eq $ship->{id})){
			my $cx = ($offy + int($ship->{y})) + $self->{'cursorx'};
			my $cy = ($offx + int($ship->{x})) + $self->{'cursory'};
			$self->setMap($cx, $cy, '+', "BLACK", "ON_WHITE");
		}
	}
}

sub _sendKeystrokesToServer {
	my $self = shift;	
	my $scr = shift;

	# send keystrokes
	if ($self->{mode} eq 'drive'){
		while ($scr->key_pressed()){ 
			#my $chr = $scr->getch();
			my $chr = getch();
			if ($chr eq '`'){
				$self->{'mode'} = 'build';
				$self->{'cursorx'} = 0;
				$self->{'cursory'} = 0;
			} elsif ($chr eq '/'){
				$self->{'msg'} = '/';
				$self->{'mode'} = 'type';
			} elsif ($chr eq "\r"){
				$self->{'mode'} = 'type';
			} elsif ($chr eq "pgup"){
				$self->{chatOffset}--;
			} elsif ($chr eq "pgdn"){
				$self->{chatOffset}++;
				if ($self->{chatOffset} > 0){ $self->{chatOffset} = 0; }
			} elsif ($chr eq "-"){
				$self->{zoom}++;
			} elsif ($chr eq "+"){
				$self->{zoom}--;
				if ($self->{zoom} < 1){ $self->{zoom} = 1; }
			} else {
				print {$self->{socket}} "$chr\n";
			}
		}
	} elsif($self->{mode} eq 'build') {
		while ($scr->key_pressed()){ 
			my $chr = $scr->getch();
			if ($chr eq '`'){
				$self->{'mode'} = 'drive';
			}
			elsif ($chr eq 'a'){ $self->{'cursory'}--; }
			elsif ($chr eq 'd'){ $self->{'cursory'}++; }
			elsif ($chr eq 's'){ $self->{'cursorx'}++; }
			elsif ($chr eq 'w'){ $self->{'cursorx'}--; }
			elsif (defined($self->{ship}->getPartDef($chr))){
				#add part
				print {$self->{socket}} "B:$self->{'cursorx'}:$self->{'cursory'}:$chr\n";
			} elsif ($chr eq ' '){
				print {$self->{socket}} "B:$self->{'cursorx'}:$self->{'cursory'}: \n";
				#remove part
			}
		}
	} elsif($self->{mode} eq 'type'){
		while ($scr->key_pressed()){ 
			{
				local $/ = undef;
				my $chr = $scr->getch();
				if ($chr eq "\r"){
                    if ($self->{'msg'} eq '/exit'){
                        endwin;
                        exit;
                    } else {
					    print {$self->{socket}} "M:$self->{username}:$self->{'msg'}\n";
                    }
					$self->{'msg'} = '';
					$self->{mode} = 'drive';
				} elsif($chr eq "\b" || ord($chr) == 127){ # 127 is delete
					chop($self->{'msg'});
				} else {
					$self->{'msg'} .= $chr;
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
			#$self->{debug} = "added item $key\n";
		} elsif ($msg->{c} eq 'itemdel'){
			my $key = $data->{k};
			delete $self->{items}->{$key};
		} elsif($msg->{c} eq 'exit'){
			$self->exitGame($data->{'msg'});
		} elsif ($msg->{c} eq 'newship'){
			my $shipNew = CaptainAscii::Ship->new($data->{design}, $data->{x}, $data->{y}, $data->{id}, $data->{options});
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
					$s->_loadShipByMap($data->{'chr_map'}, $data->{'part_map'});
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
			my $msgStringFull = "";
            if ($data->{'user'}){
				$msgStringFull .= sprintf('%-10s: %s', $data->{'user'}, $data->{'msg'});
            } else {
				$msgStringFull .= $data->{'msg'};
            }
			$Text::Wrap::columns = $self->{chatWidth} - 10;
			my @wrappedMsgs = split("\n", wrap("", "  ", $msgStringFull));
			$self->{debug} = "wrapped: $#wrappedMsgs";
			foreach my $msgString (@wrappedMsgs){
			if (defined($data->{'color'})){
				$msgString = getColor($data->{'color'}) . $msgString;
			}
			$msgString .= getColor('reset');
			push @{ $self->{msgs} }, $msgString;
			}
        } elsif ($msg->{c} eq 'sparepart'){
			if (defined($data->{add})){
				$self->{ship}->addSparePart($data->{'part'}, $data->{add});
			} elsif(defined($data->{use})){
				$self->{ship}->useSparePart($data->{'part'}, $data->{use});
			}
			delete $self->{partsDisplay};
		}
	}
}

sub exitGame {
	my $self = shift;
	my $msg = shift;
    $self->putStr(
        $self->{height} / 2, $self->{width} / 2,
        $msg
    );
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

sub getColor {
    #my $self = shift;
    #my $name = shift;
	# Do not assign variables for performance
    if (!defined($colors{$_[0]})){
        $colors{$_[0]} = color($_[0]);
    }
    return $colors{$_[0]};
}

sub setMap {
	# $self->onMap($x, $y);
	if ( ! onMap($_[0], $_[1], $_[2]) ){ return 0; }
	if ($useCurses){ putStr(@_); }

	my $self = shift;
	my ($x, $y, $chr, $color) = @_;
	if (!defined($color)){ $color = 'reset' }
	if (ref($chr) eq 'ARRAY'){
		$chr = $self->sprite($chr);
	}
	$self->{map}->[$x]->[$y] = getColor($color) . $chr . getColor('reset');
}

sub colorMap {
	my $self = shift;
	my ($x, $y, $color) = @_;
	if ( ! $self->onMap($x, $y) ){ return 0; }
	my $chr = getColor($color) . colorstrip($self->{map}->[$x]->[$y]);
	$self->{map}->[$x]->[$y] = $chr;

}

sub addLighting {
	my $self = shift;
	my ($x, $y, $level) = @_;
	if ( ! $self->onMap($x, $y) ){ return 0; }
	$lighting[$x]->[$y] += $level;
}

sub onMap {
	my $self = shift;
	my ($x, $y) = @_;
	return ($x > 0 && $y > 0 && $x < $self->{height} * $self->{zoom} && $y < $self->{width} * $self->{zoom});
}

1;
