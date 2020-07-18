/*global ajaxurl*/
(function( $ ) {
	$( document ).ready(function() {
		// Update the status every 5 seconds while the transfer is in progress.
		if ( $( '.section--status-1' ).length ) {
			updateStatus();
		}

		var tokenInput = $("input[name=siteground_migrator_transfer_token]")[0];
		var emailInput = $("input[name=siteground_migrator_email_recipient]")[0];

		$('input[name=siteground_migrator_email_recipient]'). on( 'click', function (e) {
			e.preventDefault();
			e.stopPropagation();
		} )

		// Validate migration token on keyup.
		tokenInput.addEventListener('keyup', validateToken );
		emailInput.addEventListener('keyup', validateEmail );

		// Validate and show custom error message when the migration token is not set.
		tokenInput.addEventListener('invalid', function (e) {
			var parentLabel = $(this).parents('#field-label')

			e.preventDefault();
			if ( this.value.trim() === '' ) {
				parentLabel.addClass( 'field-label--error field-label--error-required' )
			}
		} );

		emailInput.addEventListener('invalid', function (e) {
			var parentLabel = $(this).parents('#checkbox__label_email')
			e.preventDefault();

			if ( this.value.trim() === '' ) {
				parentLabel.addClass( 'field-label--error field-label--error-required' )
			}
		} );

		// Display the dialog.
		$('.btn__cancel__confirmation').on( 'click', function(e) {
			e.preventDefault();
			$('.dialog-wrapper').addClass( 'visible' );
		} )

		// Cancel the transfer.
		$('.btn__cancel').click( cancelTransfer );
		// Resume the transfer.
		$('.btn__resume').click( resumeTransfer );

		$( '.sg-wp-migrator-options-form' ).on( 'submit', function( e ) {
			e.preventDefault();

			resetScreens();

			$('#field-label').removeClass();
			$( '.dns_servers' ).html();
			$('.new-site-info').addClass( 'hidden' );

			// Put hte progress bar in progress.
			$( '.sg-wp-migrator-progress' )
				.removeClass( 'completed failed' )
				.addClass( 'inprogress' );

			// Update the option asynchronous.
			$.post(
				ajaxurl,
				$( this ).serialize()
			).done( function ( response ) {
				// Update the status.
				updateStatus();
			} )
		} )
	} );

	function resetScreens() {
		$('.dialog-wrapper').removeClass( 'visible' );
		$('.title--status').text(  objectL10n.start_message );
		// Reset the progress bar.
		$('.progress__indicator').css( 'transform', 'translateX(-100%)' );
		$('#section--transfer-status')
			.removeClass()
			.addClass( 'section--status-1' );
	}

	function cancelTransfer(e) {
		e.preventDefault();
		$.post(
			ajaxurl,
			{ 'action' : 'siteground_migrator_transfer_cancelled' }
		).done( function ( response ) {
			// Reset the token field.
			$("input[name=siteground_migrator_transfer_token]").val('');
			// Show the main screen.
			$('#section--transfer-status').removeClass();
			$('.dialog-wrapper').removeClass( 'visible' );
		} )
	}

	function resumeTransfer(e) {
		e.preventDefault()

		resetScreens();

		// Resume the transfer.
		$.post(
			ajaxurl,
			{ 'action' : 'siteground_migrator_transfer_continue' }
		).done( function ( response ) {
			updateStatus();
		} )
	}

	function validateToken(e) {
		var parentLabel = $(this).parents('#field-label, #checkbox__label_email')
			regex       = /^[\d]{10}-[\w]{16}-[\w]{16}$/;
			value       = this.value;

		parentLabel.removeClass();

		// Do not show error message when the value is empty.
		if ( value.trim() === '' ) {
			// parentLabel.addClass( 'field-label--error field-label--error-required' )
		} else if ( ! value.match( regex ) ) {
			parentLabel.addClass( 'field-label--error field-label--error-pattern' )
		} else {
			parentLabel.addClass( 'field-label--success' );
		}
	}

	function validateEmail(e) {
		var parentLabel = $(this).parents('#field-label, #checkbox__label_email')
			regex       = /(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*|"(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21\x23-\x5b\x5d-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])*")@(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\[(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21-\x5a\x53-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])+)\])/i;
			value       = this.value;

		parentLabel.removeClass();

		// Do not show error message when the value is empty.
		if ( value.trim() === '' ) {
			// parentLabel.addClass( 'field-label--error field-label--error-required' )
		} else if ( ! value.match( regex ) ) {
			parentLabel.addClass( 'field-label--error field-label--error-pattern' )
		} else {
			parentLabel.addClass( 'field-label--success' );
		}
	}

	// Update the progress bar every 5 seconds while the transfer is in progress.
	function updateStatus() {
		$.post(
			ajaxurl,
			{ action: 'siteground_migrator_get_transfer_status' }
		).done( function( response ) {
			// Bail if the status is not set.
			if ( typeof response.data.status === 'undefined' ) {
				return;
			}

			$( '.title--status' ).text( response.data.message );
			$( '.text--description' ).html( response.data.description );

			// Update the section class.
			$('#section--transfer-status')
				.removeClass()
				.addClass( 'section--status-' + response.data.status );

			switch ( response.data.status ) {
				case 1 : // In progress, the plugin prepares the data.
				case 2 : // Ready, waiting for remote api to complete the transfer.
					$('.progress__indicator').css( 'transform', 'translateX(-' + response.data.progress + '%)' );
					// Wait 5 seconds, before making new request.
					setTimeout( function() {
						updateStatus();
					}, 1500 );
					break;

				case 3 :
				case 4 :
					// Show the info box.
					$('.new-site-info').removeClass( 'hidden' );

					if ( typeof response.data.temp_url !== 'undefined'  ) {
						$( '.box--temp-url' ).removeClass( 'hidden' );
						$( '.btn--temp-url' ).attr( 'href', response.data.temp_url );
					}

					if ( typeof response.data.dns_servers !== 'undefined'  ) {
						$( '.box--dns-servers' ).removeClass( 'hidden' );
						$( '.dns_servers' ).html( '' );

						for (var i = 0; i < response.data.dns_servers.length; i++) {

							$('.dns_servers')
								.append(
									'<h4 class="title title--density-compact title--level-5 typography typography--align-center typography--weight-light with-color with-color--color-darker">NS' + ( i + 1 ) + ': <a class="link">' + response.data.dns_servers[i] + '</a></h4>'
								)
						}
					}

					if ( typeof response.data.errors !== 'undefined'  ) {
						$( '.box--errors' ).removeClass( 'hidden' )
						// Remove errors from previous transfer.
						$('.table__row:not(.table__row-template)').remove()

						for (var i = 0; i < response.data.errors.length; i++) {

							var tableRow = $('.table__row-template').clone();

							newHtml = $(tableRow).html()
								.replace( '{\$f}', response.data.errors[i].f )
								.replace( '{\$e}', response.data.errors[i].e )

							$(tableRow).removeClass( 'table__row-template' ).html( newHtml );

							$( '.table__body_errros' ).append( tableRow )
						}
					}
			}
		} );

	}

})( jQuery );
