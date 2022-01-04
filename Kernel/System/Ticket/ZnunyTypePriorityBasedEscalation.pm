# --
# Copyright (C) 2001-2022 OTRS AG, https://otrs.com/
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# $origin: znuny - 7b01128479d53da23792fc174c6b51bd183056b7 - Kernel/System/Ticket.pm
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --
## nofilter(TidyAll::Plugin::OTRS::Perl::PerlCritic)

package Kernel::System::Ticket::ZnunyTypePriorityBasedEscalation;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

# disable redefine warnings in this scope
{
    no warnings 'redefine';

    sub Kernel::System::Ticket::TicketEscalationPreferences {
        my ( $Self, %Param ) = @_;

        # check needed stuff
        for my $Needed (qw(Ticket UserID)) {
            if ( !defined $Param{$Needed} ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Needed!"
                );
                return;
            }
        }

        # get ticket attributes
        my %Ticket = %{ $Param{Ticket} };

        # get escalation properties
        my %Escalation;
# ---
# Znuny-TypePriorityBasedEscalation
# ---
#         if ( $Kernel::OM->Get('Kernel::Config')->Get('Ticket::Service') && $Ticket{SLAID} ) {
#
#             %Escalation = $Kernel::OM->Get('Kernel::System::SLA')->SLAGet(
#                 SLAID  => $Ticket{SLAID},
#                 UserID => $Param{UserID},
#                 Cache  => 1,
#             );
#         }
#         else {
#             %Escalation = $Kernel::OM->Get('Kernel::System::Queue')->QueueGet(
#                 ID     => $Ticket{QueueID},
#                 UserID => $Param{UserID},
#                 Cache  => 1,
#             );
#         }

        my $EscalationOrder = $Kernel::OM->Get('Kernel::Config')->Get('EscalationOrder');
        if ( !IsArrayRefWithData($EscalationOrder) ) {
            $EscalationOrder = [ 'SLA', 'Type', 'Priority', 'Queue' ];
        }

        ATTRIBUTE:
        for my $CurrentAttribute ( @{$EscalationOrder} ) {
            if ( $CurrentAttribute eq 'SLA' ) {
                next ATTRIBUTE if !$Kernel::OM->Get('Kernel::Config')->Get('Ticket::Service');
                next ATTRIBUTE if !$Ticket{SLAID};

                %Escalation = $Kernel::OM->Get('Kernel::System::SLA')->SLAGet(
                    SLAID  => $Ticket{SLAID},
                    UserID => $Param{UserID},
                    Cache  => 1,
                );
            }
            elsif ( $CurrentAttribute eq 'Type' ) {
                next ATTRIBUTE if !$Kernel::OM->Get('Kernel::Config')->Get('Ticket::Type');
                next ATTRIBUTE if !$Ticket{TypeID};

                %Escalation = $Kernel::OM->Get('Kernel::System::Type')->TypeGet(
                    ID     => $Ticket{TypeID},
                    UserID => $Param{UserID},
                );
            }
            elsif ( $CurrentAttribute eq 'Priority' ) {
                next ATTRIBUTE if !$Ticket{PriorityID};

                # check if priority bases escalations
                # are restricted for certain ticket types
                my $PriorityBasedEscalation = 1;
                my $TicketTypeRestriction   = $Kernel::OM->Get('Kernel::Config')->Get('TypeBasedPriorityEscalation');

                if ( IsArrayRefWithData($TicketTypeRestriction) ) {

                    next ATTRIBUTE if !$Ticket{Type};

                    $PriorityBasedEscalation = 0;

                    # check if current Type of current ticket
                    # is enabled for priority based escalations
                    if ( grep { $Ticket{Type} eq $_ } @{$TicketTypeRestriction} ) {
                        $PriorityBasedEscalation = 1;
                    }
                }

                next ATTRIBUTE if !$PriorityBasedEscalation;

                %Escalation = $Kernel::OM->Get('Kernel::System::Priority')->PriorityGet(
                    PriorityID => $Ticket{PriorityID},
                    UserID     => 1,
                );
            }
            elsif ( $CurrentAttribute eq 'Queue' ) {
                next ATTRIBUTE if !$Ticket{QueueID};

                %Escalation = $Kernel::OM->Get('Kernel::System::Queue')->QueueGet(
                    ID     => $Ticket{QueueID},
                    UserID => $Param{UserID},
                    Cache  => 1,
                );
            }

            last ATTRIBUTE
                if ( $Escalation{FirstResponseTime} || $Escalation{UpdateTime} || $Escalation{SolutionTime} );
        }
# ---
        return %Escalation;
    }

    sub Kernel::System::Ticket::_TicketGetFirstResponse {
        my ( $Self, %Param ) = @_;

        # check needed stuff
        for my $Needed (qw(TicketID Ticket)) {
            if ( !defined $Param{$Needed} ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Needed!"
                );
                return;
            }
        }

        # get database object
        my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

