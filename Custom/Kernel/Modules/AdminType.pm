# --
# Kernel/Modules/AdminType.pm - to add/update/delete ticket types
# Copyright (C) 2001-2014 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AdminType;

use strict;
use warnings;

use Kernel::System::Type;
use Kernel::System::Valid;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # check all needed objects
    for my $Needed (qw(ParamObject DBObject LayoutObject ConfigObject LogObject)) {
        if ( !$Self->{$Needed} ) {
            $Self->{LayoutObject}->FatalError( Message => "Got no $Needed!" );
        }
    }
    $Self->{TypeObject}  = Kernel::System::Type->new(%Param);
    $Self->{ValidObject} = Kernel::System::Valid->new(%Param);

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # ------------------------------------------------------------ #
    # change
    # ------------------------------------------------------------ #
    if ( $Self->{Subaction} eq 'Change' ) {
        my $ID = $Self->{ParamObject}->GetParam( Param => 'ID' ) || '';
        my %Data = $Self->{TypeObject}->TypeGet( ID => $ID );
        if ( !%Data ) {
            return $Self->{LayoutObject}->ErrorScreen(
                Message => 'Need Type!',
            );
        }
        my $Output = $Self->{LayoutObject}->Header();
        $Output .= $Self->{LayoutObject}->NavigationBar();
        $Self->_Edit(
            Action => 'Change',
            %Data,
        );
        $Output .= $Self->{LayoutObject}->Output(
            TemplateFile => 'AdminType',
            Data         => \%Param,
        );
        $Output .= $Self->{LayoutObject}->Footer();
        return $Output;
    }

    # ------------------------------------------------------------ #
    # change action
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'ChangeAction' ) {

        # challenge token check for write action
        $Self->{LayoutObject}->ChallengeTokenCheck();

        my $Note = '';
        my ( %GetParam, %Errors );
# ---
# Znuny4OTRS-TypePriorityBasedEscalation
# ---
#        for my $Parameter (qw(ID Name Text Comment ValidID)) {
        for my $Parameter (qw(ID Name  Text Comment ValidID Calendar FirstResponseTime FirstResponseNotify UpdateTime UpdateNotify SolutionTime SolutionNotify)) {
# ---
            $GetParam{$Parameter} = $Self->{ParamObject}->GetParam( Param => $Parameter ) || '';
        }

        # check needed data
        for my $Needed (qw(Name ValidID)) {
            if ( !$GetParam{$Needed} ) {
                $Errors{ $Needed . 'Invalid' } = 'ServerError';
            }
        }

        my %Data = $Self->{TypeObject}->TypeGet( ID => $GetParam{ID} );
        if ( !%Data ) {
            return $Self->{LayoutObject}->ErrorScreen(
                Message => 'Need Type!',
            );
        }

        # if no errors occurred
        if ( !%Errors ) {

            # update type
            my $Update = $Self->{TypeObject}->TypeUpdate(
                %GetParam,
                UserID => $Self->{UserID}
            );
            if ($Update) {
                $Self->_Overview();
                my $Output = $Self->{LayoutObject}->Header();
                $Output .= $Self->{LayoutObject}->NavigationBar();
                $Output .= $Self->{LayoutObject}->Notify( Info => 'Type updated!' );
                $Output .= $Self->{LayoutObject}->Output(
                    TemplateFile => 'AdminType',
                    Data         => \%Param,
                );
                $Output .= $Self->{LayoutObject}->Footer();
                return $Output;
            }
        }

        # something has gone wrong
        my $Output = $Self->{LayoutObject}->Header();
        $Output .= $Self->{LayoutObject}->NavigationBar();
        $Output .= $Self->{LayoutObject}->Notify( Priority => 'Error' );
        $Self->_Edit(
            Action => 'Change',
            Errors => \%Errors,
            %GetParam,
        );
        $Output .= $Self->{LayoutObject}->Output(
            TemplateFile => 'AdminType',
            Data         => \%Param,
        );
        $Output .= $Self->{LayoutObject}->Footer();
        return $Output;
    }

    # ------------------------------------------------------------ #
    # add
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'Add' ) {
        my %GetParam = ();
        $GetParam{Name} = $Self->{ParamObject}->GetParam( Param => 'Name' );
        my $Output = $Self->{LayoutObject}->Header();
        $Output .= $Self->{LayoutObject}->NavigationBar();
        $Self->_Edit(
            Action => 'Add',
            %GetParam,
        );
        $Output .= $Self->{LayoutObject}->Output(
            TemplateFile => 'AdminType',
            Data         => \%Param,
        );
        $Output .= $Self->{LayoutObject}->Footer();
        return $Output;
    }

    # ------------------------------------------------------------ #
    # add action
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'AddAction' ) {

        # challenge token check for write action
        $Self->{LayoutObject}->ChallengeTokenCheck();

        my $Note = '';
        my ( %GetParam, %Errors );
# ---
# Znuny4OTRS-TypePriorityBasedEscalation
# ---
#        for my $Parameter (qw(ID Name Text Comment ValidID)) {
        for my $Parameter (qw(ID Name Text Comment ValidID Calendar FirstResponseTime FirstResponseNotify UpdateTime UpdateNotify SolutionTime SolutionNotify)) {
# ---
            $GetParam{$Parameter} = $Self->{ParamObject}->GetParam( Param => $Parameter ) || '';
        }

        # check needed data
        for my $Needed (qw(Name ValidID)) {
            if ( !$GetParam{$Needed} ) {
                $Errors{ $Needed . 'Invalid' } = 'ServerError';
            }
        }

        # if no errors occurred
        if ( !%Errors ) {

            # add type
            my $NewType = $Self->{TypeObject}->TypeAdd(
                %GetParam,
                UserID => $Self->{UserID}
            );
            if ($NewType) {
                $Self->_Overview();
                my $Output = $Self->{LayoutObject}->Header();
                $Output .= $Self->{LayoutObject}->NavigationBar();
                $Output .= $Self->{LayoutObject}->Notify( Info => 'Type added!' );
                $Output .= $Self->{LayoutObject}->Output(
                    TemplateFile => 'AdminType',
                    Data         => \%Param,
                );
                $Output .= $Self->{LayoutObject}->Footer();
                return $Output;
            }
        }

        # something has gone wrong
        my $Output = $Self->{LayoutObject}->Header();
        $Output .= $Self->{LayoutObject}->NavigationBar();
        $Output .= $Self->{LayoutObject}->Notify( Priority => 'Error' );
        $Self->_Edit(
            Action => 'Add',
            Errors => \%Errors,
            %GetParam,
        );
        $Output .= $Self->{LayoutObject}->Output(
            TemplateFile => 'AdminType',
            Data         => \%Param,
        );
        $Output .= $Self->{LayoutObject}->Footer();
        return $Output;
    }

    # ------------------------------------------------------------
    # overview
    # ------------------------------------------------------------
    else {
        $Self->_Overview();
        my $Output = $Self->{LayoutObject}->Header();
        $Output .= $Self->{LayoutObject}->NavigationBar();
        $Output .= $Self->{LayoutObject}->Output(
            TemplateFile => 'AdminType',
            Data         => \%Param,
        );
        $Output .= $Self->{LayoutObject}->Footer();
        return $Output;
    }

}

