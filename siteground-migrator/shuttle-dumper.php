<?php

// @todo: separate the following code in different files and folder for version 2.0.0.
/**
 * Abstract dump file: provides common interface for writing
 * data to dump files.
 */
abstract class Shuttle_Dump_File {
	/**
	 * File Handle
	 */
	protected $fh;

	/**
	 * Location of the dump file on the disk
	 */
	protected $file_location;

	abstract function write( $string);
	abstract function end();

	static function create( $filename ) {
		if ( self::is_gzip( $filename ) ) {
			return new Shuttle_Dump_File_Gzip( $filename );
		}
		return new Shuttle_Dump_File_Plaintext( $filename );
	}

	function __construct( $file ) {
		$this->file_location = $file;
		$this->fh = $this->open();

		if ( ! $this->fh ) {
			throw new Shuttle_Exception( "Couldn't create gz file" );
		}
	}

	public static function is_gzip( $filename ) {
		return preg_match( '~gz$~i', $filename );
	}
}

/**
 * Plain text implementation. Uses standard file functions in PHP.
 */
class Shuttle_Dump_File_Plaintext extends Shuttle_Dump_File {
	function open() {
		return fopen( $this->file_location, 'w' );
	}
	function write( $string ) {
		return fwrite( $this->fh, $string );
	}
	function end() {
		return fclose( $this->fh );
	}
}

/**
 * Gzip implementation. Uses gz* functions.
 */
class Shuttle_Dump_File_Gzip extends Shuttle_Dump_File {
	function open() {
		return gzopen( $this->file_location, 'wb9' );
	}
	function write( $string ) {
		return gzwrite( $this->fh, $string );
	}
	function end() {
		return gzclose( $this->fh );
	}
}

/**
 * MySQL insert statement builder.
 */
class Shuttle_Insert_Statement {
	private $rows = array();
	private $length = 0;
	private $table;

	function __construct( $table ) {
		$this->table = $table;
	}

	function reset() {
		$this->rows = array();
		$this->length = 0;
	}

	function add_row( $row ) {
		$row = '(' . implode( ',', $row ) . ')';
		$this->rows[] = $row;
		$this->length += strlen( $row );
	}

	function get_sql() {
		if ( empty( $this->rows ) ) {
			return false;
		}

		return 'INSERT INTO `' . $this->table . '` VALUES ' .
			implode( ",\n", $this->rows ) . '; ';
	}

	function get_length() {
		return $this->length;
	}
}

/**
 * Main facade
 */
abstract class Shuttle_Dumper {
	/**
	 * Maximum length of single insert statement
	 */
	const INSERT_THRESHOLD = 838860;

	/**
	 * @var Shuttle_DBConn
	 */
	public $db;

	/**
	 * @var Shuttle_Dump_File
	 */
	public $dump_file;

	/**
	 * End of line style used in the dump
	 */
	public $eol = "\r\n";

	/**
	 * Specificed tables to include
	 */
	public $include_tables;

	/**
	 * Specified tables to exclude
	 */
	public $exclude_tables = array();

	/**
	 * Factory method for dumper on current hosts's configuration.
	 */
	static function create( $db_options ) {
		$db = Shuttle_DBConn::create( $db_options );

		$db->connect();

		if ( self::has_shell_access()
				&& self::is_shell_command_available( 'mysqldump' )
				&& self::is_shell_command_available( 'gzip' )
			) {
			$dumper = new Shuttle_Dumper_ShellCommand( $db );
		} else {
			$dumper = new Shuttle_Dumper_Native( $db );
		}

		if ( isset( $db_options['include_tables'] ) ) {
			$dumper->include_tables = $db_options['include_tables'];
		}
		if ( isset( $db_options['exclude_tables'] ) ) {
			$dumper->exclude_tables = $db_options['exclude_tables'];
		}

		return $dumper;
	}

	function __construct( Shuttle_DBConn $db ) {
		$this->db = $db;
	}

	public static function has_shell_access() {
		if ( ! is_callable( 'shell_exec' ) ) {
			return false;
		}
		$disabled_functions = ini_get( 'disable_functions' );
		return stripos( $disabled_functions, 'shell_exec' ) === false;
	}

	public static function is_shell_command_available( $command ) {
		if ( preg_match( '~win~i', PHP_OS ) ) {
			/*
			On Windows, the `where` command checks for availabilty in PATH. According
			to the manual(`where /?`), there is quiet mode:
			....
				/Q       Returns only the exit code, without displaying the list
						 of matched files. (Quiet mode)
			....
			*/
			$output = array();
			exec( 'where /Q ' . $command, $output, $return_val );

			if ( intval( $return_val ) === 1 ) {
				return false;
			} else {
				return true;
			}
		} else {
			$last_line = exec( 'which ' . $command );
			$last_line = trim( $last_line );

			// Whenever there is at least one line in the output,
			// it should be the path to the executable
			if ( empty( $last_line ) ) {
				return false;
			} else {
				return true;
			}
		}

	}

