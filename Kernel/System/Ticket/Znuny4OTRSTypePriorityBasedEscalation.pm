# --
# Copyright (C) 2001-2018 OTRS AG, https://otrs.com/
# Copyright (C) 2012-2018 Znuny GmbH, http://znuny.com/
# --
# $origin: otrs - 33b1ad6acf39acae4eb40e88f0256fa2e8b50fc4 - Kernel/System/Ticket/TicketEscalationPreferences.pm
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Ticket::Znuny4OTRSTypePriorityBasedEscalation;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

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
    my $EscalationOrder = $Self->{ConfigObject}->Get('EscalationOrder');
    if ( !IsArrayRefWithData( $EscalationOrder ) ) {
        $EscalationOrder = ['SLA', 'Type', 'Priority', 'Queue'];
    }

    ATTRIBUTE:
    for my $CurrentAttribute ( @{ $EscalationOrder } ) {

        if ( $CurrentAttribute eq 'SLA' ) {

            next ATTRIBUTE if !$Self->{ConfigObject}->Get('Ticket::Service');
            next ATTRIBUTE if !$Ticket{SLAID};

            %Escalation = $Self->{SLAObject}->SLAGet(
                SLAID  => $Ticket{SLAID},
                UserID => $Param{UserID},
                Cache  => 1,
            );
        }
        elsif ( $CurrentAttribute eq 'Type' ) {

            next ATTRIBUTE if !$Self->{ConfigObject}->Get('Ticket::Type');
            next ATTRIBUTE if !$Ticket{TypeID};

            %Escalation = $Self->{TypeObject}->TypeGet(
                ID     => $Ticket{TypeID},
                UserID => $Param{UserID},
            );
        }
        elsif ( $CurrentAttribute eq 'Priority' ) {

            next ATTRIBUTE if !$Ticket{PriorityID};

            # check if priority bases escalations
            # are restricted for certain ticket types
            my $PriorityBasedEscalation = 1;
            my $TicketTypeRestriction   = $Self->{ConfigObject}->Get('TypeBasedPriorityEscalation');

            if ( IsArrayRefWithData( $TicketTypeRestriction ) ) {

                next ATTRIBUTE if !$Ticket{Type};

                $PriorityBasedEscalation = 0;

                # check if current Type of current ticket
                # is enabled for priority based escalations
                if ( grep { $Ticket{Type} eq $_ } @{ $TicketTypeRestriction } ) {
                    $PriorityBasedEscalation = 1;
                }
            }

            next ATTRIBUTE if !$PriorityBasedEscalation;

            %Escalation = $Self->{PriorityObject}->PriorityGet(
                PriorityID => $Ticket{PriorityID},
                UserID     => 1,
            );
        }
        elsif ( $CurrentAttribute eq 'Queue' ) {

            next ATTRIBUTE if !$Ticket{QueueID};

            %Escalation = $Self->{QueueObject}->QueueGet(
                ID     => $Ticket{QueueID},
                UserID => $Param{UserID},
                Cache  => 1,
            );
        }

        last ATTRIBUTE if ( $Escalation{FirstResponseTime} || $Escalation{UpdateTime} || $Escalation{SolutionTime} );
    }

    return %Escalation;
}

sub Kernel::System::Ticket::_TicketGetFirstResponse { ## no critic
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID Ticket)) {
        if ( !defined $Param{$Needed} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $Needed!" );
            return;
        }
    }

# ---
# Znuny4OTRS-TypePriorityBasedEscalation
# ---
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
# ---
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

