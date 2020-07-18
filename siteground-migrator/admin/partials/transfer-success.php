<div class="container container--padding-xx-large container--elevation-1 thank-you thank-you--success">
	<div class="flex flex--align-center flex--gutter-none flex--direction-column flex--margin-none">
		<div class="thank-you-icon-background">
			<div class="thank-you-icon-wrapper">
				<span class="icon icon--use-current-color icon--presized with-color thank-you-icon" style="width: 40px; height: 40px;">
				   <svg viewBox="0 0 32 32" width="40" height="40">
					  <polygon points="27,3.7 12.4,18 5,10.5 0,15.5 10,25.8 12.4,28.3 32,8.7 "></polygon>
				   </svg>
				</span>
			</div>
		</div>
		<h1 class="title title--density-comfortable title--level-1 typography typography--align-center typography--weight-light with-color with-color--color-darker thank-you-title">
				<?php esc_html_e( 'Transfer Completed Successfully!', 'siteground-migrator' ); ?>
		</h1>
		<p class="text text--size-large typography typography--align-center typography--weight-regular with-color with-color--color-dark thank-you-description">
			<?php esc_html_e( 'Your WordPress has been migrated. We’ve created a temporary URL that will be valid for 48 hours to check your site on the new location. If everything looks good, you can point your domain to our servers.', 'siteground-migrator' ); ?>
		</p>
	</div>

	<?php include 'new-site-setup-info.php'; ?>

	<p class="typography typography--align-center"><a href="#" class="btn__cancel btn__new_transfer"><?php echo __( 'Initiate New Transfer', 'siteground-migrator' ) ?></a></p>
</div>
