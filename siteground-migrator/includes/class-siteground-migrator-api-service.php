<?php
/**
 * Handle all request to SiteGround API.
 *
 * @link       https://www.siteground.com
 * @since      1.0.0
 *
 * @package    Siteground_Migrator
 * @subpackage Siteground_Migrator/includes
 */

/**
 * Handle all request to SiteGround API.
 *
 * This class defines all code necessary to make requests to SiteGround API.
 * It also provides information about the current installtion and authenticaion.
 *
 * @since      1.0.0
 * @package    Siteground_Migrator
 * @subpackage Siteground_Migrator/includes
 * @author     SiteGround <hristo.p@siteground.com>
 */
class Siteground_Migrator_Api_Service {
	use Siteground_Migrator_Log_Service;

	/**
	 * The Siteground API endpoint.
	 *
	 * @var 1.0.0
	 */
	const API_URL = 'https://wp-transfer-api.sgvps.net/wp-api-v0';

	/**
	 * The max allowed difference between the current
	 * timestamp and when the request was made.
	 *
	 * @var 1.0.0
	 */
	const MAX_TIME_DIFF = 172800;

	/**
	 * The constructor
	 *
	 * @since 1.0.0
	 */
	public function __construct() {
		// Fired when the transfer is completed and the site is migrated to SiteGround server.
		add_action( 'wp_ajax_nopriv_siteground_migrator_is_plugin_installed', array( $this, 'is_plugin_installed' ) );
	}

	/**
	 * Provide information about the current WordPress installation.
	 * The information includes the following:
	 *      - Server IP address
	 *      - PHP Version
	 *      - WordPress version
	 *      - site_url
	 *      - home_url
	 *      - database size
	 *      - the size of wp-content directory
	 *      - files treemap
	 *
	 * @since  1.0.0
	 *
	 * @return array Array containg the information above.
	 */
	public function get_installation_info() {
		global $wp_version;
		global $wpdb;

		$username = '';

		if (
			function_exists( 'posix_getpwuid' ) &&
			function_exists( 'posix_geteuid' )
		) {
			$username = posix_getpwuid( posix_geteuid() )['name'];
		} else {
			$username = getenv( 'USERNAME' );
		}

		if ( empty( $username ) ) {
			$username = 'UNKNOWN';
		}

		$uploads_dir = wp_upload_dir();

		return array(
			'ip_address'        => $this->get_ip_address(),
			'php_version'       => phpversion(),
			'wordpress_version' => $wp_version,
			'site_url'          => is_multisite() ? network_site_url() : get_site_url(),
			'home_url'          => is_multisite() ? network_home_url() : get_home_url(),
			'database_size'     => Siteground_Migrator_Database_Service::get_database_size(),
			'wp_size'           => Siteground_Migrator_Directory_Service::get_wordpress_size(),
			'key'               => get_option( 'siteground_migrator_encryption_key' ),
			'base_ident'        => get_option( 'siteground_migrator_temp_directory' ),
			'table_prefix'      => $wpdb->prefix,
			'wp_content_dir'    => WP_CONTENT_DIR,
			'wp_uploads_dir'    => str_replace( ABSPATH, '', $uploads_dir['basedir'] ),
			'wp_content_folder' => str_replace( ABSPATH, '', WP_CONTENT_DIR ),
			'src_hostname'      => gethostname(),
			'sg_host'           => is_dir( '/Z' ) ? 1 : 0,
			'src_user'          => $username,
			'src_uname'         => php_uname(),
			'src_os'            => PHP_OS,
		);
	}

	/**
	 * Retrieve the server ip address.
	 *
	 * @since  1.0.0
	 *
	 * @return string $ip_address The server IP address.
	 */
	private function get_ip_address() {
		if ( ! empty( $_SERVER['HTTP_CLIENT_IP'] ) ) {
			$ip_address = $_SERVER['HTTP_CLIENT_IP']; // WPCS: sanitization ok.
		} elseif ( ! empty( $_SERVER['HTTP_X_FORWARDED_FOR'] ) ) {
			$ip_address = $_SERVER['HTTP_X_FORWARDED_FOR']; // WPCS: sanitization ok.
		} elseif ( ! empty( $_SERVER['HTTP_X_FORWARDED'] ) ) {
			$ip_address = $_SERVER['HTTP_X_FORWARDED']; // WPCS: sanitization ok.
		} elseif ( ! empty( $_SERVER['HTTP_FORWARDED_FOR'] ) ) {
			$ip_address = $_SERVER['HTTP_FORWARDED_FOR']; // WPCS: sanitization ok.
		} elseif ( ! empty( $_SERVER['HTTP_FORWARDED'] ) ) {
			$ip_address = $_SERVER['HTTP_FORWARDED']; // WPCS: sanitization ok.
		} elseif ( ! empty( $_SERVER['REMOTE_ADDR'] ) ) {
			$ip_address = $_SERVER['REMOTE_ADDR']; // WPCS: sanitization ok.
		} else {
			$ip_address = 'UNKNOWN';
		}

		return sanitize_text_field( wp_unslash( $ip_address ) );
	}

	/**
	 * Sort all request params and build the query string.
	 *
	 * @since  1.0.0
	 *
	 * @param  string $data json encoded representation of the data.
	 *
	 * @return string $api_query Query string containing all data params.
	 */
	private function prepare_verify_request( $data ) {
		$api_query = '';
		// Sort the data keys.
		ksort( $data );

		// Build the query.
		foreach ( $data as $key => $value ) {
			$api_query .= "$key=$value|";
		}

		// Finally return the query.
		return $api_query;
	}