sub _Edit {
    my ( $Self, %Param ) = @_;

    $Self->{LayoutObject}->Block(
        Name => 'Overview',
        Data => \%Param,
    );

    $Self->{LayoutObject}->Block( Name => 'ActionList' );
    $Self->{LayoutObject}->Block( Name => 'ActionOverview' );

    # get valid list
    my %ValidList        = $Self->{ValidObject}->ValidList();
    my %ValidListReverse = reverse %ValidList;

    $Param{ValidOption} = $Self->{LayoutObject}->BuildSelection(
        Data       => \%ValidList,
        Name       => 'ValidID',
        SelectedID => $Param{ValidID} || $ValidListReverse{valid},
        Class      => 'Validate_Required ' . ( $Param{Errors}->{'ValidIDInvalid'} || '' ),
    );

# ---
# Znuny4OTRS-TypePriorityBasedEscalation
# ---
    # generate CalendarOptionStrg
    my %CalendarList;
    for my $CalendarNumber ( '', 1 .. 50 ) {
        if ( $Self->{ConfigObject}->Get("TimeVacationDays::Calendar$CalendarNumber") ) {
            $CalendarList{$CalendarNumber} = "Calendar $CalendarNumber - "
                . $Self->{ConfigObject}->Get( "TimeZone::Calendar" . $CalendarNumber . "Name" );
        }
    }
    $Param{CalendarOptionStrg} = $Self->{LayoutObject}->BuildSelection(
        Data         => \%CalendarList,
        Name         => 'Calendar',
        SelectedID   => $Param{Calendar},
        Translation  => 0,
        PossibleNone => 1,
    );

    my %NotifyLevelList = (
        10 => '10%',
        20 => '20%',
        30 => '30%',
        40 => '40%',
        50 => '50%',
        60 => '60%',
        70 => '70%',
        80 => '80%',
        90 => '90%',
    );
    $Param{FirstResponseNotifyOptionStrg} = $Self->{LayoutObject}->BuildSelection(
        Data         => \%NotifyLevelList,
        Translation  => 0,
        Name         => 'FirstResponseNotify',
        SelectedID   => $Param{FirstResponseNotify},
        PossibleNone => 1,
    );
    $Param{UpdateNotifyOptionStrg} = $Self->{LayoutObject}->BuildSelection(
        Data         => \%NotifyLevelList,
        Translation  => 0,
        Name         => 'UpdateNotify',
        SelectedID   => $Param{UpdateNotify},
        PossibleNone => 1,
    );
    $Param{SolutionNotifyOptionStrg} = $Self->{LayoutObject}->BuildSelection(
        Data         => \%NotifyLevelList,
        Translation  => 0,
        Name         => 'SolutionNotify',
        SelectedID   => $Param{SolutionNotify},
        PossibleNone => 1,
    );
# ---

    $Self->{LayoutObject}->Block(
        Name => 'OverviewUpdate',
        Data => {
            %Param,
            %{ $Param{Errors} },
        },
    );

    # shows header
    if ( $Param{Action} eq 'Change' ) {
        $Self->{LayoutObject}->Block( Name => 'HeaderEdit' );
    }
    else {
        $Self->{LayoutObject}->Block( Name => 'HeaderAdd' );
    }

    return 1;
}

sub _Overview {
    my ( $Self, %Param ) = @_;

    $Self->{LayoutObject}->Block(
        Name => 'Overview',
        Data => \%Param,
    );

    $Self->{LayoutObject}->Block( Name => 'ActionList' );
    $Self->{LayoutObject}->Block( Name => 'ActionAdd' );

    $Self->{LayoutObject}->Block(
        Name => 'OverviewResult',
        Data => \%Param,
    );
    my %List = $Self->{TypeObject}->TypeList( Valid => 0 );

    # if there are any types, they are shown
    if (%List) {

        # get valid list
        my %ValidList = $Self->{ValidObject}->ValidList();

        for my $TypeID ( sort { $List{$a} cmp $List{$b} } keys %List ) {

            my %Data = $Self->{TypeObject}->TypeGet(
                ID => $TypeID,
            );
            $Self->{LayoutObject}->Block(
                Name => 'OverviewResultRow',
                Data => {
                    Valid => $ValidList{ $Data{ValidID} },
                    %Data,
                },
            );
        }
    }

    # otherwise a no data found msg is displayed
    else {
        $Self->{LayoutObject}->Block(
            Name => 'NoDataFoundMsg',
            Data => {},
        );
    }
    return 1;
}

1;
