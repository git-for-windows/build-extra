<?php
/**
 * The file that defines the core plugin class
 *
 * A class definition that includes attributes and functions used across both the
 * public-facing side of the site and the admin area.
 *
 * @link       https://www.siteground.com
 * @since      1.0.0
 *
 * @package    SiteGround_Migrator
 * @subpackage SiteGround_Migrator/includes
 */

/**
 * The core plugin class.
 *
 * This is used to define internationalization, admin-specific hooks, and
 * public-facing site hooks.
 *
 * Also maintains the unique identifier of this plugin as well as the current
 * version of the plugin.
 *
 * @since      1.0.0
 * @package    SiteGround_Migrator
 * @subpackage SiteGround_Migrator/includes
 * @author     SiteGround <hristo.p@siteground.com>
 */
class SiteGround_Migrator {

	/**
	 * The unique identifier of this plugin.
	 *
	 * @since    1.0.0
	 * @var      string    $plugin_name    The string used to uniquely identify this plugin.
	 */
	const PLUGIN_SLUG = 'siteground-migrator';

	/**
	 * The current version of the plugin.
	 *
	 * @since    1.0.0
	 * @var      string    $version    The current version of the plugin.
	 */
	const VERSION = '1.0.5';

	/**
	 * The constructor
	 *
	 * @since 1.0.0
	 */
	public function __construct() {
		$this->load_dependencies();
		$this->load_plugin_textdomain();

		// Add custom shutdown function to handle fatal errors.
		register_shutdown_function( array( &$this, 'siteground_migrator_shutdown_handler' ) );
	}

	/**
	 * Load the required dependencies for this plugin.
	 *
	 * Create an instance of the loader which will be used to register the hooks
	 * with WordPress.
	 *
	 * @since    1.0.0
	 * @access   private
	 */
	private function load_dependencies() {

		/**
		 * The classes responsible for defining all actions that occur in the admin area.
		 */
		require_once plugin_dir_path( dirname( __FILE__ ) ) . 'admin/class-siteground-migrator-admin.php';
		require_once plugin_dir_path( dirname( __FILE__ ) ) . 'admin/class-siteground-migrator-admin-settings.php';

		/**
		 * Background processing
		 */
		require_once plugin_dir_path( dirname( __FILE__ ) ) . 'includes/wp-background-processing/wp-async-request.php';
		require_once plugin_dir_path( dirname( __FILE__ ) ) . 'includes/wp-background-processing/wp-background-process.php';

		/**
		 * The classes responsible for adding settings page and settings fields.
		 */
		require_once plugin_dir_path( dirname( __FILE__ ) ) . 'admin/fields/class-siteground-migrator-settings-field.php';
		require_once plugin_dir_path( dirname( __FILE__ ) ) . 'admin/fields/class-siteground-migrator-settings-field-text.php';

		/**
		 * Services.
		 */
		require_once plugin_dir_path( dirname( __FILE__ ) ) . 'includes/trait-siteground-migrator-log-service.php';
		require_once plugin_dir_path( dirname( __FILE__ ) ) . 'includes/class-siteground-migrator-database-service.php';
		require_once plugin_dir_path( dirname( __FILE__ ) ) . 'includes/class-siteground-migrator-directory-service.php';
		require_once plugin_dir_path( dirname( __FILE__ ) ) . 'includes/class-siteground-migrator-api-service.php';
		require_once plugin_dir_path( dirname( __FILE__ ) ) . 'includes/class-siteground-migrator-files-service.php';
		require_once plugin_dir_path( dirname( __FILE__ ) ) . 'includes/class-siteground-migrator-transfer-service.php';
		require_once plugin_dir_path( dirname( __FILE__ ) ) . 'includes/class-siteground-migrator-background-process.php';
		require_once plugin_dir_path( dirname( __FILE__ ) ) . 'includes/class-siteground-migrator-email-service.php';
		require_once plugin_dir_path( dirname( __FILE__ ) ) . 'includes/class-siteground-migrator-cli.php';

		$this->plugin_admin       = new SiteGround_Migrator_Admin();
		$this->background_process = new SiteGround_Migrator_Background_Process();
		$this->settings_page      = new SiteGround_Migrator_Settings();
		$this->directory_service  = new SiteGround_Migrator_Directory_Service();
		$this->api_service        = new SiteGround_Migrator_Api_Service();
		$this->email_service      = new SiteGround_Migrator_Email_Service();
		$this->file_service       = new SiteGround_Migrator_Files_Service( $this->directory_service, $this->api_service );
		$this->database_service   = new SiteGround_Migrator_Database_Service( $this->file_service );

		$this->transfer_service   = new SiteGround_Migrator_Transfer_Service(
			$this->api_service,
			$this->file_service,
			$this->database_service,
			$this->background_process,
			$this->directory_service,
			$this->email_service
		);

	}

	/**
	 * Load the plugin text domain for translation.
	 *
	 * @since    1.0.0
	 */
	private function load_plugin_textdomain() {

		load_plugin_textdomain(
			'siteground-migrator',
			false,
			dirname( dirname( plugin_basename( __FILE__ ) ) ) . '/languages/'
		);

	}

	/**
	 * The name of the plugin used to uniquely identify it within the context of
	 * WordPress and to define internationalization functionality.
	 *
	 * @since     1.0.0
	 * @return    string    The name of the plugin.
	 */
	public function get_plugin_name() {
		return $this->plugin_name;
	}

	/**
	 * Retrieve the version number of the plugin.
	 *
	 * @since     1.0.0
	 * @return    string    The version number of the plugin.
	 */
	public function get_version() {
		return $this->version;
	}

	/**
	 * Handle all functions shutdown and check for fatal errors in plugin.
	 *
	 * @since  1.0.5
	 */
	public function siteground_migrator_shutdown_handler() {
		// Get the last error.
		$error = error_get_last();

		// Bail if there is no error.
		if ( empty( $error ) ) {
			return;
		}

		// Update the status of transfer if the fatal error occured.
		if (
			strpos( $error['file'], plugin_dir_path( dirname( __FILE__ ) ) ) !== false &&
			E_ERROR === $error['type']
		) {

			// Update the status.
			$this->transfer_service->update_status(
				esc_html__( 'Critical Environment Error', 'siteground-migrator' ),
				0,
				esc_html__( 'We’ve encountered a critical error in your current hosting environment that prevents our plugin to complete the transfer.', 'siteground-migrator' )
			);

			// Log the fatal error in our custom log.
			$this->transfer_service->log_error( print_r( $error, true ) );

		}

	}

}
