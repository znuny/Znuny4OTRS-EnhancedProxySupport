![Znuny logo](https://www.znuny.com/assets/images/logo_small.png)


![Build status](https://badge.proxy.znuny.com/Znuny4OTRS-EnhancedProxySupport/master)


Znuny4OTRS - Enhanced Proxy Support
===================================

**DEPRECATED FOR OTRS 6. Use Znuny4OTRS-WebUserAgent instead**

You use the OTRS http/ftp proxy support to access external RSS feeds and other resources but you also want to use local http/ftp resources (e. g. local package manager as OPM repository). But you have problems to configure it, because you need both (http/ftp proxy for external and just some URL's/host's). Well here´s your solution!

**Feature List**

- Allows you to define hosts/URLs in OTRS where no proxy should be used.

**Prerequisites**

- OTRS 6
- [Znuny4OTRS-Repo](https://www.znuny.com/add-ons/znuny4otrs-repository)

**Installation**

Download the [package](https://addons.znuny.com/api/addon_repos/public/1093/latest) and install it via admin interface -> package manager or use [Znuny4OTRS-Repo](https://www.znuny.com/add-ons/znuny4otrs-repository).

**Configuration**

* Configure exceptions for proxy usage via System Configuration. Add the domains which should not be access by aa proxy to the setting `WebUserAgent::NoProxy`.

**Download**

Download the [latest version](https://addons.znuny.com/api/addon_repos/public/1093/latest).

**Commercial Support**

For this add-on and for OTRS in general visit [www.znuny.com](https://www.znuny.com). Looking forward to hear from you!

Enjoy!

Your Znuny Team!

[https://www.znuny.com](https://www.znuny.com)
