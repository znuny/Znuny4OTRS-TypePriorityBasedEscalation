# TypePriorityBasedEscalation

This package extends the OTRS standard with type and priority based escalations.
In default OTRS escalation can only be activated and configured for queues and services/SLAs.

The default order is:
Service/SLA, Type, Priority, Queue

## Feature List

* Allows you to define escalation attributes for ticket types via the admin interface.
  ![Screenshot Types](doc/en/type.png "Screenshot 1 - Type configuration")
* Allows you to define escalation attributes for ticket priorities via the admin interface.
  ![Screenshot Priority](doc/en/priority.png "Screenshot 2 - Priority configuration")

## Configuration

* Define the list in Admin-Interface -> Types/Priorities
