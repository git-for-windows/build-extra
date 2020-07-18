<?php
	/**
	 * SiteGround Migrator command.
	 *
	 * ## OPTIONS
	 *
	 * <token>
	 * : Transfer token.
	 *
	 * [--email=<email>]
	 * : Email address.
	 */
function migrator_command( $args, $assoc_args ) {
	// Post args.
	$args = array(
		'siteground_migrator_transfer_token' => $args[0],
		'siteground_migrator_update_options' => wp_create_nonce( 'siteground_migrator_options' ),
	);

	// Check for email args.
	if ( ! empty( $assoc_args['email'] ) ) {
		// Bail if the provided email is invalid.
		if ( ! filter_var( $assoc_args['email'], FILTER_VALIDATE_EMAIL ) ) {
			WP_CLI::error( 'Please enter valid email address.' );
		}

		// Add the email args if the email is ok.
		$args['siteground_migrator_send_email_notification'] = 'on';
		$args['siteground_migrator_email_recipient']         = $assoc_args['email'];
	}

	// Make the request to init the transfer.
	$response = wp_remote_post(
		admin_url( 'admin-ajax.php?action=update_option_siteground_migrator_transfer_token' ),
		array(
			'method' => 'POST',
			'body'   => $args,
		)
	);

	if (
		200 !== wp_remote_retrieve_response_code( $response ) ||
		is_wp_error( $response )
	) {
		WP_CLI::error( esc_html__( 'Can not initiate the transfer.', 'siteground-migrator' ) );
	}

	// Wait for option to be updated.
	sleep( 1 );

	// Get the status after the request completes.
	$status = get_option( 'siteground_migrator_transfer_status' );

	if ( false === $status ) {
		WP_CLI::error( esc_html__( 'Can not initiate the transfer.' , 'siteground-migrator' ));	
	}

	switch ( $status['status'] ) {
		// Show the error if the status is 0.
		case 0:
			WP_CLI::error( $status['message'] . '. ' . $status['description'] );
			break;

		case 5:
			Siteground_Migrator_Transfer_Service::get_instance()->transfer_continue();
			WP_CLI::success( esc_html__( 'Transfer started. Creating archives of files...', 'siteground-migrator' ) );
			break;

		default:
			// Show success message.
			WP_CLI::success( $status['message'] . '. ' . $status['description'] );
			break;
	}
}

if ( class_exists( 'WP_CLI' ) ) {
	WP_CLI::add_command( 'migrator start', 'migrator_command' );
}