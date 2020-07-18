<?php
/**
 * The settings page in wordpress dashboard.
 *
 * @link       https://www.siteground.com
 * @since      1.0.0
 *
 * @package    Siteground_Migrator_Settings
 * @subpackage Siteground_Migrator/admin
 */

/**
 * The admin-specific functionality of the plugin.
 *
 * Defines the plugin name, version, and two examples hooks for how to
 * enqueue the admin-specific stylesheet and JavaScript.
 *
 * @package    Siteground_Migrator_Settings
 * @subpackage Siteground_Migrator/admin
 * @author     SiteGround <hristo.p@siteground.com>
 */
class Siteground_Migrator_Settings {
	/**
	 * The admin page slug
	 */
	const PAGE_SLUG = 'siteground_migrator_settings';

	/**
	 * Initialize the class and set its properties.
	 *
	 * @since    1.0.0
	 */
	public function __construct() {

		add_action( 'admin_menu', array( $this, 'add_menu_page' ) );
		add_action( 'network_admin_menu', array( $this, 'add_menu_page' ) );
		add_action( 'admin_init', array( $this, 'register_settings' ) );

	}

	/**
	 * Title of the settings page.
	 *
	 * @since 1.0.0
	 *
	 * @return string The title of the settings page.
	 */
	public static function get_page_title() {
		return __( 'SiteGround Migrator', 'siteground-migrator' );
	}

	/**
	 * Add the plugin options page.
	 *
	 * @since 1.0.0
	 */
	public function add_menu_page() {
		add_menu_page(
			self::get_page_title(), // Page title.
			'SG Migrator', // Menu item title.
			'manage_options', // Capability.
			Siteground_Migrator::PLUGIN_SLUG, // Page slug.
			array( $this, 'display_settings_page' ), // Output function.
			plugins_url( 'siteground-migrator/admin/img/icon.svg' )
		);

		// register settings section.
		add_settings_section(
			self::PAGE_SLUG,
			__( 'Website Migration Settings', 'siteground-migrator' ),
			'',
			self::PAGE_SLUG
		);
	}

	/**
	 * Defines the setting fields.
	 *
	 * @since  1.0.0
	 *
	 * @return array Array containing all setting fields.
	 */
	private function setting_fields() {
		return array(
			'siteground_migrator_transfer_token' => array(
				'type'  => 'text',
				'title' => '',
				'args'  => array(
					'pattern'     => '[\d]{10}-[\w]{16}-[\w]{16}',
					'class_names' => 'with-padding field',
					'required'    => true,
				),
			),
		);
	}

	/**
	 * Register the settings.
	 *
	 * @since  1.0.0
	 */
	public function register_settings() {
		foreach ( $this->setting_fields() as $id => $field ) {
			Siteground_Migrator_Settings_Field::factory(
				$field['type'], // The field type.
				$id, // Field id.
				$field['title'], // The field title.
				self::PAGE_SLUG, // Section name.
				$field['args']
			);
		}
	}

	/**
	 * Output the settings page content.
	 *
	 * @since  1.0.0
	 */
	public function display_settings_page() {
		include __DIR__ . '/partials/siteground-migrator-admin-settings-page.php';
	}

}
