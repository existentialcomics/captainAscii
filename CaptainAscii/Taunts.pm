#!/usr/bin/perl

use strict; use warnings;

package CaptainAscii::Taunts;

my %quotes;

$quotes{communist}->{attack} = [
'No revolution can succeed without sacrifice.',
'Only through violence can lasting peace be achieved.',
'The universe belongs to all people.',
'Property is a crime against your fellow man.',
'You are a betrayer of the revolution.',
'The path of history is set.',
'The victory of communism is inevitible.',
'The blood of the righteous will not spill in vain.',
'History will absolve us.',
'All reactionaries will be purged.',
'Justice for all at any cost.',
'Not one step back in the fight against injustice',
'History is a dialectical process.',
'The people\'s army will wash over the universe.',
'None will stand against the people\'s army',
];
$quotes{communist}->{attack} = [
'On second thought maybe a few steps back are fine.',
'I must survive to continue to fight against injustice...',
];

$quotes{nihilist}->{attack} = [
'Those who suffer greatly do not fear death.',
'Death is certain. We can only choose the time to die.',
'Man alone can interpret his existence.',
'Life is a mistake.',
'The only evil is to not embrace your freedom.',
'Nothing will save us.',
'All roads end the same.',
'Eternal life would be eternal boredom.',
'It is better to have never been born.',
"That which does not kill you can still kill someone else",
];
$quotes{nihilist}->{flee} = [
'This fight is pointless...like life in general.',
];

$quotes{imperialist}->{attack} = [
'We will stamp out every communist and return order to the land.',
'Disobedience is seed of choas.',
'The empire will be restored.',
'Deviancy is a sickness of the mind.',
'The social order will be restored at any cost.',
];
$quotes{imperialist}->{flee} = [
'We will return to prosecute your crimes',
'Disorder will be stamped out. But maybe another time.',
];

$quotes{zealot}->{attack} = [
'God will judge every non-believer.',
'God does not play dice.',
'Science will not save us.',
'Only through faith and the anguish of life subside.',
'Life cannot be understood through reason alone.',
];
$quotes{zealot}->{attack} = [
'God will punish you for your sins.',
'Even failure is part of God\'s plan.',
];

sub getTaunt {
	my $faction = shift;
	my $type = shift;
	if (defined($quotes{$faction}->{$type})){
		my @taunts = @{ $quotes{$faction}->{$type} };
		return $taunts[rand @taunts];
	}
	return undef;
}

1;
