#!/usr/bin/perl

use strict; use warnings;

package Taunts;

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
];

$quotes{imperialist}->{attack} = [
'We will stamp out every communist and return order to the land.',
'Disobedience is seed of choas.',
'Deviancy is a sickness of the mind.',
'The social order will be restored at any cost.',
];

$quotes{zealot}->{attack} = [
'God will judge every non-believer.',
'God does not play dice.',
'Science will not save us.',
'Life cannot be understood through reason alone.',
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
