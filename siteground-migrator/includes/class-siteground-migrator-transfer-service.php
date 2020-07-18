<?php
/**
 * The file that defines the class that is responsible for communication between WordPress and remote api.
 *
 * @link       https://www.siteground.com
 * @since      1.0.0
 *
 * @package    SiteGround_Migrator
 * @subpackage SiteGround_Migrator/includes
 */

/**
 * The transfer service class.
 *
 * @since      1.0.0
 * @package    SiteGround_Migrator
 * @subpackage SiteGround_Migrator/includes
 * @author     SiteGround <hristo.p@siteground.com>
 */
class Siteground_Migrator_Transfer_Service {

	use Siteground_Migrator_Log_Service;

	/**
	 * A Siteground_Migrator_Api_Service instance.
	 *
	 * @var Siteground_Migrator_Api_Service object
	 *
	 * @since 1.0.0
	 */
	private $api_service;

	/**
	 * A Siteground_Migrator_Files_Service instance.
	 *
	 * @var Siteground_Migrator_Files_Service object
	 *
	 * @since 1.0.0
	 */
	private $file_service;

	/**
	 * A Siteground_Migrator_Database_Service instance.
	 *
	 * @var Siteground_Migrator_Database_Service object
	 *
	 * @since 1.0.0
	 */
	private $database_service;

	/**
	 * A Siteground_Migrator_Background_Process instance.
	 *
	 * @var Siteground_Migrator_Background_Process object
	 *
	 * @since 1.0.0
	 */
	private $background_process;

	/**
	 * A Siteground_Migrator_Directory_Service instance.
	 *
	 * @var Siteground_Migrator_Directory_Service object
	 *
	 * @since 1.0.0
	 */
	private $directory_service;

	/**
	 * A Siteground_Migrator_Email_Service instance.
	 *
	 * @var Siteground_Migrator_Email_Service object
	 *
	 * @since 1.0.0
	 */
	private $email_service;

	/**
	 * {@link Siteground_Migrator_Transfer_Service} singleton instance.
	 *
	 * @since  1.0.0
	 * @access private
	 * @var \Siteground_Migrator_Transfer_Service $instance {@link Siteground_Migrator_Transfer_Service} singleton instance.
	 */
	private static $instance;


	/**
	 * The constructor.
	 *
	 * @param \Siteground_Migrator_Api_Service        $api_service        The {@link Siteground_Migrator_Api_Service} instance.
	 * @param \Siteground_Migrator_Files_Service      $file_service       The {@link Siteground_Migrator_Files_Service} instance.
	 * @param \Siteground_Migrator_Database_Service   $database_service   The {@link Siteground_Migrator_Database_Service} instance.
	 * @param \Siteground_Migrator_Background_Process $background_process The {@link Siteground_Migrator_Background_Process} instance.
	 * @param \Siteground_Migrator_Directory_Service  $directory_service  The {@link Siteground_Migrator_Directory_Service} instance.
	 * @param \Siteground_Migrator_Email_Service      $email_service      The {@link Siteground_Migrator_Email_Service} instance.
	 *
	 * @since 1.0.0
	 */
	public function __construct( $api_service, $file_service, $database_service, $background_process, $directory_service, $email_service ) {
		// Set the api service.
		$this->api_service        = $api_service;
		$this->file_service       = $file_service;
		$this->database_service   = $database_service;
		$this->background_process = $background_process;
		$this->directory_service  = $directory_service;
		$this->email_service      = $email_service;

		self::$instance = $this;

		// Handle options update.
		add_action( 'wp_ajax_update_option_siteground_migrator_transfer_token', array( $this, 'update_transfer_token' ) );
		add_action( 'wp_ajax_nopriv_update_option_siteground_migrator_transfer_token', array( $this, 'update_transfer_token' ) );
		// Get the transfer current status.
		add_action( 'wp_ajax_siteground_migrator_get_transfer_status', array( $this, 'get_transfer_status' ) );
		// Cancel the transfer.
		add_action( 'wp_ajax_siteground_migrator_transfer_cancelled', array( $this, 'transfer_cancelled' ) );
		// Continue the transfer.
		add_action( 'wp_ajax_siteground_migrator_transfer_continue', array( $this, 'transfer_continue' ) );
		// Restart the transfer.
		add_action( 'wp_ajax_siteground_migrator_transfer_restart', array( $this, 'transfer_restart' ) );
		// Handle all status updates from the remote api.
		add_action( 'wp_ajax_nopriv_siteground_migrator_update_transfer_status', array( $this, 'update_transfer_status_endpoint' ) );
		// Hide all annoying notices from our page.
		add_action( 'admin_init', array( $this, 'hide_errors_and_notices' ) );

	}

