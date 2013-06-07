<?php

/*
	Phoronix Test Suite
	URLs: http://www.phoronix.com, http://www.phoronix-test-suite.com/
	Copyright (C) 2008 - 2012, Phoronix Media
	Copyright (C) 2008 - 2012, Michael Larabel
	phodevi_memory.php: The PTS Device Interface object for system memory

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

class phodevi_memory extends phodevi_device_interface
{
	public static function read_property($identifier)
	{
		switch($identifier)
		{
			case 'identifier':
				$property = new phodevi_device_property('memory_string', phodevi::smart_caching);
				break;
			case 'capacity':
				$property = new phodevi_device_property('memory_capacity', phodevi::smart_caching);
				break;
		}

		return $property;
	}
	public static function memory_string()
	{
		$mem_string = null;
		$mem_prefix = null;

		if(phodevi::is_macosx())
		{
			$mem_size = phodevi_osx_parser::read_osx_system_profiler('SPMemoryDataType', 'Size', true, array('Empty'));
			$mem_speed = phodevi_osx_parser::read_osx_system_profiler('SPMemoryDataType', 'Speed');
			$mem_type = phodevi_osx_parser::read_osx_system_profiler('SPMemoryDataType', 'Type');
		}
		else if(phodevi::is_solaris())
		{
			$mem_size = phodevi_solaris_parser::read_sun_ddu_dmi_info('MemoryDevice*,InstalledSize');
			$mem_speed = phodevi_solaris_parser::read_sun_ddu_dmi_info('MemoryDevice*,Speed');
			$mem_type = phodevi_solaris_parser::read_sun_ddu_dmi_info('MemoryDevice*,MemoryDeviceType');

			if(is_array($mem_speed) && count($mem_speed) > 0)
			{
				$mem_speed = array_shift($mem_speed);
			}

			$mem_speed = str_replace('MHZ', 'MHz', $mem_speed);
		}
		else if(phodevi::is_windows())
		{
			$mem_size = phodevi_windows_parser::read_cpuz('DIMM #', 'Size', true);

			foreach($mem_size as $key => &$individual_size)
			{
				$individual_size = pts_arrays::first_element(explode(' ', $individual_size));

				if(!is_numeric($individual_size))
				{
					unset($mem_size[$key]);
				}				
			}

			$mem_type = phodevi_windows_parser::read_cpuz('Memory Type', null);
			$mem_speed = intval(phodevi_windows_parser::read_cpuz('Memory Frequency', null)) . 'MHz';
		}
		else if(phodevi::is_linux())
		{
			$mem_size = phodevi_linux_parser::read_dmidecode('memory', 'Memory Device', 'Size', false, array('Not Installed', 'No Module Installed'));
			$mem_speed = phodevi_linux_parser::read_dmidecode('memory', 'Memory Device', 'Speed', true, 'Unknown');
			$mem_type = phodevi_linux_parser::read_dmidecode('memory', 'Memory Device', 'Type', true, array('Unknown', 'Other'));
		}
		else
		{
			$mem_size = false;
			$mem_speed = false;
			$mem_type = false;
		}

		if(is_array($mem_type))
		{
			$mem_type = array_pop($mem_type);
		}

		if($mem_size != false && (!is_array($mem_size) || count($mem_size) != 0))
		{
			for($i = 0; $i < count($mem_size); $i++)
			{
				switch(substr($mem_size[$i], -1))
				{
					case 'K':
						// looks like sometimes Solaris now reports flash chip as memory. its string ends with K
						unset($mem_size[$i]);
						unset($mem_speed[$i]);
						unset($mem_type[$i]);
						break;
					case 'M':
						// report megabytes as MB, just not M, as on Solaris
						$mem_size[$i] .= 'B';
						break;
					case 'B':
						if(strtolower(substr($mem_size[$i], -2, 1)) == 'k')
						{
							// some hardware on Linux via dmidecode reports flash chips
							unset($mem_size[$i]);
							//unset($mem_speed[$i]);
							//unset($mem_type[$i]);
						}
						break;
				}
			}

			$mem_count = count($mem_size);

			if(!empty($mem_type))
			{
				if(($cut = strpos($mem_type, ' ')) > 0)
				{
					$mem_type = substr($mem_type, 0, $cut);
				}

				if(!in_array($mem_type, array('Other')) && (pts_strings::keep_in_string($mem_type, pts_strings::CHAR_NUMERIC | pts_strings::CHAR_LETTER) == $mem_type || phodevi::is_windows()))
				{
					$mem_prefix = $mem_type;
				}
			}
			else
			{
				$mem_prefix = null;
			}

			if(!empty($mem_speed))
			{
				if(($cut = strpos($mem_speed, ' (')) > 0)
				{
					$mem_speed = substr($mem_speed, 0, $cut);
				}

				if(!empty($mem_prefix))
				{
					$mem_prefix .= '-';
				}

				$mem_prefix .= str_replace(' ', null, $mem_speed);
			}

			// TODO: Allow a combination of both functions below, so like 2 x 2GB + 3 x 1GB DDR2-800
			if($mem_count > 1 && count(array_unique($mem_size)) > 1)
			{
				$mem_string = implode(' + ', $mem_size) . ' ' . $mem_prefix;
			}
			else
			{
				if(($mem_count * $mem_size[0]) != phodevi::read_property('memory', 'capacity') && phodevi::read_property('memory', 'capacity') % $mem_size[0] == 0)
				{
					// This makes sure the correct number of RAM modules is reported...
					// On at least Linux with dmidecode on an AMD Opteron multi-socket setup it's only showing the data for one socket
					$mem_count = phodevi::read_property('memory', 'capacity') / $mem_size[0];
				}

				$mem_string = $mem_count . ' x ' . $mem_size[0] . ' ' . $mem_prefix;
			}
		}

		if(empty($mem_string))
		{
			$mem_string = phodevi::read_property('memory', 'capacity');

			if($mem_string != null)
			{
				$mem_string .= 'MB';
			}
		}

		return trim($mem_string);
	}
	public static function memory_capacity()
	{
		// Returns physical memory capacity
		if(isset(phodevi::$vfs->meminfo))
		{
			$info = phodevi::$vfs->meminfo;
			$info = substr($info, strpos($info, 'MemTotal:') + 9);
			$info = intval(trim(substr($info, 0, strpos($info, 'kB'))));
			$info = floor($info / 1024);

			if(is_numeric($info) && $info > 950)
			{
				if($info > 4608)
				{
					$info = ceil($info / 1024) * 1024;
				}
				else if($info > 1536)
				{
					$info = ceil($info / 512) * 512;
				}
				else
				{
					$info = ceil($info / 256) * 256;
				}
			}
		}
		else if(phodevi::is_solaris())
		{
			$info = shell_exec('prtconf 2>&1 | grep Memory');
			$info = substr($info, strpos($info, ':') + 2);
			$info = substr($info, 0, strpos($info, 'Megabytes'));
		}
		else if(phodevi::is_bsd())
		{
			$mem_size = phodevi_bsd_parser::read_sysctl('hw.physmem');

			if($mem_size == false)
			{
				$mem_size = phodevi_bsd_parser::read_sysctl('hw.realmem');
			}

			$info = ceil(floor($mem_size / 1048576) / 256) * 256;
		}
		else if(phodevi::is_macosx())
		{
			$info = phodevi_osx_parser::read_osx_system_profiler('SPHardwareDataType', 'Memory');
			$info = explode(' ', $info);
			$info = (isset($info[1]) && $info[1] == 'GB' ? $info[0] * 1024 : $info[0]);
		}
		else if(phodevi::is_windows())
		{
			$info = phodevi_windows_parser::read_cpuz('Memory Size', null);

			if($info != null)
			{
				if(($e = strpos($info, ' MBytes')) !== false)
				{
					$info = substr($info, 0, $e);
				}

				$info = trim($info);
			}
		}
		else
		{
			$info = null;
		}

		return $info;
	}
}

?>
