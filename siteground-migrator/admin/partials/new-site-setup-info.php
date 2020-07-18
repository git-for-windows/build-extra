<?php
$temp_url    = ! empty( $status['temp_url'] ) ? $status['temp_url'] : '';
$dns_servers = ! empty( $status['dns_servers'] ) ? $status['dns_servers'] : array();
?>
<div class="flex flex--gutter-medium flex--margin-medium new-site-info hidden">
	<div class="box box--direction-row box--sm-6 box--flex box--temp-url ua-margin-top-medium <?php echo empty( $temp_url ) ? 'hidden' : ''; ?>">
		<div class="border-box ua-flex-grow">
			<span class="icon icon--presized with-color border-box__icon" style="width: 72px; height: 72px;">
				<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96"><rect width="96" height="95.956" fill="#fff" opacity="0"/><rect x="40.325" y="37.507" width="37.07" height="19.61" fill="#e3f4f9"/><rect x="2.833" y="30.211" width="29.327" height="50.131" fill="#e3f4f9"/><rect x="2.803" y="14.998" width="90.306" height="15.212" fill="#e3f4f9"/><path d="M93.109,14H2.8a1,1,0,0,0-1,1V80.341a1,1,0,0,0,1,1H93.109a1,1,0,0,0,1-1V15A1,1,0,0,0,93.109,14Zm-1,2V29.21H3.8V16ZM3.8,31.21H31.16V79.341H3.8ZM33.16,79.341V31.21H92.109V79.341Z" fill="#256e7a"/><path d="M77.4,58.117H40.325a1,1,0,0,1-1-1V37.507a1,1,0,0,1,1-1H77.4a1,1,0,0,1,1,1v19.61A1,1,0,0,1,77.4,58.117Zm-36.071-2H76.4V38.507H41.325Z" fill="#256e7a"/><path d="M77.4,65.966H40.325a1,1,0,0,1,0-2H77.4a1,1,0,1,1,0,2Z" fill="#256e7a"/></svg>
			</span>
			<div class="ua-margin-bottom-medium">
				<h3 class="title title--density-none title--level-4 typography typography--align-center typography--weight-bold with-color with-color--color-darker">
					<?php esc_html_e( 'Check Site', 'siteground-migrator' ); ?>
				</h3>

				<p class="text text--size-medium typography typography--weight-regular with-color with-color--color-dark">
					<?php esc_html_e( 'We’ve provided a temporary URL for you to check your site before pointing your nameservers to SiteGround. Мake sure everything is working fine before pointing your domain.', 'siteground-migrator' ); ?>
				</p>
			</div>
			<a href="<?php echo $temp_url; ?>" class="btn btn--temp-url btn--secondary btn--large btn--outlined ua-margin-top-auto" target="_blank"><span class="btn__content"><span class="btn__text"><?php esc_html_e( 'Go to Site', 'siteground-migrator' ) ?></span></span></a>
		</div>
	</div>

	<div class="box box--direction-row box--dns-servers box--sm-6 box--flex ua-margin-top-medium <?php echo empty( $dns_servers ) ? 'hidden' : ''; ?>">
		<div class="border-box ua-flex-grow">
			<span class="icon icon--presized with-color border-box__icon" style="width: 72px; height: 72px;">
				<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96"><rect width="96" height="96" fill="#fff" opacity="0"/><polygon points="74.246 8.766 67.531 15.427 8 15.399 8.083 87.234 80.083 87.234 80 30.381 88 22.399 74.246 8.766" fill="#ecf3da"/><path d="M89,22.4a1,1,0,0,0-.3-.708L74.95,8.056a1,1,0,0,0-1.41,0l-5.6,5.585-.81.784L8,14.4a1,1,0,0,0-1,1l.082,71.834a1,1,0,0,0,1,1h72a1,1,0,0,0,1-1L81,30.813l7.706-7.706A1,1,0,0,0,89,22.4Zm-9.653,7.24a1,1,0,0,0-.092.092L55.442,53.54,41,55.6l.065-.476c0-.007,0-.012,0-.019v0L42.8,42.509a.969.969,0,0,0,.1-.42,1.012,1.012,0,0,0-.024-.122l.084-.611L68.933,15.473,81.283,27.7Zm-.266,56.6h-70L9,16.4l56.142.026L41.31,40.177a1,1,0,0,0-.285.572l-.046.34H19.142a1,1,0,1,0,0,2H40.7L39.189,54.108H19.142a1,1,0,0,0,0,2H38.914l-.074.537a1,1,0,0,0,.99,1.136.978.978,0,0,0,.142-.01l16.084-2.3a1,1,0,0,0,.565-.283L79,32.809ZM82.7,26.288,70.349,14.061l3.9-3.885L86.583,22.4Z" fill="#567635"/><path d="M18.142,67.273a1,1,0,0,0,1,1H69.221a1,1,0,0,0,0-2H19.142A1,1,0,0,0,18.142,67.273Z" fill="#567635"/></svg>
			</span>
			<div class="ua-margin-bottom-medium">
				<h3 class="title title--density-none title--level-4 typography typography--align-center typography--weight-bold with-color with-color--color-darker"><?php esc_html_e( 'Update Your DNS', 'siteground-migrator' ); ?></h3>
				<p class="text text--size-medium typography typography--weight-regular with-color with-color--color-dark"><?php esc_html_e( 'Please change your domain’s NS. Note that those changes require up to 48 hours of propagation time. Don’t modify your site during that period to avoid data loss.', 'siteground-migrator' ); ?></p>
			</div>

			<div class="dns_servers">
				<?php
				foreach ( $dns_servers as $counter => $server ) :
					// Bail if the dns server is empty.
					if ( empty( $server ) ) {
						continue;
					}
				?>
					<h4 class="title title--density-compact title--level-5 typography typography--align-center typography--weight-light with-color with-color--color-darker">NS<?php echo $counter + 1; ?>: <a class="link"><?php echo esc_html( $server ); ?></a></h4>
				<?php endforeach ?>
			</div>
		</div>
	</div>

    <div class="box box--direction-row box--sm-12 box--flex box--temp-url ua-margin-top-medium">
        <div class="border-box ua-flex-grow">
            <div class="ua-margin-bottom-medium">
                <h3 class="title title--density-none title--level-4 typography typography--align-center typography--weight-bold with-color with-color--color-darker"><?php echo esc_html__( 'That went smoothly, right?', 'siteground-migrator' ) ?></h3>
                <p class="text text--size-medium typography typography--weight-regular with-color with-color--color-dark">
                    <a href="https://wordpress.org/support/plugin/siteground-migrator/reviews/#new-post" target="_blank" class="link"><?php echo esc_html__( 'Help us help other people by rating this plugin on WP.org!', 'siteground-migrator' ) ?></a>
                </p>
            </div>
            <a href="https://wordpress.org/support/plugin/siteground-migrator/reviews/#new-post" target="_blank" class="link">
                <span class="icon icon--presized with-color border-box__icon icon--rating">
                    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 22 21">
                        <path fill="#25b8d2" d="M11,18l5.2,2.866a1.244,1.244,0,0,0,1.77-1.382L17,13l4.552-3.371a1.243,1.243,0,0,0-.494-2.161L15,6,12.079.626a1.243,1.243,0,0,0-2.158,0L7,6,.942,7.468A1.243,1.243,0,0,0,.448,9.629L5,13l-.969,6.484A1.244,1.244,0,0,0,5.8,20.866Z"></path>
                    </svg>
                </span>
                <span class="icon icon--presized with-color border-box__icon icon--rating">
                    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 22 21">
                        <path fill="#25b8d2" d="M11,18l5.2,2.866a1.244,1.244,0,0,0,1.77-1.382L17,13l4.552-3.371a1.243,1.243,0,0,0-.494-2.161L15,6,12.079.626a1.243,1.243,0,0,0-2.158,0L7,6,.942,7.468A1.243,1.243,0,0,0,.448,9.629L5,13l-.969,6.484A1.244,1.244,0,0,0,5.8,20.866Z"></path>
                    </svg>
                </span>
                <span class="icon icon--presized with-color border-box__icon icon--rating">
                    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 22 21">
                        <path fill="#25b8d2" d="M11,18l5.2,2.866a1.244,1.244,0,0,0,1.77-1.382L17,13l4.552-3.371a1.243,1.243,0,0,0-.494-2.161L15,6,12.079.626a1.243,1.243,0,0,0-2.158,0L7,6,.942,7.468A1.243,1.243,0,0,0,.448,9.629L5,13l-.969,6.484A1.244,1.244,0,0,0,5.8,20.866Z"></path>
                    </svg>
                </span>
                <span class="icon icon--presized with-color border-box__icon icon--rating">
                    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 22 21">
                        <path fill="#25b8d2" d="M11,18l5.2,2.866a1.244,1.244,0,0,0,1.77-1.382L17,13l4.552-3.371a1.243,1.243,0,0,0-.494-2.161L15,6,12.079.626a1.243,1.243,0,0,0-2.158,0L7,6,.942,7.468A1.243,1.243,0,0,0,.448,9.629L5,13l-.969,6.484A1.244,1.244,0,0,0,5.8,20.866Z"></path>
                    </svg>
                </span>
                <span class="icon icon--presized with-color border-box__icon icon--rating">
                    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 22 21">
                        <path fill="#25b8d2" d="M11,18l5.2,2.866a1.244,1.244,0,0,0,1.77-1.382L17,13l4.552-3.371a1.243,1.243,0,0,0-.494-2.161L15,6,12.079.626a1.243,1.243,0,0,0-2.158,0L7,6,.942,7.468A1.243,1.243,0,0,0,.448,9.629L5,13l-.969,6.484A1.244,1.244,0,0,0,5.8,20.866Z"></path>
                    </svg>
                </span>
            </a>
        </div>
    </div>

</div>