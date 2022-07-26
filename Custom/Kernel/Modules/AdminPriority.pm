# --
# Copyright (C) 2001-2021 OTRS AG, https://otrs.com/
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# $origin: znuny - 012b2cb0daf8519ff314f751ad03b62219f63331 - Kernel/Modules/AdminPriority.pm
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::Modules::AdminPriority;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);
use Kernel::Language qw(Translatable);

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # Store last entity screen.
    $Kernel::OM->Get('Kernel::System::AuthSession')->UpdateSessionID(
        SessionID => $Self->{SessionID},
        Key       => 'LastScreenEntity',
        Value     => $Self->{RequestedURL},
    );

    my $LayoutObject   = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject    = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $PriorityObject = $Kernel::OM->Get('Kernel::System::Priority');

    # ------------------------------------------------------------ #
    # change
    # ------------------------------------------------------------ #
    if ( $Self->{Subaction} eq 'Change' ) {
        my %GetParam = ();
        $GetParam{PriorityID} = $ParamObject->GetParam( Param => 'PriorityID' ) || '';
        my %PriorityData = $PriorityObject->PriorityGet(
            PriorityID => $GetParam{PriorityID},
            UserID     => $Self->{UserID},
        );
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Self->_Edit(
            Action => 'Change',
            %PriorityData,
            %GetParam,
        );
        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminPriority',
            Data         => \%Param,
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }

    # ------------------------------------------------------------ #
    # change action
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'ChangeAction' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        my ( %GetParam, %Errors );

        # get params
# ---
# Znuny-TypePriorityBasedEscalation
# ---
#        for my $Parameter (qw(PriorityID Name ValidID)) {
        for my $Parameter (qw(PriorityID Name ValidID Calendar FirstResponseTime FirstResponseNotify UpdateTime UpdateNotify SolutionTime SolutionNotify)) {
# ---
            $GetParam{$Parameter} = $ParamObject->GetParam( Param => $Parameter ) || '';
        }

        # check needed data
        for my $Needed (qw(Name ValidID)) {
            if ( !$GetParam{$Needed} ) {
                $Errors{ $Needed . 'Invalid' } = 'ServerError';
            }
        }

        # Check if priority is present in SysConfig setting
        my %PriorityData = $PriorityObject->PriorityGet(
            PriorityID => $GetParam{PriorityID},
            UserID     => $Self->{UserID},
        );
        my $UpdateEntity    = $ParamObject->GetParam( Param => 'UpdateEntity' ) || '';
        my $SysConfigObject = $Kernel::OM->Get('Kernel::System::SysConfig');
        my %PriorityOldData = %PriorityData;
        my @IsPriorityInSysConfig;
        @IsPriorityInSysConfig = $SysConfigObject->ConfigurationEntityCheck(
            EntityType => 'Priority',
            EntityName => $PriorityData{Name},
        );
        if (@IsPriorityInSysConfig) {

            # An entity present in SysConfig couldn't be invalidated.
            if (
                $Kernel::OM->Get('Kernel::System::Valid')->ValidLookup( ValidID => $GetParam{ValidID} )
                ne 'valid'
                )
            {
                $Errors{ValidIDInvalid}         = 'ServerError';
                $Errors{ValidOptionServerError} = 'InSetting';
            }

            # In case changing name an authorization (UpdateEntity) should be send.
            elsif ( $PriorityData{Name} ne $GetParam{Name} && !$UpdateEntity ) {
                $Errors{NameInvalid}              = 'ServerError';
                $Errors{InSettingNameServerError} = 'InSetting';
            }
        }

        # if no errors occurred
        if ( !%Errors ) {

            # update priority
            my $Update = $PriorityObject->PriorityUpdate(
                %GetParam,
                UserID => $Self->{UserID}
            );

            if ($Update) {

                if (
                    @IsPriorityInSysConfig
                    && $PriorityOldData{Name} ne $GetParam{Name}
                    && $UpdateEntity
                    )
                {
                    SETTING:
                    for my $SettingName (@IsPriorityInSysConfig) {

                        my %Setting = $SysConfigObject->SettingGet(
                            Name => $SettingName,
                        );

                        next SETTING if !IsHashRefWithData( \%Setting );

                        $Setting{EffectiveValue} =~ s/$PriorityOldData{Name}/$GetParam{Name}/g;

                        my $ExclusiveLockGUID = $SysConfigObject->SettingLock(
                            Name   => $Setting{Name},
                            Force  => 1,
                            UserID => $Self->{UserID}
                        );
                        $Setting{ExclusiveLockGUID} = $ExclusiveLockGUID;

                        my %UpdateSuccess = $SysConfigObject->SettingUpdate(
                            %Setting,
                            UserID => $Self->{UserID},
                        );

                    }

                    $SysConfigObject->ConfigurationDeploy(
                        Comments      => "Priority name change",
                        DirtySettings => \@IsPriorityInSysConfig,
                        UserID        => $Self->{UserID},
                        Force         => 1,
                    );
                }

                # if the user would like to continue editing the priority, just redirect to the edit screen
                if (
                    defined $ParamObject->GetParam( Param => 'ContinueAfterSave' )
                    && ( $ParamObject->GetParam( Param => 'ContinueAfterSave' ) eq '1' )
                    )
                {
                    my $PriorityID = $ParamObject->GetParam( Param => 'PriorityID' ) || '';
                    return $LayoutObject->Redirect(
                        OP => "Action=$Self->{Action};Subaction=Change;PriorityID=$PriorityID"
                    );
                }
                else {

                    # otherwise return to overview
                    return $LayoutObject->Redirect( OP => "Action=$Self->{Action}" );
                }
            }
        }

        # something has gone wrong
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Output .= $LayoutObject->Notify( Priority => Translatable('Error') );
        $Self->_Edit(
            Action => 'Change',
            Errors => \%Errors,
            %GetParam,
        );
        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminPriority',
            Data         => \%Param,
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }

    # ------------------------------------------------------------ #
    # add
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'Add' ) {
        my %GetParam = ();
        $GetParam{PriorityID} = $ParamObject->GetParam( Param => 'PriorityID' ) || '';
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Self->_Edit(
            Action => 'Add',
            %GetParam,
        );
        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminPriority',
            Data         => \%Param,
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }

    # ------------------------------------------------------------ #
    # add action
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'AddAction' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        my ( %GetParam, %Errors );

        # get params
