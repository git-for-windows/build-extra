<div class="dialog-wrapper">
	<div class="dialog dialog--align-center dialog--size-medium dialog--density-medium dialog--state-inactive">
		<div class="dialog__header">
			<div class="dialog__icon hide-on-mobile">
				<span class="icon icon--use-current-color icon--presized with-color" style="width: 25px; height: 25px;">
				   <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 15.56 15.56">
					<rect x="-2.21" y="6.79" width="20" height="2" fill= "#fff" transform="translate(7.78 -3.24) rotate(45)"/>
					<rect x="-2.21" y="6.79" width="20" height="2" fill= "#fff" transform="translate(18.79 7.78) rotate(135)"/>
				</svg>
				</span>
			</div>
			<h3 class="title title--density-airy title--level-3 typography typography--align-center typography--weight-regular with-color with-color--color-darkest dialog__title"><?php _e( 'Are you sure you want to cancel the transfer?', 'siteground-migrator' ) ?></h3>
		</div>
		<div class="dialog__content"></div>
		<div class="toolbar toolbar--background-light toolbar--density-comfortable toolbar--align-baseline dialog__toolbar">
			<div>
				<button class="btn btn--primary btn--medium btn__resume" type="submit" data-e2e="dialog-submit">
					<?php _e( 'Continue', 'siteground-migrator' ) ?>
				</button>
				<button class="btn btn--neutral btn--medium btn__cancel" type="submit">
					<?php _e( 'Cancel Transfer', 'siteground-migrator' ) ?>
				</button>
			</div>
		</div>
	</div>
</div>