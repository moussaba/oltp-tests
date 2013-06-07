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

class upload_result implements pts_option_interface
{
	const doc_section = 'OpenBenchmarking.org';
	const doc_description = 'This option is used for uploading a test result to OpenBenchmarking.org.';

	public static function argument_checks()
	{
		return array(
		new pts_argument_check(0, array('pts_types', 'is_result_file'), null)
		);
	}
	public static function command_aliases()
	{
		return array('upload', 'upload_results', 'upload_result_file');
	}
	public static function invalid_command($passed_args = null)
	{
		pts_tests::recently_saved_results();
	}
	public static function run($r)
	{
		$result_file = pts_types::identifier_to_object($r[0]);
		$upload_url = pts_openbenchmarking::upload_test_result($result_file);

		if($upload_url == false)
		{
			echo PHP_EOL . 'Results Failed To Upload.' . PHP_EOL;
		}
	}
}

?>
