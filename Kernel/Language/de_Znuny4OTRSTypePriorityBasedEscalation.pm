# --
# Kernel/Language/de_Znuny4OTRSTypePriorityBasedEscalation.pm - the German translation of the texts of Znuny4OTRSTypePriorityBasedEscalation
# Copyright (C) 2013 Znuny GmbH, http://znuny.com/
# --

package Kernel::Language::de_Znuny4OTRSTypePriorityBasedEscalation;

use strict;
use warnings;

sub Data {
    my $Self = shift;

    $Self->{Translation}->{"This configuration defines if the first response time should be calculated based on the first owner change or the first agent response."} = "Diese Konfiguration definiert ob die Reaktionszeit beim ersten Besitzerwechsel oder der ersten Kundenantwort gelöscht werden soll.";
    $Self->{Translation}->{"First owner change"} = 'Erster Besitzerwechsel';
    $Self->{Translation}->{"First agent response"} = 'Erste Kundenantwort';

    return 1;
}

1;
