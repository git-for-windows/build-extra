<?php $errors = ! empty( $status['errors'] ) ? $status['errors'] : array(); ?>
<div class="container container--padding-xx-large container--elevation-1 thank-you thank-you--warning">
	<div class="flex flex--align-center flex--gutter-none flex--direction-column flex--margin-none">
		<div class="thank-you-icon-background">
			<div class="thank-you-icon-wrapper">
				<span class="icon icon--use-current-color icon--presized with-color thank-you-icon" style="width: 45px; height: 45px;">
					<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 34 31">
						<path d="M26,52a1,1,0,0,1-.78-.373s-.252-.313-.632-.879a1,1,0,1,1,1.66-1.115c.312.465.52.728.533.745A1,1,0,0,1,26,52Z" transform="translate(-21 -23)"/>
						<path d="M55,40A17.019,17.019,0,0,0,38,23c-7.117,0-12.927,3.589-15.541,9.6v.008c-.14.318-.269.643-.39.976a1,1,0,0,0,1.881.682q.16-.443.344-.867v0C26.581,28.139,31.705,25,38,25A14.978,14.978,0,0,1,48,51.149V46H46v8h8V52H50.041A16.908,16.908,0,0,0,55,40Z" transform="translate(-21 -23)"/>
						<path d="M23,40c0-.615.029-1.229.087-1.823a1,1,0,0,0-1.99-.194c-.065.66-.1,1.337-.1,2.017l0,.226,2-.031Z" transform="translate(-21 -23)"/>
						<path d="M23.632,44.13a1,1,0, 1,0-1.918.566,20.674,20.674,0,0,0,.754,2.113,1,1,0,0,0,.923.613,1.014,1.014,0,0,0,.386-.077,1,1,0,0,0,.536-1.31A18.468,18.468,0,0,1,23.632,44.13Z" transform="translate(-21 -23)"/>
						<path d="M38.9,46.269a1.851,1.851,0,0,1,.517,1.35A1.933,1.933,0,0,1,38.9,49.01a1.734,1.734,0,0,1-1.311.543A1.678,1.678,0,0,1,36.309,49a1.942,1.942,0,0,1-.517-1.377,1.851,1.851,0,0,1,.517-1.35,1.716,1.716,0,0,1,1.284-.531A1.75,1.75,0,0,1,38.9,46.269ZM35.951,30.957h3.311v4.609l-.582,7.708H36.533l-.582-7.708Z" transform="translate(-21 -23)"/>
					</svg>
				</span>
			</div>
		</div>
		<h1 class="title title--status title--density-comfortable title--level-1 typography typography--align-center typography--weight-light with-color with-color--color-darker thank-you-title"><?php echo $status['message']; ?></h1>

		<p class="text text--description text--size-large typography typography--align-center typography--weight-regular with-color with-color--color-dark thank-you-description">
			<?php
			if ( ! empty( $status['description'] ) ) {
				echo esc_html( $status['description'] );
			}
			?>
		</p>

		<div class="box--actions">
			<button class="btn btn--x-large btn__cancel btn--primary btn--dark" type="button" data-e2e="create-box-submit" data-restart="true">
				<span class="btn__content btn__loader">
					<span class="btn__text"><?php esc_html_e( 'Cancel Transfer', 'siteground-migrator' ); ?></span>
				</span>
			</button>

			<button class="btn btn--x-large btn__resume btn--primary" type="button" data-e2e="create-box-submit" data-restart="true">
				<span class="btn__content btn__loader">
					<span class="btn__text"><?php esc_html_e( 'Continue', 'siteground-migrator' ); ?></span>
				</span>
			</button>

		</div>
	</div>
	<div style="width:100%" class="box--errors <?php echo empty( $errors ) ? 'hidden' : '' ?>">
		<div class="table-wrapper border-box table-wrapper--density-medium table-wrapper--mobile">
			<table class="table table--no-footer">
				<thead class="table__head table__head--background-default">
					<tr>
						<th class="table__cell" data-cell-index="0">File</th>
						<th class="table__cell" data-cell-index="1">Status</th>
					</tr>
				</thead>
				<tbody class="table__body table__body_errros">
					<?php
					foreach ( $errors as $error ) :
						if ( empty( $error['f'] ) ) {
							continue;
						}
					?>
						<tr class="table__row" style="touch-action: pan-y; user-select: none; -webkit-user-drag: none; -webkit-tap-highlight-color: rgba(0, 0, 0, 0);">
							<td class="table__cell" data-label="For Email" data-cell-index="0" data-row-index="5">
								<div class="table__cell-text">
									<?php echo esc_html( $error['f'] ); ?>
								</div>
							</td>
							<?php if ( ! empty( $error['e'] ) ) : ?>
								<td class="table__cell" data-label="Status" data-cell-index="2" data-row-index="5">
									<span class="label label--type-inactive-link label--size-medium">
										<?php echo $error['e']; ?>
									</span>
								</td>
							<?php endif ?>
						</tr>
					<?php endforeach ?>
					
					<tr class="table__row table__row-template" style="touch-action: pan-y; user-select: none; -webkit-user-drag: none; -webkit-tap-highlight-color: rgba(0, 0, 0, 0);">
						<td class="table__cell" data-label="For Email" data-cell-index="0" data-row-index="5">
							<div class="table__cell-text">
								{$f}
							</div>
						</td>
						<td class="table__cell" data-label="Status" data-cell-index="2" data-row-index="5">
							<span class="label label--type-inactive-link label--size-medium">
								{$e}
							</span>
						</td>
					</tr>
				</tbody>
			</table>
		</div>
	</div>

	<?php include 'new-site-setup-info.php'; ?>

	<p class="typography typography--align-center"><a href="#" class="btn__cancel btn__new_transfer"><?php echo __( 'Initiate New Transfer', 'siteground-migrator' ) ?></a></p>
</div>