	/**
	 * Get {@link Siteground_Migrator_Transfer_Service} singleton instance.
	 *
	 * @since 1.0.0
	 *
	 * @return Siteground_Migrator_Transfer_Service {@link Siteground_Migrator_Transfer_Service} singleton instance.
	 */
	public static function get_instance() {
		return self::$instance;
	}

	/**
	 * Hide all errors and notices on our custom dashboard.
	 *
	 * @since  1.0.6
	 */
	public function hide_errors_and_notices() {
		// Hide all error on our dashboard.
		if (
			isset( $_GET['page'] ) &&
			'siteground-migrator' === $_GET['page']
		) {
			remove_all_actions( 'network_admin_notices' );
			remove_all_actions( 'user_admin_notices' );
			remove_all_actions( 'admin_notices' );
			remove_all_actions( 'all_admin_notices' );
		}
	}

	/**
	 * Update plugin settings and trigger the migration.
	 *
	 * @since  1.0.0
	 */
	public function update_transfer_token() {
		// Bail if the nonce field is not set.
		if ( empty( $_POST['siteground_migrator_update_options'] ) ) {
			return;
		}

		// Verify that the nonce is correct and unexpired.
		if ( ! wp_verify_nonce( sanitize_key( $_POST['siteground_migrator_update_options'] ), 'siteground_migrator_options' ) ) {
			return;
		}

		// Bail if the transfer token is empty.
		if ( empty( $_POST['siteground_migrator_transfer_token'] ) ) {
			return;
		}

		// Update the token.
		update_option(
			'siteground_migrator_transfer_token',
			sanitize_text_field( wp_unslash( $_POST['siteground_migrator_transfer_token'] ) )
		);

		// Set user preferences for email notification.
		update_option(
			'siteground_migrator_send_email_notification',
			isset( $_POST['siteground_migrator_send_email_notification'] ) ? 'yes' : 'no'
		);

		// Update the token.
		update_option(
			'siteground_migrator_email_recipient',
			sanitize_text_field( wp_unslash( $_POST['siteground_migrator_email_recipient'] ) )
		);

		// Bail if temp dirs didn't exist.
		if ( false === $this->directory_service->check_if_temp_dirs_extist() ) {
			// Update the status.
			return self::update_status(
				esc_html__( 'Transfer cannot be initiated due to permissions error.', 'siteground-migrator' ),
				0,
				esc_html__( 'For the purposes of this transfer we need to create temporary files on your current hosting account. Please fix your files permissions at your current host and make sure your wp-content folder is writable. Files should be set to 644 and folders to 755.', 'siteground-migrator' )
			);
		}

		// Start the transfer.
		$this->transfer_start();
	}

	/**
	 * Retrieve information from api to check if the domain is the same
	 * and if there is enough free space for migration.
	 *
	 * @since  1.0.0
	 *
	 * @return bool True if everything is ok
	 */
	private function before_start_transfer() {

		// Bail if transfer token in not parsed or invalid.
		if ( false === $this->api_service->parse_transfer_token() ) {
			return false;
		}

		$data = $this->api_service->get_installation_info();

		$response = $this->api_service->do_request( '/transfer/init/', $data );

		// Bail if the transfer init has failed.
		if ( 0 !== $response['status_code'] ) {
			self::update_status(
				$response['message'],
				0,
				esc_html__( 'Please, generate another Migration Token from your SiteGround control panel.', 'siteground-migrator' )
			);

			return false;
		}

		// Bail if there is not enough space on new server.
		if ( false === $this->check_size( $response['transfer_info'], $data['wp_size'] ) ) {
			return false;
		}

		// Bail if the new domain is different from current one.
		if ( false === $this->validate_domain( $response['transfer_info'] ) ) {
			return false;
		}

		return true;
	}

