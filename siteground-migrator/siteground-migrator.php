<?php

/**
 * The plugin bootstrap file
 *
 * This file is read by WordPress to generate the plugin information in the plugin
 * admin area. This file also includes all of the dependencies used by the plugin,
 * registers the activation and deactivation functions, and defines a function
 * that starts the plugin.
 *
 * @link              https://www.siteground.com
 * @since             1.0.0
 * @package           SiteGround_Migrator
 *
 * @wordpress-plugin
 * Plugin Name:       SiteGround Migrator
 * Plugin URI:        http://siteground.com
 * Description:       This plugin is designed to migrate your WordPress site to SiteGround
 * Version:           1.0.21
 * Author:            SiteGround
 * Author URI:        https://www.siteground.com
 * License:           GPL-2.0+
 * License URI:       http://www.gnu.org/licenses/gpl-2.0.txt
 * Text Domain:       siteground-migrator
 * Domain Path:       /languages
 */

// If this file is called directly, abort.
if ( ! defined( 'WPINC' ) ) {
	die;
}

/**
 * The core plugin class that is used to define internationalization,
 * admin-specific hooks, and public-facing site hooks.
 */
require plugin_dir_path( __FILE__ ) . 'includes/class-siteground-migrator.php';
require plugin_dir_path( __FILE__ ) . 'includes/class-siteground-migrator-activator.php';
require plugin_dir_path( __FILE__ ) . 'includes/class-siteground-migrator-deactivator.php';
require plugin_dir_path( __FILE__ ) . 'shuttle-dumper.php';

register_activation_hook( __FILE__, array( 'SiteGround_Migrator_Activator', 'activate' ) );
register_deactivation_hook( __FILE__, array( 'SiteGround_Migrator_Deactivator', 'deactivate' ) );

// Check the php version and deactivate the plugin is it's lower that 5.4.
if ( version_compare( PHP_VERSION, '5.4', '<' ) ) {
	add_action( 'network_admin_notices', 'siteground_migrator_compatability_warning' );
	add_action( 'admin_notices', 'siteground_migrator_compatability_warning' );
	add_action( 'admin_init', 'siteground_migrator_deactivate_self' );
} elseif ( is_multisite() && is_network_admin() ) {
	add_action( 'network_admin_notices', 'siteground_migrator_multisite_warning' );
	add_action( 'admin_init', 'siteground_migrator_deactivate_self' );
} else {
	// Activate the plugin.
	add_action( 'plugins_loaded', 'run_siteground_migrator' );
}

/**
 * Activates the plugin.
 *
 * @since  1.0.0
 */
function run_siteground_migrator() {
	$siteground_migrator = new SiteGround_Migrator();
}

/**
 * Display notice for minimum supported php version.
 *
 * @since  1.0.0
 */
function siteground_migrator_compatability_warning() {
	printf(
		__( '<div class="error"><p>“%1$s” requires PHP %2$s (or newer) to function properly. Your site is using PHP %3$s. Please upgrade. The plugin has been automatically deactivated.</p></div>', 'siteground-migrator' ),
		'SiteGround Migrator',
		'5.4',
		PHP_VERSION
	);

	// Hide "Plugin activated" message.
	if ( isset( $_GET['activate'] ) ) {
		unset( $_GET['activate'] );
	}
}

/**
 * Display notice if wp is multisite.
 *
 * @since  1.0.1
 */
function siteground_migrator_multisite_warning() {
	_e( '<div class="error"><p>This plugin does not support full Multise Network migrations.</p></div>', 'siteground-migrator' );

	// Hide "Plugin activated" message.
	if ( isset( $_GET['activate'] ) ) {
		unset( $_GET['activate'] );
	}
}

/**
 * Deactivate the plugin if server php version
 * is lower than plugin supported version.
 *
 * @since  1.0.0
 */
function siteground_migrator_deactivate_self() {
	deactivate_plugins( plugin_basename( __FILE__ ) );
}
