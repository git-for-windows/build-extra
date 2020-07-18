<?php
/**
 * Provide a admin area view for the plugin
 *
 * This file is used to markup the admin-facing aspects of the plugin.
 *
 * @link       https://www.siteground.com
 * @since      1.0.0
 *
 * @package    SG_WP_Migrator
 * @subpackage SG_WP_Migrator/admin/partials
 */

$status = get_option( 'siteground_migrator_transfer_status' );
?>
<div id="section--transfer-status" class="<?php echo esc_attr( ! empty( $status ) ? 'section--status-' . $status['status'] : '' ); ?>">
	<div class="section section--density-cozy section--content-size-default">
		<div class="section__content">

			<h1 class="title title--density-comfortable title--level-1 typography typography--weight-light with-color with-color--color-darkest">
				<?php echo esc_html( self::get_page_title() ); ?>
			</h1>

			<?php
			include 'transfer-success-warnings.php';
			include 'transfer-fail.php';
			include 'transfer-success.php';
			include 'transfer-settings.php';
			?>
		</div>
	</div>
</div>

<?php
include 'cancel-transfer-confirmation.php';
