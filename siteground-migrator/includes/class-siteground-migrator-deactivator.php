<?php
/**
 * Fired during plugin deactivation
 *
 * @link       https://www.siteground.com
 * @since      1.0.0
 *
 * @package    Siteground_Migrator
 * @subpackage Siteground_Migrator/includes
 */

/**
 * Fired during plugin deactivation.
 *
 * This class defines all code necessary to run during the plugin's deactivation.
 *
 * @since      1.0.0
 * @package    Siteground_Migrator
 * @subpackage Siteground_Migrator/includes
 * @author     SiteGround <hristo.p@siteground.com>
 */
class Siteground_Migrator_Deactivator {

	/**
	 * Short Description. (use period)
	 *
	 * Long Description.
	 *
	 * @since    1.0.0
	 */
	public static function deactivate() {

		if ( class_exists( 'Siteground_Migrator_Directory_Service' ) ) {
			Siteground_Migrator_Directory_Service::get_instance()->remove_temp_dir();
		}

		global $wpdb;

		// Delete the plugin options.
		$result = $wpdb->get_results( "
			DELETE
			FROM $wpdb->options
			WHERE `option_name` LIKE 'siteground_migrator_%'"
		);
	}

}