	/**
	 * Make request to SG endpoint.
	 *
	 * @since  1.0.0
	 *
	 * @param  string $api_endpoint API ednpoint.
	 * @param  array  $data         Request body.
	 *
	 * @return array  Array containing the response code and response message.
	 */
	public function do_request( $api_endpoint, $data = array() ) {
		$transfer_id  = get_option( 'siteground_migrator_transfer_id' );
		$transfer_psk = get_option( 'siteground_migrator_transfer_psk' );

		// Add the endpoint command to data.
		$data['cmd'] = $api_endpoint . $transfer_id;

		// Create the authentication hash.
		$auth = sha1( $this->prepare_verify_request( $data ) . $transfer_psk );

		// Prepare the json encoded data for the request.
		$json_data = json_encode(
			array(
				'data' => $data,
			)
		);

		// Send request to SG api.
		$response = wp_remote_post(
			// Add the auth parameter to endpoint.
			add_query_arg( 'auth', $auth, self::API_URL . $api_endpoint . $transfer_id ),
			array(
				'method'  => 'POST',
				'headers' => array(
					// Get the content length of encoded data.
					'Content-Length' => strlen( $json_data ),
					// Add the content type.
					'Content-type'   => 'application/json',
				),
				'body'    => $json_data,
				'timeout' => 30,
			)
		);

		// Return the response containing the status code and the response message.
		return $this->prepare_response_message( $response );
	}

	/**
	 * Prepare response message using the response from the api.
	 *
	 * @since  1.0.0
	 *
	 * @param  array $response The response from the server.
	 *
	 * @return array Array containing the error message and status code.
	 */
	private function prepare_response_message( $response ) {
		// Check for wp errors.
		if ( is_wp_error( $response ) ) {
			return array(
				// The status code.
				'status_code' => 404,
				// The response message.
				'message'     => $response->get_error_message(),
			);
		}

		// Get the status code.
		$status_code = wp_remote_retrieve_response_code( $response );

		// Retrieve the response body.
		$response_body = json_decode( wp_remote_retrieve_body( $response ) );

		// Return the response.
		return array(
			// The status code.
			'status_code'   => (int) $response_body->status,
			// The response message.
			'message'       => $response_body->message,
			// Transfer info if there is such.
			'transfer_info' => ! empty( $response_body->transfer_info ) ? $response_body->transfer_info : '',
		);
	}

	/**
	 * Parse the transfer token to `transfer_id` & `transfer_psk`
	 *
	 * @since  1.0.0
	 */
	public function parse_transfer_token() {
		// Get the transfer token.
		$transfer_token = get_option( 'siteground_migrator_transfer_token' );

		// Parse the token and retrieve the `transfer_id` and `transfer_psk`.
		$parse_result = preg_match( '~(\d{10}-\w{16})-(\w{16})~', $transfer_token, $matches );

		// Bail if there are no matches.
		if ( empty( $parse_result ) ) {
			$this->log_error( 'Error parsing transfer token. Please, make sure it\'s valid!' );
			return false;
		}

		// Set transfer id.
		if ( ! empty( $matches[1] ) ) {
			$this->log_info( 'Updating transfer id.' );
			update_option( 'siteground_migrator_transfer_id', $matches[1] );
		}

		// Set transfer psk.
		if ( ! empty( $matches[2] ) ) {
			$this->log_info( 'Updating transfer psk.' );
			update_option( 'siteground_migrator_transfer_psk', $matches[2] );
		}

		return true;
	}

	/**
	 * Verify the the request is made from SiteGroud
	 * server and has all required params.
	 *
	 * @param string $key Authentication key.
	 *
	 * @return bool True on success.
	 *
	 * @since  1.0.0
	 */
	public function authenticate( $key ) {
		// Bail if any of required parameters is missing.
		if (
			empty( $_GET['transfer_id'] ) ||
			empty( $_GET['ts'] ) ||
			empty( $_GET['auth'] )
		) {
			$this->log_die( '`transfer_id`, `ts` & `auth` parameters are required.' );
		}

		// Get the time diff between current timestamp and `ts` param.
		$time_diff = time() - sanitize_text_field( wp_unslash( $_GET['ts'] ) );

		// Bail if the transfer timestamp is not valid.
		if (
			! is_int( $time_diff ) ||
			$time_diff < 0 ||
			$time_diff > self::MAX_TIME_DIFF
		) {
			$this->log_die( 'Transfer ts is invalid.' );
		}

		// Get `transfer_id`.
		$transfer_id = get_option( 'siteground_migrator_transfer_id' );

		// Bail if the transfer id is not valid.
		if ( $transfer_id !== $_GET['transfer_id'] ) {
			$this->log_die( 'Transfer id is invalid.' );
		}

		// Generate authentication token.
		$auth = sha1( $transfer_id . '-' . $key . '-' . get_option( 'siteground_migrator_transfer_psk' ) . '-' . $_GET['ts'] ); // input var ok; sanitization ok.

		// Bail if the auth param doens't exists or if the auth is not valid.
		if ( $auth !== $_GET['auth'] ) {
			$this->log_die( 'Authentication doesn\'t match.' );
		}

		return true;
	}

	/**
	 * Send json success which means the plugin is installed.
	 *
	 * @since  1.0.0.
	 */
	public function is_plugin_installed() {
		wp_send_json_success( array( 'siteground_migrator' => true ) );
	}

}
