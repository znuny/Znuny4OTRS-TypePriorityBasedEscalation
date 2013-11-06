# Copyright (C) 2013 Znuny GmbH, http://znuny.com/

use strict;
use warnings;

use Kernel::System::Ticket;

use vars qw(@ISA);

# disable redefine warnings in this scope
{
no warnings 'redefine';

sub Kernel::System::Ticket::TicketEscalationPreferences {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Ticket UserID)) {
        if ( !defined $Param{$Needed} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $Needed!" );
            return;
        }
    }

    # get ticket attributes
    my %Ticket = %{ $Param{Ticket} };

    # get escalation properties
    my %Escalation;
    if ( $Self->{ConfigObject}->Get('Ticket::Service') && $Ticket{SLAID} ) {
        %Escalation = $Self->{SLAObject}->SLAGet(
            SLAID  => $Ticket{SLAID},
            UserID => $Param{UserID},
            Cache  => 1,
        );
    }
    else {
        my %Priority = $Self->{PriorityObject}->PriorityGet(
            PriorityID => $Ticket{PriorityID},
            UserID     => 1,
        );
        if ( $Priority{FirstResponseTime} || $Priority{UpdateTime} || $Priority{SolutionTime} ) {
            %Escalation = %Priority;
        }
        else {
            %Escalation = $Self->{QueueObject}->QueueGet(
                ID     => $Ticket{QueueID},
                UserID => $Param{UserID},
                Cache  => 1,
            );
        }
    }

    return %Escalation;
}

}

1;
