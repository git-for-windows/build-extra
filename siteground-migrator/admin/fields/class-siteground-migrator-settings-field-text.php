<?php
/**
 * The text settings field.
 *
 * @link       https://www.siteground.com
 * @since      1.0.0
 *
 * @package    Siteground_Migrator_Settings_Field_Text
 * @subpackage Siteground_Migrator/admin
 */

/**
 * The settings field class.
 *
 * @package    Siteground_Migrator_Settings_Field_Text
 * @subpackage Siteground_Migrator/admin
 * @author     SiteGround <hristo.p@siteground.com>
 */
class Siteground_Migrator_Settings_Field_Text extends Siteground_Migrator_Settings_Field {

	/**
	 * Render this field.
	 *
	 * @since 1.0.0
	 */
	public function render() {
		include __DIR__ . '/../partials/field-text.php';
	}

}
