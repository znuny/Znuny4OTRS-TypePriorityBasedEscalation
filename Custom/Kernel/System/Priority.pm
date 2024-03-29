# --
# Copyright (C) 2001-2021 OTRS AG, https://otrs.com/
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# $origin: Znuny - 4cf40286149a04dc09d9973fcd484bc5ddfe5b22 - Kernel/System/Priority.pm
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Priority;

use strict;
use warnings;

our @ObjectDependencies = (
# ---
# Znuny-TypePriorityBasedEscalation
# ---
#     'Kernel::Config',
# ---
    'Kernel::System::Cache',
    'Kernel::System::DB',
    'Kernel::System::Log',
# ---
# Znuny-TypePriorityBasedEscalation
# ---
#     'Kernel::System::SysConfig',
# ---
    'Kernel::System::Valid',
);

=head1 NAME

Kernel::System::Priority - priority lib

=head1 DESCRIPTION

All ticket priority functions.

=head1 PUBLIC INTERFACE

=head2 new()

create an object

    my $PriorityObject = $Kernel::OM->Get('Kernel::System::Priority');


=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{CacheType} = 'Priority';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 20;

    return $Self;
}

=head2 PriorityList()

get priority list as a hash of ID, Name pairs

    my %PriorityList = $PriorityObject->PriorityList(
        Valid => 0,   # (optional) default 1 (0|1)
    );

returns

    %PriorityList = (
        1 => '1 very low',
        2 => '2 low',
        3 => '3 normal',
        4 => '4 high',
        5 => '5 very high'
    )

=cut

sub PriorityList {
    my ( $Self, %Param ) = @_;

    # check valid param
    if ( !defined $Param{Valid} ) {
        $Param{Valid} = 1;
    }

    # create cachekey
    my $CacheKey;
    if ( $Param{Valid} ) {
        $CacheKey = 'PriorityList::Valid';
    }
    else {
        $CacheKey = 'PriorityList::All';
    }

    # check cache
    my $Cache = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # create sql
    my $SQL = 'SELECT id, name FROM ticket_priority ';
    if ( $Param{Valid} ) {
        $SQL
            .= "WHERE valid_id IN ( ${\(join ', ', $Kernel::OM->Get('Kernel::System::Valid')->ValidIDsGet())} )";
    }

    return if !$DBObject->Prepare( SQL => $SQL );

    # fetch the result
    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Data{ $Row[0] } = $Row[1];
    }

    # set cache
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Data,
    );

    return %Data;
}

=head2 PriorityGet()

get priority attributes

    my %PriorityData = $PriorityObject->PriorityGet(
        PriorityID => 123,
        UserID     => 1,
    );

returns:

    %PriorityData = (
        ID         => '123',
        Name       => '123 something',
        ValidID    => '1',
        Color      => '#FF8A25',
        CreateTime => '2021-02-01 12:15:00',
        CreateBy   => '321',
        ChangeTime => '2021-04-01 15:30:00',
        ChangeBy   => '223',
    );

=cut

sub PriorityGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(PriorityID UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # check cache
    my $Cache = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => 'PriorityGet' . $Param{PriorityID},
    );
    return %{$Cache} if $Cache;

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # ask database
# ---
# Znuny-TypePriorityBasedEscalation
# ---
#    return if !$DBObject->Prepare(
#        SQL => 'SELECT id, name, valid_id, create_time, create_by, change_time, change_by '
    return if !$DBObject->Prepare(
        SQL => 'SELECT id, name, valid_id, create_time, create_by, change_time, change_by, calendar_name, first_response_time, first_response_notify, update_time, update_notify, solution_time, solution_notify '
            . 'FROM ticket_priority WHERE id = ?',
        Bind  => [ \$Param{PriorityID} ],
        Limit => 1,
    );
# ---

    # fetch the result
    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Data{ID}         = $Row[0];
        $Data{Name}       = $Row[1];
        $Data{ValidID}    = $Row[2];
        $Data{CreateTime} = $Row[3];
        $Data{CreateBy}   = $Row[4];
        $Data{ChangeTime} = $Row[5];
        $Data{ChangeBy}   = $Row[6];
# ---
# Znuny-TypePriorityBasedEscalation
# ---
        $Data{Calendar}            = $Row[7];
        $Data{FirstResponseTime}   = $Row[8];
        $Data{FirstResponseNotify} = $Row[9];
        $Data{UpdateTime}          = $Row[10];
        $Data{UpdateNotify}        = $Row[11];
        $Data{SolutionTime}        = $Row[12];
        $Data{SolutionNotify}      = $Row[13];
# ---
    }

    # set cache
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => 'PriorityGet' . $Param{PriorityID},
        Value => \%Data,
    );

    return %Data;
}

=head2 PriorityAdd()

add a ticket priority

    my $True = $PriorityObject->PriorityAdd(
        Name    => 'Prio',
        ValidID => 1,
        Color   => '#FF8A25',
        UserID  => 1,
    );

=cut

