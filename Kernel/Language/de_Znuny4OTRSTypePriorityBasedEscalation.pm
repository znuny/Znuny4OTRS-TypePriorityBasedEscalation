# --
# Copyright (C) 2012-2017 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Language::de_Znuny4OTRSTypePriorityBasedEscalation;

use strict;
use warnings;

use utf8;

sub Data {
    my $Self = shift;

    # SysConfigs
    $Self->{Translation}->{"This configuration defines if the first response time should be calculated based on the first owner change or the first agent response."} = "Diese Konfiguration definiert ob die Reaktionszeit beim ersten Besitzerwechsel oder der ersten Kundenantwort gelöscht werden soll.";
    $Self->{Translation}->{"This configuration defines a list of ticket types to which the priority based escalation should be restricted. Only tickets with a ticket type of this list will get checked for priority based escalation. All tickets will escalate priority based if this configuration is deactivated or has no types configured."} = 'Diese Konfiguration definiert eine Liste von Ticket-Typen, für die eine prioritätsbasierte Eskalation möglich ist. Nur Tickets mit einem Typen aus dieser Liste werden auf eine prioritätsbasierte Eskalation geprüft. Es werden alle Tickets auf eine prioritätsbasierte Eskalation geprüft, wenn diese Konfiguration deaktiviert ist oder keine Ticket-Typen konfiguriert sind.';
    $Self->{Translation}->{"First owner change"} = 'Erster Besitzerwechsel';
    $Self->{Translation}->{"First agent response"} = 'Erste Kundenantwort';
    $Self->{Translation}->{"This configuration defines in which order escalations should get checked and if configured applied to the ticket. Possible options are: SLA, Type, Priority and Queue. This configuration is key sensetive."} = "Diese Konfiguration definiert die Reihenfolge in der die Eskalation eines Tickets geprüft werden soll. Mögliche Werte sind 'SLA', 'Type', 'Priority' und 'Queue', bei deren Konfiguration auf Groß- und Kleinschreibung geachtet werden muss.";
    $Self->{Translation}->{"This configuration registers a custom ticket module that overloads (redefines) existing functions in Kernel::System::Ticket to provide the Znuny4OTRS-TypePriorityBasedEscalation functionality."} = "Diese Konfiguration registriert ein Custom-Ticket-Modul, das Funktionen in Kernel::System::Ticket überschreibt (redefined) um die Znuny4OTRS-TypePriorityBasedEscalation Funktionalität bereitzustellen.";

    return 1;
}

1;