# ---
# Znuny-TypePriorityBasedEscalation
# ---
#        for my $Parameter (qw(PriorityID Name ValidID)) {
        for my $Parameter (qw(PriorityID Name ValidID Calendar FirstResponseTime FirstResponseNotify UpdateTime UpdateNotify SolutionTime SolutionNotify)) {
# ---
            $GetParam{$Parameter} = $ParamObject->GetParam( Param => $Parameter ) || '';
        }

        # check needed data
        for my $Needed (qw(Name ValidID)) {
            if ( !$GetParam{$Needed} ) {
                $Errors{ $Needed . 'Invalid' } = 'ServerError';
            }
        }

        # if no errors occurred
        if ( !%Errors ) {

            my $NewPriority = $PriorityObject->PriorityAdd(
                %GetParam,
                UserID => $Self->{UserID},
            );

            if ($NewPriority) {
                $Self->_Overview();
                my $Output = $LayoutObject->Header();
                $Output .= $LayoutObject->NavigationBar();
                $Output .= $LayoutObject->Notify( Info => Translatable('Priority added!') );
                $Output .= $LayoutObject->Output(
                    TemplateFile => 'AdminPriority',
                    Data         => \%Param,
                );
                $Output .= $LayoutObject->Footer();
                return $Output;
            }
        }

        # something has gone wrong
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Output .= $LayoutObject->Notify( Priority => Translatable('Error') );
        $Self->_Edit(
            Action => 'Add',
            Errors => \%Errors,
            %GetParam,
        );
        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminPriority',
            Data         => \%Param,
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }

    # ------------------------------------------------------------
    # overview
    # ------------------------------------------------------------
    else {
        $Self->_Overview();
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminPriority',
            Data         => \%Param,
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }
}