	/**
	 * Create an export file from the tables with that prefix.
	 *
	 * @param string $export_file_location the file to put the dump to.
	 *      Note that whenever the file has .gz extension the dump will be comporessed with gzip
	 * @param string $table_prefix Allow to export only tables with particular prefix
	 * @return void
	 */
	abstract public function dump( $export_file_location, $table_prefix = '');

	protected function get_tables( $table_prefix ) {
		if ( ! empty( $this->include_tables ) ) {
			return $this->include_tables;
		}

		// $tables will only include the tables and not views.
		// TODO - Handle views also, edits to be made in function 'get_create_table_sql' line 336
		$tables = $this->db->fetch_numeric(
			'
			SHOW FULL TABLES WHERE Table_Type = "BASE TABLE" AND Tables_in_' . $this->db->name . ' LIKE "' . $this->db->escape_like( $table_prefix ) . '%"
		'
		);

		$tables_list = array();
		foreach ( $tables as $table_row ) {
			$table_name = $table_row[0];
			if ( ! in_array( $table_name, $this->exclude_tables ) ) {
				$tables_list[] = $table_name;
			}
		}
		return $tables_list;
	}
}

class Shuttle_Dumper_ShellCommand extends Shuttle_Dumper {
	function dump( $export_file_location, $table_prefix = '' ) {
		$command = 'mysqldump -h ' . escapeshellarg( $this->db->host ) .
			' -u ' . escapeshellarg( $this->db->username ) .
			' --password=' . escapeshellarg( $this->db->password ) .
			' ' . escapeshellarg( $this->db->name ) .
			' --port=' . escapeshellarg( $this->db->port );

		$include_all_tables = empty( $table_prefix ) &&
			empty( $this->include_tables ) &&
			empty( $this->exclude_tables );

		if ( ! $include_all_tables ) {
			$tables = $this->get_tables( $table_prefix );
			$command .= ' ' . implode( ' ', array_map( 'escapeshellarg', $tables ) );
		}

		$error_file = tempnam( sys_get_temp_dir(), 'err' );

		$command .= ' 2> ' . escapeshellarg( $error_file );

		if ( Shuttle_Dump_File::is_gzip( $export_file_location ) ) {
			$command .= ' | gzip';
		}

		$command .= ' > ' . escapeshellarg( $export_file_location );

		exec( $command, $output, $return_val );

		if ( $return_val !== 0 ) {
			$error_text = file_get_contents( $error_file );
			unlink( $error_file );
			throw new Shuttle_Exception( 'Couldn\'t export database: ' . $error_text );
		}

		unlink( $error_file );
	}
}

class Shuttle_Dumper_Native extends Shuttle_Dumper {
	public function dump( $export_file_location, $table_prefix = '' ) {
		$eol = $this->eol;

		$this->dump_file = Shuttle_Dump_File::create( $export_file_location );

		$this->dump_file->write( '-- Generation time: ' . date( 'r' ) . $eol );
		$this->dump_file->write( '-- Host: ' . $this->db->host . $eol );
		$this->dump_file->write( '-- DB name: ' . $this->db->name . $eol );
		$this->dump_file->write( "/*!40030 SET NAMES UTF8 */;$eol" );

		$this->dump_file->write( "/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;$eol" );
		$this->dump_file->write( "/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;$eol" );
		$this->dump_file->write( "/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;$eol" );
		$this->dump_file->write( "/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;$eol" );
		$this->dump_file->write( "/*!40103 SET TIME_ZONE='+00:00' */;$eol" );
		$this->dump_file->write( "/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;$eol" );
		$this->dump_file->write( "/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;$eol" );
		$this->dump_file->write( "/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;$eol" );
		$this->dump_file->write( "/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;$eol$eol" );

		$tables = $this->get_tables( $table_prefix );
		foreach ( $tables as $table ) {
			$this->dump_table( $table );
		}

		$this->dump_file->write( "$eol$eol" );
		$this->dump_file->write( "/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;$eol" );
		$this->dump_file->write( "/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;$eol" );
		$this->dump_file->write( "/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;$eol" );
		$this->dump_file->write( "/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;$eol" );
		$this->dump_file->write( "/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;$eol" );
		$this->dump_file->write( "/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;$eol" );
		$this->dump_file->write( "/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;$eol$eol" );

		unset( $this->dump_file );
	}

	protected function dump_table( $table ) {
		$eol = $this->eol;

		$this->dump_file->write( "DROP TABLE IF EXISTS `$table`;$eol" );

		$create_table_sql = $this->get_create_table_sql( $table );
		$this->dump_file->write( $create_table_sql . $eol . $eol );

		$data = $this->db->query( "SELECT * FROM `$table`" );

		$insert = new Shuttle_Insert_Statement( $table );

		while ( $row = $this->db->fetch_row( $data ) ) {
			$row_values = array();
			foreach ( $row as $value ) {
				$row_values[] = $this->db->escape( $value );
			}
			$insert->add_row( $row_values );

			if ( $insert->get_length() > self::INSERT_THRESHOLD ) {
				// The insert got too big: write the SQL and create
				// new insert statement
				$this->dump_file->write( $insert->get_sql() . $eol );
				$insert->reset();
			}
		}

		$sql = $insert->get_sql();
		if ( $sql ) {
			$this->dump_file->write( $insert->get_sql() . $eol );
		}
		$this->dump_file->write( $eol . $eol );
	}

