<?php

/*
	Phoronix Test Suite
	URLs: http://www.phoronix.com, http://www.phoronix-test-suite.com/
	Copyright (C) 2008 - 2011, Phoronix Media
	Copyright (C) 2008 - 2011, Michael Larabel
	phodevi_monitor.php: The PTS Device Interface object for the display monitor

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

class phodevi_monitor extends phodevi_device_interface
{
	public static function read_property($identifier)
	{
		switch($identifier)
		{
			case 'identifier':
				$property = new phodevi_device_property('monitor_string', phodevi::smart_caching);
				break;
			case 'count':
				$property = new phodevi_device_property('monitor_count', phodevi::std_caching);
				break;
			case 'layout':
				$property = new phodevi_device_property('monitor_layout', phodevi::std_caching);
				break;
			case 'modes':
				$property = new phodevi_device_property('monitor_modes', phodevi::std_caching);
				break;
		}

		return $property;
	}
	public static function monitor_string()
	{
		if(phodevi::is_macosx())
		{
			$system_profiler = shell_exec('system_profiler SPDisplaysDataType 2>&1');
			$system_profiler = substr($system_profiler, strrpos($system_profiler, 'Displays:'));
			$system_profiler = substr($system_profiler, strpos($system_profiler, "\n"));
			$monitor = trim(substr($system_profiler, 0, strpos($system_profiler, ':')));

			if($monitor == 'Display Connector')
			{
				$monitor = null;
			}
		}
		else if(isset(phodevi::$vfs->xorg_log))
		{
			$log_parse = phodevi::$vfs->xorg_log;
			if(($monitor_name = strpos($log_parse, 'Monitor name:')))
			{
				$log_parse = substr($log_parse, $monitor_name + 14);
				$monitor = trim(substr($log_parse, 0, strpos($log_parse, "\n")));
			}
		}

		return empty($monitor) ? false : $monitor;
	}
	public static function monitor_count()
	{
		// Report number of connected/enabled monitors
		$monitor_count = 0;

		// First try reading number of monitors from xdpyinfo
		$monitor_count = count(phodevi_parser::read_xdpy_monitor_info());

		if($monitor_count == 0)
		{
			// Fallback support for ATI and NVIDIA if phodevi_parser::read_xdpy_monitor_info() fails
			if(phodevi::is_nvidia_graphics())
			{
				$enabled_displays = phodevi_parser::read_nvidia_extension('EnabledDisplays');

				switch($enabled_displays)
				{
					case '0x00010000':
						$monitor_count = 1;
						break;
					case '0x00010001':
						$monitor_count = 2;
						break;
					default:
						$monitor_count = 1;
						break;
				}
			}
			else if(phodevi::is_ati_graphics() && phodevi::is_linux())
			{
				$amdpcsdb_enabled_monitors = phodevi_linux_parser::read_amd_pcsdb('SYSTEM/BUSID-*/DDX,EnableMonitor');
				$amdpcsdb_enabled_monitors = pts_arrays::to_array($amdpcsdb_enabled_monitors);

				foreach($amdpcsdb_enabled_monitors as $enabled_monitor)
				{
					foreach(pts_strings::comma_explode($enabled_monitor) as $monitor_connection)
					{
						$monitor_count++;
					}
				}
			}
			else
			{
				$monitor_count = 1;
			}
		}

		return $monitor_count;
	}
	public static function monitor_layout()
	{
		// Determine layout for multiple monitors
		$monitor_layout = array('CENTER');

		if(phodevi::read_property('monitor', 'count') > 1)
		{
			$xdpy_monitors = phodevi_parser::read_xdpy_monitor_info();
			$hit_0_0 = false;
			for($i = 0; $i < count($xdpy_monitors); $i++)
			{
				$monitor_position = explode('@', $xdpy_monitors[$i]);
				$monitor_position = trim($monitor_position[1]);
				$monitor_position_x = substr($monitor_position, 0, strpos($monitor_position, ','));
				$monitor_position_y = substr($monitor_position, strpos($monitor_position, ',') + 1);

				if($monitor_position == '0,0')
				{
					$hit_0_0 = true;
				}
				else if($monitor_position_x > 0 && $monitor_position_y == 0)
				{
					array_push($monitor_layout, ($hit_0_0 ? 'RIGHT' : 'LEFT'));
				}
				else if($monitor_position_x == 0 && $monitor_position_y > 0)
				{
					array_push($monitor_layout, ($hit_0_0 ? 'LOWER' : 'UPPER'));
				}
			}

			if(count($monitor_layout) == 1)
			{
				// Something went wrong with xdpy information, go to fallback support
				if(phodevi::is_ati_graphics() && phodevi::is_linux())
				{
					$amdpcsdb_monitor_layout = phodevi_linux_parser::read_amd_pcsdb('SYSTEM/BUSID-*/DDX,DesktopSetup');
					$amdpcsdb_monitor_layout = pts_arrays::to_array($amdpcsdb_monitor_layout);

					foreach($amdpcsdb_monitor_layout as $card_monitor_configuration)
					{
						switch($card_monitor_configuration)
						{
							case 'horizontal':
								array_push($monitor_layout, 'RIGHT');
								break;
							case 'horizontal,reverse':
								array_push($monitor_layout, 'LEFT');
								break;
							case 'vertical':
								array_push($monitor_layout, 'ABOVE');
								break;
							case 'vertical,reverse':
								array_push($monitor_layout, 'BELOW');
								break;
						}
					}
				}
			}
		}

		return implode(',', $monitor_layout);
	}
	public static function monitor_modes()
	{
		// Determine resolutions for each monitor
		$resolutions = array();

		if(phodevi::read_property('monitor', 'count') == 1)
		{
			array_push($resolutions, phodevi::read_property('gpu', 'screen-resolution-string'));
		}
		else
		{
			foreach(phodevi_parser::read_xdpy_monitor_info() as $monitor_line)
			{
				$this_resolution = substr($monitor_line, strpos($monitor_line, ':') + 2);
				$this_resolution = substr($this_resolution, 0, strpos($this_resolution, ' '));
				array_push($resolutions, $this_resolution);
			}
		}

		return implode(',', $resolutions);
	}
}

?>
