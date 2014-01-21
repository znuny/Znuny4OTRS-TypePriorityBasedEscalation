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

        %Escalation = $Self->{PriorityObject}->PriorityGet(
            PriorityID => $Ticket{PriorityID},
            UserID     => 1,
        );

        if ( !( $Escalation{FirstResponseTime} || $Escalation{UpdateTime} || $Escalation{SolutionTime} ) ) {
            %Escalation = $Self->{QueueObject}->QueueGet(
                ID     => $Ticket{QueueID},
                UserID => $Param{UserID},
                Cache  => 1,
            );
        }
    }

    return %Escalation;
}


sub _TicketGetFirstResponse {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID Ticket)) {
        if ( !defined $Param{$Needed} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $Needed!" );
            return;
        }
    }

#---
# Znuny4OTRS-PriorityBasedEscalations
#---
#    # check if first response is already done
#    return if !$Self->{DBObject}->Prepare(
#        SQL => 'SELECT a.create_time,a.id FROM article a, article_sender_type ast, article_type art'
#            . ' WHERE a.article_sender_type_id = ast.id AND a.article_type_id = art.id AND'
#            . ' a.ticket_id = ? AND ast.name = \'agent\' AND'
#            . ' (art.name LIKE \'email-ext%\' OR art.name LIKE \'note-ext%\' OR art.name = \'phone\' OR art.name = \'fax\' OR art.name = \'sms\')'
#            . ' ORDER BY a.create_time',
#        Bind  => [ \$Param{TicketID} ],
#        Limit => 1,
#    );

    my $FirstResponseSQL;
    my $FirstResponseReset = $Self->{ConfigObject}->Get('FirstResponseDecisionBase');
    if (
        $FirstResponseReset
        && $FirstResponseReset eq 'Owner'
    ) {
        $FirstResponseSQL = "SELECT th.create_time"
                            ." FROM ticket_history th, ticket_history_type tht"
                            ." WHERE tht.name = 'OwnerUpdate' AND th.history_type_id = tht.id AND th.ticket_id = ?"
                            ." ORDER BY th.create_time";
    }
    else {
        $FirstResponseSQL = 'SELECT a.create_time,a.id FROM article a, article_sender_type ast, article_type art'
                        . ' WHERE a.article_sender_type_id = ast.id AND a.article_type_id = art.id AND'
                        . ' a.ticket_id = ? AND ast.name = \'agent\' AND'
                        . ' (art.name LIKE \'email-ext%\' OR art.name LIKE \'note-ext%\' OR art.name = \'phone\' OR art.name = \'fax\' OR art.name = \'sms\')'
                        . ' ORDER BY a.create_time';
    }

    # check if first response is already done
    return if !$Self->{DBObject}->Prepare(
        SQL   => $FirstResponseSQL,
        Bind  => [ \$Param{TicketID} ],
        Limit => 1,
    );
#---
    my %Data;
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        $Data{FirstResponse} = $Row[0];

        # cleanup time stamps (some databases are using e. g. 2008-02-25 22:03:00.000000
        # and 0000-00-00 00:00:00 time stamps)
        $Data{FirstResponse} =~ s/^(\d\d\d\d-\d\d-\d\d\s\d\d:\d\d:\d\d)\..+?$/$1/;
    }

    return if !$Data{FirstResponse};

    # get escalation properties
    my %Escalation = $Self->TicketEscalationPreferences(
        Ticket => $Param{Ticket},
        UserID => $Param{UserID} || 1,
    );

    if ( $Escalation{FirstResponseTime} ) {

        # get unix time stamps
        my $CreateTime = $Self->{TimeObject}->TimeStamp2SystemTime(
            String => $Param{Ticket}->{Created},
        );
        my $FirstResponseTime = $Self->{TimeObject}->TimeStamp2SystemTime(
            String => $Data{FirstResponse},
        );

        # get time between creation and first response
        my $WorkingTime = $Self->{TimeObject}->WorkingTime(
            StartTime => $CreateTime,
            StopTime  => $FirstResponseTime,
            Calendar  => $Escalation{Calendar},
        );

        $Data{FirstResponseInMin} = int( $WorkingTime / 60 );
        my $EscalationFirstResponseTime = $Escalation{FirstResponseTime} * 60;
        $Data{FirstResponseDiffInMin} = int( ( $EscalationFirstResponseTime - $WorkingTime ) / 60 );
    }
    return %Data;
}

}

1;