	public function get_create_table_sql( $table ) {
		$create_table_sql = $this->db->fetch( 'SHOW CREATE TABLE `' . $table . '`' );
		return $create_table_sql[0]['Create Table'] . ';';
	}
}

class Shuttle_DBConn {
	public $host;
	public $username;
	public $password;
	public $name;

	protected $connection;

	function __construct( $options ) {

		preg_match("~([A-Za-z0-9\-\.]+):?([0-9]+)?~", $options['host'], $parsed_host );

		$this->host = ! empty( $parsed_host[1] ) ? $parsed_host[1] : 'localhost';
		$this->port = ! empty( $parsed_host[2] ) ? $parsed_host[2] : 3306;
		$this->username = $options['username'];
		$this->password = $options['password'];
		$this->name     = $options['db_name'];
	}

	static function create( $options ) {
		if ( class_exists( 'mysqli' ) ) {
			$class_name = 'Shuttle_DBConn_Mysqli';
		} else {
			$class_name = 'Shuttle_DBConn_Mysql';
		}

		return new $class_name( $options );
	}
}

class Shuttle_DBConn_Mysql extends Shuttle_DBConn {
	function connect() {
		$this->connection = @mysql_connect( $this->host . ':' . $this->port, $this->username, $this->password );
		if ( ! $this->connection ) {
			throw new Shuttle_Exception( "Couldn't connect to the database: " . mysql_error() );
		}

		$select_db_res = mysql_select_db( $this->name, $this->connection );
		if ( ! $select_db_res ) {
			throw new Shuttle_Exception( "Couldn't select database: " . mysql_error( $this->connection ) );
		}

		return true;
	}

	function query( $q ) {
		if ( ! $this->connection ) {
			$this->connect();
		}
		$res = mysql_query( $q );
		if ( ! $res ) {
			throw new Shuttle_Exception( 'SQL error: ' . mysql_error( $this->connection ) );
		}
		return $res;
	}

	function fetch_numeric( $query ) {
		return $this->fetch( $query, MYSQL_NUM );
	}

	function fetch( $query, $result_type = MYSQL_ASSOC ) {
		$result = $this->query( $query, $this->connection );
		$return = array();
		while ( $row = mysql_fetch_array( $result, $result_type ) ) {
			$return[] = $row;
		}
		return $return;
	}

	function escape( $value ) {
		if ( is_null( $value ) ) {
			return 'NULL';
		}
		return "'" . mysql_real_escape_string( $value ) . "'";
	}

	function escape_like( $search ) {
		return str_replace( array( '_', '%' ), array( '\_', '\%' ), $search );
	}

	function get_var( $sql ) {
		$result = $this->query( $sql );
		$row = mysql_fetch_array( $result );
		return $row[0];
	}

	function fetch_row( $data ) {
		return mysql_fetch_assoc( $data );
	}
}


class Shuttle_DBConn_Mysqli extends Shuttle_DBConn {
	function connect() {
		$this->connection = @new MySQLi( $this->host, $this->username, $this->password, $this->name, $this->port );

		if ( $this->connection->connect_error ) {
			throw new Shuttle_Exception( "Couldn't connect to the database: " . $this->connection->connect_error );
		}

		return true;
	}

	function query( $q ) {
		if ( ! $this->connection ) {
			$this->connect();
		}
		$res = $this->connection->query( $q );

		if ( ! $res ) {
			throw new Shuttle_Exception( 'SQL error: ' . $this->connection->error );
		}

		return $res;
	}

	function fetch_numeric( $query ) {
		return $this->fetch( $query, MYSQLI_NUM );
	}

	function fetch( $query, $result_type = MYSQLI_ASSOC ) {
		$result = $this->query( $query, $this->connection );
		$return = array();
		while ( $row = $result->fetch_array( $result_type ) ) {
			$return[] = $row;
		}
		return $return;
	}

	function escape( $value ) {
		if ( is_null( $value ) ) {
			return 'NULL';
		}
		return "'" . $this->connection->real_escape_string( $value ) . "'";
	}

	function escape_like( $search ) {
		return str_replace( array( '_', '%' ), array( '\_', '\%' ), $search );
	}

	function get_var( $sql ) {
		$result = $this->query( $sql );
		$row = $result->fetch_array( $result, MYSQLI_NUM );
		return $row[0];
	}

	function fetch_row( $data ) {
		return $data->fetch_array( MYSQLI_ASSOC );
	}
}

class Shuttle_Exception extends Exception {};
