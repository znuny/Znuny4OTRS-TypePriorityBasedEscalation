# --
# Copyright (C) 2001-2015 OTRS AG, http://otrs.com/
# Copyright (C) 2012-2015 Znuny GmbH, http://znuny.com/
# --
# $origin: https://github.com/OTRS/otrs/blob/5a8c531f122fbf9019cc08e5b2965a2f2ba0e469/Kernel/System/Type.pm
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Type;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Cache',
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::Valid',
);

=head1 NAME

Kernel::System::Type - type lib

=head1 SYNOPSIS

All type functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $TypeObject = $Kernel::OM->Get('Kernel::System::Type');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{CacheType} = 'Type';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 20;

    return $Self;
}

=item TypeAdd()

add a new ticket type

    my $ID = $TypeObject->TypeAdd(
        Name    => 'New Type',
        ValidID => 1,
        UserID  => 123,
    );

=cut

sub TypeAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Name ValidID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # check if a type with this name already exists
    if ( $Self->NameExistsCheck( Name => $Param{Name} ) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "A type with name '$Param{Name}' already exists!"
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

# ---
# Znuny4OTRS-TypePriorityBasedEscalation
# ---
#    return if !$DBObject->Do(
#        SQL => 'INSERT INTO ticket_type (name, valid_id, '
#            . ' create_time, create_by, change_time, change_by)'
#            . ' VALUES (?, ?, current_timestamp, ?, current_timestamp, ?)',
#        Bind => [ \$Param{Name}, \$Param{ValidID}, \$Param{UserID}, \$Param{UserID} ],
#    );
    for my $DefaultNullAttr ( qw(FirstResponseTime FirstResponseNotify UpdateTime UpdateNotify SolutionTime SolutionNotify) ) {
        $Param{ $DefaultNullAttr } ||= 0;
    }
    $Param{Calendar} ||= '';

    return if !$DBObject->Do(
        SQL => 'INSERT INTO ticket_type (name, valid_id, calendar_name, first_response_time, first_response_notify, update_time, update_notify, solution_time, solution_notify, '
            . ' create_time, create_by, change_time, change_by)'
            . ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [ \$Param{Name}, \$Param{ValidID}, \$Param{Calendar}, \$Param{FirstResponseTime}, \$Param{FirstResponseNotify}, \$Param{UpdateTime}, \$Param{UpdateNotify}, \$Param{SolutionTime}, \$Param{SolutionNotify}, \$Param{UserID}, \$Param{UserID} ],
    );
# ---

    # get new type id
    return if !$DBObject->Prepare(
        SQL   => 'SELECT id FROM ticket_type WHERE name = ?',
        Bind  => [ \$Param{Name} ],
        Limit => 1,
    );

    # fetch the result
    my $ID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ID = $Row[0];
    }
    return if !$ID;

    # reset cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    return $ID;
}

=item TypeGet()

get types attributes

    my %Type = $TypeObject->TypeGet(
        ID => 123,
    );

    my %Type = $TypeObject->TypeGet(
        Name => 'default',
    );

Returns:

    Type = (
        ID                  => '123',
        Name                => 'Service Request',
        ValidID             => '1',
        CreateTime          => '2010-04-07 15:41:15',
        CreateBy            => '321',
        ChangeTime          => '2010-04-07 15:59:45',
        ChangeBy            => '223',
    );

=cut

sub TypeGet {
    my ( $Self, %Param ) = @_;

    # either ID or Name must be passed
    if ( !$Param{ID} && !$Param{Name} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need ID or Name!',
        );
        return;
    }

    # check that not both ID and Name are given
    if ( $Param{ID} && $Param{Name} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need either ID OR Name - not both!',
        );
        return;
    }

    # lookup the ID
    if ( $Param{Name} ) {
        $Param{ID} = $Self->TypeLookup(
            Type => $Param{Name},
        );
        if ( !$Param{ID} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "TypeID for Type '$Param{Name}' not found!",
            );
            return;
        }
    }

    # check cache
    my $CacheKey = 'TypeGet::ID::' . $Param{ID};
    my $Cache    = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # ask the database
# ---
# Znuny4OTRS-TypePriorityBasedEscalation
# ---
#    return if !$DBObject->Prepare(
#        SQL => 'SELECT id, name, valid_id, '
#            . 'create_time, create_by, change_time, change_by '
#            . 'FROM ticket_type WHERE id = ?',
#        Bind => [ \$Param{ID} ],
#    );
    return if !$DBObject->Prepare(
        SQL => 'SELECT id, name, valid_id, '
            . 'create_time, create_by, change_time, change_by, calendar_name, first_response_time, first_response_notify, update_time, update_notify, solution_time, solution_notify '
            . 'FROM ticket_type WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );
# ---

    # fetch the result
    my %Type;
    while ( my @Data = $DBObject->FetchrowArray() ) {
        $Type{ID}         = $Data[0];
        $Type{Name}       = $Data[1];
        $Type{ValidID}    = $Data[2];
        $Type{CreateTime} = $Data[3];
        $Type{CreateBy}   = $Data[4];
        $Type{ChangeTime} = $Data[5];
        $Type{ChangeBy}   = $Data[6];
# ---
# Znuny4OTRS-TypePriorityBasedEscalation
# ---
        $Type{Calendar}            = $Data[7];
        $Type{FirstResponseTime}   = $Data[8];
        $Type{FirstResponseNotify} = $Data[9];
        $Type{UpdateTime}          = $Data[10];
        $Type{UpdateNotify}        = $Data[11];
        $Type{SolutionTime}        = $Data[12];

    }

    # no data found
    if ( !%Type ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "TypeID '$Param{ID}' not found!",
        );
        return;
    }

    # set cache
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Type,
    );

    return %Type;
}