sub _Edit {
    my ( $Self, %Param ) = @_;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    $LayoutObject->Block(
        Name => 'Overview',
        Data => \%Param,
    );

    $LayoutObject->Block( Name => 'ActionList' );
    $LayoutObject->Block( Name => 'ActionOverview' );

    # get valid list
    my %ValidList        = $Kernel::OM->Get('Kernel::System::Valid')->ValidList();
    my %ValidListReverse = reverse %ValidList;

    $Param{ValidOptionStrg} = $LayoutObject->BuildSelection(
        Data       => \%ValidList,
        Name       => 'ValidID',
        SelectedID => $Param{ValidID} || $ValidListReverse{valid},
        Class      => 'Modernize Validate_Required ' . ( $Param{Errors}->{'ValidIDInvalid'} || '' ),
    );

# ---
# Znuny-TypePriorityBasedEscalation
# ---
    # generate CalendarOptionStrg
    my %CalendarList;
    for my $CalendarNumber ( '', 1 .. 50 ) {
        if ( $Kernel::OM->Get('Kernel::Config')->Get("TimeVacationDays::Calendar$CalendarNumber") ) {
            $CalendarList{$CalendarNumber} = "Calendar $CalendarNumber - "
                . $Kernel::OM->Get('Kernel::Config')->Get( "TimeZone::Calendar" . $CalendarNumber . "Name" );
        }
    }
    $Param{CalendarOptionStrg} = $LayoutObject->BuildSelection(
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
    $Param{FirstResponseNotifyOptionStrg} = $LayoutObject->BuildSelection(
        Data         => \%NotifyLevelList,
        Translation  => 0,
        Name         => 'FirstResponseNotify',
        SelectedID   => $Param{FirstResponseNotify},
        PossibleNone => 1,
    );
    $Param{UpdateNotifyOptionStrg} = $LayoutObject->BuildSelection(
        Data         => \%NotifyLevelList,
        Translation  => 0,
        Name         => 'UpdateNotify',
        SelectedID   => $Param{UpdateNotify},
        PossibleNone => 1,
    );
    $Param{SolutionNotifyOptionStrg} = $LayoutObject->BuildSelection(
        Data         => \%NotifyLevelList,
        Translation  => 0,
        Name         => 'SolutionNotify',
        SelectedID   => $Param{SolutionNotify},
        PossibleNone => 1,
    );
# ---

    $LayoutObject->Block(
        Name => 'OverviewUpdate',
        Data => {
            %Param,
            %{ $Param{Errors} },
        },
    );

    # Several error messages can be used for Name.
    $Param{Errors}->{InSettingNameServerError} //= 'Required';
    $LayoutObject->Block(
        Name => $Param{Errors}->{InSettingNameServerError} . 'NameServerError',
    );

    # Several error messages can be used for Valid option.
    $Param{Errors}->{ValidOptionServerError} //= 'Required';
    $LayoutObject->Block(
        Name => $Param{Errors}->{ValidOptionServerError} . 'ValidOptionServerError',
    );

    if ( $Param{PriorityID} ) {
        my $PriorityName = $Kernel::OM->Get('Kernel::System::Priority')->PriorityLookup(
            PriorityID => $Param{PriorityID},
        );

        # Add warning in case the Priority belongs a SysConfig setting.
        my $SysConfigObject = $Kernel::OM->Get('Kernel::System::SysConfig');

        # In case dirty setting, disable form.
        my $IsDirtyConfig = 0;
        my @IsDirtyResult = $SysConfigObject->ConfigurationDirtySettingsList();
        my %IsDirtyList   = map { $_ => 1 } @IsDirtyResult;

        my @IsPriorityInSysConfig = $SysConfigObject->ConfigurationEntityCheck(
            EntityType => 'Priority',
            EntityName => $PriorityName // '',
        );

        if (@IsPriorityInSysConfig) {
            $LayoutObject->Block(
                Name => 'PriorityInSysConfig',
                Data => {
                    OldName => $PriorityName,
                },
            );
            for my $SettingName (@IsPriorityInSysConfig) {
                $LayoutObject->Block(
                    Name => 'PriorityInSysConfigRow',
                    Data => {
                        SettingName => $SettingName,
                    },
                );

                # Verify if dirty setting.
                if ( $IsDirtyList{$SettingName} ) {
                    $IsDirtyConfig = 1;
                }
            }

        }

        if ($IsDirtyConfig) {
            $LayoutObject->Block(
                Name => 'PriorityInSysConfigDirty',
            );
        }

    }

    return 1;
}

sub _Overview {
    my ( $Self, %Param ) = @_;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    $LayoutObject->Block(
        Name => 'Overview',
        Data => \%Param,
    );

    $LayoutObject->Block( Name => 'ActionList' );
    $LayoutObject->Block( Name => 'ActionAdd' );
    $LayoutObject->Block( Name => 'Filter' );

    $LayoutObject->Block(
        Name => 'OverviewResult',
        Data => \%Param,
    );

    my $PriorityObject = $Kernel::OM->Get('Kernel::System::Priority');

    # get priority list
    my %PriorityList = $PriorityObject->PriorityList(
        Valid  => 0,
        UserID => $Self->{UserID},
    );

    # if there are any priorities defined, they are shown
    if (%PriorityList) {

        # get valid list
        my %ValidList = $Kernel::OM->Get('Kernel::System::Valid')->ValidList();

        for my $PriorityID ( sort { $a <=> $b } keys %PriorityList ) {

            # get priority data
            my %PriorityData = $PriorityObject->PriorityGet(
                PriorityID => $PriorityID,
                UserID     => $Self->{UserID},
            );

            $LayoutObject->Block(
                Name => 'OverviewResultRow',
                Data => {
                    %PriorityData,
                    PriorityID => $PriorityID,
                    Valid      => $ValidList{ $PriorityData{ValidID} },
                },
            );
        }
    }

    # otherwise a no data found msg is displayed
    else {
        $LayoutObject->Block(
            Name => 'NoDataFoundMsg',
            Data => {},
        );
    }
    return 1;
}

1;
