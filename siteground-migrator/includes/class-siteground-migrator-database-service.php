<?php
/**
 * The file that defines the class that is responsible for all processes regarding database.
 *
 * @link       https://www.siteground.com
 * @since      1.0.0
 *
 * @package    SiteGround_Migrator
 * @subpackage SiteGround_Migrator/includes
 */

/**
 * The database class.
 *
 * Provides tools to retrieve information about the size of database and exporting database tables.
 *
 * @since      1.0.0
 * @package    SiteGround_Migrator
 * @subpackage SiteGround_Migrator/includes
 * @author     SiteGround <hristo.p@siteground.com>
 */
class Siteground_Migrator_Database_Service {

	use Siteground_Migrator_Log_Service;

	/**
	 * A Siteground_Migrator_Files_Service instance.
	 *
	 * @var Siteground_Migrator_Files_Service object
	 *
	 * @since 1.0.0
	 */
	private $files_service;

	/**
	 * The constructor
	 *
	 * @param \Siteground_Migrator_Files_Service $files_service The {@link Siteground_Migrator_Files_Service} instance.
	 *
	 * @since 1.0.0
	 */
	public function __construct( $files_service ) {
		// Init the `Siteground_Migrator_Files_Service`.
		$this->files_service = $files_service;
	}

	/**
	 * Retrieve information about the tabels
	 * in database and the size of each one.
	 *
	 * @since  1.0.0
	 *
	 * @return array $tables The tables in database and their size.
	 */
	private function get_tables() {
		// Load the global `wpdb`.
		global $wpdb;

		// Get the tables information.
		$tables = $wpdb->get_results(
			$wpdb->prepare(
				"
				SELECT
					table_name AS 'table_name',
					ROUND( ( data_length + index_length ), 2 ) AS 'size'
				FROM information_schema.TABLES
				WHERE table_schema = %s
				AND table_name LIKE %s
				",
				DB_NAME,
				$wpdb->prefix . '%'
			)
		); // WPCS: cache ok.

		// Return the tables info.
		return $tables;
	}

	/**
	 * Create a dump for each table in database.
	 *
	 * @since  1.0.0
	 */
	public function export_database() {
		// Set the initial status to `in progress`.
		$response = array(
			'title'  => esc_html__( 'Database successfully compressed. Creating transfer manifest...', 'siteground-migrator' ),
			'status' => 1,
		);

		// Loop through all tables and create a dump for each one.
		foreach ( $this->get_tables() as $table ) {
			// Export the table.
			$result = $this->export_and_encrypt_table( $table->table_name );

			// Stop if table export fails and continue with next one.
			// Additionally set the status to failed.
			if ( 0 !== $result ) {
				$response['status'] = 0;
				continue;
			}
		}

		// Generate response message using the status.
		if ( 0 === $response['status'] ) {
			$response['title']       = esc_html__( 'Transfer Failed Due To Database Error!', 'siteground-migrator' );
			$response['description'] = __( 'The most common reason for such failure is if you have a large table or database that cannot be dumped for the purposes of this migration. If that is the case you may not be able to use the auto-migrator. If you believe the problem is elsewhere, such as temporary MySQL connectivity issue, you may <a href="#" class="link">restart the transfer</a>.', 'siteground-migrator' );
		}

		return $response;
	}

	/**
	 * Export and encypt mysql table.
	 *
	 * @since  1.0.0
	 *
	 * @param  string $table_name   The name of the table to export.
	 *
	 * @return bool   $status       True on failure, false on success.
	 */
	private function export_and_encrypt_table( $table_name ) {
		$filename = Siteground_Migrator_Directory_Service::get_temp_directory_path() . '/sql/' . $table_name . '.txt';

		// Try to dump database.
		try {
			$dumper = Shuttle_Dumper::create(array(
				'host'           => DB_HOST,
				'username'       => DB_USER,
				'password'       => DB_PASSWORD,
				'db_name'        => DB_NAME,
				'include_tables' => array(
					$table_name,
				),
			));

			// Dump the database to plain text file.
			$dumper->dump( $filename );
		} catch ( Exception $e ) {
			// translators: The table name that failed to be exported.
			$this->log_error( sprintf( 'Couldn\'t dump table: %s', $e->getMessage() ) );
			// Return the status.
			return 1;
		}

		// Encrypt the dump file and detele the original one.
		$encryption_result = $this->files_service->encrypt_and_delete_original( $filename );

		// Check if the encryption was successfull.
		if ( false === $encryption_result ) {
			// translators: The filename of mysql dump.
			$this->log_error( sprintf( 'Error encrypting database: %s', $filename ) );
			return 1;
		}

		// Return false on success, which means that there were no errors.
		return 0;
	}

	/**
	 * Return the size of current WordPress database.
	 *
	 * @since  1.0.0
	 *
	 * @return mixed False on failure, the database size on success.
	 */
	public static function get_database_size() {
		// Load the global `$wpdb`.
		global $wpdb;

		// Get the size of database.
		$response = $wpdb->get_results(
			$wpdb->prepare(
				"SELECT
					sum( data_length + index_length ) AS 'size'
				FROM information_schema.TABLES
				WHERE table_schema = %s
				AND table_name LIKE %s
				",
				DB_NAME,
				'%' . $wpdb->prefix . '%'
			)
		); // WPCS: cache ok.

		// Log an error if the size is not properly calculated.
		if ( empty( $response[0]->size ) ) {
			$this->log_error( 'Error calculating database size.' );
		}

		return $response[0]->size;
	}
}
