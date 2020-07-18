<?php
/**
 * This file defines a class that is responsible for all directory processes.
 *
 * @link       https://www.siteground.com
 * @since      1.0.0
 *
 * @package    SiteGround_Migrator
 * @subpackage SiteGround_Migrator/includes
 */

/**
 * The directory service class.
 *
 * Provides a way to create, remove and retrieve directory size.
 *
 * @since      1.0.0
 * @package    SiteGround_Migrator
 * @subpackage SiteGround_Migrator/includes
 * @author     SiteGround <hristo.p@siteground.com>
 */
class Siteground_Migrator_Directory_Service {

	use Siteground_Migrator_Log_Service;

	/**
	 * List of child directories that should be created in temp dir.
	 *
	 * @since 1.0.0
	 *
	 * @var array
	 */
	private $child_directories = array(
		'/plugins',
		'/themes',
		'/sql',
	);

	/**
	 * {@link Siteground_Migrator_Directory_Service} singleton instance.
	 *
	 * @since  1.0.0
	 * @access private
	 * @var \Siteground_Migrator_Directory_Service $instance {@link Siteground_Migrator_Directory_Service} singleton instance.
	 */
	private static $instance;

	/**
	 * The constructor
	 *
	 * @since 1.0.0
	 */
	public function __construct() {
		// Create the temp directory for archives and database dumps.
		$this->create_temp_directories();

		self::$instance = $this;
	}

	/**
	 * Get {@link Siteground_Migrator_Directory_Service} singleton instance.
	 *
	 * @since 1.0.0
	 *
	 * @return Siteground_Migrator_Directory_Service {@link Siteground_Migrator_Directory_Service} singleton instance.
	 */
	public static function get_instance() {
		return self::$instance;
	}

	/**
	 * Create the directory where the mysql tables will be dumped.
	 *
	 * @since  1.0.0
	 *
	 * @return bool True on success or if the directory already exists
	 *              False on failure.
	 */
	private function create_temp_directories() {
		// Get the temp directory.
		$directory = $this->get_temp_directory_path();

		// try to create the temp directory.
		$result = $this->create_directory( $directory );

		// Bail if the main temp directory was not created.
		if ( false === $result ) {
			return;
		}

		// Create child directories if the main directory was successfully created.
		foreach ( $this->child_directories as $child_dir ) {
			$this->create_directory( $directory . $child_dir );
		}

	}

	/**
	 * Create directory.
	 *
	 * @since  1.0.0
	 *
	 * @param  string $directory The new directory path.
	 *
	 * @return bool              True is the directory is created.
	 *                           False on failure.
	 */
	private function create_directory( $directory ) {
		if ( empty( $directory ) ) {
			return $this->log_error( 'Temporary directory name is not set.' );
		}

		// The directory already exists.
		if ( is_dir( $directory ) ) {
			return true;
		}

		// Create the directory and return the result.
		$is_directory_created = wp_mkdir_p( $directory );

		// Bail if cannot create temp dir.
		if ( false === $is_directory_created ) {
			// translators: `$directory` is the name of directory that should be created.
			$this->log_error( sprintf( 'Cannot create directory: %s.', $directory ) );
		}

		return $is_directory_created;
	}

	/**
	 * Remove temp dir after the transfer is completed.
	 *
	 * @since  1.0.0
	 *
	 * @param  string $directory The directory to remove. Plugin temp dir by default.
	 */
	public function remove_temp_dir( $directory = '' ) {
		global $wp_filesystem;
		// Initialize the WP filesystem, no more using 'file-put-contents' function.
		if ( empty( $wp_filesystem ) ) {
			require_once( ABSPATH . '/wp-admin/includes/file.php' );
			WP_Filesystem();
		}

		if ( empty( $directory ) ) {
			$directory = self::get_temp_directory_path();
		}

		// Bail if the temp dir doesn't exists.
		if ( ! is_dir( self::get_temp_directory_path() ) ) {
			return;
		}

		foreach ( scandir( $directory ) as $file ) {
			// Skip system files.
			if ( '.' === $file || '..' === $file ) {
				continue;
			}

			// Remove the file and continue.
			if ( ! is_dir( "$directory/$file" ) ) {
				$wp_filesystem->delete( "$directory/$file" );
				continue;
			}

			// Continue with child directories.
			$this->remove_temp_dir( "$directory/$file" );
		}

		// Remove the main dir.
		$wp_filesystem->rmdir( $directory );
	}

