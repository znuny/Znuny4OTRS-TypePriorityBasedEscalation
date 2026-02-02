<div align="center">
  <a href="https://www.znuny.org">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://www.znuny.com/assets/znuny-logo.svg">
      <img alt="Znuny" src="https://www.znuny.com/assets/znuny-logo-black.svg" width="300">
    </picture>
  </a>

  ![Build status](https://badge.proxy.znuny.com/Znuny4OTRS-TypePriorityBasedEscalation/dev)
</div>


Znuny-TypePriorityBasedEscalation
=================================
This package extends Znuny with type and priority based escalations.

**Features**

* Allows you to define escalation attributes for ticket types via the admin interface.
* Allows you to define escalation attributes for ticket priorities via the admin interface.

**Prerequisites**

- Znuny 7.3

**Installation**

Use the online repository **Znuny Open Source Add-ons** from the package manager to install the add-on. From the command line use this command: `bin/znuny.Console.pl Admin::Package::Install  https://addons.znuny.com/public/:Znuny-TypePriorityBasedEscalation`

**Configuration**

The lookup for escalation data is configurable via SysConfig. The default order is service/SLA, type, priority, queue.

**Commercial Support**

For this add-on and for Znuny in general visit [www.znuny.com](https://www.znuny.com). Looking forward to hear from you.


Your Znuny Team!

[https://www.znuny.com](https://www.znuny.com)
