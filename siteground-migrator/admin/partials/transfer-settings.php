<?php $progress = get_option( 'siteground_migrator_progress', 100 ); ?>

<div class="container container--padding-none container--elevation-1 create-box container--progress">
	<div class="flex flex--gutter-xx-large flex--margin-medium">
		<div class="loader">
			
			<div class="icon-x">
				<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 15.56 15.56">
					<rect x="-2.21" y="6.79" width="20" height="2" fill= "#fff" transform="translate(7.78 -3.24) rotate(45)"/>
					<rect x="-2.21" y="6.79" width="20" height="2" fill= "#fff" transform="translate(18.79 7.78) rotate(135)"/>
				</svg>
			</div>
			
			<div class="loader-spinner"></div>
			
			<h2 class="title-migration title title--density-comfortable title--level-3 typography typography--weight-regular with-color with-color--color-darkest title--density-none"><?php esc_html_e( 'Website Migration in Progress', 'siteground-migrator' ); ?></h2>
			
			<p class="title--status text text--size-medium typography typography--weight-regular with-color with-color--color-darkest"><?php echo ! empty( $status['message'] ) ? $status['message'] : 'Transfer started'; ?></p>

			<div class="progress">
				<div class="progress__indicator progress__indicator--color-blue" style="transform: translateX(-<?php echo $progress; ?>%);"></div>
			</div>
			
			<button class="btn btn--dark btn--x-large btn__cancel__confirmation" type="button" data-e2e="create-box-submit" data-restart="false">
				<span class="btn__content btn__loader">
					<span class="btn__text"><?php esc_html_e( 'Cancel Transfer', 'siteground-migrator' ); ?></span>
				</span>
			</button>
		</div>

		<div class="settings">
			<p class="text text--size-medium typography typography--weight-regular with-color with-color--color-darkest">
				<?php printf(__( 'To initiate the transfer you will need to provide your transfer token. It can be generated through the <strong>WordPress Migrator</strong> tool in your SiteGround control panel. You can check out this <a href="%s" target="_blank">tutorial</a> if you need more detailed instructions.', 'siteground-migrator' ), 'https://my.siteground.com/support/tutorials/wordpress/wordpress-automatic-migrator' ); ?>
			</p>

			<form class="sg-wp-migrator-options-form form">
				<?php wp_nonce_field( 'siteground_migrator_options', 'siteground_migrator_update_options' ); ?>
				
				<input type="hidden" name="action" value="update_option_siteground_migrator_transfer_token">
			
				<label id="field-label">
					<?php esc_html_e( 'Migration Token', 'siteground-migrator' ); ?>

					<span class="field-wrapper field-wrapper--large field-wrapper--has-label">
						<?php do_settings_fields( Siteground_Migrator_Settings::PAGE_SLUG, Siteground_Migrator_Settings::PAGE_SLUG ); ?>
					</span>

					<span class="validation validation--error validation--required">
						<?php esc_html_e( 'This field is required', 'siteground-migrator' ); ?>
					</span>

					<span class="validation validation--error validation--pattern">
						<?php esc_html_e( 'Token doesn\'t match requested format.', 'siteground-migrator' ); ?>
					</span>
				</label>

				<label class="checkbox checkbox--medium checkbox--align-center field-label">
					<input type="checkbox" class="checkbox__input hidden" name="siteground_migrator_send_email_notification" checked>
					<span class="icon icon--use-current-color with-color checkbox__icon">
						<svg viewBox="0 0 32 32">
							<polygon class="st0" points="27,3.7 12.4,18 5,10.5 0,15.5 10,25.8 12.4,28.3 32,8.7 "></polygon>
						</svg>
					</span>
					<span id="checkbox__label_email">
						<span class="checkbox-label-text"><?php _e( 'Send notification email when migration is over to ', 'siteground-migrator' ); ?></span>
						<span class="field-wrapper field-wrapper--small">
							<input type="email" class="field" name="siteground_migrator_email_recipient" required pattern="^[\w._%+-]+@[\w.-]+\.[\w]{2,12}$" value="<?php echo get_option( 'admin_email' ) ?>"/>
							<span class="validation validation--error validation--required">
								<?php esc_html_e( 'This field is required', 'siteground-migrator' ); ?>
							</span>

							<span class="validation validation--error validation--pattern">
								<?php esc_html_e( 'Email doesn\'t match requested format.', 'siteground-migrator' ); ?>
							</span>
						</span>
					</span>
				</label>

				<button class="btn btn--primary btn--x-large" type="submit" data-e2e="create-box-submit">
					<span class="btn__content">
						<span class="btn__text">
							<?php esc_html_e( 'Initiate Transfer', 'siteground-migrator' ); ?>
						</span>
					</span>
				</button>
			</form>
		</div>

	</div>
</div>