	/**
	 * Return the total size of a directory in bytes.
	 *
	 * @since  1.0.0
	 *
	 * @param  string $directory The directory which size to calculate.
	 *
	 * @return int    $size The total size of the directory.
	 */
	public static function get_directory_size( $directory ) {
		// Init the size.
		$size = 0;

		// Bail if the directory doesn't exists.
		if ( ! file_exists( $directory ) ) {
			// translators: `$directory` placeholder contains the name of directory which size we are trying to retrieve.
			(new self)->log_error( sprintf( 'Directory: %s doesn\'t exists', $directory ) );
			return;
		}

		// Init the iterator.
		// We create this variable for code readability.
		// Otherwise the foreach below looks very ugly.
		$iterator = new RecursiveIteratorIterator(
			new RecursiveDirectoryIterator(
				$directory,
				FilesystemIterator::SKIP_DOTS
			)
		);

		// Loop through all sub-directories and files
		// and calculate the size of the directory.
		foreach ( $iterator as $object ) {
			// Increase the `size` by adding the current object size.
			$size += $object->getSize();
		}

		// Finally return the total size of the directory.
		return $size;
	}

	/**
	 * Get WordPress installation size.
	 *
	 * @since  1.0.0
	 *
	 * @return int $size The size of the installation.
	 */
	public static function get_wordpress_size() {
		$size = 0;
		$paths = array(
			ABSPATH . 'wp-admin',
			WP_CONTENT_DIR,
			ABSPATH . 'wp-includes',
		);

		foreach ( $paths as $path ) {
			$size += self::get_directory_size( $path );
		}

		// return the size.
		return $size;
	}

	/**
	 * Creates a tree-structured array of directories and files from a given root folder.
	 *
	 * @param string $directory The directory.
	 *
	 * @since 1.0.0
	 *
	 * @return array Tree array.
	 */
	public function get_upload_paths( $directory ) {
		// Init the dir and file arrays.
		$paths = '';

		// Make the dir innstance of `RecursiveDirectoryIterator`.
		$directory = new RecursiveDirectoryIterator(
			(string) $directory,
			RecursiveDirectoryIterator::SKIP_DOTS
		);

		// Loop throug all directories and build the tree.
		foreach ( $directory as $node ) {
			// Call the method recursivelly if the node is directory.
			if ( $node->isDir() ) {
				$paths .= $this->get_upload_paths( $node->getPathname() );
			} else {
				// We need to replace the ABSPATH with `/` and windows server backslashes.
				$path = str_replace(
					array(
						ABSPATH,
						'\\',
					),
					array(
						'/',
						'/',
					),
					$node->getPath()
				);

				$paths .= $path . '/' . $node->getFilename() . "\n";
			}
		}

		// Return the paths.
		return $paths;
	}

	/**
	 * Retrieve directories in certain folder.
	 *
	 * @since  1.0.0
	 *
	 * @param string $directory The main directory.
	 *
	 * @return array $directories Child directories in main dir.
	 */
	private function get_child_directories( $directory ) {
		$directories = array();

		// Make the directory innstance of `RecursiveDirectoryIterator`.
		$directory_iterator = new RecursiveDirectoryIterator(
			WP_CONTENT_DIR . (string) $directory,
			RecursiveDirectoryIterator::SKIP_DOTS
		);

		// Loop through all directories and get the child directories.
		foreach ( $directory_iterator as $node ) {
			// Bail if the current node is not directory.
			if (
				! $node->isDir() ||
				'siteground-migrator' === $node->getFilename()
			) {
				continue;
			}

			$directories[] = $directory . '/' . $node->getFilename();
		}

		// Return the directories.
		return $directories;
	}

	/**
	 * Build array of all directories that should be archived.
	 *
	 * @since  1.0.0
	 *
	 * @return array $directories Directories that should be archived.
	 */
	public function get_plugin_and_theme_child_directories() {
		$directories = array();
		// The parent directories.
		$parent_dirs = array(
			'/plugins',
			'/themes',
		);

		// Loop throught all parent directories
		// and retrieve the sub directories in them.
		foreach ( $parent_dirs as $directory ) {
			$directories = array_merge( $directories, $this->get_child_directories( $directory ) );
		}

		// Finally return the directories that should be archived.
		return $directories;
	}

	/**
	 * Retrieve temp directory name.
	 *
	 * @since  1.0.0
	 *
	 * @return string|bool False if the directory is not set, directory name otherwise.
	 */
	public static function get_temp_directory_path() {
		// Get directory name.
		$directory_name = get_option( 'siteground_migrator_temp_directory' );

		// Bail if the directory name is empty.
		if ( empty( $directory_name ) ) {
			return false;
		}

		$upload_dir = wp_upload_dir();

		// Return the full path to directory.
		return $upload_dir['basedir'] . '/' . $directory_name;
	}

	/**
	 * Check if temp directories have been created.
	 *
	 * @since  1.0.1
	 *
	 * @return bool True is directories exist, false otherwise.
	 */
	public function check_if_temp_dirs_extist() {
		// Get the main temp dir.
		$directory = $this->get_temp_directory_path();

		// Bail if main directory is not created.
		if ( ! is_dir( $directory ) ) {
			return false;
		}

		// Loop through all child dirs and make sure each one has been created.
		foreach ( $this->child_directories as $child_dir ) {
			if ( ! is_dir( $directory . $child_dir ) ) {
				return false;
			}
		}

		// All dirs have been created.
		return true;
	}

}