# ---
# Znuny-TypePriorityBasedEscalation
# ---
#         # check if first response is already done
#         return if !$DBObject->Prepare(
#             SQL => '
#                 SELECT a.create_time,a.id FROM article a, article_sender_type ast
#                 WHERE a.article_sender_type_id = ast.id
#                     AND a.ticket_id = ?
#                     AND ast.name = ?
#                     AND a.is_visible_for_customer = ?
#                 ORDER BY a.create_time',
#             Bind  => [ \$Param{TicketID}, \'agent', \1 ],
#             Limit => 1,
#         );

        my $FirstResponseSQL;
        my $FirstResponseReset = $Kernel::OM->Get('Kernel::Config')->Get('FirstResponseDecisionBase');
        if (
            $FirstResponseReset
            && $FirstResponseReset eq 'Owner'
            )
        {
            $FirstResponseSQL = "SELECT th.create_time"
                . " FROM ticket_history th, ticket_history_type tht"
                . " WHERE tht.name = 'OwnerUpdate' AND th.history_type_id = tht.id AND th.ticket_id = ?"
                . " ORDER BY th.create_time";
        }
        else {
            $FirstResponseSQL = '
                SELECT a.create_time,a.id FROM article a, article_sender_type ast
                WHERE a.article_sender_type_id = ast.id
                    AND a.ticket_id = ?
                    AND ast.name = \'agent\'
                    AND a.is_visible_for_customer = 1
                ORDER BY a.create_time';
        }

        # check if first response is already done
        return if !$DBObject->Prepare(
            SQL   => $FirstResponseSQL,
            Bind  => [ \$Param{TicketID} ],
            Limit => 1,
        );
# ---
        my %Data;
        while ( my @Row = $DBObject->FetchrowArray() ) {
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

            # create datetime object
            my $DateTimeObject = $Kernel::OM->Create(
                'Kernel::System::DateTime',
                ObjectParams => {
                    String => $Param{Ticket}->{Created},
                }
            );

            my $FirstResponseTimeObj = $DateTimeObject->Clone();
            $FirstResponseTimeObj->Set(
                String => $Data{FirstResponse}
            );

            my $DeltaObj = $DateTimeObject->Delta(
                DateTimeObject => $FirstResponseTimeObj,
                ForWorkingTime => 1,
                Calendar       => $Escalation{Calendar},
            );

            my $WorkingTime = $DeltaObj ? $DeltaObj->{AbsoluteSeconds} : 0;

            $Data{FirstResponseInMin} = int( $WorkingTime / 60 );
            my $EscalationFirstResponseTime = $Escalation{FirstResponseTime} * 60;
            $Data{FirstResponseDiffInMin} =
                int( ( $EscalationFirstResponseTime - $WorkingTime ) / 60 );
        }

        return %Data;
    }

    sub Kernel::System::Ticket::TicketOwnerSet {
        my ( $Self, %Param ) = @_;

        # check needed stuff
        for my $Needed (qw(TicketID UserID)) {
            if ( !$Param{$Needed} ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Needed!"
                );
                return;
            }
        }
        if ( !$Param{NewUserID} && !$Param{NewUser} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => 'Need NewUserID or NewUser!'
            );
            return;
        }

        # get user object
        my $UserObject = $Kernel::OM->Get('Kernel::System::User');

        # lookup if no NewUserID is given
        if ( !$Param{NewUserID} ) {
            $Param{NewUserID} = $UserObject->UserLookup(
                UserLogin => $Param{NewUser},
            );
        }

        # lookup if no NewUser is given
        if ( !$Param{NewUser} ) {
            $Param{NewUser} = $UserObject->UserLookup(
                UserID => $Param{NewUserID},
            );
        }

        # make sure the user exists
        if ( !$UserObject->UserLookup( UserID => $Param{NewUserID} ) ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "User does not exist.",
            );
            return;
        }

        # check if update is needed!
        my ( $OwnerID, $Owner ) = $Self->OwnerCheck( TicketID => $Param{TicketID} );
        if ( $OwnerID eq $Param{NewUserID} ) {

            # update is "not" needed!
            return 2;
        }

