<input
	name="<?php echo esc_attr( $this->get_id() ); ?>"
	id="<?php echo esc_attr( $this->get_id() ); ?>"
	type="text"
	value="<?php echo esc_attr( $this->get_value() ); ?>"
	class="<?php echo esc_attr( $this->get_class_names() ) ?>"
	<?php echo $this->add_pattern() ?>
	<?php echo $this->is_required() ?>
/>