	/**
	 * Check if the current domain match the domain where the site will be migrated.
	 *
	 * @since  1.0.0
	 *
	 * @param  object $transfer_info Transfer info provided by the remote server.
	 *
	 * @return Bool                  True if the domain matches, false otherwise.
	 */
	private function validate_domain( $transfer_info ) {
		$src_url = $transfer_info->src_domain . $transfer_info->src_path;
		$dst_url = $transfer_info->dst_domain . $transfer_info->dst_path;

		if ( untrailingslashit( $src_url ) !== untrailingslashit( $dst_url ) ) {
			self::update_status(
				sprintf(
					esc_html__(
						'Site domain to be changed to %s',
						'siteground-migrator'
					),
					$dst_url
				),
				5,
				esc_html__( 'While generating the transfer token, you have chosen to use a different domain than the one currently used with your WordPress. To accommodate this change we will automatically update your database while transferring it to the SiteGround servers and replace the domain information on the needed places.', 'siteground-migrator' )
			);

			return false;
		}

		return true;
	}

	/**
	 * Check if the remote server has enough space to host the current installation.
	 *
	 * @since  1.0.0
	 *
	 * @param  object $transfer_info Transfer info provided by the remote server.
	 * @param  int    $wp_size       Size of current WordPress installation.
	 *
	 * @return bool                  True if the space is ok, false otherwise.
	 */
	private function check_size( $transfer_info, $wp_size ) {
		if ( empty( $transfer_info->free_space ) ) {
			return false;
		}

		if ( $wp_size > $transfer_info->free_space ) {
			self::update_status(
				esc_html__( 'There is no enough free space on your new server.', 'siteground-migrator' ),
				0,
				esc_html__( 'Please either free some space at your receiving SiteGround hosting account, or upgrade it to a higher plan that will provide you enough space for the website you want to transfer.', 'siteground-migrator' )
			);

			return false;
		}

		return true;
	}

	/**
	 * Send request to SG api to start the transfer.
	 *
	 * @since  1.0.0
	 */
	private function run_background_processes() {
		// Prepare the background process actions.
		$processes = array(
			array(
				'class'    => $this->file_service,
				'method'   => 'prepare_archives_for_download',
				'attempts' => 3,
			),
			array(
				'class'    => $this->database_service,
				'method'   => 'export_database',
				'attempts' => 3,
			),
			array(
				'class'    => $this->file_service,
				'method'   => 'create_transfer_manifest',
				'attempts' => 3,
			),
			array(
				'class'    => $this,
				'method'   => 'transfer_prepared',
				'attempts' => 3,
			),
		);

		// Loop through all processes and add them to the queue.
		foreach ( $processes as $process ) {
			$this->background_process->push_to_queue( $process );
		}

		// Dispatch.
		$this->background_process->save()->dispatch();
	}

	/**
	 * Restart the transfer.
	 *
	 * @since  1.0.0
	 */
	public function transfer_start() {
		// Update the status, that transfer has started.
		self::update_status( esc_html__( 'Transfer started. Creating archives of files...', 'siteground-migrator' ) );

		// Reset the current step.
		update_option( 'siteground_migrator_current_step', 0 );

		// Bail if transfer cannot be initated.
		if ( true === $this->before_start_transfer() ) {
			// Start the transfer.
			$this->run_background_processes();
		}
	}

	/**
	 * Resume the transfer.
	 *
	 * @since  1.0.0
	 */
	public function transfer_continue() {
		// Update the status, that transfer has started.
		self::update_status( esc_html__( 'Transfer started. Creating archives of files...', 'siteground-migrator' ) );

		$this->run_background_processes();
	}

	/**
	 * Notify the remote server that transfer is prepared.
	 *
	 * @since  1.0.0
	 */
	public function transfer_prepared() {
		// Make the request.
		$server_response = $this->api_service->do_request( '/transfer/prepared/' );

		switch ( $server_response['status_code'] ) {
			case 0:
				$response = array(
					'status' => 2,
					'title' => esc_html__( 'Transfer request has been sent to SiteGround server.', 'siteground-migrator' ),
				);
				break;
			case 500:
				$response = array(
					'status'      => 0,
					'title'       => esc_html__( 'Network connection problem', 'siteground-migrator' ),
					'description' => esc_html__( 'The transfer was interrupted due to connectivity issues. Please restart transfer.', 'siteground-migrator' ),
				);
				break;
			default:
				$response = array(
					'status'        => 0,
					'title'         => $server_response['message'],
					'skip_retrying' => true,
				);
		}

		return $response;
	}

