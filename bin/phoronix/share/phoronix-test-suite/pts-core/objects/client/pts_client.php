<?php

/*
	Phoronix Test Suite
	URLs: http://www.phoronix.com, http://www.phoronix-test-suite.com/
	Copyright (C) 2008 - 2012, Phoronix Media
	Copyright (C) 2008 - 2012, Michael Larabel

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

class pts_client
{
	public static $display;
	protected static $lock_pointers = null;

	public static function create_lock($lock_file)
	{
		if(isset(self::$lock_pointers[$lock_file]) || is_writable(dirname($lock_file)) == false || disk_free_space(dirname($lock_file)) < 1024)
		{
			return false;
		}

		self::$lock_pointers[$lock_file] = fopen($lock_file, 'w');
		chmod($lock_file, 0644);
		return self::$lock_pointers[$lock_file] != false && flock(self::$lock_pointers[$lock_file], LOCK_EX | LOCK_NB);
	}
	public static function init()
	{
		pts_define_directories(); // Define directories

		if(QUICK_START)
		{
			return true;
		}

		self::basic_init_process(); // Initalize common / needed PTS start-up work
		pts_network::client_startup();
		self::core_storage_init_process();

		if(!is_file(PTS_TEMP_STORAGE))
		{
			self::build_temp_cache();
		}

		pts_config::init_files();
		define('PTS_TEST_INSTALL_DEFAULT_PATH', pts_client::parse_home_directory(pts_config::read_user_config('PhoronixTestSuite/Options/Installation/EnvironmentDirectory', '~/.phoronix-test-suite/installed-tests/')));
		define('PTS_SAVE_RESULTS_PATH', pts_client::parse_home_directory(pts_config::read_user_config('PhoronixTestSuite/Options/Testing/ResultsDirectory', '~/.phoronix-test-suite/test-results/')));
		self::extended_init_process();

		$openbenchmarking = pts_storage_object::read_from_file(PTS_CORE_STORAGE, 'openbenchmarking');
		if($openbenchmarking != null)
		{
			// OpenBenchmarking.org Account
			pts_openbenchmarking_client::init_account($openbenchmarking);
		}

		return true;
	}
	public static function module_framework_init()
	{
		// Process initially called when PTS starts up
		// Check for modules to auto-load from the configuration file
		$load_modules = pts_config::read_user_config('PhoronixTestSuite/Options/Modules/LoadModules', null);

		if(!empty($load_modules))
		{
			foreach(pts_strings::comma_explode($load_modules) as $module)
			{
				$module_r = pts_strings::trim_explode('=', $module);

				if(count($module_r) == 2)
				{
					// TODO: end up hooking this into pts_module::read_variable() rather than using the real env
					pts_client::set_environment_variable($module_r[0], $module_r[1]);
				}
				else
				{
					pts_module_manager::attach_module($module);
				}
			}
		}

		// Check for modules to load manually in PTS_MODULES
		if(($load_modules = pts_client::read_env('PTS_MODULES')) !== false)
		{
			foreach(pts_strings::comma_explode($load_modules) as $module)
			{
				if(!pts_module_manager::is_module_attached($module))
				{
					pts_module_manager::attach_module($module);
				}
			}
		}

		// Detect modules to load automatically
		pts_module_manager::detect_modules_to_load();

		// Clean-up modules list
		pts_module_manager::clean_module_list();

		// Reset counter
		pts_module_manager::set_current_module(null);

		// Load the modules
		$module_store_list = array();
		foreach(pts_module_manager::attached_modules() as $module)
		{
			$class_vars = get_class_vars($module);
			$module_store_vars = isset($class_vars['module_store_vars']) ? $class_vars['module_store_vars'] : null;

			if(is_array($module_store_vars))
			{
				foreach($module_store_vars as $store_var)
				{
					if(!in_array($store_var, $module_store_list))
					{
						array_push($module_store_list, $store_var);
					}
				}
			}
		}

		// Should any of the module options be saved to the results?
		foreach($module_store_list as $var)
		{
			$var_value = pts_client::read_env($var);

			if(!empty($var_value))
			{
				pts_module_manager::var_store_add($var, $var_value);
			}
		}

		pts_module_manager::module_process('__startup');
		define('PTS_STARTUP_TASK_PERFORMED', true);
		register_shutdown_function(array('pts_module_manager', 'module_process'), '__shutdown');
	}
	public static function open_basedir_check()
	{
		$passes = true;
		$open_basedir = ini_get('open_basedir');

		if($open_basedir != false)
		{
			$is_in_allowed_dir = false;
			foreach(explode(':', $open_basedir) as $allowed_dir)
			{
				if(strpos(PTS_PATH, $allowed_dir) === 0)
				{
					$is_in_allowed_dir = true;
					break;
				}
			}

			if($is_in_allowed_dir == false)
			{
				$passes = false;
			}
		}

		return $passes;
	}
	public static function environmental_variables()
	{
		// The PTS environmental variables passed during the testing process, etc
		static $env_variables = null;

		if($env_variables == null)
		{
			$env_variables = array(
			'PTS_VERSION' => PTS_VERSION,
			'PTS_CODENAME' => PTS_CODENAME,
			'PTS_DIR' => PTS_PATH,
			'PHP_BIN' => PHP_BIN,
			'NUM_CPU_CORES' => phodevi::read_property('cpu', 'core-count'),
			'NUM_CPU_JOBS' => (phodevi::read_property('cpu', 'core-count') * 2),
			'SYS_MEMORY' => phodevi::read_property('memory', 'capacity'),
			'VIDEO_MEMORY' => phodevi::read_property('gpu', 'memory-capacity'),
			'VIDEO_WIDTH' => pts_arrays::first_element(phodevi::read_property('gpu', 'screen-resolution')),
			'VIDEO_HEIGHT' => pts_arrays::last_element(phodevi::read_property('gpu', 'screen-resolution')),
			'VIDEO_MONITOR_COUNT' => phodevi::read_property('monitor', 'count'),
			'VIDEO_MONITOR_LAYOUT' => phodevi::read_property('monitor', 'layout'),
			'VIDEO_MONITOR_SIZES' => phodevi::read_property('monitor', 'modes'),
			'OPERATING_SYSTEM' => phodevi::read_property('system', 'vendor-identifier'),
			'OS_VERSION' => phodevi::read_property('system', 'os-version'),
			'OS_ARCH' => phodevi::read_property('system', 'kernel-architecture'),
			'OS_TYPE' => phodevi::operating_system(),
			'THIS_RUN_TIME' => PTS_INIT_TIME,
			'DEBUG_REAL_HOME' => pts_client::user_home_directory()
			);

			if(!pts_client::executable_in_path('cc') && pts_client::executable_in_path('gcc'))
			{
				// This helps some test profiles build correctly if they don't do a cc check internally
				$env_variables['CC'] = 'gcc';
			}
		}

		return $env_variables;
	}
	public static function test_install_root_path()
	{
		if(getenv('PTS_TEST_INSTALL_ROOT_PATH') != false && is_dir(getenv('PTS_TEST_INSTALL_ROOT_PATH')) && is_writable(getenv('PTS_TEST_INSTALL_ROOT_PATH')))
		{
			return getenv('PTS_TEST_INSTALL_ROOT_PATH');
		}
		else
		{
			return PTS_TEST_INSTALL_DEFAULT_PATH;
		}
	}
	public static function user_run_save_variables()
	{
		static $runtime_variables = null;

		if($runtime_variables == null)
		{
			$runtime_variables = array(
			'VIDEO_RESOLUTION' => phodevi::read_property('gpu', 'screen-resolution-string'),
			'VIDEO_CARD' => phodevi::read_name('gpu'),
			'VIDEO_DRIVER' => phodevi::read_property('system', 'display-driver-string'),
			'OPERATING_SYSTEM' => phodevi::read_property('system', 'operating-system'),
			'PROCESSOR' => phodevi::read_name('cpu'),
			'MOTHERBOARD' => phodevi::read_name('motherboard'),
			'CHIPSET' => phodevi::read_name('chipset'),
			'KERNEL_VERSION' => phodevi::read_property('system', 'kernel'),
			'COMPILER' => phodevi::read_property('system', 'compiler'),
			'HOSTNAME' => phodevi::read_property('system', 'hostname')
			);
		}

		return $runtime_variables;
	}
	public static function save_test_result($save_to = null, $save_results = null, $render_graphs = true, $result_identifier = null)
	{
		// Saves PTS result file
		if(substr($save_to, -4) != '.xml')
		{
			$save_to .= '.xml';
		}

		$save_to_dir = pts_client::setup_test_result_directory($save_to);

		if($save_to == null || $save_results == null)
		{
			$bool = false;
		}
		else
		{
			$save_name = basename($save_to, '.xml');

			if($save_name == 'composite' && $render_graphs)
			{
				pts_client::generate_result_file_graphs($save_results, $save_to_dir);
			}

			$bool = file_put_contents(PTS_SAVE_RESULTS_PATH . $save_to, $save_results);

			if($result_identifier != null && (pts_config::read_bool_config('PhoronixTestSuite/Options/Testing/SaveSystemLogs', 'TRUE') || (pts_c::$test_flags & pts_c::batch_mode) || (pts_c::$test_flags & pts_c::auto_mode)))
			{
				// Save verbose system information here
				$system_log_dir = $save_to_dir . '/system-logs/' . $result_identifier . '/';
				pts_file_io::mkdir($system_log_dir, 0777, true);

				// Backup system files
				// TODO: move out these files/commands to log out to respective Phodevi components so only what's relevant will be logged
				$system_log_files = array(
					'/var/log/Xorg.0.log',
					'/proc/cpuinfo',
					'/proc/meminfo',
					'/proc/modules',
					'/proc/mounts',
					'/proc/cmdline',
					'/proc/version',
					'/etc/X11/xorg.conf',
					'/sys/kernel/debug/dri/0/radeon_pm_info',
					'/sys/kernel/debug/dri/0/i915_capabilities',
					'/sys/kernel/debug/dri/0/i915_cur_delayinfo',
					'/sys/kernel/debug/dri/0/i915_drpc_info',
					'/sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies',
					);

				/*
				if(phodevi::is_linux())
				{
					// the kernel config file might just be too large to upload for now
					array_push($system_log_files, '/boot/config-' . php_uname('r'));
				}
				*/

				foreach($system_log_files as $file)
				{
					if(is_file($file) && is_readable($file))
					{
						// copy() can't be used in this case since it will result in a blank file for /proc/ file-system
						$file_contents = file_get_contents($file);
						$file_contents = pts_strings::remove_line_timestamps($file_contents);
						file_put_contents($system_log_dir . basename($file), $file_contents);
					}
				}

				// Generate logs from system commands to backup
				$system_log_commands = array(
					'lspci -mmkvvvnn',
					'lscpu',
					'cc -v',
					'lsusb',
					'lsmod',
					'sensors',
					'dmesg',
					'vdpauinfo',
					'cpufreq-info',
					'glxinfo',
					'clinfo',
					'uname -a',
					// 'udisks --dump',
					'upower --dump',
					);

				if(phodevi::is_bsd())
				{
					array_push($system_log_commands, 'sysctl -a');
					array_push($system_log_commands, 'kenv');
				}
				if(is_readable('/dev/mem'))
				{
					array_push($system_log_commands, 'dmidecode');
				}

				foreach($system_log_commands as $command_string)
				{
					$command = explode(' ', $command_string);

					if(($command_bin = pts_client::executable_in_path($command[0])))
					{
						$cmd_output = shell_exec('cd ' . dirname($command_bin) . ' && ./' . $command_string . ' 2>&1');

						// Try to filter out any serial numbers, etc.
						$cmd_output = pts_strings::remove_lines_containing($cmd_output, array('Serial N', 'S/N', 'Serial #', 'serial:', 'serial='));
						$cmd_output = pts_strings::remove_line_timestamps($cmd_output);

						file_put_contents($system_log_dir . $command[0], $cmd_output);
					}
				}

				// Dump some common / important environmental variables
				$environment_variables = array(
					'PATH' => null,
					'CFLAGS' => null,
					'CXXFLAGS' => null,
					'LD_LIBRARY_PATH' => null,
					'CC' => null,
					'CXX' => null,
					'LIBGL_DRIVERS_PATH' => null
					);

				foreach($environment_variables as $variable => &$value)
				{
					$v = getenv($variable);

					if($v != null)
					{
						$value = $v;
					}
					else
					{
						unset($environment_variables[$variable]);
					}
				}

				if(!empty($environment_variables))
				{
					$variable_dump = null;
					foreach($environment_variables as $variable => $value)
					{
						$variable_dump .= $variable . '=' . $value . PHP_EOL;
					}
					file_put_contents($system_log_dir . 'environment-variables', $variable_dump);
				}
			}
		}

		return $bool;
	}
	public static function save_result_file(&$result_file_writer, $save_name)
	{
		// Save the test file
		// TODO: clean this up with pts_client::save_test_result
		$j = 1;
		while(is_file(PTS_SAVE_RESULTS_PATH . $save_name . '/test-' . $j . '.xml'))
		{
			$j++;
		}

		$real_name = $save_name . '/test-' . $j . '.xml';

		pts_client::save_test_result($real_name, $result_file_writer->get_xml());

		if(!is_file(PTS_SAVE_RESULTS_PATH . $save_name . '/composite.xml'))
		{
			pts_client::save_test_result($save_name . '/composite.xml', file_get_contents(PTS_SAVE_RESULTS_PATH . $real_name), true, $result_file_writer->get_result_identifier());
		}
		else
		{
			// Merge Results
			$merged_results = pts_merge::merge_test_results(file_get_contents(PTS_SAVE_RESULTS_PATH . $save_name . '/composite.xml'), file_get_contents(PTS_SAVE_RESULTS_PATH . $real_name));
			pts_client::save_test_result($save_name . '/composite.xml', $merged_results, true, $result_file_writer->get_result_identifier());
		}

		return $real_name;
	}
	private static function basic_init_process()
	{
		// Initialize The Phoronix Test Suite

		// PTS Defines
		define('PHP_BIN', pts_client::read_env('PHP_BIN'));
		define('PTS_INIT_TIME', time());

		if(!defined('PHP_VERSION_ID'))
		{
			// PHP_VERSION_ID is only available in PHP 5.2.6 and later
			$php_version = explode('.', PHP_VERSION);
			define('PHP_VERSION_ID', ($php_version[0] * 10000 + $php_version[1] * 100 + $php_version[2]));
		}

		$dir_init = array(PTS_USER_PATH);
		foreach($dir_init as $dir)
		{
			pts_file_io::mkdir($dir);
		}
	}
	public static function init_display_mode($flags = 0)
	{
		$env_mode = ($flags & pts_c::debug_mode) ? 'BASIC' : false;

		switch(($env_mode != false || ($env_mode = pts_client::read_env('PTS_DISPLAY_MODE')) != false ? $env_mode : pts_config::read_user_config('PhoronixTestSuite/Options/General/DefaultDisplayMode', 'DEFAULT')))
		{
			case 'BASIC':
				self::$display = new pts_basic_display_mode();
				break;
			case 'BATCH':
			case 'CONCISE':
				self::$display = new pts_concise_display_mode();
				break;
			case 'DEFAULT':
			default:
				self::$display = new pts_concise_display_mode();
				break;
		}
	}
	private static function extended_init_process()
	{
		// Extended Initalization Process
		$directory_check = array(
			PTS_TEST_INSTALL_DEFAULT_PATH,
			PTS_SAVE_RESULTS_PATH,
			PTS_MODULE_LOCAL_PATH,
			PTS_MODULE_DATA_PATH,
			PTS_DOWNLOAD_CACHE_PATH,
			PTS_OPENBENCHMARKING_SCRATCH_PATH,
			PTS_TEST_PROFILE_PATH,
			PTS_TEST_SUITE_PATH,
			PTS_TEST_PROFILE_PATH . 'local/',
			PTS_TEST_SUITE_PATH . 'local/'
			);

		foreach($directory_check as $dir)
		{
			pts_file_io::mkdir($dir);
		}

		// Setup PTS Results Viewer
		pts_file_io::mkdir(PTS_SAVE_RESULTS_PATH . 'pts-results-viewer');

		foreach(pts_file_io::glob(PTS_RESULTS_VIEWER_PATH . '*') as $result_viewer_file)
		{
			copy($result_viewer_file, PTS_SAVE_RESULTS_PATH . 'pts-results-viewer/' . basename($result_viewer_file));
		}

		copy(PTS_CORE_STATIC_PATH . 'images/pts-106x55.png', PTS_SAVE_RESULTS_PATH . 'pts-results-viewer/pts-106x55.png');

		// Setup ~/.phoronix-test-suite/xsl/
		pts_file_io::mkdir(PTS_USER_PATH . 'xsl/');
		copy(PTS_CORE_STATIC_PATH . 'xsl/pts-test-installation-viewer.xsl', PTS_USER_PATH . 'xsl/' . 'pts-test-installation-viewer.xsl');
		copy(PTS_CORE_STATIC_PATH . 'xsl/pts-user-config-viewer.xsl', PTS_USER_PATH . 'xsl/' . 'pts-user-config-viewer.xsl');
		copy(PTS_CORE_STATIC_PATH . 'images/pts-308x160.png', PTS_USER_PATH . 'xsl/' . 'pts-logo.png');

		// pts_compatibility ops here

		pts_client::init_display_mode();
	}
	public static function program_requirement_checks($only_show_required = false)
	{
		$extension_checks = pts_needed_extensions();

		$printed_required_header = false;
		$printed_optional_header = false;
		foreach($extension_checks as $extension)
		{
			if($extension[1] == false)
			{
				if($extension[0] == 1)
				{
					// Oops, this extension is required
					if($printed_required_header == false)
					{
						echo PHP_EOL . 'The following PHP extensions are REQUIRED by the Phoronix Test Suite:' . PHP_EOL . PHP_EOL;
						$printed_required_header = true;
					}
				}
				else
				{
					if($only_show_required && $printed_required_header == false)
					{
						continue;
					}

					// This extension is missing but optional
					if($printed_optional_header == false)
					{
						echo PHP_EOL . ($printed_required_header ? null : 'NOTICE: ') . 'The following PHP extensions are OPTIONAL but recommended:' . PHP_EOL . PHP_EOL;
						$printed_optional_header = true;
					}
				}

				echo sprintf('%-8ls %-30ls' . PHP_EOL, $extension[2], $extension[3]);
			}
		}

		if($printed_required_header || $printed_optional_header)
		{
			echo PHP_EOL;

			if($printed_required_header)
			{
				exit;
			}
		}
	}
	private static function build_temp_cache()
	{
		$pso = pts_storage_object::recover_from_file(PTS_TEMP_STORAGE);

		if($pso == false)
		{
			$pso = new pts_storage_object();
		}

		$pso->add_object('environmental_variables_for_modules', pts_module_manager::modules_environmental_variables());
		$pso->add_object('vendor_alias_list', pts_external_dependencies::vendor_alias_list());
		$pso->add_object('command_alias_list', pts_documentation::client_commands_aliases());

		$pso->save_to_file(PTS_TEMP_STORAGE);
	}
	private static function core_storage_init_process()
	{
		$pso = pts_storage_object::recover_from_file(PTS_CORE_STORAGE);

		if($pso == false)
		{
			$pso = new pts_storage_object(true, true);
		}

		// OpenBenchmarking.org - GSID
		$global_gsid = $pso->read_object('global_system_id');
		$global_gsid_e = $pso->read_object('global_system_id_e');
		$global_gsid_p = $pso->read_object('global_system_id_p');

		if(empty($global_gsid) || pts_openbenchmarking::is_valid_gsid_format($global_gsid) == false)
		{
			// Global System ID for anonymous uploads, etc
			$requested_gsid = true;
			$global_gsid = pts_openbenchmarking_client::request_gsid();

			if(is_array($global_gsid))
			{
				$pso->add_object('global_system_id', $global_gsid['gsid']); // GSID
				$pso->add_object('global_system_id_p', $global_gsid['gsid_p']); // GSID_P
				$pso->add_object('global_system_id_e', $global_gsid['gsid_e']); // GSID_E
				define('PTS_GSID', $global_gsid['gsid']);
				define('PTS_GSID_E', $global_gsid['gsid_e']);
			}
		}
		else if(pts_openbenchmarking::is_valid_gsid_e_format($global_gsid_e) == false || pts_openbenchmarking::is_valid_gsid_e_format($global_gsid_p) == false)
		{
			define('PTS_GSID', $global_gsid);
			$requested_gsid = false;
			$global_gsid = pts_openbenchmarking_client::retrieve_gsid();

			if(is_array($global_gsid))
			{
				$pso->add_object('global_system_id_p', $global_gsid['gsid_p']); // GSID_P
				$pso->add_object('global_system_id_e', $global_gsid['gsid_e']); // GSID_E
				define('PTS_GSID_E', $global_gsid['gsid_e']);
			}
		}
		else
		{
			define('PTS_GSID', $global_gsid);
			define('PTS_GSID_E', $global_gsid_e);
			$requested_gsid = false;
		}

		// Last Run Processing
		$last_core_version = $pso->read_object('last_core_version');
		define('FIRST_RUN_ON_PTS_UPGRADE', ($last_core_version != PTS_CORE_VERSION));

		if(FIRST_RUN_ON_PTS_UPGRADE || ($pso->read_object('last_php_version') != phpversion()))
		{
			// Report any missing/recommended extensions
			self::program_requirement_checks();
		}

		if(FIRST_RUN_ON_PTS_UPGRADE)
		{
			if($requested_gsid == false)
			{
				pts_openbenchmarking_client::update_gsid();
			}

			pts_client::build_temp_cache();
		}
		$pso->add_object('last_core_version', PTS_CORE_VERSION); // PTS version last run
		$pso->add_object('last_php_version', phpversion()); // PHP version last run

		//$last_pts_version = $pso->read_object('last_pts_version');
		// do something here with $last_pts_version if you want that information
		$pso->add_object('last_pts_version', PTS_VERSION); // PTS version last run

		// Last Run Processing
		$last_run = $pso->read_object('last_run_time');
		define('IS_FIRST_RUN_TODAY', (substr($last_run, 0, 10) != date('Y-m-d')));
		$pso->add_object('last_run_time', date('Y-m-d H:i:s')); // Time PTS was last run


		// User Agreement Checking
		$agreement_cs = $pso->read_object('user_agreement_cs');

		$pso->add_object('user_agreement_cs', $agreement_cs); // User agreement check-sum

		// Phodevi Cache Handling
		$phodevi_cache = $pso->read_object('phodevi_smart_cache');

		if($phodevi_cache instanceof phodevi_cache && pts_flags::no_phodevi_cache() == false)
		{
			$phodevi_cache = $phodevi_cache->restore_cache(PTS_USER_PATH, PTS_CORE_VERSION);
			phodevi::set_device_cache($phodevi_cache);

			if(($external_phodevi_cache = pts_client::read_env('EXTERNAL_PHODEVI_CACHE')))
			{
				if(is_dir($external_phodevi_cache) && is_file($external_phodevi_cache . '/core.pt2so'))
				{
					$external_phodevi_cache .= '/core.pt2so';
				}

				if(is_file($external_phodevi_cache))
				{
					$external_phodevi_cache = pts_storage_object::force_recover_from_file($external_phodevi_cache);

					if($external_phodevi_cache != false)
					{
						$external_phodevi_cache = $external_phodevi_cache->read_object('phodevi_smart_cache');
						$external_phodevi_cache = $external_phodevi_cache->restore_cache(null, PTS_CORE_VERSION);

						if($external_phodevi_cache != false)
						{
							//unset($external_phodevi_cache['system']['operating-system']);
							//unset($external_phodevi_cache['system']['vendor-identifier']);
							phodevi::set_device_cache($external_phodevi_cache);
						}
					}
				}
			}
		}

		// Archive to disk
		$pso->save_to_file(PTS_CORE_STORAGE);
	}
	public static function user_agreement_check($command)
	{
		$pso = pts_storage_object::recover_from_file(PTS_CORE_STORAGE);

		if($pso == false)
		{
			return false;
		}

		$config_md5 = $pso->read_object('user_agreement_cs');
		$current_md5 = md5_file(PTS_PATH . 'pts-core/user-agreement.txt');

		if($config_md5 != $current_md5 || pts_config::read_user_config('PhoronixTestSuite/Options/OpenBenchmarking/AnonymousUsageReporting', 'UNKNOWN') == 'UNKNOWN')
		{
			$prompt_in_method = pts_client::check_command_for_function($command, 'pts_user_agreement_prompt');
			$user_agreement = file_get_contents(PTS_PATH . 'pts-core/user-agreement.txt');

			if($prompt_in_method)
			{
				$user_agreement_return = call_user_func(array($command, 'pts_user_agreement_prompt'), $user_agreement);

				if(is_array($user_agreement_return))
				{
					if(count($user_agreement_return) == 3)
					{
						list($agree, $usage_reporting, $hwsw_reporting) = $user_agreement_return;
					}
					else
					{
						$agree = array_shift($user_agreement_return);
						$usage_reporting = -1;
						$hwsw_reporting = -1;
					}
				}
				else
				{
					$agree = $user_agreement_return;
					$usage_reporting = -1;
					$hwsw_reporting = -1;
				}
			}

			if($prompt_in_method == false || $usage_reporting == -1 || $hwsw_reporting == -1)
			{
				pts_client::$display->generic_heading('User Agreement');
				echo wordwrap($user_agreement, 65);
				$agree = pts_flags::user_agreement_skip() || pts_user_io::prompt_bool_input('Do you agree to these terms and wish to proceed', true);

				if(pts_flags::no_openbenchmarking_reporting())
				{
					$usage_reporting = false;
					$hwsw_reporting = false;
				}
				else
				{
					$usage_reporting = $agree ? pts_user_io::prompt_bool_input('Enable anonymous usage / statistics reporting', true) : -1;
					$hwsw_reporting = $agree ? pts_user_io::prompt_bool_input('Enable anonymous statistical reporting of installed software / hardware', true) : -1;
				}
			}

			if($agree)
			{
				echo PHP_EOL;
				$pso->add_object('user_agreement_cs', $current_md5);
				$pso->save_to_file(PTS_CORE_STORAGE);
			}
			else
			{
				pts_client::exit_client('In order to run the Phoronix Test Suite, you must agree to the listed terms.');
			}

			pts_config::user_config_generate(array(
				'PhoronixTestSuite/Options/OpenBenchmarking/AnonymousUsageReporting' => pts_config::bool_to_string($usage_reporting),
				'PhoronixTestSuite/Options/OpenBenchmarking/AnonymousHardwareReporting' => pts_config::bool_to_string($hwsw_reporting),
				'PhoronixTestSuite/Options/OpenBenchmarking/AnonymousSoftwareReporting' => pts_config::bool_to_string($hwsw_reporting)
				));
		}
	}
	public static function swap_variables($user_str, $replace_call)
	{
		if(is_array($replace_call))
		{
			if(count($replace_call) != 2 || method_exists($replace_call[0], $replace_call[1]) == false)
			{
				echo PHP_EOL . 'Var Swap With Method Failed.' . PHP_EOL;
				return $user_str;
			}
		}
		else if(!function_exists($replace_call))
		{
			echo PHP_EOL . 'Var Swap With Function Failed.' . PHP_EOL;
			return $user_str;
		}

		$offset = 0;
		$replace_call_return = false;

		while($offset < strlen($user_str) && ($s = strpos($user_str, '$', $offset)) !== false)
		{
			$s++;
			$var_name = substr($user_str, $s, (($e = strpos($user_str, ' ', $s)) == false ? strlen($user_str) : $e) - $s);

			if($replace_call_return === false)
			{
				$replace_call_return = call_user_func($replace_call);
			}

			$var_replacement = isset($replace_call_return[$var_name]) ? $replace_call_return[$var_name] : null;

			if($var_replacement != null)
			{
				$user_str = str_replace('$' . $var_name, $var_replacement, $user_str);
			}
			else
			{
				// echo "\nVariable Swap For $var_name Failed.\n";
			}

			$offset = $s + strlen($var_replacement);
		}

		return $user_str;
	}
	public static function setup_test_result_directory($save_to)
	{
		$save_to_dir = PTS_SAVE_RESULTS_PATH . $save_to;

		if(strpos(basename($save_to_dir), '.'))
		{
			$save_to_dir = dirname($save_to_dir);
		}

		if($save_to_dir != '.')
		{
			pts_file_io::mkdir($save_to_dir);
		}

		file_put_contents($save_to_dir . '/index.html', '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN"><html><head><title>Phoronix Test Suite</title><meta http-equiv="REFRESH" content="0;url=composite.xml"></HEAD><BODY></BODY></HTML>');

		return $save_to_dir;
	}
	public static function remove_installed_test(&$test_profile)
	{
		pts_file_io::delete($test_profile->get_install_dir(), null, true);
	}
	public static function exit_client($string = null, $exit_status = 0)
	{
		// Exit the Phoronix Test Suite client
		define('PTS_EXIT', 1);

		if($string != null)
		{
			echo PHP_EOL . $string . PHP_EOL;
		}

		exit($exit_status);
	}
	public static function current_user()
	{
		// Current system user
		return ($pts_user = pts_openbenchmarking_client::user_name()) != null ? $pts_user : phodevi::read_property('system', 'username');
	}
	public static function user_home_directory()
	{
		// Gets the system user's home directory
		static $userhome = null;

		if($userhome == null)
		{
			if(function_exists('posix_getpwuid') && function_exists('posix_getuid'))
			{
				$userinfo = posix_getpwuid(posix_getuid());
				$userhome = $userinfo['dir'];
			}
			else if(($home = pts_client::read_env('HOME')))
			{
				$userhome = $home;
			}
			else if(($home = pts_client::read_env('HOMEPATH')))
			{
				$userhome = pts_client::read_env('HOMEDRIVE') . $home;
			}
			else
			{
				echo PHP_EOL . 'ERROR: Cannot find home directory.' . PHP_EOL;
				$userhome = null;
			}

			$userhome = pts_strings::add_trailing_slash($userhome);
		}

		return $userhome;
	}
	public static function test_profile_debug_message($message)
	{
		$reported = false;

		if((pts_c::$test_flags & pts_c::debug_mode))
		{
			pts_client::$display->test_run_instance_error($message);
			$reported = true;
		}

		return $reported;
	}
	public static function parse_home_directory($path)
	{
		// Find home directory if needed
		if(strpos($path, '~/') !== false)
		{
			$path = str_replace('~/', pts_client::user_home_directory(), $path);
		}

		return pts_strings::add_trailing_slash($path);
	}
	public static function xsl_results_viewer_graph_template()
	{
		$raw_xsl = file_get_contents(PTS_RESULTS_VIEWER_PATH . 'pts-results-viewer.xsl');

		// System Tables
		$conversions = array('systems', 'detailed_component', 'radar', 'overview', 'visualize');
		foreach($conversions as $convert)
		{
			$graph_string = pts_svg_dom::html_embed_code('result-graphs/' . $convert . '.BILDE_EXTENSION', 'SVG', array('width' => 'auto', 'height' => 'auto'), true);
			$raw_xsl = str_replace('<!-- ' . strtoupper($convert) . ' TAG -->', $graph_string, $raw_xsl);
		}

		// Result Graphs
		$graph_string = pts_svg_dom::html_embed_code('result-graphs/<xsl:number value="position()" />.BILDE_EXTENSION', 'SVG', array('width' => 'auto', 'height' => 'auto'), true);
		$raw_xsl = str_replace('<!-- GRAPH TAG -->', $graph_string, $raw_xsl);

		return $raw_xsl;
	}
	public static function generate_result_file_graphs($test_results_identifier, $save_to_dir = false)
	{
		if($save_to_dir)
		{
			if(pts_file_io::mkdir($save_to_dir . '/result-graphs') == false)
			{
				// Directory must exist, so remove any old graph files first
				foreach(pts_file_io::glob($save_to_dir . '/result-graphs/*') as $old_file)
				{
					unlink($old_file);
				}
			}
		}

		$result_file = new pts_result_file($test_results_identifier);

		$generated_graphs = array();
		$generated_graph_tables = false;

		// Render overview chart
		if($save_to_dir)
		{
			$chart = new pts_ResultFileTable($result_file);
			$chart->renderChart($save_to_dir . '/result-graphs/overview.BILDE_EXTENSION');

			$intent = -1;
			if(($intent = pts_result_file_analyzer::analyze_result_file_intent($result_file, $intent, true)) || $result_file->get_system_count() == 1)
			{
				$chart = new pts_ResultFileCompactSystemsTable($result_file, $intent);
			}
			else
			{
				$chart = new pts_ResultFileSystemsTable($result_file);
			}
			$chart->renderChart($save_to_dir . '/result-graphs/systems.BILDE_EXTENSION');
			unset($chart);

			if($intent && is_dir($save_to_dir . '/system-logs/'))
			{
				$chart = new pts_DetailedSystemComponentTable($result_file, $save_to_dir . '/system-logs/', $intent);

				if($chart)
				{
					$chart->renderChart($save_to_dir . '/result-graphs/detailed_component.BILDE_EXTENSION');
				}
			}
		}

		foreach($result_file->get_result_objects() as $key => $result_object)
		{
			$save_to = $save_to_dir;

			if($save_to_dir && is_dir($save_to_dir))
			{
				$save_to .= '/result-graphs/' . ($key + 1) . '.BILDE_EXTENSION';

				if(PTS_IS_CLIENT)
				{
					if($result_file->is_multi_way_comparison() || pts_client::read_env('GRAPH_GROUP_SIMILAR'))
					{
						$table_keys = array();
						$titles = $result_file->get_test_titles();

						foreach($titles as $this_title_index => $this_title)
						{
							if($this_title == $titles[$key])
							{
								array_push($table_keys, $this_title_index);
							}
						}
					}
					else
					{
						$table_keys = $key;
					}

					$chart = new pts_ResultFileTable($result_file, null, $table_keys);
					$chart->renderChart($save_to_dir . '/result-graphs/' . ($key + 1) . '_table.BILDE_EXTENSION');
					unset($chart);
					$generated_graph_tables = true;
				}
			}

			$graph = pts_render::render_graph($result_object, $result_file, $save_to);
			array_push($generated_graphs, $graph);
		}

		// Generate mini / overview graphs
		if($save_to_dir)
		{
			$graph = new pts_OverviewGraph($result_file);

			if($graph->doSkipGraph() == false)
			{
				$graph->renderGraph();

				// Check to see if skip_graph was realized during the rendering process
				if($graph->doSkipGraph() == false)
				{
					$graph->svg_dom->output($save_to_dir . '/result-graphs/visualize.BILDE_EXTENSION');
				}
			}
			unset($graph);

			$graph = new pts_RadarOverviewGraph($result_file);

			if($graph->doSkipGraph() == false)
			{
				$graph->renderGraph();

				// Check to see if skip_graph was realized during the rendering process
				if($graph->doSkipGraph() == false)
				{
					$graph->svg_dom->output($save_to_dir . '/result-graphs/radar.BILDE_EXTENSION');
				}
			}
			unset($graph);

			/*
			// TODO XXX: just stuffing some debug code here temporarily while working on block diagram code...
			$graph = new pts_BlockDiagramGraph($result_file);
			$graph->renderGraph();
			$graph->svg_dom->output($save_to_dir . '/result-graphs/blocks.BILDE_EXTENSION');
			*/
		}

		// Save XSL
		if(count($generated_graphs) > 0 && $save_to_dir)
		{
			file_put_contents($save_to_dir . '/pts-results-viewer.xsl', pts_client::xsl_results_viewer_graph_template($generated_graph_tables));
		}

		return $generated_graphs;
	}
	public static function process_shutdown_tasks()
	{
		// TODO: possibly do something like posix_getpid() != pts_client::$startup_pid in case shutdown function is called from a child process

		// Generate Phodevi Smart Cache
		if(pts_flags::no_phodevi_cache() == false && pts_client::read_env('EXTERNAL_PHODEVI_CACHE') == false)
		{
			if(pts_config::read_bool_config('PhoronixTestSuite/Options/General/UsePhodeviCache', 'TRUE'))
			{
				pts_storage_object::set_in_file(PTS_CORE_STORAGE, 'phodevi_smart_cache', phodevi::get_phodevi_cache_object(PTS_USER_PATH, PTS_CORE_VERSION));
			}
			else
			{
				pts_storage_object::set_in_file(PTS_CORE_STORAGE, 'phodevi_smart_cache', null);
			}
		}

		if(is_array(self::$lock_pointers))
		{
			foreach(array_keys(self::$lock_pointers) as $lock_file)
			{
				self::release_lock($lock_file);
			}
		}
	}
	public static function do_anonymous_usage_reporting()
	{
		return pts_config::read_bool_config('PhoronixTestSuite/Options/OpenBenchmarking/AnonymousUsageReporting', 0);
	}
	public static function release_lock($lock_file)
	{
		// Remove lock
		if(isset(self::$lock_pointers[$lock_file]) == false)
		{
			return false;
		}

		if(is_resource(self::$lock_pointers[$lock_file]))
		{
			fclose(self::$lock_pointers[$lock_file]);
		}

		pts_file_io::unlink($lock_file);
		unset(self::$lock_pointers[$lock_file]);
	}
	public static function check_command_for_function($option, $check_function)
	{
		$in_option = false;

		if(is_file(PTS_COMMAND_PATH . $option . '.php'))
		{
			if(!class_exists($option, false) && is_file(PTS_COMMAND_PATH . $option . '.php'))
			{
				include(PTS_COMMAND_PATH . $option . '.php');
			}

			if(method_exists($option, $check_function))
			{
				$in_option = true;
			}
		}

		return $in_option;
	}
	public static function regenerate_graphs($result_file_identifier, $full_process_string = false, $extra_graph_attributes = null)
	{
		$save_to_dir = pts_client::setup_test_result_directory($result_file_identifier);
		$generated_graphs = pts_client::generate_result_file_graphs($result_file_identifier, $save_to_dir, false, $extra_graph_attributes);
		$generated = count($generated_graphs) > 0;

		if($generated && $full_process_string)
		{
			echo PHP_EOL . $full_process_string . PHP_EOL;
			pts_client::display_web_page(PTS_SAVE_RESULTS_PATH . $result_file_identifier . '/index.html');
		}

		return $generated;
	}
	public static function set_test_flags($test_flags = 0)
	{
		pts_c::$test_flags = $test_flags;
	}
	public static function execute_command($command, $pass_args = null)
	{
		if(!class_exists($command, false) && is_file(PTS_COMMAND_PATH . $command . '.php'))
		{
			include(PTS_COMMAND_PATH . $command . '.php');
		}

		if(is_file(PTS_COMMAND_PATH . $command . '.php') && method_exists($command, 'argument_checks'))
		{
			$argument_checks = call_user_func(array($command, 'argument_checks'));

			foreach($argument_checks as &$argument_check)
			{
				$function_check = $argument_check->get_function_check();
				$method_check = false;

				if(is_array($function_check) && count($function_check) == 2)
				{
					$method_check = $function_check[0];
					$function_check = $function_check[1];
				}

				if(substr($function_check, 0, 1) == '!')
				{
					$function_check = substr($function_check, 1);
					$return_fails_on = true;
				}
				else
				{
					$return_fails_on = false;
				}

				
				if($method_check != false)
				{
					if(!method_exists($method_check, $function_check))
					{
						echo PHP_EOL . 'Method check fails.' . PHP_EOL;
						continue;
					}

					$function_check = array($method_check, $function_check);
				}
				else if(!function_exists($function_check))
				{
					continue;
				}

				if($argument_check->get_argument_index() == 'VARIABLE_LENGTH')
				{
					$return_value = null;

					foreach($pass_args as $arg)
					{
						$return_value = call_user_func_array($function_check, array($arg));

						if($return_value == true)
						{
							break;
						}
					}

				}
				else
				{
					$return_value = call_user_func_array($function_check, array((isset($pass_args[$argument_check->get_argument_index()]) ? $pass_args[$argument_check->get_argument_index()] : null)));
				}

				if($return_value == $return_fails_on)
				{
					$command_alias = defined($command . '::doc_use_alias') ? constant($command . '::doc_use_alias') : $command;

					if((isset($pass_args[$argument_check->get_argument_index()]) && !empty($pass_args[$argument_check->get_argument_index()])) || ($argument_check->get_argument_index() == 'VARIABLE_LENGTH' && !empty($pass_args)))
					{
						pts_client::$display->generic_error('Invalid Argument: ' . implode(' ', $pass_args));
					}
					else
					{
						pts_client::$display->generic_error('Argument Missing.');
					}

					echo 'CORRECT SYNTAX:' . PHP_EOL . 'phoronix-test-suite ' . str_replace('_', '-', $command_alias) . ' ' . implode(' ', $argument_checks) . PHP_EOL . PHP_EOL;

					if(method_exists($command, 'invalid_command'))
					{
						call_user_func_array(array($command, 'invalid_command'), $pass_args);
						echo PHP_EOL;
					}

					return false;
				}
				else
				{
					if($argument_check->get_function_return_key() != null && !isset($pass_args[$argument_check->get_function_return_key()]))
					{
						$pass_args[$argument_check->get_function_return_key()] = $return_value;
					}
				}
			}
		}

		pts_module_manager::module_process('__pre_option_process', $command);

		if(is_file(PTS_COMMAND_PATH . $command . '.php'))
		{
			if(method_exists($command, 'run'))
			{
				call_user_func(array($command, 'run'), $pass_args);
			}
			else
			{
				echo PHP_EOL . 'There is an error in the requested command: ' . $command . PHP_EOL . PHP_EOL;
			}
		}
		else if(($t = pts_module::valid_run_command($command)) != false)
		{
			list($module, $module_command) = $t;
			pts_module_manager::set_current_module($module);
			pts_module_manager::run_command($module, $module_command, $pass_args);
			pts_module_manager::set_current_module(null);
		}
		echo PHP_EOL;

		pts_module_manager::module_process('__post_option_process', $command);
	}
	public static function terminal_width()
	{
		static $terminal_width = null;

		if($terminal_width == null)
		{
			$chars = -1;

			if(pts_client::executable_in_path('tput'))
			{
				$terminal_width = trim(shell_exec('tput cols 2>&1'));

				if(is_numeric($terminal_width) && $terminal_width > 1)
				{
					$chars = $terminal_width;
				}
			}
			else if(phodevi::is_windows())
			{
				// Need a better way to handle this
				$chars = 80;
			}

			$terminal_width = $chars;
		}

		return $terminal_width;
	}
	public static function user_hardware_software_reporting()
	{
		$hw_reporting = pts_config::read_bool_config('PhoronixTestSuite/Options/OpenBenchmarking/AnonymousHardwareReporting', 'FALSE');
		$sw_reporting = pts_config::read_bool_config('PhoronixTestSuite/Options/OpenBenchmarking/AnonymousSoftwareReporting', 'FALSE');

		if($hw_reporting == false && $sw_reporting == false)
		{
			return;
		}

		$hw = array();
		$sw = array();
		$pso = pts_storage_object::recover_from_file(PTS_CORE_STORAGE);

		if($hw_reporting)
		{
			$hw = array();
			foreach(pts_openbenchmarking::stats_hardware_list() as $key => $value)
			{
				if(count($value) == 2)
				{
					$hw[$key] = phodevi::read_property($value[0], $value[1]);
				}
				else
				{
					$hw[$key] = phodevi::read_name($value[0]);
				}
			}

			$hw_prev = $pso->read_object('global_reported_hw');
			$pso->add_object('global_reported_hw', $hw);

			if(is_array($hw_prev))
			{
				$hw = array_diff_assoc($hw, $hw_prev);
			}

			// Check the PCI devices
			$pci = phodevi::read_property('motherboard', 'pci-devices');
			$pci_prev = $pso->read_object('global_reported_pci');
			$pso->add_object('global_reported_pci', $pci);

			if(!empty($pci_prev) && is_array($pci_prev) && is_array($pci))
			{
				if($pci == $pci_prev)
				{
					$pci = null;
				}
				else
				{
					$pci = array_diff($pci, $pci_prev);
				}
			}

			if(!empty($pci))
			{
				pts_openbenchmarking_client::upload_pci_data($pci);
			}

			// Check the USB devices
			$usb = phodevi::read_property('motherboard', 'usb-devices');
			$usb_prev = $pso->read_object('global_reported_usb');
			$pso->add_object('global_reported_usb', $usb);

			if(!empty($usb_prev) && is_array($usb_prev) && is_array($usb) && $usb != $usb_prev)
			{
				pts_openbenchmarking_client::upload_usb_data($usb);
			}
		}
		if($sw_reporting)
		{
			$sw = array();
			foreach(pts_openbenchmarking::stats_software_list() as $key => $value)
			{
				if(count($value) == 2)
				{
					$sw[$key] = phodevi::read_property($value[0], $value[1]);
				}
				else
				{
					$sw[$key] = phodevi::read_name($value[0]);
				}
			}
			$sw_prev = $pso->read_object('global_reported_sw');
			$pso->add_object('global_reported_sw', $sw);

			if(is_array($sw_prev))
			{
				$sw = array_diff_assoc($sw, $sw_prev);
			}
		}

		$to_report = array_merge($hw, $sw);
		$pso->save_to_file(PTS_CORE_STORAGE);

		if(!empty($to_report))
		{
			pts_openbenchmarking_client::upload_hwsw_data($to_report);
		}				
	}
	public static function is_process_running($process)
	{
		if(phodevi::is_linux())
		{
			// Checks if process is running on the system
			$running = shell_exec('ps -C ' . strtolower($process) . ' 2>&1');
			$running = trim(str_replace(array('PID', 'TTY', 'TIME', 'CMD'), '', $running));
		}
		else if(phodevi::is_solaris())
		{
			// Checks if process is running on the system
			$ps = shell_exec('ps -ef 2>&1');
			$running = strpos($ps, ' ' . strtolower($process)) != false ? 'TRUE' : null;
		}
		else if(pts_client::executable_in_path('ps') != false)
		{
			// Checks if process is running on the system
			$ps = shell_exec('ps -ax 2>&1');
			$running = strpos($ps, ' ' . strtolower($process)) != false ? 'TRUE' : null;
		}
		else
		{
			$running = null;
		}

		return !empty($running);
	}
	public static function parse_value_string_double_identifier($value_string)
	{
		// i.e. with PRESET_OPTIONS='stream.run-type=Add'
		$values = array();

		foreach(explode(';', $value_string) as $preset)
		{
			if(count($preset = pts_strings::trim_explode('=', $preset)) == 2)
			{
				if(count($preset[0] = pts_strings::trim_explode('.', $preset[0])) == 2)
				{
					$values[$preset[0][0]][$preset[0][1]] = $preset[1];
				}
			}
		}

		return $values;
	}
	public static function create_temporary_file()
	{
		return tempnam(pts_client::temporary_directory(), 'PTS');
	}
	public static function temporary_directory()
	{
		if(PHP_VERSION_ID >= 50210)
		{
			$dir = sys_get_temp_dir();
		}
		else
		{
			$dir = '/tmp'; // Assume /tmp
		}

		return $dir;
	}
	public static function read_env($var)
	{
		return getenv($var);
	}
	public static function pts_set_environment_variable($name, $value)
	{
		// Sets an environmental variable
		return getenv($name) == false && putenv($name . '=' . $value);
	}
	public static function shell_exec($exec, $extra_vars = null)
	{
		// Same as shell_exec() but with the PTS env variables added in
		// Convert pts_client::environmental_variables() into shell export variable syntax

		$var_string = '';
		$extra_vars = ($extra_vars == null ? pts_client::environmental_variables() : array_merge(pts_client::environmental_variables(), $extra_vars));

		foreach(array_keys($extra_vars) as $key)
		{
			$var_string .= 'export ' . $key . '=' . $extra_vars[$key] . ';';
		}

		$var_string .= ' ';

		return shell_exec($var_string . $exec);
	}
	public static function executable_in_path($executable)
	{
		static $cache = null;

		if(!isset($cache[$executable]))
		{
			$paths = pts_strings::trim_explode((phodevi::is_windows() ? ';' : ':'), (($path = pts_client::read_env('PATH')) == false ? '/usr/bin:/usr/local/bin' : $path));
			$executable_path = false;

			foreach($paths as $path)
			{
				$path = pts_strings::add_trailing_slash($path);

				if(is_executable($path . $executable))
				{
					$executable_path = $path . $executable;
					break;
				}
			}

			$cache[$executable] = $executable_path;
		}

		return $cache[$executable];
	}
	public static function display_web_page($URL, $alt_text = null, $default_open = false, $auto_open = false)
	{
		if(((pts_c::$test_flags & pts_c::auto_mode) && $auto_open == false && $default_open == false) || (pts_client::read_env('DISPLAY') == false && phodevi::is_windows() == false && phodevi::is_macosx() == false))
		{
			return;
		}

		// Launch the web browser
		$text = $alt_text == null ? 'Do you want to view the results in your web browser' : $alt_text;

		if($auto_open == false)
		{
			if((pts_c::$test_flags & pts_c::batch_mode))
			{
				$view_results = pts_config::read_bool_config('PhoronixTestSuite/Options/BatchMode/OpenBrowser', 'FALSE');
			}
			else
			{
				$view_results = pts_user_io::prompt_bool_input($text, $default_open);
			}
		}
		else
		{
			$view_results = true;
		}

		if($view_results)
		{
			static $browser = null;

			if($browser == null)
			{
				$config_browser = pts_config::read_user_config('PhoronixTestSuite/Options/General/DefaultBrowser', null);

				if($config_browser != null && (is_executable($config_browser) || ($config_browser = pts_client::executable_in_path($config_browser))))
				{
					$browser = $config_browser;
				}
				else if(phodevi::is_windows())
				{
					$windows_browsers = array(
						'C:\Program Files (x86)\Mozilla Firefox\firefox.exe',
						'C:\Program Files\Internet Explorer\iexplore.exe'
						);

					foreach($windows_browsers as $browser_test)
					{
						if(is_executable($browser_test))
						{
							$browser = $browser_test;
							break;
						}
					}

					if(substr($URL, 0, 1) == '\\')
					{
						$URL = 'file:///C:' . str_replace('/', '\\', $URL);
					}
				}
				else
				{
					$possible_browsers = array('epiphany', 'firefox', 'mozilla', 'x-www-browser', 'open', 'xdg-open', 'iceweasel', 'konqueror');

					foreach($possible_browsers as &$b)
					{
						if(($b = pts_client::executable_in_path($b)))
						{
							$browser = $b;
							break;
						}
					}
				}
			}

			if($browser != null)
			{
				shell_exec($browser . ' "' . $URL . '" 2> /dev/null &');
			}
			else
			{
				echo PHP_EOL . 'No Web Browser Found.' . PHP_EOL;
			}
		}
	}
	public static function cache_hardware_calls()
	{
		phodevi::system_hardware(true);
		phodevi::supported_sensors();
		phodevi::unsupported_sensors();
	}
	public static function cache_software_calls()
	{
		phodevi::system_software(true);
	}
	public static function remove_saved_result_file($identifier)
	{
		pts_file_io::delete(PTS_SAVE_RESULTS_PATH . $identifier, null, true);
	}
	public static function saved_test_results()
	{
		$results = array();
		$ignore_ids = array();

		foreach(pts_file_io::glob(PTS_SAVE_RESULTS_PATH . '*/composite.xml') as $result_file)
		{
			$identifier = basename(dirname($result_file));

			if(!in_array($identifier, $ignore_ids))
			{
				array_push($results, $identifier);
			}
		}

		return $results;
	}
	public static function code_error_handler($error_code, $error_string, $error_file, $error_line)
	{
		if(($error_code & (E_USER_ERROR | E_USER_WARNING | E_USER_NOTICE)))
		{
			// It's a self-generated error by pts-core code intentionally
			return self::user_error_handler($error_code, $error_string, $error_file, $error_line);
		}

		/*if(!(error_reporting() & $error_code))
		{
			return;
		}*/

		switch($error_code)
		{
			case E_ERROR:
			case E_PARSE:
				$error_type = 'ERROR';
				break;
			case E_WARNING:
			case E_NOTICE:
				if(($s = strpos($error_string, 'Undefined ')) !== false && ($x = strpos($error_string, ': ', $s)) !== false)
				{
					$error_string = 'Undefined: ' . substr($error_string, ($x + 2));
				}
				else if(strpos($error_string, 'Name or service not known') !== false || strpos($error_string, 'HTTP request failed') !== false || strpos($error_string, 'fopen') !== false || strpos($error_string, 'file_get_contents') !== false || strpos($error_string, 'Directory not empty') !== false)
				{
					// Don't report network errors
					return;
				}
				$error_type = 'NOTICE';
				break;
			default:
				$error_type = $error_code;
				break;
		}

		echo PHP_EOL . '[' . $error_type . '] ' . $error_string . ' in ' . basename($error_file) . ':' . $error_line . PHP_EOL;

		if($error_type == 'ERROR')
		{
			exit(1);
		}
	}
	public static function user_error_handler($error_code, $error_string, $error_file, $error_line)
	{
/*

		trigger_error('Scheisse', E_USER_WARNING);
		trigger_error('Okay', E_USER_NOTICE);
		trigger_error('F', E_USER_ERROR);
*/
		switch($error_code)
		{
			case E_USER_ERROR:
				$error_type = 'ERROR';
				break;
			case E_USER_NOTICE:
				if(pts_client::is_client_debug_mode() == false)
				{
					return;
				}
				$error_type = 'NOTICE';
				break;
			case E_USER_WARNING:
				$error_type = 'NOTICE'; // Yes, report warnings as a notice label
				break;
		}

		echo '[' . $error_type . '] ' . $error_string . (pts_client::is_client_debug_mode() ? ' in ' . basename($error_file) . ':' . $error_line : null) . PHP_EOL;
		return;
	}
	public static function is_client_debug_mode()
	{
		return false; // TODO
	}
}

// Some extra magic
set_error_handler(array('pts_client', 'code_error_handler'));

if(PTS_IS_CLIENT && (PTS_IS_DEV_BUILD || pts_client::is_client_debug_mode()))
{
	// Enable more verbose error reporting only when PTS is in development with milestone (alpha/beta) releases but no release candidate (r) or gold versions
	error_reporting(E_ALL | E_NOTICE | E_STRICT);
}

?>
