<?php
/**
 * The file that defines the class that handle all encryption and archiving processes.
 *
 * @link       https://www.siteground.com
 * @since      1.0.0
 *
 * @package    SiteGround_Migrator
 * @subpackage SiteGround_Migrator/includes
 */

/**
 * The files service class.
 *
 * Provide methods to encrypt, archive and download files.
 *
 * @since      1.0.0
 * @package    SiteGround_Migrator
 * @subpackage SiteGround_Migrator/includes
 * @author     SiteGround <hristo.p@siteground.com>
 */
class Siteground_Migrator_Files_Service {

	use Siteground_Migrator_Log_Service;

	/**
	 * A Siteground_Migrator_Directory_Service instance.
	 *
	 * @var Siteground_Migrator_Directory_Service object
	 *
	 * @since 1.0.0
	 */
	private $directory_service;

	/**
	 * A Siteground_Migrator_Api_Service instance.
	 *
	 * @var Siteground_Migrator_Api_Service object
	 *
	 * @since 1.0.0
	 */
	private $api_service;

	/**
	 * The constructor.
	 *
	 * @param \Siteground_Migrator_Directory_Service $directory_service The {@link Siteground_Migrator_Directory_Service} instance.
	 * @param \Siteground_Migrator_Api_Service       $api_service       The {@link Siteground_Migrator_Api_Service} instance.
	 *
	 * @since 1.0.0
	 */
	public function __construct( $directory_service, $api_service ) {

		$this->directory_service = $directory_service;
		$this->api_service       = $api_service;

		add_action( 'wp_ajax_nopriv_siteground_migrator_download_file', array( $this, 'download_file_from_uploads' ) );
	}

	/**
	 * Allow SiteGround server to
	 * download php files via http.
	 *
	 * @since  1.0.0
	 */
	public function download_file_from_uploads() {
		// Bail if the path parameter is not set.
		if ( empty( $_GET['path'] ) ) {
			$this->log_die( '`path` parameter is rquired.' );
		}
		$maybe_path = sanitize_text_field( wp_unslash( $_GET['path'] ) );

		// Check if the request is made from SiteGround server.
		$this->api_service->authenticate( $maybe_path );

		// Validate and build the whole path to the file.
		$path = $this->validate_and_build_path( $maybe_path ); // input var ok; sanitization ok.

		// Bail if the path doesn't exist.
		if ( false === $path ) {
			$this->log_die(
				// translators: The placeholder is the path to the file that we are trying to downlaod.
				sprintf( 'The following filepath doesn\'t exist: %s', $path ) // phpcs:ignore WordPress.XSS.EscapeOutput
			);
		}

		// Get encrypted file content.
		$cipher_content = $this->get_encrypted_file_content( $path );

		if ( empty( $cipher_content ) ) {
			$this->log_die(
				// translators: The placeholder is the path to the file that we are trying to downlaod.
				sprintf( 'Error creating encrypted content for file: %s', $path ) // phpcs:ignore WordPress.XSS.EscapeOutput
			);
		}

		die( $cipher_content ); // phpcs:ignore WordPress.XSS.EscapeOutput
	}

	/**
	 * Validate that the path is correct and it exists.
	 *
	 * @since  1.0.0
	 *
	 * @param  string $maybe_path The path to validate/build.
	 *
	 * @return string  $maybe_path Full path to the file/folder.
	 */
	private function validate_and_build_path( $maybe_path ) {
		// Bail if the filepath is undefined.
		if ( empty( $maybe_path ) ) {
			$this->log_error( 'You must specify the path to file.' );
			return false;
		}

		// Replace all forbidden strings.
		$maybe_path = str_replace( '../', '', $maybe_path );

		// Build the path to the filem using the `WP_CONTENT_DIR` const.
		$path = ABSPATH . $maybe_path;

		// Bail if the file doesn't exists.
		if ( ! file_exists( $path ) ) {
			// translators: The placeholder is the name of the path that wasn't found.
			$this->log_error( sprintf( 'File not found %s.', $path ) ); // phpcs:ignore WordPress.XSS.EscapeOutput
			return false;
		}

		return $path;
	}

	/**
	 * Archive all subdirs from plugins/themes.
	 *
	 * @since  1.0.0
	 */
	public function prepare_archives_for_download() {
		// Build the response.
		$response = array(
			'status' => 1,
			'title'  => esc_html__( 'Files archived, compressing the database..', 'siteground-migrator' ),
		);

		// Loop through all child directories and create encrypted archives.
		foreach ( $this->directory_service->get_plugin_and_theme_child_directories() as $path ) {
			$result = $this->create_encrypted_archive( $path );

			// Write in logs in case the file wasn't encrypted.
			if ( false === $result ) {
				$response['status'] = 0;
			}
		}

		// Change the response status to failed.
		if ( 0 === $response['status'] ) {
			$response = array_merge(
				$response,
				array(
					'title'  => esc_html__( 'Transfer cannot be initiated due to permissions error.', 'siteground-migrator' ),
					'description' => __( 'For the purposes of this transfer we need to create temporary files on your current hosting account. Please fix your files permissions at your current host and make sure your wp-content folder is writable. Files should be set to 644 and folders to 755.', 'siteground-migrator' ),
				)
			);
		}

		// Return the response.
		return $response;
	}

