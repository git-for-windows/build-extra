<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en" dir="ltr">
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
	<title>Migration to SiteGround completed, some files could not be transferred</title>
	<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=0"/>
	<link href="https://fonts.googleapis.com/css?family=Open+Sans:400,600|Roboto:400,500" rel="stylesheet">
	<style type="text/css">
		body {
			margin: 0;
			padding: 0;
			width: 100% !important;
			-webkit-text-size-adjust: 100%;
			-ms-text-size-adjust: 100%;
		}

		img {
			max-width: 100%;
			outline: none;
			text-decoration: none;
			-ms-interpolation-mode: bicubic;
			display: block !important;
			border: none;
		}
		#backgroundTable {
			margin: 0;
			padding: 10px 10px 10px 10px;
			width: 100% !important;
			line-height: 100%;
		}

		@media screen and (max-width: 480px), screen and (max-device-width: 480px) {
			.flex, [class=flex] {
				width: 94% !important;
			}
			#backgroundTable {
				padding: 10px 0 10px 0px;
			}
		}
	</style>
	<!--Fallback For Outlook -->
	<!--[if mso]>
	<style type=”text/css”>
		.body-text {
			font-family: Arial, sans-serif !important;
		}
	</style>
	<![endif]-->
</head>

<body style="margin: 0; padding: 0;">
<table border="0" cellpadding="0" cellspacing="0" width="100%" id="backgroundTable" style="background: #ffffff;">
	<tr>
		<td>
			<!-- Main Container -->
			<table class="flex" align="center" border="0" cellpadding="0" cellspacing="0" width="600"
				   style="border-collapse: collapse; font-family: 'Open Sans', Arial, Helvetica, sans-serif;">
				<tr>
					<td>
						<!-- Header -->
						<table border="0" cellpadding="0" cellspacing="0" width="100%">
							<tr>
								<td height="30"
									style="padding: 20px 0 30px 0;">
									<a style="border: none"
									   href="https://www.siteground.com/?utm_source=newsletter&utm_medium=email&utm_campaign=logo"
									   target="_blank" rel="noreferrer"><img
											src="https://www.siteground.com/static/en/img/emails/logo_b.png"
											width="170" alt="Your Website at SiteGround"></a>
								</td>

							</tr>
						</table>
						<!-- End Header -->
					</td>
				</tr>
				<tr>
					<td style="padding: 0 0 30px 0">
						<img src="https://www.siteground.com/static/en/img/emails/generic/sg_migration_errors_header.png"
							 width="600" alt="Migration to SiteGround completed, some files could not be transferred"
							 style="max-height: 250px;"/>
					</td>
				</tr>
				<tr>
					<td class="body-text"
						style="color: #363636; font-weight: 500; font-family: 'Roboto', Arial, Helvetica, sans-serif; font-size: 26px; line-height: 38px; padding: 0 0 25px 0">
						<?php _e( 'Hello,', 'siteground-migrator' ); ?>
					</td>
				</tr>
				<tr>
					<td class="body-text"
						style="color: #444444; font-weight: 400; font-family: 'Open Sans', Arial, Helvetica, sans-serif; font-size: 16px; line-height: 26px; padding: 0px 0 25px 0">
						<?php
						printf(
							__(
								'A copy of <a href="%1$s" target="_blank" rel="noreferrer" style="color: #22b8d1; outline: none; text-decoration: none;">%1$s</a> has been migrated to SiteGround, as you requested. The database and most of the WordPress files of your website were transferred to the new server.  However, <b>the files listed below could not be transferred due to restrictions of the current hosting environment</b>:',
								'siteground-migrator'
							),
							get_home_url( '/' )
						)
						?>
					</td>
				</tr>

				<?php if ( ! empty( $data['errors'] ) ): ?>                                                         
					<tr>
						<td style="padding: 0px 0px 15px 0px; font-size: 14px; color: #0d0d0d; line-height: 150%;">
							<?php
							foreach ( $data['errors'] as $error ) {
								echo $error['f'] . '<br>';
							}
							?>
						</td>
					</tr>
				<?php endif ?>

				<tr>
					<td class="body-text"
						style="color: #444444; font-weight: 400; font-family: 'Open Sans', Arial, Helvetica, sans-serif; font-size: 16px; line-height: 26px; padding: 0px 0 25px 0">
						<?php _e( 'Please preview your migrated website on the link below to see if it looks and functions as expected:', 'siteground-migrator' ) ?>
					</td>
				</tr>
				<tr>
					<td class="body-text"
						style="color: #444444; font-weight: 400; font-family: 'Open Sans', Arial, Helvetica, sans-serif; font-size: 16px; line-height: 26px; padding: 0px 0 25px 0">
						<a href="<?php echo $data['temp_url'] ?>" target="_blank" rel="noreferrer" style="color: #22b8d1; outline: none; text-decoration: none;"><b><?php echo $data['temp_url'] ?></b></a>
					</td>
				</tr>
				<tr>
					<td class="body-text"
						style="color: #444444; font-weight: 400; font-family: 'Open Sans', Arial, Helvetica, sans-serif; font-size: 16px; line-height: 26px; padding: 0px 0 25px 0">
						<?php
						printf(
							__(
								'If there are any errors, either try to migrate the files from the list above manually using FTP or sFTP, or contact our SiteGround support team through your Help Desk under <a href="%s" target="_blank" rel="noreferrer" style="color: #22b8d1; outline: none; text-decoration: none;">Other Technical Issues</a> category. ',
								'siteground-migrator'
							),
							__( 'https://ua.siteground.com/login_office.htm', 'siteground-migrator' )
						);
						?>
					</td>
				</tr>
				<tr>
					<td class="body-text"
						style="color: #444444; font-weight: 400; font-family: 'Open Sans', Arial, Helvetica, sans-serif; font-size: 16px; line-height: 26px; padding: 0px 0 25px 0">
						<?php __( 'If your site looks as expected on the new location and you wish to complete the transfer, just point your domain name to SiteGround. To do this, please change your name servers to the following:', 'siteground-migrator' ); ?>
					</td>
				</tr>
				<tr>
					<td style="padding: 0 0 25px 0;">
						<table border="0" cellpadding="0" cellspacing="0" width="100%"
							   bgcolor="#e6f6ea">
							<tr>
								<td class="body-text"
									style="color: #444444; font-weight: 400; font-family: 'Open Sans', Arial, Helvetica, sans-serif; font-size: 16px; line-height: 26px; padding: 20px 25px 20px 25px;">
									<?php
									foreach ( $data['dns_servers'] as $counter => $server ) :
										// Bail if the dns server is empty.
										if ( empty( $server ) ) {
											continue;
										}
									?>
										
										<strong>NS<?php echo $counter + 1; ?>: <?php echo esc_html( $server ); ?></strong>
										<br>
									<?php endforeach ?>
								</td>
							</tr>
						</table>
					</td>
				</tr>
				<tr>
					<td class="body-text"
						style="color: #444444; font-weight: 400; font-family: 'Open Sans', Arial, Helvetica, sans-serif; font-size: 16px; line-height: 26px; padding: 0px 0 40px 0">
						<?php _e( '<b>Important:</b> It can take up to 48 hours for the nameserver changes to propagate. It’s very important to make no changes to your website during the transfer period to avoid data loss or data discrepancy.', 'siteground-migrator' ); ?>
					</td>
				</tr>
				<tr>
					<td class="body-text"
						style="color: #444444; font-weight: 400; font-family: 'Open Sans', Arial, Helvetica, sans-serif; font-size: 16px; line-height: 26px; padding: 0px 0 25px 0">
						<?php _e( 'Best Regards, <br>The SiteGround Team', 'siteground-migrator' ); ?>
					</td>
				</tr>

			</table>

			<!-- End Main Container -->
		</td>
	</tr>
</table>

</body>
</html>

