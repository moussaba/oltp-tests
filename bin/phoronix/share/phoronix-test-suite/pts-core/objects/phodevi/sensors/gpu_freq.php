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

class gpu_freq implements phodevi_sensor
{
	public static function get_type()
	{
		return 'gpu';
	}
	public static function get_sensor()
	{
		return 'freq';
	}
	public static function get_unit()
	{
		return 'Megahertz';
	}
	public static function support_check()
	{
		$test = self::read_sensor();
		return is_numeric($test) && $test > 0;
	}
	public static function read_sensor()
	{
		// Graphics processor real/current frequency
		$show_memory = false;
		$core_freq = 0;
		$mem_freq = 0;

		if(phodevi::is_nvidia_graphics()) // NVIDIA GPU
		{
			$nv_freq = phodevi_parser::read_nvidia_extension('GPUCurrentClockFreqs');

			$nv_freq = pts_strings::comma_explode($nv_freq);
			$core_freq = isset($nv_freq[0]) ? $nv_freq[0] : 0;
			$mem_freq = isset($nv_freq[1]) ? $nv_freq[1] : 0;
		}
		else if(phodevi::is_ati_graphics() && phodevi::is_linux()) // ATI GPU
		{
			$od_clocks = phodevi_linux_parser::read_ati_overdrive('CurrentClocks');

			if(is_array($od_clocks) && count($od_clocks) >= 2) // ATI OverDrive
			{
				$core_freq = array_shift($od_clocks);
				$mem_freq = array_pop($od_clocks);
			}
		}
		else if(phodevi::is_linux())
		{
			if(isset(phodevi::$vfs->radeon_pm_info))
			{
				// radeon_pm_info should be present with Linux 2.6.34+
				foreach(pts_strings::trim_explode("\n", phodevi::$vfs->radeon_pm_info) as $pm_line)
				{
					list($descriptor, $value) = pts_strings::colon_explode($pm_line);

					switch($descriptor)
					{
						case 'current engine clock':
							$core_freq = pts_arrays::first_element(explode(' ', $value)) / 1000;
							break;
						case 'current memory clock':
							$mem_freq = pts_arrays::first_element(explode(' ', $value)) / 1000;
							break;
					}
				}
			}
			else if(is_file('/sys/class/drm/card0/device/performance_level'))
			{
				$performance_level = pts_file_io::file_get_contents('/sys/class/drm/card0/device/performance_level');
				$performance_level = explode(' ', $performance_level);

				$core_string = array_search('core', $performance_level);
				if($core_string !== false && isset($performance_level[($core_string + 1)]))
				{
					$core_string = str_ireplace('MHz', null, $performance_level[($core_string + 1)]);
					if(is_numeric($core_string) && $core_string > $core_freq)
					{
						$core_freq = $core_string;
					}
				}

				$mem_string = array_search('memory', $performance_level);
				if($mem_string !== false && isset($performance_level[($mem_string + 1)]))
				{
					$mem_string = str_ireplace('MHz', null, $performance_level[($mem_string + 1)]);
					if(is_numeric($mem_string) && $mem_string > $mem_freq)
					{
						$mem_freq = $mem_string;
					}
				}
			}
			else if(isset(phodevi::$vfs->i915_cur_delayinfo))
			{
				$i915_cur_delayinfo = phodevi::$vfs->i915_cur_delayinfo;
				$cagf = strpos($i915_cur_delayinfo, 'CAGF: ');

				if($cagf !== false)
				{
					$cagf_mhz = substr($i915_cur_delayinfo, $cagf + 6);
					$cagf_mhz = substr($cagf_mhz, 0, strpos($cagf_mhz, 'MHz'));

					if(is_numeric($cagf_mhz))
					{
						$core_freq = $cagf_mhz;
					}
				}
			}
		}

		if(!is_numeric($core_freq))
		{
			$core_freq = 0;
		}
		if(!is_numeric($mem_freq))
		{
			$mem_freq = 0;
		}

		if($core_freq == 0 && $mem_freq == 0)
		{
			$show_memory = false;
			$core_freq = -1;
		}

		return $show_memory ? array($core_freq, $mem_freq) : $core_freq;
	}
}

?>
