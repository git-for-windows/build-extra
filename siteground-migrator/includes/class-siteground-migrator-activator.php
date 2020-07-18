<?php
/**
 * Fired during plugin activation
 *
 * @link       https://www.siteground.com
 * @since      1.0.0
 *
 * @package    Siteground_Migrator
 * @subpackage Siteground_Migrator/includes
 */

/**
 * Fired during plugin activation.
 *
 * This class defines all code necessary to run during the plugin's activation.
 *
 * @since      1.0.0
 * @package    Siteground_Migrator
 * @subpackage Siteground_Migrator/includes
 * @author     SiteGround <hristo.p@siteground.com>
 */
class Siteground_Migrator_Activator {

	/**
	 * Fires on plugin activation.
	 *
	 * @since    1.0.0
	 */
	public static function activate() {
		// Set the temp directory.
		self::set_temp_directory();
		// Set the encryption key.
		self::set_encryption_key();
	}

	/**
	 * Set temp directory.
	 *
	 * @since 1.0.0
	 */
	public static function set_temp_directory() {
		// Try to get the temp dir.
		$temp_dir = get_option( 'siteground_migrator_temp_directory' );

		// Set the directory is it's empty.
		if ( empty( $temp_dir ) ) {
			update_option( 'siteground_migrator_temp_directory', time() . '-' . sha1( mt_rand() ) );
		}
	}

	/**
	 * Set the encryption key for current installation.
	 *
	 * @since 1.0.0
	 */
	public static function set_encryption_key() {
		// Get the encryption key.
		$encryption_key = get_option( 'siteground_migrator_encryption_key' );

		// Generate encryption key if it's not set already.
		if ( empty( $encryption_key ) ) {
			update_option( 'siteground_migrator_encryption_key', sha1( uniqid() ) );
		}
	}

}