	/**
	 * Create encrypted archive.
	 *
	 * @since  1.0.0
	 *
	 * @param  string $path The path relative to wp-content.
	 *
	 * @return bool         True on success, false on failure.
	 */
	private function create_encrypted_archive( $path ) {
		// Bail if the temp directory doesn't exist.
		if ( ! is_dir( $this->directory_service->get_temp_directory_path() ) ) {
			return false;
		}

		$wp_filesystem = $this->setup_wp_filesystem();
		// Validate and build the path.
		$source_path = $this->validate_and_build_path( 'wp-content/' . $path );

		if ( false === $source_path ) {
			$this->log_error( sprintf( 'The following path is invalid or doesn\'t exist: %s.', $path ) );
			return false;
		}

		// Build archive filename.
		$archive_filename = $this->directory_service->get_temp_directory_path() . '/' . $path . '.tar';

		// Delete the file if it exists and create fresh archive.
		if ( file_exists( $archive_filename ) ) {
			$wp_filesystem->delete( $archive_filename );
		}

		// Init the PharData.
		$phar = new PharData( $archive_filename );

		// Create archive from directory.
		$phar->buildFromDirectory( $source_path );

		return $this->encrypt_and_delete_original( $archive_filename );
	}

	/**
	 * Create the transfer manifest.
	 *
	 * @since  1.0.0
	 *
	 * @return bool True on success, false on failure
	 */
	public function create_transfer_manifest() {
		// Get uploas dir.
		$upload_dir = wp_upload_dir();

		$result = $this->create_encrypted_file(
			$this->directory_service->get_temp_directory_path() . '/manifest.txt', // The file name.
			$this->directory_service->get_upload_paths( $upload_dir['basedir'] ) // File content.
		);

		$response = array(
			'status' => intval( $result ),
			'title' => esc_html__( 'Failed to create transfer manifest.', 'siteground-migrator' ),
		);

		if ( 1 === $response['status'] ) {
			$response['title'] = esc_html__( 'Transfer manifest has been created. Sending request to SiteGround API ...', 'siteground-migrator' );
		}

		// Return the result of the process.
		return $response;
	}

	/**
	 * Create encrypted file.
	 *
	 * @since  1.0.0
	 *
	 * @param  string $filename The name of the file.
	 * @param  string $content  The content of file.
	 *
	 * @return bool True on success, false on failure.
	 */
	private function create_encrypted_file( $filename, $content ) {
		$wp_filesystem = $this->setup_wp_filesystem();

		// Add the paths to the file.
		if ( false === $wp_filesystem->put_contents( $filename, $content ) ) {
			$this->log_error( 'Error creating file.' );
			return false;
		}

		// Encrypt the file and delete the original file.
		if ( false === $this->encrypt_and_delete_original( $filename ) ) {
			$this->log_error( 'Error encrypting file.' );
			return false;
		}

		return true;
	}

	/**
	 * Encrypt file and delete the original one.
	 *
	 * @since  1.0.0
	 *
	 * @param  string $file Path to the file.
	 *
	 * @return string|bool The number of bytes that were written
	 *                     to the file, or false on failure.
	 */
	public function encrypt_and_delete_original( $file ) {
		$wp_filesystem = $this->setup_wp_filesystem();

		// Get encrypted content of archive.
		$encrypted_content = $this->get_encrypted_file_content( $file );

		// Delete the original file.
		$wp_filesystem->delete( $file );

		// Create new file with encrypted content.
		return $wp_filesystem->put_contents(
			$file,
			$encrypted_content
		);
	}


	/**
	 * Retrieve encrypted content of file.
	 *
	 * @since  1.0.0
	 *
	 * @param  string $file The filepath.
	 *
	 * @return string $cipher_content File encrypted content.
	 */
	private function get_encrypted_file_content( $file ) {
		$wp_filesystem = $this->setup_wp_filesystem();
		// Bail if the file is empty.
		if ( empty( $file ) ) {
			$this->log_error( 'File parameter is required.' );
			return;
		}

		if ( ! extension_loaded( 'openssl' ) ) {
			Siteground_Migrator_Transfer_Service::update_status(
				__( 'Openssl module is not loaded', 'siteground_migrator' ),
				0,
				__( 'This plugin requires openssl module enabled. Please enable the module and restart the transfer.', 'siteground_migrator' )
			);
		}

		if (
			! in_array( 'AES-128-CBC', openssl_get_cipher_methods() ) &&
			! in_array( 'aes-128-cbc', openssl_get_cipher_methods() )
		) {
			Siteground_Migrator_Transfer_Service::update_status(
				__( 'AES-128-CBC cipher method is required.', 'siteground_migrator' ),
				0,
				__( 'This plugin requires AES-128-CBC cipher method to work.', 'siteground_migrator' )
			);
		}

		// Get contents of the file.
		$key            = get_option( 'siteground_migrator_encryption_key' );
		$cipher         = 'AES-128-CBC';
		$ivlen          = openssl_cipher_iv_length( $cipher );
		$iv             = openssl_random_pseudo_bytes( $ivlen );
		$file_contents  = $wp_filesystem->get_contents( $file );
		$hash           = sha1( $file_contents, true );
		$cipher_content = openssl_encrypt( $file_contents, $cipher, $key, OPENSSL_RAW_DATA, $iv );

		// Return the encrypted content.
		return $iv . $hash . $cipher_content;
	}

	/**
	 * Load the global wp_filesystem.
	 *
	 * @since  1.0.0
	 *
	 * @return object The {@link Siteground_Migrator_Api_Service} instance.
	 */
	private function setup_wp_filesystem() {
		global $wp_filesystem;

		// Initialize the WP filesystem, no more using 'file-put-contents' function.
		if ( empty( $wp_filesystem ) ) {
			require_once( ABSPATH . '/wp-admin/includes/file.php' );
			WP_Filesystem();
		}

		return $wp_filesystem;
	}
}