	/**
	 * Cancel the transfer.
	 *
	 * @param mixed $hard_reset Whetherto delete the transfer status ot not.
	 *
	 * @since  1.0.0
	 */
	public function transfer_cancelled( $hard_reset = true ) {
		// Invalidate the token.
		$this->api_service->do_request( '/transfer/cancel/' );

		if ( false !== $hard_reset ) {
			delete_option( 'siteground_migrator_transfer_status' );
			delete_option( 'siteground_migrator_transfer_token' );
		}

		// Remove temp directory.
		$this->directory_service->remove_temp_dir();

		// Cancel the process.
		$this->background_process->cancel_all();

		wp_send_json_success();
	}

	/**
	 * Update the status of transfer in database.
	 *
	 * @since  1.0.0
	 *
	 * @param  string $message     The response message.
	 * @param  string $status      Current status of migration.
	 *                             There are several types:
	 *                              - 0 - transfer has failed.
	 *                              - 1 - transfer is in progress.
	 *                              - 2 - waiting for remote server to complete the migration.
	 *                              - 3 - transfer completed.
	 *                              - 4 - completed with errors.
	 * @param  string $description The description of the status.
	 */
	public static function update_status( $message, $status = 1, $description = '' ) {
		// Build the data array.
		$data = array(
			'message'     => $message,
			'status'      => $status,
			'description' => $description,
		);

		// Write the result to the log.
		self::get_instance()->log_info( $message );

		// Update the current status of the transfer.
		update_option( 'siteground_migrator_transfer_status', $data );
	}

	/**
	 * Get transfer status.
	 *
	 * @since  1.0.0
	 */
	public function get_transfer_status() {
		$progress           = get_option( 'siteground_migrator_progress' );
		$status             = get_option( 'siteground_migrator_transfer_status' );
		$status['progress'] = $progress;

		wp_send_json_success( $status );
		exit;
	}

	/**
	 * Update the progress bar of currently running transfer.
	 *
	 * @since  1.0.0
	 *
	 * @param  int $step The step to update the progress.
	 */
	public static function update_transfer_progress( $step ) {
		// Get the current % of progress bar.
		$progress = get_option( 'siteground_migrator_progress', 100 );
		// Update the progress.
		update_option( 'siteground_migrator_progress', $progress - $step );
	}

	/**
	 * Handle transfer status updates from remote api.
	 *
	 * @since  1.0.0
	 */
	public function update_transfer_status_endpoint() {
		// Bail if the data parameter is not set.
		if ( empty( $_POST['data'] ) ) {
			$this->log_die( '`data` parameter is required.' );
		}

		// Authenitcate the request.
		$this->api_service->authenticate( stripcslashes( $_POST['data'] ) );
		// Convert the data to array.
		$data = json_decode( sanitize_text_field( wp_unslash( $_POST['data'] ) ), true );

		$step = 5;

		$current_step = get_option( 'siteground_migrator_current_step', 0 );

		// Translate the message from out api.
		// See http://keithdevon.com/using-variables-wordpress-translation-functions/
		$data['message'] = __( $data['message'], 'siteground-migrator' );

		if ( ! empty( $data['description'] ) ) {
			$data['description'] = __( $data['description'], 'siteground-migrator' );
		}

		// Very ugly way to prevent unwanted messages to be displayed.
		if (
			empty( $data['tot_files'] ) ||
			(
				isset( $data['tot_files'] ) &&
				$data['n_file'] > $current_step
			)
		) {
			// Update the current step only if the `n_file` param exists.
			if ( isset( $data['n_file'] ) ) {
				update_option( 'siteground_migrator_current_step', $data['n_file'] );
			}

			// Update the progress bar.
			if ( isset( $data['tot_files'] ) ) {
				// Calculate the step to update the progress bar.
				$step = 30 / ( $data['tot_files'] / 20 );
				$data['message'] = sprintf( __( 'Downloaded %d out of %d files...', 'siteground-migrator' ), $data['n_file'], $data['tot_files'] );
			}

			// Update the status of transfer.
			update_option( 'siteground_migrator_transfer_status', $data );
			// Update the progress bar as well.
			$this->update_transfer_progress( $step );
		}

		// Send notification to site admin when the transfer is completed or failed.
		$this->email_service->prepare_and_send_notification( $data );

		$data['success'] = 1;

		wp_send_json( $data, 1 );

	}

}
