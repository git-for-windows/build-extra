=== SiteGround Migrator ===
Contributors: Hristo Sg, sstoqnov, SiteGround
License: GPLv3
License URI: http://www.gnu.org/licenses/gpl.html
Tags: Transfer, Migration, SiteGround, automatic transfer, automatic migration
Requires at least: 4.8
Tested up to: 5.5.0
Requires PHP: 5.6.0

Transfer your WordPress website to SiteGround without any hassle in a completely automated way using SiteGround Migrator.

== Description ==

= SiteGround Migrator: the easiest way to move your site to SiteGround =

This plugin is designed to automate the transfer of a WordPress instance to a SiteGround hosting account. It can't be used to transfer a WordPress instance to another hosting provider. 

Important: This solution is not suitable for migrating localhost WordPress sites or for Full Multisite installations (separate Multisite blogs are fine).

= How to Use =

First, you need to get a transfer token from your SiteGround account. You can do this through the WordPress Migrator tool located in the WordPress section of your SiteGround hosting control panel. 

Once you select the domain name that you want to initiate the transfer for, our system will generate a transfer token for you.Paste the token in your SiteGround Migrator plugin and press Initiate Transfer. That's all! 

== Installation ==

= Automatic Installation =

1. Visit Plugins -> Add New
1. Search for "SiteGround Migrator"
1. Activate SiteGround Migrator from your Plugins page.
1. Go to Plugins -> Activate SiteGround Migrator.

= Manual Installation =

1. Upload the "siteground-migrator" folder to the "/wp-content/plugins/" directory
1. Activate the SiteGround Migrator plugin through the 'Plugins' menu in WordPress
1. Go to Plugins -> Activate SiteGround Migrator.

= WP-CLI Support =

In version 1.0.13 we've added WP-CLI command for migrations.

* wp migrator start transfertoken --email=your@email.com

== Changelog ==

= 1.0.21 =
Release Date: March 19th, 2020
* Fixed RTL bug

= 1.0.20 =
Release Date: January 8th, 2020
* Custom dir support improvement

= 1.0.19 =
Release Date: January 8th, 2020
* Better support for custom setup hosting providers

= 1.0.18 =
Release Date: January 7th, 2020
* Better handling migrations with custom uploads folder
* Better handling migrations with custom hosts/ports

= 1.0.17 =
Release Date: October 23rd, 2019
* WordPress 5.3 Support Declared
* Added PHP 7.4 support

= 1.0.16 =
Release Date: September 19th, 2019
* Improved domain change checks

= 1.0.15 =
Release Date: June 4th, 2019
* Improved support for unorthodox filetypes

= 1.0.14 =
Release Date: June 4th, 2019
* Improved Email validation
* Improved migrator icon
* Better notices in case the host is missing

= 1.0.13 =
Release Date: February 25th, 2019
* Added WP-CLI support and example in the main page

= 1.0.12 =
Release Date: October 23th, 2018
* Better AES-128-CBC cipher method detection

= 1.0.11 =
Release Date: October 16th, 2018
* Fix typos in readme.txt

= 1.0.10 =
Release Date: October 10th, 2018
* Add rating box on success screen
* Update translations

= 1.0.9 =
Release Date: October 8th, 2018
* Fix authentication issue, due to missing parameters

= 1.0.8 =
Release Date: October 6th, 2018
* Add more precise check when trying to retrieve the `src_user`

= 1.0.7 =
Release Date: October 5th, 2018
* Add wp-content dir and other host params to init transfer

= 1.0.6 =
Release Date: September 13th, 2018
* Show the real error message from SiteGround api on failure.
* Hide annoying plugin notices on migrator page.
* Send wp-content dir to SiteGroud api.

= 1.0.5 =
Release Date: July 23th, 2018
* Handle fatal errors in background processes and display appropriate message to the user.

= 1.0.4 =
Release Date: July 16th, 2018
* Bug fixes

= 1.0.3 =
Release Date: July 16th, 2018
* Add fallback, when exec is not supported.

= 1.0.2 =
Release Date: July 13th, 2018
* Proper Multisite notifications
* Improved PHP Version check

= 1.0.1 =
Release Date: July 12th, 2018
* Added field for custom notification email
* Added PHP version check upon plugin activation
* Improved encryption process to save memory usage
* Fixed bug with the www prefix being considered as a domain change
* Improved support for custom database servers
* Improved support for Windows-based hosting environments
* Fixed a bug with the temporary link

= 1.0.0 =
Release Date: June 7th, 2018
* Initial Release

== Frequently Asked Questions ==

= Does it work with Localhost environments? =

We download your site content directly on the SiteGround server, that's why we can't access your content if it's hosted on a local environment.

= Does it work with WordPress.com? =

No, the plugin is designed to migrate from stand-alone WordPress installations. If you want to migrate from WordPress.com, please check the Guided Transfer service they offer.

= Does it work with Multisite? =

Due to the complexity of MS sites we don't migrate full MS networks at this point. However, separate blogs from a MS network can be migrated successfully.

= What content is migrated? =

We move only your WordPress content - themes, plugins, uploads. If you have other applications or content outside WordPress it will not be migrated

= Does it work only with cPanel hosts? =

No, we strive to make our plugin work flawlessly on every hosting environment. 

= Transfer is completed but I didn't get a notification? =

The plugin uses your current site admin email to notify you that the transfer is completed. If it fails to send emails you may not receive one upon completion.

= I am getting transfer errors, now what? =

Unfortunately, our plugin works on environments that we have no control over. That's why it can fail or some hosts. In such cases, please contact our support team via a ticket in your Help Desk and we will assist you further!

== Screenshots ==

1. Starting the transfer - paste your Migration Token and select notification email if you want
2. If domains are different, the plugin will inform you about the changes we will make
3. Downloading your site files to the SiteGround server
4. Once data migration is completed, we will set your site on the new server, even change its url if necessary
5. Migration completed! We've generated a temporary URL for you to verify your site on the new server