=item TypeUpdate()

update type attributes

    $TypeObject->TypeUpdate(
        ID      => 123,
        Name    => 'New Type',
        ValidID => 1,
        UserID  => 123,
    );

=cut

sub TypeUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID Name ValidID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # check if a type with this name already exists
    if (
        $Self->NameExistsCheck(
            Name => $Param{Name},
            ID   => $Param{ID}
        )
        )
    {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "A type with name '$Param{Name}' already exists!"
        );
        return;
    }

    # sql
# ---
# Znuny4OTRS-TypePriorityBasedEscalation
# ---
#    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
#        SQL => 'UPDATE ticket_type SET name = ?, valid_id = ?, '
#            . ' change_time = current_timestamp, change_by = ? WHERE id = ?',
#        Bind => [
#            \$Param{Name}, \$Param{ValidID}, \$Param{UserID}, \$Param{ID},
#        ],
#    );
    for my $DefaultNullAttr ( qw(FirstResponseTime FirstResponseNotify UpdateTime UpdateNotify SolutionTime SolutionNotify) ) {
        $Param{ $DefaultNullAttr } ||= 0;
    }
    $Param{Calendar} ||= '';

    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => 'UPDATE ticket_type SET name = ?, valid_id = ?, '
            . 'change_time = current_timestamp, change_by = ?, calendar_name = ?, first_response_time = ?, first_response_notify = ?, update_time = ?, update_notify = ?, solution_time = ?, solution_notify = ? WHERE id = ?',
        Bind => [
            \$Param{Name}, \$Param{ValidID}, \$Param{UserID}, \$Param{Calendar}, \$Param{FirstResponseTime}, \$Param{FirstResponseNotify}, \$Param{UpdateTime}, \$Param{UpdateNotify}, \$Param{SolutionTime}, \$Param{SolutionNotify}, \$Param{ID},
        ],
    );
# ---

    # reset cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    return 1;
}

=item TypeList()

get type list

    my %List = $TypeObject->TypeList();

or

    my %List = $TypeObject->TypeList(
        Valid => 0,
    );

=cut

sub TypeList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    my $Valid = 1;
    if ( !$Param{Valid} && defined $Param{Valid} ) {
        $Valid = 0;
    }

    # check cache
    my $CacheKey = "TypeList::Valid::$Valid";
    my $Cache    = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    # create the valid list
    my $ValidIDs = join ', ', $Kernel::OM->Get('Kernel::System::Valid')->ValidIDsGet();

    # build SQL
    my $SQL = 'SELECT id, name FROM ticket_type';

    # add WHERE statement
    if ($Valid) {
        $SQL .= ' WHERE valid_id IN (' . $ValidIDs . ')';
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # ask database
    return if !$DBObject->Prepare(
        SQL => $SQL,
    );

    # fetch the result
    my %TypeList;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $TypeList{ $Row[0] } = $Row[1];
    }

    # set cache
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%TypeList,
    );

    return %TypeList;
}

=item TypeLookup()

get id or name for a ticket type

    my $Type = $TypeObject->TypeLookup( TypeID => $TypeID );

    my $TypeID = $TypeObject->TypeLookup( Type => $Type );

=cut

sub TypeLookup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Type} && !$Param{TypeID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Got no Type or TypeID!',
        );
        return;
    }

    # get (already cached) type list
    my %TypeList = $Self->TypeList(
        Valid => 0,
    );

    my $Key;
    my $Value;
    my $ReturnData;
    if ( $Param{TypeID} ) {
        $Key        = 'TypeID';
        $Value      = $Param{TypeID};
        $ReturnData = $TypeList{ $Param{TypeID} };
    }
    else {
        $Key   = 'Type';
        $Value = $Param{Type};
        my %TypeListReverse = reverse %TypeList;
        $ReturnData = $TypeListReverse{ $Param{Type} };
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

=item NameExistsCheck()

    return 1 if another type with this name already exits

        $Exist = $TypeObject->NameExistsCheck(
            Name => 'Some::Template',
            ID => 1, # optional
        );

=cut

sub NameExistsCheck {
    my ( $Self, %Param ) = @_;

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DBObject->Prepare(
        SQL  => 'SELECT id FROM ticket_type WHERE name = ?',
        Bind => [ \$Param{Name} ],
    );

    # fetch the result
    my $Flag;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        if ( !$Param{ID} || $Param{ID} ne $Row[0] ) {
            $Flag = 1;
        }
    }
    if ($Flag) {
        return 1;
    }
    return 0;
}
1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<http://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
