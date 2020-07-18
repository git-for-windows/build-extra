<?php
/**
 * The file that defines the class that log running processes in custom log file.
 *
 * @link       https://www.siteground.com
 * @since      1.0.0
 *
 * @package    SiteGround_Migrator
 * @subpackage SiteGround_Migrator/includes
 */

/**
 * The log service class.
 *
 * @since      1.0.0
 * @package    SiteGround_Migrator
 * @subpackage SiteGround_Migrator/includes
 * @author     SiteGround <hristo.p@siteground.com>
 */
trait Siteground_Migrator_Log_Service {
	/**
	 * Log a message.
	 *
	 * @since 1.0.0
	 *
	 * @param string $level   The log level.
	 * @param string $message The message to log.
	 */
	public function log( $level, $message ) {
		// Finally log the message.
		error_log(
			sprintf(
				"[%s] %s: %s \n",
				date( 'd-M-Y H:i:s e' ),
				$level,
				is_array( $message ) ? implode( ', ', $message ) : $message
			),
			3,
			WP_CONTENT_DIR . '/siteground-migrator.log'
		);
	}

	/**
	 * Logs an error message to custom log file.
	 *
	 * @since  1.0.0
	 *
	 * @param  string|array $message Error message/messages.
	 */
	public function log_error( $message ) {
		$this->log( 'ERROR', $message );
	}

	/**
	 * Logs an info message to custom log file.
	 *
	 * @since  1.0.0
	 *
	 * @param  string|array $message Error message/messages.
	 */
	public function log_info( $message ) {
		$this->log( 'INFO', $message );
	}

	/**
	 * Write to custom log and prevent execution of other code.
	 *
	 * @since  1.0.0
	 *
	 * @param  string|array $message Error message/messages.
	 */
	public function log_die( $message ) {
		$this->log( 'ERROR', $message );

		// translators: `$message` the error message that will be displayed.
		wp_die( $message, '', array( 'response' => 400 ) ); // phpcs:ignore WordPress.XSS.EscapeOutput
	}

}
