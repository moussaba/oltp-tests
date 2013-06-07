<?php

/*
	Phoronix Test Suite
	URLs: http://www.phoronix.com, http://www.phoronix-test-suite.com/
	Copyright (C) 2009 - 2012, Phoronix Media
	Copyright (C) 2009 - 2012, Michael Larabel

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

class pts_test_run_manager
{
	public $result_file_writer = null;

	private $tests_to_run = array();
	private $failed_tests_to_run = array();
	private $last_test_run_index = 0;
	private $test_run_pos = 0;
	private $test_run_count = 0;

	private $file_name = null;
	private $file_name_title = null;
	private $results_identifier = null;
	private $run_description = null;

	private $force_save_results = false;
	private $prompt_save_results = true;
	private $post_run_message = null;
	private $pre_run_message = null;
	private $allow_sharing_of_results = true;
	private $auto_upload_to_openbenchmarking = false;
	private $is_pcqs = false;

	private $do_dynamic_run_count = false;
	private $dynamic_run_count_on_length_or_less;
	private $dynamic_run_count_std_deviation_threshold;
	private $dynamic_run_count_export_script;

	private static $test_run_process_active = false;

	public function __construct($test_flags = 0)
	{
		pts_client::set_test_flags($test_flags);

		$this->do_dynamic_run_count = pts_config::read_bool_config('PhoronixTestSuite/Options/TestResultValidation/DynamicRunCount', 'TRUE');
		$this->dynamic_run_count_on_length_or_less = pts_config::read_user_config('PhoronixTestSuite/Options/TestResultValidation/LimitDynamicToTestLength', 20);
		$this->dynamic_run_count_std_deviation_threshold = pts_config::read_user_config('PhoronixTestSuite/Options/TestResultValidation/StandardDeviationThreshold', 3.50);
		$this->dynamic_run_count_export_script = pts_config::read_user_config('PhoronixTestSuite/Options/TestResultValidation/ExportResultsTo', null);

		pts_module_manager::module_process('__run_manager_setup', $this);
	}
	public function is_pcqs()
	{
		return $this->is_pcqs;
	}
	public function do_dynamic_run_count()
	{
		return $this->do_dynamic_run_count;
	}
	public function auto_upload_to_openbenchmarking($do = true)
	{
		$this->auto_upload_to_openbenchmarking = ($do == true);
	}
	public function increase_run_count_check(&$test_results, $scheduled_times_to_run, $latest_test_run_time)
	{
		// First make sure this test doesn't take too long to run where we don't want dynamic handling
		if(floor($latest_test_run_time / 60) > $this->dynamic_run_count_on_length_or_less)
		{
			return false;
		}

		// Determine if results are statistically significant, otherwise up the run count
		$std_dev = pts_math::percent_standard_deviation($test_results->test_result_buffer->get_values());
		if($std_dev >= $this->dynamic_run_count_std_deviation_threshold)
		{
			static $last_run_count = 128; // just a number that should always cause the first check below to be true
			static $run_std_devs;
			$times_already_ran = $test_results->test_result_buffer->get_count();

			if($times_already_ran <= $last_run_count)
			{
				// We're now onto a new test so clear out the array
				$run_std_devs = array();
			}
			$last_run_count = $times_already_ran;
			$run_std_devs[$last_run_count] = $std_dev;

			// If we haven't reached scheduled times to run x 2, increase count straight away
			if($times_already_ran < ($scheduled_times_to_run * 2))
			{
				return true;
			}
			else if($times_already_ran < ($scheduled_times_to_run * 3))
			{
				// More aggressive determination whether to still keep increasing the run count
				$first_and_now_diff = pts_arrays::first_element($run_std_devs) - pts_arrays::last_element($run_std_devs);

				// Increasing the run count at least looks to be helping...
				if($first_and_now_diff > (pts_arrays::first_element($run_std_devs) / 2))
				{
					// If we are at least making progress in the right direction, increase the run count some more
					return true;
				}

				// TODO: could add more checks and take better advantage of the array of data to better determine if it's still worth increasing
			}

		}

		// Check to see if there is an external/custom script to export the results to in determining whether results are valid
		if(($ex_file = $this->dynamic_run_count_export_script) != null && is_executable($ex_file) || is_executable(($ex_file = PTS_USER_PATH . $this->dynamic_run_count_export_script)))
		{
			$exit_status = trim(shell_exec($ex_file . ' ' . $test_results->test_result_buffer->get_values_as_string() . ' > /dev/null 2>&1; echo $?'));

			switch($exit_status)
			{
				case 1:
					// Run the test again
					return true;
				case 2:
					// Results are bad, abandon testing and do not record results
					return -1;
				case 0:
				default:
					// Return was 0 or something else, results are valid, or was some other exit status
					break;
			}
		}

		// No reason to increase the run count with none of the previous checks requesting otherwise
		return false;
	}
	protected function add_test_result_object(&$test_result)
	{
		if($this->validate_test_to_run($test_result->test_profile))
		{
			pts_arrays::unique_push($this->tests_to_run, $test_result);
		}
	}
	public function get_tests_to_run()
	{
		return $this->tests_to_run;
	}
	public function get_tests_to_run_identifiers()
	{
		$identifiers = array();

		foreach($this->tests_to_run as $test_run_request)
		{
			array_push($identifiers, $test_run_request->test_profile->get_identifier());
		}

		array_unique($identifiers);

		return $identifiers;
	}
	public function get_estimated_run_time($index = -1)
	{
		if($index == -1)
		{
			$index = $this->last_test_run_index;
		}

		$estimated_time = 0;
		for($i = $index; $i < count($this->tests_to_run); $i++)
		{
			$estimated_time += $this->tests_to_run[$i]->test_profile->get_estimated_run_time();
		}

		return $estimated_time;
	}
	public function get_test_to_run($index)
	{
		$this->last_test_run_index = $index;
		return isset($this->tests_to_run[$index]) ? $this->tests_to_run[$index] : false;
	}
	public function get_test_count()
	{
		return count($this->tests_to_run);
	}
	public function force_results_save()
	{
		$this->force_save_results = true;
	}
	protected function do_save_results()
	{
		return $this->file_name != null;
	}
	public function get_file_name()
	{
		return $this->file_name;
	}
	public function get_title()
	{
		return $this->file_name_title;
	}
	public function get_results_identifier()
	{
		return $this->results_identifier;
	}
	public function get_description()
	{
		return $this->run_description;
	}
	public function get_notes()
	{
		return null; // TODO: Not Yet Implemented
	}
	public function get_internal_tags()
	{
		return null;
	}
	public function get_reference_id()
	{
		return null;
	}
	public function get_preset_environment_variables()
	{
		return pts_module_manager::var_store_string();
	}
	public function result_already_contains_identifier()
	{
		$result_file = new pts_result_file($this->file_name);
		return in_array($this->results_identifier, $result_file->get_system_identifiers());
	}
	public function set_save_name($save_name, $is_new_save = true)
	{
		if(empty($save_name))
		{
			$save_name = date('Y-m-d-Hi');
		}

		$this->file_name = self::clean_save_name($save_name, $is_new_save);
		$this->file_name_title = $save_name;
		$this->force_save_results = true;
	}
	public function set_results_identifier($identifier)
	{
		$this->results_identifier = self::clean_results_identifier($identifier);
	}
	public static function recently_saved_test_results()
	{
		$recent_results = array();
		foreach(pts_file_io::glob(PTS_SAVE_RESULTS_PATH . '*/composite.xml') as $composite)
		{
			$recent_results[filemtime($composite)] = basename(dirname($composite));
		}

		if(count($recent_results) > 0)
		{
			krsort($recent_results);
			$recent_results = array_slice($recent_results, 0, 4, true);
			$res_length = strlen(pts_strings::find_longest_string($recent_results)) + 2;
			$current_time = time();

			foreach($recent_results as $m_time => &$recent_result)
			{
				$days = floor(($current_time - $m_time) / 86400);
				$recent_result = sprintf('%-' . $res_length . 'ls [%-ls]', $recent_result, ($days == 0 ? 'Today' : pts_strings::days_ago_format_string($days) . ' old'));
			}
			echo PHP_EOL . 'Recently Saved Test Results:' . PHP_EOL;
			echo pts_user_io::display_text_list($recent_results) . PHP_EOL;
			return true;
		}

		return false;
	}
	public function prompt_save_name()
	{
		if($this->file_name != null)
		{
			return;
		}

		// Prompt to save a file when running a test
		$save_name = null;

		if(($env = pts_client::read_env('TEST_RESULTS_NAME')))
		{
			$save_name = $env;
			//echo 'Saving Results To: ' . $proposed_name . PHP_EOL;
		}

		if((pts_c::$test_flags ^ pts_c::batch_mode) || pts_config::read_bool_config('PhoronixTestSuite/Options/BatchMode/PromptSaveName', 'FALSE'))
		{
			$is_reserved_word = false;
			// Be of help to the user by showing recently saved test results
			if($save_name == null)
			{
				self::recently_saved_test_results();

			}

			while(empty($save_name) || ($is_reserved_word = pts_types::is_test_or_suite($save_name)))
			{
				if($is_reserved_word)
				{
					echo PHP_EOL . 'The name of the saved file cannot be the same as a test/suite: ' . $save_name . PHP_EOL;
					$is_reserved_word = false;
				}

				pts_client::$display->generic_prompt('Enter a name to save these results under: ');
				$save_name = pts_user_io::read_user_input();
			}
		}

		$this->set_save_name($save_name);
	}
	public function prompt_results_identifier()
	{
		// Prompt for a results identifier
		$results_identifier = null;
		$show_identifiers = array();
		$no_repeated_tests = true;

		if(pts_result_file::is_test_result_file($this->file_name))
		{
			$result_file = new pts_result_file($this->file_name);
			$current_identifiers = $result_file->get_system_identifiers();
			$current_hardware = $result_file->get_system_hardware();
			$current_software = $result_file->get_system_software();

			$result_objects = $result_file->get_result_objects();

			foreach(array_keys($result_objects) as $result_key)
			{
				$result_objects[$result_key] = $result_objects[$result_key]->get_comparison_hash(false);
			}

			foreach($this->tests_to_run as &$run_request)
			{
				if($run_request instanceof pts_test_result && in_array($run_request->get_comparison_hash(), $result_objects))
				{
					$no_repeated_tests = false;
					break;
				}
			}
		}
		else
		{
			$current_identifiers = array();
			$current_hardware = array();
			$current_software = array();
		}

		if((pts_c::$test_flags ^ pts_c::batch_mode) || pts_config::read_bool_config('PhoronixTestSuite/Options/BatchMode/PromptForTestIdentifier', 'TRUE') && (pts_c::$test_flags ^ pts_c::auto_mode) && (pts_c::$test_flags ^ pts_c::is_recovering))
		{
			if(count($current_identifiers) > 0)
			{
				echo PHP_EOL . 'Current Test Identifiers:' . PHP_EOL;
				echo pts_user_io::display_text_list($current_identifiers);
				echo PHP_EOL;
			}

			$times_tried = 0;
			do
			{
				if($times_tried == 0 && ($env_identifier = pts_client::read_env('TEST_RESULTS_IDENTIFIER')))
				{
					$results_identifier = isset($env_identifier) ? $env_identifier : null;
					echo 'Test Identifier: ' . self::clean_results_identifier($results_identifier) . PHP_EOL;
				}
				else if((pts_c::$test_flags ^ pts_c::auto_mode))
				{
					pts_client::$display->generic_prompt('Enter a unique name to describe this test run / configuration: ');
					$results_identifier = self::clean_results_identifier(pts_user_io::read_user_input());
				}
				$times_tried++;

				$identifier_pos = (($p = array_search($results_identifier, $current_identifiers)) !== false ? $p : -1);

				if((pts_c::$test_flags & pts_c::auto_mode))
				{
					// Make sure if in auto-mode we don't get stuck in a loop
					break;
				}
			}
			while((!$no_repeated_tests && $identifier_pos != -1) || (isset($current_hardware[$identifier_pos]) && $current_hardware[$identifier_pos] != phodevi::system_hardware(true)) || (isset($current_software[$identifier_pos]) && $current_software[$identifier_pos] != phodevi::system_software(true)));
		}

		if(empty($results_identifier))
		{
			// If the save result identifier is empty, try to come up with something based upon the tests being run.
			$subsystem_r = array();
			$subsystems_to_test = $this->subsystems_under_test();

			if(pts_result_file::is_test_result_file($this->file_name))
			{
				$result_file = new pts_result_file($this->file_name);
				$result_file_intent = pts_result_file_analyzer::analyze_result_file_intent($result_file);

				if(is_array($result_file_intent) && $result_file_intent[0] != 'Unknown')
				{
					array_unshift($subsystems_to_test, $result_file_intent[0]);
				}
			}

			foreach($subsystems_to_test as $subsystem)
			{
				$components = pts_result_file_analyzer::system_component_string_to_array(phodevi::system_hardware(true) . ', ' . phodevi::system_software(true));
				if(isset($components[$subsystem]))
				{
					$subsystem_name = pts_strings::trim_search_query($components[$subsystem]);

					if(phodevi::is_vendor_string($subsystem_name) && !in_array($subsystem_name, $subsystem_r))
					{
						array_push($subsystem_r, $subsystem_name);
					}
					if(isset($subsystem_r[2]) || isset($subsystem_name[19]))
					{
						break;
					}
				}
			}

			if(isset($subsystem_r[0]))
			{
				$results_identifier = implode(' - ', $subsystem_r);
			}

			if(empty($results_identifier))
			{
				$results_identifier = date('Y-m-d H:i');
			}
		}

		$this->results_identifier = $results_identifier;
	}
	public static function clean_results_identifier($results_identifier)
	{
		$results_identifier = trim(pts_client::swap_variables($results_identifier, array('pts_client', 'user_run_save_variables')));
		$results_identifier = pts_strings::remove_redundant(pts_strings::keep_in_string($results_identifier, pts_strings::CHAR_LETTER | pts_strings::CHAR_NUMERIC | pts_strings::CHAR_DASH | pts_strings::CHAR_UNDERSCORE | pts_strings::CHAR_COLON | pts_strings::CHAR_COMMA | pts_strings::CHAR_SLASH | pts_strings::CHAR_SPACE | pts_strings::CHAR_DECIMAL | pts_strings::CHAR_AT | pts_strings::CHAR_PLUS | pts_strings::CHAR_SEMICOLON | pts_strings::CHAR_EQUAL), ' ');

		return $results_identifier;
	}
	public function get_test_run_position()
	{
		return $this->test_run_pos + 1;
	}
	public function get_test_run_count_reported()
	{
		return $this->test_run_count;
	}
	public function call_test_runs()
	{
		// Create a lock
		$lock_path = pts_client::temporary_directory() . '/phoronix-test-suite.active';
		pts_client::create_lock($lock_path);

		if($this->pre_run_message != null)
		{
			pts_user_io::display_interrupt_message($this->pre_run_message);
		}

		// Hook into the module framework
		self::$test_run_process_active = true;
		pts_module_manager::module_process('__pre_run_process', $this);
		pts_file_io::unlink(PTS_USER_PATH . 'halt-testing');
		pts_file_io::unlink(PTS_USER_PATH . 'skip-test');

		$continue_test_flag = true;
		$tests_to_run_count = $this->get_test_count();
		pts_client::$display->test_run_process_start($this);

		$total_loop_count = (($t = pts_client::read_env('TOTAL_LOOP_COUNT')) && is_numeric($t) && $t > 0) ? $t : 1;
		$total_loop_time = (($t = pts_client::read_env('TOTAL_LOOP_TIME')) && is_numeric($t) && $t > 60) ? ($t * 60) : -1;
		$loop_end_time = $total_loop_time != -1 ? (time() + $total_loop_time) : false;
		$this->test_run_count = ($tests_to_run_count * $total_loop_count);

		for($loop = 1; $loop <= $total_loop_count && $continue_test_flag; $loop++)
		{
			for($i = 0; $i < $tests_to_run_count && $continue_test_flag; $i++)
			{
				$this->test_run_pos = $i;
				$continue_test_flag = $this->process_test_run_request($i);

				if(pts_flags::remove_test_on_completion())
				{
					// Remove the installed test if it's no longer needed in this run queue
					$this_test_profile_identifier = $this->get_test_to_run($this->test_run_pos)->test_profile->get_identifier();
					$still_in_queue = false;

					for($j = ($this->test_run_pos + 1); $j < $tests_to_run_count && $still_in_queue == false; $j++)
					{
						if($this->get_test_to_run($j)->test_profile->get_identifier() == $this_test_profile_identifier)
						{
							$still_in_queue = true;
						}
					}

					if($still_in_queue == false)
					{
						pts_client::remove_installed_test($this->get_test_to_run($this->test_run_pos)->test_profile);
					}
				}

				if($loop_end_time)
				{
					if(time() > $loop_end_time)
					{
						$continue_test_flag = false;
					}
					else if($this->test_run_count == ($i + 1))
					{
						// There's still time remaining so increase the run count....
						$this->test_run_count += $tests_to_run_count;
					}
				}
			}
		}

		pts_file_io::unlink(PTS_SAVE_RESULTS_PATH . $this->get_file_name() . '/active.xml');

		foreach($this->tests_to_run as &$run_request)
		{
			// Remove cache shares
			foreach(pts_file_io::glob($run_request->test_profile->get_install_dir() . 'cache-share-*.pt2so') as $cache_share_file)
			{
				unlink($cache_share_file);
			}
		}

		if($this->post_run_message != null)
		{
			pts_user_io::display_interrupt_message($this->post_run_message);
		}

		self::$test_run_process_active = -1;
		pts_module_manager::module_process('__post_run_process', $this);
		pts_client::release_lock($lock_path);

		// Report any tests that failed to properly run
		if((pts_c::$test_flags ^ pts_c::batch_mode) || (pts_c::$test_flags & pts_c::debug_mode) || $this->get_test_count() > 3)
		{
			if(count($this->failed_tests_to_run) > 0)
			{
				echo PHP_EOL . PHP_EOL . 'The following tests failed to properly run:' . PHP_EOL . PHP_EOL;
				foreach($this->failed_tests_to_run as &$run_request)
				{
					echo "\t- " . $run_request->test_profile->get_identifier() . ($run_request->get_arguments_description() != null ? ': ' . $run_request->get_arguments_description() : null) . PHP_EOL;
				}
				echo PHP_EOL;
			}
		}
	}
	public static function test_run_process_active()
	{
		return self::$test_run_process_active = true;
	}
	private function process_test_run_request($run_index)
	{
		$result = false;

		if($this->get_file_name() != null)
		{
			$this->result_file_writer->save_xml(PTS_SAVE_RESULTS_PATH . $this->get_file_name() . '/active.xml');
		}

		$test_run_request = $this->get_test_to_run($run_index);

		if(($run_index != 0 && count(pts_file_io::glob($test_run_request->test_profile->get_install_dir() . 'cache-share-*.pt2so')) == 0))
		{
			// Sleep for six seconds between tests by default
			sleep(6);
		}

		pts_test_execution::run_test($this, $test_run_request);

		if(pts_file_io::unlink(PTS_USER_PATH . 'halt-testing'))
		{
			// Stop the testing process entirely
			return false;
		}
		else if(pts_file_io::unlink(PTS_USER_PATH . 'skip-test'))
		{
			// Just skip the current test and do not save the results, but continue testing
			continue;
		}

		$test_successful = false;
		if($test_run_request->test_profile->get_display_format() == 'NO_RESULT')
		{
			$test_successful = true;
		}
		else if($test_run_request instanceof pts_test_result)
		{
			$end_result = $test_run_request->get_result();

			// removed count($result) > 0 in the move to pts_test_result
			if(count($test_run_request) > 0 && ((is_numeric($end_result) && $end_result > 0) || (!is_numeric($end_result) && isset($end_result[3]))))
			{
				pts_module_manager::module_process('__post_test_run_success', $test_run_request);
				$test_identifier = $this->get_results_identifier();
				$test_successful = true;

				if(!empty($test_identifier))
				{
					// XXX : add to attributes JSON here
					$json_report_attributes = null;

					if(($t = $test_run_request->test_profile->test_installation->get_compiler_data()))
					{
						$json_report_attributes['compiler-options'] = $t;
					}

					$this->result_file_writer->add_result_from_result_object_with_value_string($test_run_request, $test_run_request->get_result(), $test_run_request->test_result_buffer->get_values_as_string(), $json_report_attributes);

					if($this->get_results_identifier() != null && $this->get_file_name() != null && pts_config::read_bool_config('PhoronixTestSuite/Options/Testing/SaveTestLogs', 'FALSE'))
					{
						static $xml_write_pos = 1;
						pts_file_io::mkdir(PTS_SAVE_RESULTS_PATH . $this->get_file_name() . '/test-logs/' . $xml_write_pos . '/');

						if(is_dir(PTS_SAVE_RESULTS_PATH . $this->get_file_name() . '/test-logs/active/' . $this->get_results_identifier()))
						{
							$test_log_write_dir = PTS_SAVE_RESULTS_PATH . $this->get_file_name() . '/test-logs/' . $xml_write_pos . '/' . $this->get_results_identifier() . '/';

							if(is_dir($test_log_write_dir))
							{
								pts_file_io::delete($test_log_write_dir, null, true);
							}

							rename(PTS_SAVE_RESULTS_PATH . $this->get_file_name() . '/test-logs/active/' . $this->get_results_identifier() . '/', $test_log_write_dir);
						}
						$xml_write_pos++;
					}
				}
			}

			pts_file_io::unlink(PTS_SAVE_RESULTS_PATH . $this->get_file_name() . '/test-logs/active/');
		}

		if($test_successful == false && $test_run_request->test_profile->get_identifier() != null)
		{
			array_push($this->failed_tests_to_run, $test_run_request);

			// For now delete the failed test log files, but it may be a good idea to keep them
			pts_file_io::delete(PTS_SAVE_RESULTS_PATH . $this->get_file_name() . '/test-logs/active/' . $this->get_results_identifier() . '/', null, true);
		}

		pts_module_manager::module_process('__post_test_run_process', $this->result_file_writer);

		return true;
	}
	public static function clean_save_name($input, $is_new_save = true)
	{
		$input = pts_client::swap_variables($input, array('pts_client', 'user_run_save_variables'));
		$input = str_replace(array('--', '---'), '-', pts_strings::keep_in_string(str_replace(' ', '-', trim($input)), pts_strings::CHAR_LETTER | pts_strings::CHAR_NUMERIC | pts_strings::CHAR_DASH));

		if($is_new_save)
		{
			$input = strtolower($input);
		}

		return $input;
	}
	public static function initial_checks(&$to_run, $test_flags = 0)
	{
		// Refresh the pts_client::$display in case we need to run in debug mode
		$test_flags |= pts_c::is_run_process;
		pts_client::init_display_mode($test_flags);
		pts_client::set_test_flags($test_flags);
		$to_run = pts_types::identifiers_to_objects($to_run);

		if((pts_c::$test_flags & pts_c::batch_mode))
		{
			if(pts_config::read_bool_config('PhoronixTestSuite/Options/BatchMode/Configured', 'FALSE') == false && (pts_c::$test_flags ^ pts_c::auto_mode))
			{
				pts_client::$display->generic_error('The batch mode must first be configured.' . PHP_EOL . 'To configure, run phoronix-test-suite batch-setup');
				return false;
			}
		}

		if(!is_writable(pts_client::test_install_root_path()))
		{
			pts_client::$display->generic_error('The test installation directory is not writable.' . PHP_EOL . 'Location: ' . pts_client::test_install_root_path());
			return false;
		}

		// Cleanup tests to run
		if(pts_test_run_manager::cleanup_tests_to_run($to_run) == false)
		{
			return false;
		}
		else if(count($to_run) == 0)
		{
			pts_client::$display->generic_error('You must enter at least one test, suite, or result identifier to run.');

			return false;
		}

		return true;
	}
	public function pre_execution_process()
	{
		if($this->do_save_results())
		{
			$this->result_file_writer = new pts_result_file_writer($this->get_results_identifier());

			if((pts_c::$test_flags ^ pts_c::is_recovering) && (!pts_result_file::is_test_result_file($this->get_file_name()) || $this->result_already_contains_identifier() == false))
			{
				$this->result_file_writer->add_result_file_meta_data($this);
				$this->result_file_writer->add_current_system_information();
			}

			pts_client::setup_test_result_directory($this->get_file_name());
		}
	}
	protected function generate_json_system_attributes()
	{
		$test_external_dependencies = array();
		$test_hardware_types = array();
		$test_internal_tags = array();

		foreach($this->tests_to_run as $test_to_run)
		{
			$test_external_dependencies = array_merge($test_external_dependencies, $test_to_run->test_profile->get_dependencies());
			$test_internal_tags = array_merge($test_internal_tags, $test_to_run->test_profile->get_internal_tags());
			pts_arrays::unique_push($test_hardware_types, $test_to_run->test_profile->get_test_hardware_type());
		}

		return self::pull_test_notes(false, $test_external_dependencies, $test_internal_tags, $test_hardware_types);
	}
	public static function pull_test_notes($show_all = false, $test_external_dependencies = array(), $test_internal_tags = array(), $test_hardware_types = array())
	{
		$notes = null;

		if($show_all || in_array('build-utilities', $test_external_dependencies))
		{
			// So compiler tests were run....
			$test = false;
			$compiler_mask_dir = pts_test_installer::create_compiler_mask($test);

			if($compiler_mask_dir && is_executable($compiler_mask_dir . 'cc'))
			{
				$compiler_configuration = phodevi_system::sw_compiler_build_configuration($compiler_mask_dir . 'cc');
				pts_file_io::delete($compiler_mask_dir, null, true);

				if(!empty($compiler_configuration))
				{
					$notes['compiler-configuration'] = $compiler_configuration;
				}
			}
		}
		if($show_all || in_array('OpenCL', $test_internal_tags))
		{
			// So OpenCL tests were run....
			$gpu_compute_cores = phodevi::read_property('gpu', 'compute-cores');
			if($gpu_compute_cores > 0)
			{
				$notes['graphics-compute-cores'] = $gpu_compute_cores;
			}
		}
		if($show_all || in_array('Disk', $test_hardware_types))
		{
			// A disk test was run so report some disk information...
			$disk_scheduler = phodevi::read_property('disk', 'scheduler');
			if($disk_scheduler)
			{
				$notes['disk-scheduler'] = $disk_scheduler;
			}

			$mount_options = phodevi::read_property('disk', 'mount-options');
			if(isset($mount_options['mount-options']) && $mount_options['mount-options'] != null)
			{
				$notes['disk-mount-options'] = $mount_options['mount-options'];
			}
		}
		if($show_all || in_array('Processor', $test_hardware_types) || in_array('System', $test_hardware_types))
		{
			$scaling_governor = phodevi::read_property('cpu', 'scaling-governor');
			if($scaling_governor)
			{
				$notes['cpu-scaling-governor'] = $scaling_governor;
			}
		}
		if($show_all || in_array('Graphics', $test_hardware_types))
		{
			$accel_2d = phodevi::read_property('gpu', '2d-acceleration');
			if($accel_2d)
			{
				$notes['graphics-2d-acceleration'] = $accel_2d;
			}
		}

		return $notes;
	}
	public function post_execution_process()
	{
		if($this->do_save_results())
		{
			if($this->result_file_writer->get_result_count() == 0 && !pts_result_file::is_test_result_file($this->get_file_name()) && (pts_c::$test_flags ^ pts_c::is_recovering) && (pts_c::$test_flags ^ pts_c::remote_mode))
			{
				pts_file_io::delete(PTS_SAVE_RESULTS_PATH . $this->get_file_name());
				return false;
			}

			pts_file_io::delete(PTS_SAVE_RESULTS_PATH . $this->get_file_name() . '/test-logs/active/', null, true);

			if((pts_c::$test_flags ^ pts_c::is_recovering) && (!pts_result_file::is_test_result_file($this->get_file_name()) || $this->result_already_contains_identifier() == false))
			{
				$this->result_file_writer->add_test_notes(pts_test_notes_manager::generate_test_notes($this->tests_to_run), $this->generate_json_system_attributes());
			}

			echo PHP_EOL;
			pts_module_manager::module_process('__event_results_process', $this);
			pts_client::save_result_file($this->result_file_writer, $this->get_file_name());
			pts_module_manager::module_process('__event_results_saved', $this);
			//echo PHP_EOL . 'Results Saved To: ; . PTS_SAVE_RESULTS_PATH . $this->get_file_name() . ;/composite.xml' . PHP_EOL;
			pts_client::display_web_page(PTS_SAVE_RESULTS_PATH . $this->get_file_name() . '/index.html');

			if($this->allow_sharing_of_results && pts_network::network_support_available())
			{
				if($this->auto_upload_to_openbenchmarking || pts_openbenchmarking_client::auto_upload_results() || pts_flags::upload_to_openbenchmarking())
				{
					$upload_results = true;
				}
				else if((pts_c::$test_flags & pts_c::batch_mode))
				{
					$upload_results = pts_config::read_bool_config('PhoronixTestSuite/Options/BatchMode/UploadResults', 'TRUE');
				}
				else if((pts_c::$test_flags ^ pts_c::auto_mode))
				{
					$upload_results = pts_user_io::prompt_bool_input('Would you like to upload the results to OpenBenchmarking.org', true);
				}
				else
				{
					$upload_results = false;
				}

				if($upload_results)
				{
					$upload_url = pts_openbenchmarking::upload_test_result($this);

					if(!empty($upload_url))
					{
						if((pts_c::$test_flags ^ pts_c::auto_mode) && pts_openbenchmarking_client::auto_upload_results() == false)
						{
							pts_client::display_web_page($upload_url, 'Do you want to launch OpenBenchmarking.org', true);
						}
					}
					else
					{
						echo PHP_EOL . 'Results Failed To Upload.' . PHP_EOL;
					}
				}
			}
		}
	}
	public static function cleanup_tests_to_run(&$to_run_objects)
	{
		$skip_tests = ($e = pts_client::read_env('SKIP_TESTS')) ? pts_strings::comma_explode($e) : false;
		$tests_verified = array();
		$tests_missing = array();

		foreach($to_run_objects as &$run_object)
		{
			if($skip_tests && (in_array($run_object->get_identifier(false), $skip_tests) || ($run_object instanceof pts_test_profile && in_array($run_object->get_identifier_base_name(), $skip_tests))))
			{
				echo 'Skipping: ' . $run_object->get_identifier() . PHP_EOL;
				continue;
			}
			else if($run_object instanceof pts_test_profile)
			{
				if($run_object->get_title() == null)
				{
					echo 'Not A Test: ' . $run_object . PHP_EOL;
					continue;
				}
				else
				{
					if($run_object->is_supported(false) == false)
					{
						continue;
					}
					if($run_object->is_test_installed() == false)
					{
						// Check to see if older version of test is currently installed
						// TODO: show change-log between installed versions and upstream
						array_push($tests_missing, $run_object);
						continue;
					}
				}
			}
			else if($run_object instanceof pts_result_file)
			{
				$num_installed = 0;
				foreach($run_object->get_contained_test_profiles() as $test_profile)
				{
					if($test_profile == null || $test_profile->get_identifier() == null || $test_profile->is_supported(false) == false)
					{
						continue;
					}
					else if($test_profile->is_test_installed() == false)
					{
						array_push($tests_missing, $test_profile);
					}
					else
					{
						$num_installed++;
					}
				}

				if($num_installed == 0)
				{
					continue;
				}
			}
			else if($run_object instanceof pts_test_suite || $run_object instanceof pts_virtual_test_suite)
			{
				if($run_object->is_core_version_supported() == false)
				{
					echo $run_object->get_title() . ' is a suite not supported by this version of the Phoronix Test Suite.' . PHP_EOL;
					continue;
				}

				$num_installed = 0;

				foreach($run_object->get_contained_test_profiles() as $test_profile)
				{
					if($test_profile == null || $test_profile->get_identifier() == null || $test_profile->is_supported(false) == false)
					{
						continue;
					}

					if($test_profile->is_test_installed() == false)
					{
						array_push($tests_missing, $test_profile);
					}
					else
					{
						$num_installed++;
					}
				}

				if($num_installed == 0)
				{
					continue;
				}
			}
			else
			{
				echo 'Not Recognized: ' . $run_object . PHP_EOL;
				continue;
			}

			array_push($tests_verified, $run_object);
		}

		$to_run_objects = $tests_verified;

		if(count($tests_missing) > 0)
		{
			$tests_missing = array_unique($tests_missing);

			if(count($tests_missing) == 1)
			{
				pts_client::$display->generic_error($tests_missing[0] . ' is not installed.' . PHP_EOL . 'To install, run: phoronix-test-suite install ' . $tests_missing[0]);
			}
			else
			{
				$message = PHP_EOL . PHP_EOL . 'Multiple tests are not installed:' . PHP_EOL . PHP_EOL;
				$message .= pts_user_io::display_text_list($tests_missing);
				$message .= PHP_EOL . 'To install, run: phoronix-test-suite install ' . implode(' ', $tests_missing) . PHP_EOL . PHP_EOL;
				echo $message;
			}

			if((pts_c::$test_flags & pts_c::auto_mode) == false && (pts_c::$test_flags & pts_c::batch_mode) == false && pts_flags::is_live_cd() == false)
			{
				$stop_and_install = pts_user_io::prompt_bool_input('Would you like to stop and install these tests now', true);

				if($stop_and_install)
				{
					pts_test_installer::standard_install($tests_missing, pts_c::$test_flags);
					self::cleanup_tests_to_run($to_run_objects);
				}
			}
		}

		return true;
	}
	public function auto_save_results($save_name, $result_identifier, $description = null)
	{
		$this->set_save_name($save_name, false);
		$this->set_results_identifier($result_identifier);
		$this->set_description($description);
	}
	public function set_description($description)
	{
		$this->run_description = $description == null ? self::auto_generate_description() : $description;
	}
	public function subsystems_under_test()
	{
		$subsystems_to_test = array();
		foreach($this->tests_to_run as $test_run_request)
		{
			pts_arrays::unique_push($subsystems_to_test, $test_run_request->test_profile->get_test_hardware_type());
		}
		return $subsystems_to_test;
	}
	protected function auto_generate_description()
	{

		$hw_components = array(pts_result_file_analyzer::system_component_string_to_array(phodevi::system_hardware(true)));
		$sw_components = array(pts_result_file_analyzer::system_component_string_to_array(phodevi::system_software(true)));

		if(pts_result_file::is_test_result_file($this->file_name))
		{
			$result_file = new pts_result_file($this->file_name);
			$existing_identifier_count = count($result_file->get_system_identifiers());

			foreach($result_file->get_system_hardware() as $component_string)
			{
				array_push($hw_components, pts_result_file_analyzer::system_component_string_to_array($component_string));
			}
			foreach($result_file->get_system_software() as $component_string)
			{
				array_push($sw_components, pts_result_file_analyzer::system_component_string_to_array($component_string));
			}
		}
		else
		{
			$existing_identifier_count = 0;
		}

		$auto_description = 'Running ' . implode(', ', array_unique($this->get_tests_to_run_identifiers()));
		$subsystems_to_test = $this->subsystems_under_test();

		// TODO: hook into $hw_components and $sw_components for leveraging existing result file data for comparisons already in existent
		// dropped: count($subsystems_to_test) == 1 && $
		if($existing_identifier_count == 0)
		{
			switch($subsystems_to_test)
			{
				case 'Graphics':
					$auto_description = phodevi::read_property('gpu', 'model') . ' graphics testing with ' . phodevi::read_property('system', 'display-driver-string') . ' / ' . phodevi::read_property('system', 'opengl-driver');
					break;
				case 'Disk':
					$auto_description = phodevi::read_name('disk') . ' testing on ' . phodevi::read_property('system', 'operating-system') . ' with a ' . phodevi::read_property('system', 'filesystem') . ' file-system';
					break;
				case 'Memory':
				case 'Processor':
					$auto_description = phodevi::read_property('cpu', 'model') . ' testing with a ' . phodevi::read_name('motherboard') . ' on ' . phodevi::read_property('system', 'operating-system');
					break;
				default:
					if(phodevi::read_property('system', 'system-layer'))
					{
						// Virtualization, Wine testing...
						$auto_description = phodevi::read_property('system', 'system-layer') . ' testing on ' . phodevi::read_property('system', 'operating-system');
					}
					else if(phodevi::read_name('motherboard') != null && phodevi::read_property('gpu', 'model') != null)
					{
						// Standard description
						$auto_description = phodevi::read_property('cpu', 'model') . ' testing with a ' . phodevi::read_name('motherboard') . ' and ' . phodevi::read_property('gpu', 'model') . ' on ' . phodevi::read_property('system', 'operating-system');
					}
					else
					{
						// A virtualized environment or a BSD or other OS where not all hardware info is available...
						$auto_description = phodevi::read_property('cpu', 'model') . ' testing on ' . phodevi::read_property('system', 'operating-system');
					}
					break;
			}
		}
		else
		{
			if(pts_result_file::is_test_result_file($this->file_name))
			{
				$result_file = new pts_result_file($this->file_name);
				$result_file_intent = pts_result_file_analyzer::analyze_result_file_intent($result_file);

				if(is_array($result_file_intent) && $result_file_intent[0] != 'Unknown')
				{
					$auto_description = 'A ' . $result_file_intent[0] . ' comparison';
				}
			}
		}

		$auto_description .= ' via the Phoronix Test Suite.';

		return $auto_description;
	}
	public function save_results_prompt()
	{
		if((pts_c::$test_flags ^ pts_c::auto_mode))
		{
			pts_client::$display->generic_heading('System Information');
			echo 'Hardware:' . PHP_EOL . phodevi::system_hardware(true) . PHP_EOL . PHP_EOL;
			echo 'Software:' . PHP_EOL . phodevi::system_software(true) . PHP_EOL . PHP_EOL;
		}

		if(($this->prompt_save_results || $this->force_save_results) && count($this->tests_to_run) > 0) // or check for DO_NOT_SAVE_RESULTS == false
		{
			if($this->force_save_results || pts_client::read_env('TEST_RESULTS_NAME'))
			{
				$save_results = true;
			}
			else if((pts_c::$test_flags & pts_c::batch_mode))
			{
				$save_results = pts_config::read_user_config('PhoronixTestSuite/Options/BatchMode/SaveResults', 'TRUE');
			}
			else
			{
				$save_results = pts_user_io::prompt_bool_input('Would you like to save these test results', true);
			}

			if($save_results)
			{
				// Prompt Save File Name
				$this->prompt_save_name();

				// Prompt Identifier
				$this->prompt_results_identifier();

				if(!isset($this->run_description[16]) || strpos($this->run_description, 'via the Phoronix Test Suite') !== false)
				{
					// Write the auto-description if nothing is set or attempt to auto-detect if it was a previous auto-description saved
					$this->run_description = self::auto_generate_description();
				}

				// Prompt Description
				if((pts_c::$test_flags ^ pts_c::batch_mode) || pts_config::read_bool_config('PhoronixTestSuite/Options/BatchMode/PromptForTestDescription', 'FALSE'))
				{
					if($this->run_description == null)
					{
						$this->run_description = 'N/A';
					}

					if(pts_client::read_env('TEST_RESULTS_DESCRIPTION'))
					{
						if(strlen(pts_client::read_env('TEST_RESULTS_DESCRIPTION')) > 1)
						{
							$this->run_description = pts_client::read_env('TEST_RESULTS_DESCRIPTION');
							echo 'Test Description: ' . $this->run_description . PHP_EOL;
						}
					}
					else if((pts_c::$test_flags ^ pts_c::auto_mode))
					{
						pts_client::$display->generic_heading('If you wish, enter a new description below to better describe this result set / system configuration under test.' . PHP_EOL . 'Press ENTER to proceed without changes.');
						echo 'Current Description: ' . $this->run_description . PHP_EOL . PHP_EOL . 'New Description: ';
						$new_test_description = pts_user_io::read_user_input();

						if(!empty($new_test_description))
						{
							$this->run_description = $new_test_description;
						}
					}
				}
			}
		}
	}
	public function load_tests_to_run(&$to_run_objects)
	{
		// Determine what to run
		$this->determine_tests_to_run($to_run_objects);

		// Is there something to run?
		return $this->get_test_count() > 0;
	}
	public function load_result_file_to_run($save_name, $result_identifier, &$result_file, $tests_to_complete = null)
	{
		// Determine what to run
		$this->auto_save_results($save_name, $result_identifier);
		$this->run_description = $result_file->get_description();
		$result_objects = $result_file->get_result_objects();

		// Unset result objects that shouldn't be run
		if(is_array($tests_to_complete))
		{
			foreach(array_keys($result_objects) as $i)
			{
				if(!in_array($i, $tests_to_complete))
				{
					unset($result_objects[$i]);
				}
			}
		}

		if(count($result_objects) == 0)
		{
			return false;
		}


		foreach($result_objects as &$result_object)
		{
			if($this->validate_test_to_run($result_object->test_profile))
			{
				$test_result = new pts_test_result($result_object->test_profile);
				$test_result->set_used_arguments($result_object->get_arguments());
				$test_result->set_used_arguments_description($result_object->get_arguments_description());
				$this->add_test_result_object($test_result);
			}
		}

		// Is there something to run?
		return $this->get_test_count() > 0;
	}
	public function load_test_run_requests_to_run($save_name, $result_identifier, &$result_file, &$test_run_requests)
	{
		// Determine what to run
		$this->auto_save_results($save_name, $result_identifier);
		$this->run_description = $result_file->get_description();

		if(count($test_run_requests) == 0)
		{
			return false;
		}

		foreach($test_run_requests as &$test_run_request)
		{
			if($this->validate_test_to_run($test_run_request->test_profile) == false)
			{
				continue;
			}

			if($test_run_request->test_profile->get_override_values() != null)
			{
				$test_run_request->test_profile->set_override_values($test_run_request->test_profile->get_override_values());
			}

			$test_result = new pts_test_result($test_run_request->test_profile);
			$test_result->set_used_arguments($test_run_request->get_arguments());
			$test_result->set_used_arguments_description($test_run_request->get_arguments_description());
			$this->add_test_result_object($test_result);
		}

		// Is there something to run?
		return $this->get_test_count() > 0;
	}
	protected function test_prompts_to_result_objects(&$test_profile)
	{
		$result_objects = array();

		if((pts_c::$test_flags & pts_c::batch_mode) && pts_config::read_bool_config('PhoronixTestSuite/Options/BatchMode/RunAllTestCombinations', 'TRUE'))
		{
			list($test_arguments, $test_arguments_description) = pts_test_run_options::batch_user_options($test_profile);
		}
		else if((pts_c::$test_flags & pts_c::defaults_mode))
		{
			list($test_arguments, $test_arguments_description) = pts_test_run_options::default_user_options($test_profile);
		}
		else
		{
			list($test_arguments, $test_arguments_description) = pts_test_run_options::prompt_user_options($test_profile);
		}

		foreach(array_keys($test_arguments) as $i)
		{
			$test_result = new pts_test_result($test_profile);
			$test_result->set_used_arguments($test_arguments[$i]);
			$test_result->set_used_arguments_description($test_arguments_description[$i]);
			array_push($result_objects, $test_result);
		}

		return $result_objects;
	}
	public function determine_tests_to_run(&$to_run_objects)
	{
		$unique_test_count = count(array_unique($to_run_objects));
		$run_contains_a_no_result_type = false;
		$request_results_save = false;

		foreach($to_run_objects as &$run_object)
		{
			// TODO: determine whether to print the titles of what's being run?
			if($run_object instanceof pts_test_profile)
			{
				if($run_object->get_identifier() == null || $run_object->get_title() == null || $this->validate_test_to_run($run_object) == false)
				{
					continue;
				}

				if($run_contains_a_no_result_type == false && $run_object->get_display_format() == 'NO_RESULT')
				{
					$run_contains_a_no_result_type = true;
				}
				if($request_results_save == false && $run_object->do_auto_save_results())
				{
					$request_results_save = true;
				}

				foreach(self::test_prompts_to_result_objects($run_object) as $result_object)
				{
					$this->add_test_result_object($result_object);
				}
			}
			else if($run_object instanceof pts_test_suite)
			{
				$this->pre_run_message = $run_object->get_pre_run_message();
				$this->post_run_message = $run_object->get_post_run_message();

				if($run_object->get_run_mode() == 'PCQS')
				{
					$this->is_pcqs = true;
				}

				foreach($run_object->get_contained_test_result_objects() as $result_object)
				{
					$this->add_test_result_object($result_object);
				}
			}
			else if($run_object instanceof pts_result_file)
			{
				// Print the $to_run ?
				$this->run_description = $run_object->get_description();
				$preset_vars = $run_object->get_preset_environment_variables();
				$result_objects = $run_object->get_result_objects();

				$this->set_save_name($run_object->get_identifier(), false);

				pts_module_manager::process_environment_variables_string_to_set($preset_vars);

				foreach($result_objects as &$result_object)
				{
					if($result_object->test_profile->get_identifier() == null)
					{
						continue;
					}

					$test_result = new pts_test_result($result_object->test_profile);
					$test_result->set_used_arguments($result_object->get_arguments());
					$test_result->set_used_arguments_description($result_object->get_arguments_description());
					$this->add_test_result_object($test_result);
				}
			}
			else if($run_object instanceof pts_virtual_test_suite)
			{
				$virtual_suite_tests = $run_object->get_contained_test_profiles();

				foreach(array_keys($virtual_suite_tests) as $i)
				{
					if($virtual_suite_tests[$i]->is_supported(false) == false || $this->validate_test_to_run($virtual_suite_tests[$i]) == false)
					{
						unset($virtual_suite_tests[$i]);
					}
				}
				sort($virtual_suite_tests);

				if(count($virtual_suite_tests) > 1)
				{
					array_push($virtual_suite_tests, 'All Tests In Suite');
				}

				$run_index = explode(',', pts_user_io::prompt_text_menu('Select the tests in the virtual suite to run', $virtual_suite_tests, true, true));

				if(count($virtual_suite_tests) > 2 && in_array((count($virtual_suite_tests) - 1), $run_index))
				{
					// The appended 'All Tests In Suite' was selected, so run all
				}
				else
				{
					foreach(array_keys($virtual_suite_tests) as $i)
					{
						if(!in_array($i, $run_index))
						{
							unset($virtual_suite_tests[$i]);
						}
					}
				}

				foreach($virtual_suite_tests as &$test_profile)
				{
					if($test_profile instanceof pts_test_profile)
					{
						// The user is to configure virtual suites manually
						foreach(self::test_prompts_to_result_objects($test_profile) as $result_object)
						{
							$this->add_test_result_object($result_object);
						}
					}
				}
			}
			else
			{
				pts_client::$display->generic_error($to_run . ' is not recognized.');
				continue;
			}
		}

		// AlwaysUploadResultsToOpenBenchmarking AutoSortRunQueue
		if(pts_config::read_bool_config('PhoronixTestSuite/Options/Testing/AutoSortRunQueue', 'TRUE') && $this->force_save_results == false)
		{
			// Not that it matters much, but if $this->force_save_results is set that means likely running from a result file...
			// so if running a result file, don't change the ordering of the existing results

			// Sort the run order so that all tests that are similar are grouped together, etc
			usort($this->tests_to_run, array('pts_test_run_manager', 'cmp_result_object_sort'));
		}

		$this->prompt_save_results = $run_contains_a_no_result_type == false || $unique_test_count > 1;
		$this->force_save_results = $this->force_save_results || $request_results_save;
	}
	public static function cmp_result_object_sort($a, $b)
	{
		$a_comp = $a->test_profile->get_test_hardware_type() . $a->test_profile->get_test_software_type() . $a->test_profile->get_internal_tags_raw() . $a->test_profile->get_result_scale_formatted() . $a->test_profile->get_identifier(true);
		$b_comp = $b->test_profile->get_test_hardware_type() . $b->test_profile->get_test_software_type() . $b->test_profile->get_internal_tags_raw() . $b->test_profile->get_result_scale_formatted() . $b->test_profile->get_identifier(true);

		if($a_comp == $b_comp)
		{
			// So it's the same test being compared... try to sort in ascending order (such that 800 x 600 resolution comes before 1024 x 768), below way is an attempt to recognize such in weird manner
			if(strlen($a->get_arguments_description()) == strlen($b->get_arguments_description()))
			{
				return strcmp($a->get_arguments_description(), $b->get_arguments_description());
			}
			else
			{
				return strcmp(strlen($a->get_arguments_description()), strlen($b->get_arguments_description()));
			}
		}

		return strcmp($a_comp, $b_comp);
	}
	public static function test_profile_system_compatibility_check(&$test_profile, $report_errors = false)
	{
		$valid_test_profile = true;
		$test_type = $test_profile->get_test_hardware_type();
		$skip_tests = pts_client::read_env('SKIP_TESTS') ? pts_strings::comma_explode(pts_client::read_env('SKIP_TESTS')) : false;
		$display_driver = phodevi::read_property('system', 'display-driver');

		if($test_profile->is_supported(false) == false)
		{
			$valid_test_profile = false;
		}
		else if($test_type == 'Graphics' && pts_client::read_env('DISPLAY') == false && phodevi::is_windows() == false && phodevi::is_macosx() == false)
		{
			$report_errors && pts_client::$display->test_run_error('No display server was found, cannot run ' . $test_profile);
			$valid_test_profile = false;
		}
		else if($test_type == 'Graphics' && in_array($display_driver, array('vesa', 'nv', 'cirrus')))
		{
			$report_errors && pts_client::$display->test_run_error('3D acceleration support not available, cannot run ' . $test_profile);
			$valid_test_profile = false;
		}
		else if($test_type == 'Disk' && stripos(phodevi::read_property('system', 'filesystem'), 'SquashFS') !== false)
		{
			$report_errors && pts_client::$display->test_run_error('Running on a RAM-based live file-system, cannot run ' . $test_profile);
			$valid_test_profile = false;
		}
		else if(pts_client::read_env('NO_' . strtoupper($test_type) . '_TESTS') ||($skip_tests && (in_array($test_profile, $skip_tests) || in_array($test_type, $skip_tests) || in_array($test_profile->get_identifier(false), $skip_tests) || in_array($run_object->get_identifier_base_name(), $skip_tests))))
		{
			$report_errors && pts_client::$display->test_run_error('Due to a pre-set environmental variable, skipping ' . $test_profile);
			$valid_test_profile = false;
		}
		else if($test_profile->is_root_required() && (pts_c::$test_flags & pts_c::batch_mode) && phodevi::is_root() == false)
		{
			$report_errors && pts_client::$display->test_run_error('Cannot run ' . $test_profile . ' in batch mode as root access is required.');
			$valid_test_profile = false;
		}

		return $valid_test_profile;
	}
	protected function validate_test_to_run(&$test_profile)
	{
		static $test_checks = null;

		if(!isset($test_checks[$test_profile->get_identifier()]))
		{
			$valid_test_profile = true;

			if(self::test_profile_system_compatibility_check($test_profile, true) == false)
			{
				$valid_test_profile = false;
			}
			else if($test_profile->get_test_executable_dir() == null)
			{
				pts_client::$display->test_run_error('The test executable for ' . $test_profile . ' could not be located.');
				$valid_test_profile = false;
			}

			if($valid_test_profile && $this->allow_sharing_of_results && $test_profile->allow_results_sharing() == false)
			{
				$this->allow_sharing_of_results = false;
			}

			$test_checks[$test_profile->get_identifier()] = $valid_test_profile;
		}

		return $test_checks[$test_profile->get_identifier()];
	}
	public static function standard_run($to_run, $test_flags = 0)
	{
		if(pts_test_run_manager::initial_checks($to_run, $test_flags) == false)
		{
			return false;
		}

		$test_run_manager = new pts_test_run_manager($test_flags);

		// Load the tests to run
		if($test_run_manager->load_tests_to_run($to_run) == false)
		{
			return false;
		}

		// Save results?
		$test_run_manager->save_results_prompt();

		// Run the actual tests
		$test_run_manager->pre_execution_process();
		$test_run_manager->call_test_runs();
		$test_run_manager->post_execution_process();

		return $test_run_manager;
	}
}

?>