sub Kernel::System::Ticket::TicketOwnerSet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID UserID)) {
        if ( !$Param{$Needed} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $Needed!" );
            return;
        }
    }
    if ( !$Param{NewUserID} && !$Param{NewUser} ) {
        $Self->{LogObject}->Log( Priority => 'error', Message => 'Need NewUserID or NewUser!' );
        return;
    }

    # lookup if no NewUserID is given
    if ( !$Param{NewUserID} ) {
        $Param{NewUserID} = $Self->{UserObject}->UserLookup( UserLogin => $Param{NewUser} );
    }

    # lookup if no NewUser is given
    if ( !$Param{NewUser} ) {
        $Param{NewUser} = $Self->{UserObject}->UserLookup( UserID => $Param{NewUserID} );
    }

    # check if update is needed!
    my ( $OwnerID, $Owner ) = $Self->OwnerCheck( TicketID => $Param{TicketID} );
    if ( $OwnerID eq $Param{NewUserID} ) {

        # update is "not" needed!
        return 2;
    }

# ---
# Znuny4OTRS-TypePriorityBasedEscalation
# ---
    # get current ticket
    my %Ticket = $Self->TicketGet(
        %Param,
        DynamicFields => 0,
    );
# ---
    # db update
    return if !$Self->{DBObject}->Do(
        SQL => 'UPDATE ticket SET '
            . ' user_id = ?, change_time = current_timestamp, change_by = ? WHERE id = ?',
        Bind => [ \$Param{NewUserID}, \$Param{UserID}, \$Param{TicketID} ],
    );

    # clear ticket cache
    $Self->_TicketCacheClear( TicketID => $Param{TicketID} );

    # add history
    $Self->HistoryAdd(
        TicketID     => $Param{TicketID},
        CreateUserID => $Param{UserID},
        HistoryType  => 'OwnerUpdate',
        Name         => "\%\%$Param{NewUser}\%\%$Param{NewUserID}",
    );

    # send agent notify
    if ( !$Param{SendNoNotification} ) {
        if (
            $Param{UserID} ne $Param{NewUserID}
            && $Param{NewUserID} ne $Self->{ConfigObject}->Get('PostmasterUserID')
            )
        {

            # send agent notification
            $Self->SendAgentNotification(
                Type                  => 'OwnerUpdate',
                RecipientID           => $Param{NewUserID},
                CustomerMessageParams => {
                    %Param,
                    Body => $Param{Comment} || '',
                },
                TicketID => $Param{TicketID},
                UserID   => $Param{UserID},
            );
        }
    }

# ---
# Znuny4OTRS-TypePriorityBasedEscalation
# ---
#     # trigger event
#     $Self->EventHandler(
#         Event => 'TicketOwnerUpdate',
#         Data  => {
#             TicketID => $Param{TicketID},
#         },
#         UserID => $Param{UserID},
#     );
    # trigger event
    $Self->EventHandler(
        Event => 'TicketOwnerUpdate',
        Data  => {
            TicketID      => $Param{TicketID},
            OldTicketData => \%Ticket,
        },
        UserID => $Param{UserID},
    );
# ---
    return 1;
}

sub Kernel::System::Ticket::TicketTypeSet {
    my ( $Self, %Param ) = @_;

    # type lookup
    if ( $Param{Type} && !$Param{TypeID} ) {
        $Param{TypeID} = $Self->{TypeObject}->TypeLookup( Type => $Param{Type} );
    }

    # check needed stuff
    for my $Needed (qw(TicketID TypeID UserID)) {
        if ( !$Param{$Needed} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $Needed!" );
            return;
        }
    }

    # get current ticket
    my %Ticket = $Self->TicketGet(
        %Param,
        DynamicFields => 0,
    );

    # update needed?
    return 1 if $Param{TypeID} == $Ticket{TypeID};

    # permission check
    my %TypeList = $Self->TicketTypeList(%Param);
    if ( !$TypeList{ $Param{TypeID} } ) {
        $Self->{LogObject}->Log(
            Priority => 'notice',
            Message  => "Permission denied on TicketID: $Param{TicketID}!",
        );
        return;
    }

    return if !$Self->{DBObject}->Do(
        SQL => 'UPDATE ticket SET type_id = ?, change_time = current_timestamp, '
            . ' change_by = ? WHERE id = ?',
        Bind => [ \$Param{TypeID}, \$Param{UserID}, \$Param{TicketID} ],
    );

    # clear ticket cache
    $Self->_TicketCacheClear( TicketID => $Param{TicketID} );

    # get new ticket data
    my %TicketNew = $Self->TicketGet(
        %Param,
        DynamicFields => 0,
    );
    $TicketNew{Type} = $TicketNew{Type} || 'NULL';
    $Param{TypeID}   = $Param{TypeID}   || '';
    $Ticket{Type}    = $Ticket{Type}    || 'NULL';
    $Ticket{TypeID}  = $Ticket{TypeID}  || '';

    # history insert
    $Self->HistoryAdd(
        TicketID    => $Param{TicketID},
        HistoryType => 'TypeUpdate',
        Name        => "\%\%$TicketNew{Type}\%\%$Param{TypeID}\%\%$Ticket{Type}\%\%$Ticket{TypeID}",
        CreateUserID => $Param{UserID},
    );

    # trigger event
# ---
# Znuny4OTRS-TypePriorityBasedEscalation
# ---
#     $Self->EventHandler(
#         Event => 'TicketTypeUpdate',
#         Data  => {
#             TicketID => $Param{TicketID},
#         },
#         UserID => $Param{UserID},
#     );
    $Self->EventHandler(
        Event => 'TicketTypeUpdate',
        Data  => {
            TicketID      => $Param{TicketID},
            OldTicketData => \%Ticket,
        },
        UserID => $Param{UserID},
    );
# ---

    return 1;
}

