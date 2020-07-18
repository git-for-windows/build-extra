<?php

/**
 * The admin-specific functionality of the plugin.
 *
 * @link       https://www.siteground.com
 * @since      1.0.0
 *
 * @package    Siteground_Migrator
 * @subpackage Siteground_Migrator/admin
 */

/**
 * The admin-specific functionality of the plugin.
 *
 * Defines the plugin name, version, and two examples hooks for how to
 * enqueue the admin-specific stylesheet and JavaScript.
 *
 * @package    Siteground_Migrator
 * @subpackage Siteground_Migrator/admin
 * @author     SiteGround <hristo.p@siteground.com>
 */
class Siteground_Migrator_Admin {

	/**
	 * Initialize the class and set its properties.
	 *
	 * @since    1.0.0
	 */
	public function __construct() {
		add_action( 'admin_enqueue_scripts', array( $this, 'enqueue_styles' ) );
		add_action( 'admin_enqueue_scripts', array( $this, 'enqueue_scripts' ) );

		add_action( 'admin_print_styles', array( $this, 'admin_print_styles' ) );
	}

	public function admin_print_styles(){
		echo '<style>.toplevel_page_siteground-migrator.menu-top .wp-menu-image img { width:20px; } </style>';
	}


	/**
	 * Register the stylesheets for the admin area.
	 *
	 * @since    1.0.0
	 */
	public function enqueue_styles() {
		$current_screen = get_current_screen();

		// Bail if this is not our settgins page.
		if (
			'toplevel_page_siteground-migrator' !== $current_screen->id &&
			'toplevel_page_siteground-migrator-network' !== $current_screen->id
		) {
			return;
		}

		/**
		 * This function is provided for demonstration purposes only.
		 *
		 * An instance of this class should be passed to the run() function
		 * defined in Siteground_Migrator_Loader as all of the hooks are defined
		 * in that particular class.
		 *
		 * The Siteground_Migrator_Loader will then create the relationship
		 * between the defined hooks and the functions defined in this
		 * class.
		 */

		wp_enqueue_style(
			Siteground_Migrator::PLUGIN_SLUG, // The plugin name.
			plugin_dir_url( __FILE__ ) . 'css/siteground-migrator-admin.css',
			array(),
			Siteground_Migrator::VERSION, // The plugin version.
			'all'
		);

		wp_style_add_data( Siteground_Migrator::PLUGIN_SLUG, 'rtl', 'replace' );

	}

	/**
	 * Register the JavaScript for the admin area.
	 *
	 * @since    1.0.0
	 */
	public function enqueue_scripts() {
		$current_screen = get_current_screen();

		// Bail if this is not our settgins page.
		if (
			'toplevel_page_siteground-migrator' !== $current_screen->id &&
			'toplevel_page_siteground-migrator-network' !== $current_screen->id
		) {
			return;
		}

		/**
		 * This function is provided for demonstration purposes only.
		 *
		 * An instance of this class should be passed to the run() function
		 * defined in Siteground_Migrator_Loader as all of the hooks are defined
		 * in that particular class.
		 *
		 * The Siteground_Migrator_Loader will then create the relationship
		 * between the defined hooks and the functions defined in this
		 * class.
		 */

		wp_enqueue_script(
			Siteground_Migrator::PLUGIN_SLUG, // The plugin name.
			plugin_dir_url( __FILE__ ) . 'js/siteground-migrator-admin.js',
			array( 'jquery' ), // Dependencies.
			Siteground_Migrator::VERSION, // The plugin version.
			false // Load the script in the footer.
		);

		// Load translated strings that are used in the js.
		wp_localize_script(
			Siteground_Migrator::PLUGIN_SLUG,
			'objectL10n',
			array(
				'start_message' => __( 'Transfer started. Creating archives of files...', 'siteground-migrator' ),
			)
		);

	}

}
