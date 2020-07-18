<?php
/**
 * Provides functionallity to fire off non-blocking asynchronous requests as a background processes.
 *
 * @link       https://www.siteground.com
 * @since      1.0.0
 *
 * @package    Siteground_Migrator
 * @subpackage Siteground_Migrator/includes
 */

/**
 * Provides functionallity to fire off non-blocking asynchronous requests as a background processes.
 *
 * @since      1.0.0
 * @package    Siteground_Migrator
 * @subpackage Siteground_Migrator/includes
 * @author     SiteGround <hristo.p@siteground.com>
 */
class Siteground_Migrator_Background_Process extends Siteground_WP_Background_Process {

	use Siteground_Migrator_Log_Service;

	/**
	 * Action.
	 *
	 * @var string
	 *
	 * @since 1.0.0
	 */
	protected $action = 'background_process';

	/**
	 * Task
	 *
	 * @param array $item Array containing the class and the
	 *                    method to call in background process.
	 *
	 * @return mixed      False on process success.
	 *                    The current item on failure, which will restart the process.
	 */
	protected function task( $item ) {
		$status = get_option( 'siteground_migrator_transfer_status' );

		// Cancel the transfer if any of the previous processes has failed.
		if ( 0 === $status['status'] ) {
			Siteground_Migrator_Transfer_Service::get_instance()->transfer_cancelled( false );
			return false;
		}

		$attempts = intval( $item['attempts'] );

		for ( $i = 0; $i <= $attempts; $i++ ) {
			// Call the class method.
			$result = call_user_func( array( $item['class'], $item['method'] ) );

			// @todo: fina a way to improve this ugly condition.
			if (
				1 === $result['status'] ||
				2 === $result['status'] ||
				$i === $attempts ||
				isset( $result['skip_retrying'] )
			) {
				Siteground_Migrator_Transfer_Service::update_status(
					$result['title'],
					$result['status'],
					isset( $result['description'] ) ? $result['description'] : ''
				);

				Siteground_Migrator_Transfer_Service::get_instance()->update_transfer_progress( 6 );

				return false;
			}

			$this->log_error( sprintf( 'Process failed : %s. Retrying...', $item['method'] ) );
		}

		// Remove the process from queue.
		return false;
	}

	/**
	 * Complete.
	 *
	 * @since 1.0.0
	 */
	protected function complete() {
		parent::complete();
	}

}