sub Kernel::System::Ticket::TicketPrioritySet {
    my ( $Self, %Param ) = @_;

    # lookup!
    if ( !$Param{PriorityID} && $Param{Priority} ) {
        $Param{PriorityID} = $Self->{PriorityObject}->PriorityLookup(
            Priority => $Param{Priority},
        );
    }
    if ( $Param{PriorityID} && !$Param{Priority} ) {
        $Param{Priority} = $Self->{PriorityObject}->PriorityLookup(
            PriorityID => $Param{PriorityID},
        );
    }

    # check needed stuff
    for my $Needed (qw(TicketID UserID PriorityID Priority)) {
        if ( !$Param{$Needed} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $Needed!" );
            return;
        }
    }
    my %Ticket = $Self->TicketGet(
        %Param,
        DynamicFields => 0,
    );

    # check if update is needed
    if ( $Ticket{Priority} eq $Param{Priority} ) {

        # update not needed
        return 1;
    }

    # permission check
    my %PriorityList = $Self->PriorityList(%Param);
    if ( !$PriorityList{ $Param{PriorityID} } ) {
        $Self->{LogObject}->Log(
            Priority => 'notice',
            Message  => "Permission denied on TicketID: $Param{TicketID}!",
        );
        return;
    }

    # db update
    return if !$Self->{DBObject}->Do(
        SQL => 'UPDATE ticket SET ticket_priority_id = ?, '
            . ' change_time = current_timestamp, change_by = ?'
            . ' WHERE id = ?',
        Bind => [ \$Param{PriorityID}, \$Param{UserID}, \$Param{TicketID} ],
    );

    # clear ticket cache
    $Self->_TicketCacheClear( TicketID => $Param{TicketID} );

    # add history
    $Self->HistoryAdd(
        TicketID     => $Param{TicketID},
        QueueID      => $Ticket{QueueID},
        CreateUserID => $Param{UserID},
        HistoryType  => 'PriorityUpdate',
        Name         => "\%\%$Ticket{Priority}\%\%$Ticket{PriorityID}"
            . "\%\%$Param{Priority}\%\%$Param{PriorityID}",
    );

    # trigger event
# ---
# Znuny4OTRS-TypePriorityBasedEscalation
# ---
#     $Self->EventHandler(
#         Event => 'TicketPriorityUpdate',
#         Data  => {
#             TicketID => $Param{TicketID},
#         },
#         UserID => $Param{UserID},
#     );
    $Self->EventHandler(
        Event => 'TicketPriorityUpdate',
        Data  => {
            TicketID      => $Param{TicketID},
            OldTicketData => \%Ticket,
        },
        UserID => $Param{UserID},
    );
# ---

    return 1;
}

}

1;
