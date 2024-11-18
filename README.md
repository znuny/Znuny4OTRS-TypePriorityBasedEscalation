![Znuny logo](https://www.znuny.com/assets/images/logo_small.png)


![Build status](https://badge.proxy.znuny.com/Znuny4OTRS-TypePriorityBasedEscalation/rel-7_1)

Znuny-TypePriorityBasedEscalation
=================================
This package extends Znuny with type and priority based escalations.

**Features**

* Allows you to define escalation attributes for ticket types via the admin interface.
* Allows you to define escalation attributes for ticket priorities via the admin interface.

**Prerequisites**

- Znuny 7.1

**Installation**

Use the online repository **Znuny Open Source Add-ons** from the package manager to install the add-on. From the command line use this command: `bin/znuny.Console.pl Admin::Package::Install  https://addons.znuny.com/public/:Znuny-TypePriorityBasedEscalation`

**Configuration**

The lookup for escalation data is configurable via SysConfig. The default order is service/SLA, type, priority, queue.

**Commercial Support**

For this add-on and for Znuny in general visit [www.znuny.com](https://www.znuny.com). Looking forward to hear from you.


Your Znuny Team!

[https://www.znuny.com](https://www.znuny.com)
