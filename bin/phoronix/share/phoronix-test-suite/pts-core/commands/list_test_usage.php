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

class list_test_usage implements pts_option_interface
{
	const doc_section = 'Information';
	const doc_description = 'This option will list various details about installed tests and their usage.';

	public static function run($r)
	{
		$installed_tests = pts_tests::installed_tests();
		pts_client::$display->generic_heading(count($installed_tests) . ' Tests Installed');

		if(count($installed_tests) > 0)
		{
			echo sprintf('%-18ls   %-8ls %-13ls %-11ls %-13ls %-10ls', 'TEST', 'VERSION', 'INSTALL DATE', 'LAST RUN', 'AVG RUN-TIME', 'TIMES RUN') . PHP_EOL;
			foreach($installed_tests as $identifier)
			{
				$test_profile = new pts_test_profile($identifier);

				if($test_profile && $test_profile->test_installation && $test_profile->test_installation->get_installed_version() != null)
				{
					$avg_time = $test_profile->test_installation->get_average_run_time();
					$avg_time = !empty($avg_time) ? pts_strings::format_time($avg_time, 'SECONDS', false) : 'N/A';

					$last_run = $test_profile->test_installation->get_last_run_date();
					$last_run = $last_run == '0000-00-00' ? 'NEVER' : $last_run;

					echo sprintf('%-18ls - %-8ls %-13ls %-11ls %-13ls %-10ls', $identifier, $test_profile->test_installation->get_installed_version(), $test_profile->test_installation->get_install_date(), $last_run, $avg_time, $test_profile->test_installation->get_run_count()) . PHP_EOL;
				}
			}
		}
	}
}

?>
