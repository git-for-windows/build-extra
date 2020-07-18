<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en" dir="ltr">
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
	<title>Migration to SiteGround Failed</title>
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
						<img src="https://www.siteground.com/static/en/img/emails/generic/sg_migration_failed_header.png"
							 width="600" alt="Migration to SiteGround Failed"
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
									'As you requested, we’ve tried to move a copy of <a href="%1$s" target="_blank" rel="noreferrer" style="color: #22b8d1; outline: none; text-decoration: none;">%1$s</a> to SiteGround. Unfortunately, the transfer failed due to restriction in the current hosting environment.',
									'siteground-migrator'
								),
								get_home_url( '/' )
							);
						?>
					</td>
				</tr>
				<tr>
					<td class="body-text"
						style="color: #444444; font-weight: 400; font-family: 'Open Sans', Arial, Helvetica, sans-serif; font-size: 16px; line-height: 26px; padding: 0px 0 40px 0">
						<?php
							printf(
								__(
									'Please review <a href="%s" target="_blank" rel="noreferrer" style="color: #22b8d1; outline: none; text-decoration: none;">our tutorial</a> for manual transfer or request a professional transfer from our Support Team by posting a ticket in your Help Desk under <a href="%s" target="_blank" rel="noreferrer" style="color: #22b8d1; outline: none; text-decoration: none;">Website Transfer</a> category.',
									'siteground-migrator'
								),
								__( 'https://www.siteground.com/tutorials/wordpress/move-copy/', 'siteground-migrator' ),
								__( 'https://ua.siteground.com/support/website_transfer.htm', 'siteground-migrator' )
							);
						?>
					</td>
				</tr>
				<tr>
					<td class="body-text"
						style="color: #444444; font-weight: 400; font-family: 'Open Sans', Arial, Helvetica, sans-serif; font-size: 16px; line-height: 26px; padding: 0px 0 25px 0">
						<?php _e( 'Best Regards, <br>The SiteGround Team', 'siteground-migrator' ) ?>
					</td>
				</tr>

			</table>

			<!-- End Main Container -->
		</td>
	</tr>
</table>

</body>
</html>

