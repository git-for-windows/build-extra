<?php
/**
 * The settings field.
 *
 * @link       https://www.siteground.com
 * @since      1.0.0
 *
 * @package    Siteground_Migrator_Settings_Field
 * @subpackage Siteground_Migrator/admin
 */

/**
 * The settings field class.
 *
 * @package    Siteground_Migrator_Settings_Field
 * @subpackage Siteground_Migrator/admin
 * @author     SiteGround <hristo.p@siteground.com>
 */
abstract class Siteground_Migrator_Settings_Field {
	/**
	 * The title of the field.
	 *
	 * @since 1.0.0
	 *
	 * @var string $title The title of the field.
	 */
	protected $title;

	/**
	 * The field unique id.
	 *
	 * @since 1.0.0
	 *
	 * @var string $id The id of the field.
	 */
	protected $id;

	/**
	 * The field additional args.
	 *
	 * @since 1.0.0
	 *
	 * @var array $args The field additional args.
	 */
	protected $args;

	/**
	 * Constructor.
	 *
	 * Register an administration settings field.
	 *
	 * @since 1.0.0
	 *
	 * @param string $id The ID of the field.
	 * @param string $title The title of the field.
	 * @param string $section The name of the section.
	 * @param array  $args Additional args.
	 */
	public function __construct( $id, $title, $section = '', $args = array() ) {

		$this->title = $title;
		$this->id    = $id;
		$this->args  = $args;

		add_settings_field(
			$id,
			$title,
			array( $this, 'render' ),
			Siteground_Migrator_Settings::PAGE_SLUG,
			$section,
			$args
		);

		register_setting( Siteground_Migrator_Settings::PAGE_SLUG, $id );
	}

	/**
	 * Register a new administration settings field of a certain type.
	 *
	 * @since 1.0.0
	 *
	 * @param string $type Type of the field.
	 * @param string $id The ID of the field.
	 * @param string $title The title of the field.
	 * @param string $section The name of the section.
	 * @param array  $args Additional args.
	 *
	 * @return Siteground_Migrator_Settings_Field $field
	 */
	public static function factory( $type, $id, $title, $section = '', $args = array() ) {

		// Build the class name.
		$class_name = __CLASS__ . '_' . ucwords( $type );

		// Throw an exception if the class doesn't exists.
		if ( ! class_exists( $class_name ) ) {
			throw new Exception( 'Unknown settings field type "' . $type . '".' );
		}

		$field = new $class_name( $id, $title, $section, $args );

		return $field;
	}

	/**
	 * Retrieve the field title.
	 *
	 * @access public
	 *
	 * @return string $title The title of this field.
	 */
	public function get_title() {
		return $this->title;
	}

	/**
	 * Retrieve the field ID.
	 *
	 * @access public
	 *
	 * @return string $id The ID of this field.
	 */
	public function get_id() {
		return $this->id;
	}

	/**
	 * Render help text under the field.
	 *
	 * @since  1.0.0
	 */
	public function render_help() {
		if ( ! empty( $this->args['help_text'] ) ) {
			echo wp_kses(
				wpautop( $this->args['help_text'] ),
				array(
					'p' => array(),
				)
			);
		}
	}

	public function add_pattern() {
		return sprintf( 'pattern="%s"', $this->args['pattern']);
	}

	public function get_class_names() {
		return $this->args['class_names'];
	}

	public function is_required() {
		if ( true === $this->args['required'] ) {
			return 'required="required"';
		}	
	}

	/**
	 * Retrieve the value of a field.
	 *
	 * @since  1.0.0
	 */
	protected function get_value() {
		return get_option( $this->get_id() );
	}

	/**
	 * Render this field.
	 *
	 * @since 1.0.0
	 */
	abstract public function render();

}