sub PriorityAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Name ValidID UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    $Param{Color} //= '#FF8A25';

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

# ---
# Znuny-TypePriorityBasedEscalation
# ---
#    return if !$DBObject->Do(
#        SQL => 'INSERT INTO ticket_priority (name, valid_id, create_time, create_by, '
#            . 'change_time, change_by) VALUES '
#            . '(?, ?, current_timestamp, ?, current_timestamp, ?)',
#        Bind => [
#            \$Param{Name}, \$Param{ValidID}, \$Param{UserID}, \$Param{UserID},
#        ],
#    );
    for my $DefaultNullAttr ( qw(FirstResponseTime FirstResponseNotify UpdateTime UpdateNotify SolutionTime SolutionNotify) ) {
        $Param{ $DefaultNullAttr } ||= 0;
    }
    return if !$DBObject->Do(
        SQL => 'INSERT INTO ticket_priority (name, valid_id, create_time, create_by, calendar_name, first_response_time, first_response_notify, update_time, update_notify, solution_time, solution_notify, '
            . 'change_time, change_by) VALUES '
            . '(?, ?, current_timestamp, ?, ?, ?, ?, ?, ?, ?, ?, current_timestamp, ?)',
        Bind => [
            \$Param{Name}, \$Param{ValidID}, \$Param{UserID}, \$Param{Calendar}, \$Param{FirstResponseTime}, \$Param{FirstResponseNotify}, \$Param{UpdateTime}, \$Param{UpdateNotify}, \$Param{SolutionTime}, \$Param{SolutionNotify}, \$Param{UserID},
        ],
    );
# ---

    # get new priority id
    return if !$DBObject->Prepare(
        SQL   => 'SELECT id FROM ticket_priority WHERE name = ?',
        Bind  => [ \$Param{Name} ],
        Limit => 1,
    );

    # fetch the result
    my $ID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ID = $Row[0];
    }

    return if !$ID;

    # delete cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    return $ID;
}

=head2 PriorityUpdate()

update a existing ticket priority

    my $True = $PriorityObject->PriorityUpdate(
        PriorityID => 123,
        Name       => 'New Prio',
        ValidID    => 1,
        Color      => '#FF8A25',
        UserID     => 1,
    );

=cut

sub PriorityUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(PriorityID Name ValidID UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    $Param{Color} //= '#FF8A25';
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

# ---
# Znuny-TypePriorityBasedEscalation
# ---
#    return if !$DBObject->Do(
#        SQL => 'UPDATE ticket_priority SET name = ?, valid_id = ?, '
#            . 'change_time = current_timestamp, change_by = ? WHERE id = ?',
#        Bind => [
#            \$Param{Name}, \$Param{ValidID}, \$Param{UserID}, \$Param{PriorityID},
#        ],
#    );
    for my $DefaultNullAttr ( qw(FirstResponseTime FirstResponseNotify UpdateTime UpdateNotify SolutionTime SolutionNotify) ) {
        $Param{ $DefaultNullAttr } ||= 0;
    }
    $Param{Calendar} ||= '';

    return if !$DBObject->Do(
        SQL => 'UPDATE ticket_priority SET name = ?, valid_id = ?, '
            . 'change_time = current_timestamp, change_by = ?, calendar_name = ?, first_response_time = ?, first_response_notify = ?, update_time = ?, update_notify = ?, solution_time = ?, solution_notify = ? WHERE id = ?',
        Bind => [
            \$Param{Name}, \$Param{ValidID}, \$Param{UserID}, \$Param{Calendar}, \$Param{FirstResponseTime}, \$Param{FirstResponseNotify}, \$Param{UpdateTime}, \$Param{UpdateNotify}, \$Param{SolutionTime}, \$Param{SolutionNotify}, \$Param{PriorityID},
        ],
    );
# ---

    # delete cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    return 1;
}

=head2 PriorityLookup()

returns the id or the name of a priority

    my $PriorityID = $PriorityObject->PriorityLookup(
        Priority => '3 normal',
    );

    my $Priority = $PriorityObject->PriorityLookup(
        PriorityID => 1,
    );

=cut

sub PriorityLookup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Priority} && !$Param{PriorityID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Priority or PriorityID!'
        );
        return;
    }

    # get (already cached) priority list
    my %PriorityList = $Self->PriorityList(
        Valid => 0,
    );

    my $Key;
    my $Value;
    my $ReturnData;
    if ( $Param{PriorityID} ) {
        $Key        = 'PriorityID';
        $Value      = $Param{PriorityID};
        $ReturnData = $PriorityList{ $Param{PriorityID} };
    }
    else {
        $Key   = 'Priority';
        $Value = $Param{Priority};
        my %PriorityListReverse = reverse %PriorityList;
        $ReturnData = $PriorityListReverse{ $Param{Priority} };
    }

    # check if data exists
    if ( !defined $ReturnData ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No $Key for $Value found!",
        );
        return;
    }

    return $ReturnData;
}

1;

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<https://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (GPL). If you
did not receive this file, see L<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
