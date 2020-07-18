<div class="container container--padding-xx-large container--elevation-1 thank-you thank-you--fail">
	<div class="flex flex--align-center flex--gutter-none flex--direction-column flex--margin-none">
		<div class="thank-you-icon-background">
			<div class="thank-you-icon-wrapper">
				<span class="icon icon--use-current-color icon--presized with-color thank-you-icon" style="width: 32px; height: 32px;">
				<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 15.56 15.56">
					<rect x="-2.21" y="6.79" width="20" height="2" fill= "#f54545" transform="translate(7.78 -3.24) rotate(45)"/>
					<rect x="-2.21" y="6.79" width="20" height="2" fill= "#f54545" transform="translate(18.79 7.78) rotate(135)"/>
				</svg>
				</span>
			</div>
		</div>
		<h1 class="title title--status title--density-comfortable title--level-1 typography typography--align-center typography--weight-light with-color with-color--color-darker thank-you-title"><?php echo $status['message']; ?></h1>
		<p class="text text--description text--size-large typography typography--align-center typography--weight-regular with-color with-color--color-dark thank-you-description">
			<?php
			if ( ! empty( $status['description'] ) ) {
				echo $status['description'];
			}
			?>
		</p>

		<p><a href="#" class="btn__cancel"><?php echo __( 'Initiate New Transfer', 'siteground-migrator' ) ?></a></p>

	</div>
</div>