# ---
# Znuny-TypePriorityBasedEscalation
# ---
        # get current ticket
        my %Ticket = $Self->TicketGet(
            %Param,
            DynamicFields => 0,
        );
# ---
        # db update
        return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
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

            my @SkipRecipients;
            if ( $Param{UserID} eq $Param{NewUserID} ) {
                @SkipRecipients = [ $Param{UserID} ];
            }

            # trigger notification event
            $Self->EventHandler(
                Event => 'NotificationOwnerUpdate',
                Data  => {
                    TicketID              => $Param{TicketID},
                    SkipRecipients        => \@SkipRecipients,
                    CustomerMessageParams => {
                        %Param,
                        Body => $Param{Comment} || '',
                    },
                },
                UserID => $Param{UserID},
            );
        }

        # trigger event
        $Self->EventHandler(
            Event => 'TicketOwnerUpdate',
            Data  => {
                TicketID => $Param{TicketID},
# ---
# Znuny-TypePriorityBasedEscalation
# ---
                OldTicketData => \%Ticket,
# ---
            },
            UserID => $Param{UserID},
        );

        return 1;
    }

    sub Kernel::System::Ticket::TicketTypeSet {
        my ( $Self, %Param ) = @_;

        # type lookup
        if ( $Param{Type} && !$Param{TypeID} ) {
            $Param{TypeID} = $Kernel::OM->Get('Kernel::System::Type')->TypeLookup( Type => $Param{Type} );
        }

        # check needed stuff
        for my $Needed (qw(TicketID TypeID UserID)) {
            if ( !$Param{$Needed} ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Needed!"
                );
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
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'notice',
                Message  => "Permission denied on TicketID: $Param{TicketID}!",
            );
            return;
        }

        return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
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
            TicketID     => $Param{TicketID},
            HistoryType  => 'TypeUpdate',
            Name         => "\%\%$TicketNew{Type}\%\%$Param{TypeID}\%\%$Ticket{Type}\%\%$Ticket{TypeID}",
            CreateUserID => $Param{UserID},
        );

        # trigger event
        $Self->EventHandler(
            Event => 'TicketTypeUpdate',
            Data  => {
                TicketID => $Param{TicketID},
# ---
# Znuny-TypePriorityBasedEscalation
# ---
                OldTicketData => \%Ticket,
# ---
            },
            UserID => $Param{UserID},
        );

        return 1;
    }

    sub Kernel::System::Ticket::TicketPrioritySet {
        my ( $Self, %Param ) = @_;

        # get priority object
        my $PriorityObject = $Kernel::OM->Get('Kernel::System::Priority');

        # lookup!
        if ( !$Param{PriorityID} && $Param{Priority} ) {
            $Param{PriorityID} = $PriorityObject->PriorityLookup(
                Priority => $Param{Priority},
            );
        }
        if ( $Param{PriorityID} && !$Param{Priority} ) {
            $Param{Priority} = $PriorityObject->PriorityLookup(
                PriorityID => $Param{PriorityID},
            );
        }

        # check needed stuff
        for my $Needed (qw(TicketID UserID PriorityID Priority)) {
            if ( !$Param{$Needed} ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Needed!"
                );
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
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'notice',
                Message  => "Permission denied on TicketID: $Param{TicketID}!",
            );
            return;
        }

        # db update
        return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
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
        $Self->EventHandler(
            Event => 'TicketPriorityUpdate',
            Data  => {
                TicketID => $Param{TicketID},
# ---
# Znuny-TypePriorityBasedEscalation
# ---
                OldTicketData => \%Ticket,
# ---
            },
            UserID => $Param{UserID},
        );

        return 1;
    }

}

1;
