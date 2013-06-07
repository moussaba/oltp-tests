<?php

/*
	Phoronix Test Suite
	URLs: http://www.phoronix.com, http://www.phoronix-test-suite.com/
	Copyright (C) 2008 - 2012, Phoronix Media
	Copyright (C) 2008 - 2012, Michael Larabel
	pts-core.php: To boot-strap the Phoronix Test Suite start-up

	This program is free software; you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation; either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program. If not, see <http://www.gnu.org/licenses/>.
*/

define('PTS_VERSION', '4.0.0');
define('PTS_CORE_VERSION', 4000);
define('PTS_CODENAME', 'SULDAL');
define('PTS_IS_CLIENT', (defined('PTS_MODE') && PTS_MODE == 'CLIENT'));
define('PTS_IS_DEV_BUILD', (substr(PTS_VERSION, -2, 1) == 'm'));

if(!defined('PTS_PATH'))
{
	define('PTS_PATH', dirname(dirname(__FILE__)) . '/');
}

function pts_codename($full_string = false)
{
	$codename = ucwords(strtolower(PTS_CODENAME));

	return ($full_string ? 'PhoronixTestSuite/' : null) . $codename;
}
function pts_title($show_codename = false)
{
	return 'Phoronix Test Suite v' . PTS_VERSION . ($show_codename ? ' (' . pts_codename() . ')' : null);
}
function pts_define_directories()
{
	// User's home directory for storing results, module files, test installations, etc.
	define('PTS_CORE_PATH', PTS_PATH . 'pts-core/');

	if(PTS_IS_CLIENT)
	{
		//define('PTS_USER_PATH', pts_client::user_home_directory() . './test_tmp/data/');
		define('PTS_USER_PATH', PTS_PATH . '../../../../test_tmp/data/');
		define('PTS_CORE_STORAGE', PTS_USER_PATH . 'core.pt2so');
		define('PTS_TEMP_STORAGE', PTS_USER_PATH . 'temp.pt2so');
		define('PTS_MODULE_LOCAL_PATH', PTS_USER_PATH . 'modules/');
		define('PTS_MODULE_DATA_PATH', PTS_USER_PATH . 'modules-data/');
		define('PTS_DOWNLOAD_CACHE_PATH', PTS_USER_PATH . 'download-cache/');
		define('PTS_OPENBENCHMARKING_SCRATCH_PATH', PTS_USER_PATH . 'openbenchmarking.org/');
		define('PTS_TEST_PROFILE_PATH', PTS_USER_PATH . 'test-profiles/');
		define('PTS_TEST_SUITE_PATH', PTS_USER_PATH . 'test-suites/');
		define('PTS_RESULTS_VIEWER_PATH', PTS_CORE_PATH . 'results-viewer/');
	}

	// Misc Locations
	define('PTS_MODULE_PATH', PTS_CORE_PATH . 'modules/');
	define('PTS_CORE_STATIC_PATH', PTS_CORE_PATH . 'static/');
	define('PTS_COMMAND_PATH', PTS_CORE_PATH . 'commands/');
	define('PTS_EXDEP_PATH', PTS_CORE_PATH . 'external-test-dependencies/');
	define('PTS_OPENBENCHMARKING_PATH', PTS_CORE_PATH . 'openbenchmarking.org/');
}
function pts_needed_extensions()
{
	return array(
		// Required? - The Check If In Place - Name - Description
		// Required extesnions denoted by 1 at [0]
		array(1, extension_loaded('dom'), 'DOM', 'The PHP Document Object Model (DOM) is required for XML operations.'),
		array(1, extension_loaded('zip') || extension_loaded('zlib'), 'ZIP', 'PHP Zip support is required for file compression and decompression.'),
		array(1, function_exists('json_decode'), 'JSON', 'PHP JSON support is required for OpenBenchmarking.org communication.'),
		// Optional but recommended extensions
		array(0, extension_loaded('openssl'), 'OpenSSL', 'PHP OpenSSL support is recommended to support HTTPS traffic.'),
		array(0, extension_loaded('gd'), 'GD', 'The PHP GD library is recommended for improved graph rendering.'),
		array(0, extension_loaded('zlib'), 'Zlib', 'The PHP Zlib extension can be used for greater file compression.'),
		array(0, function_exists('pcntl_fork'), 'PCNTL', 'PHP PCNTL is highly recommended as it is required by some tests.'),
		array(0, function_exists('posix_getpwuid'), 'POSIX', 'PHP POSIX support is highly recommended.'),
		array(0, function_exists('curl_init'), 'CURL', 'PHP CURL is recommended for an enhanced download experience.'),
		array(0, is_file('/usr/share/php/fpdf/fpdf.php'), 'PHP FPDF', 'PHP FPDF is recommended if wishing to generate PDF reports.')
		);
}
function pts_version_codenames()
{
	return array(
		'1.0' => 'Trondheim',
		'1.2' => 'Malvik',
		'1.4' => 'Orkdal',
		'1.6' => 'Tydal',
		'1.8' => 'Selbu',
		'2.0' => 'Sandtorg',
		'2.2' => 'Bardu',
		'2.4' => 'Lenvik',
		'2.6' => 'Lyngen',
		'2.8' => 'Torsken',
		'2.9' => 'Iveland', // early PTS3 development work
		'3.0' => 'Iveland',
		'3.2' => 'Grimstad',
		'3.4' => 'Lillesand',
		'3.6' => 'Arendal',
		'3.8' => 'Bygland',
		'4.0' => 'Suldal',
		'4.2' => 'Randaberg',
		);
}

if(PTS_IS_CLIENT || defined('PTS_AUTO_LOAD_OBJECTS'))
{
	function pts_build_dir_php_list($dir, &$files)
	{
		if($dh = opendir($dir))
		{
			while(($file = readdir($dh)) !== false)
			{
				if($file != '.' && $file != '..')
				{
					if(is_dir($dir . '/' . $file) && (PTS_IS_CLIENT || $file != 'client'))
					{
						// The client folder should contain classes exclusively used by the client
						pts_build_dir_php_list($dir . '/' . $file, $files);
					}
					else if(substr($file, -4) == '.php')
					{
						$files[substr($file, 0, -4)] = $dir . '/' . $file;
					}
				}
			}
		}
		closedir($dh);
	}
	function __autoload($to_load)
	{
		static $obj_files = null;

		if($obj_files == null)
		{
			pts_build_dir_php_list(PTS_PATH . 'pts-core/objects', $obj_files);
		}

		if(isset($obj_files[$to_load]))
		{
			include($obj_files[$to_load]);
			unset($obj_files[$to_load]);
		}
	}
}

?>
