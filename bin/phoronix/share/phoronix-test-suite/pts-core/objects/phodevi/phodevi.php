<?php

/*
	Phoronix Test Suite
	URLs: http://www.phoronix.com, http://www.phoronix-test-suite.com/
	Copyright (C) 2009 - 2012, Phoronix Media
	Copyright (C) 2009 - 2012, Michael Larabel
	phodevi.php: The object for interacting with the PTS device framework

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

phodevi::create_vfs();

if(PTS_IS_CLIENT)
{
	phodevi::initial_setup();
}


class phodevi
{
	public static $vfs = false;
	private static $device_cache = null;
	private static $smart_cache = null;
	private static $sensors = null;

	private static $operating_system = null;
	private static $graphics = array(
		'mesa' => false,
		'ati' => false,
		'nvidia' => false
		);
	private static $operating_systems = array(
		'linux' => false,
		'macosx' => false,
		'solaris' => false,
		'bsd' => false,
		'hurd' => false,
		'minix' => false,
		'windows' => false
		);

	// A variable that modules can use to override Phodevi caching support, etc
	public static $allow_phodevi_caching = true;

	const no_caching = 1;
	const std_caching = 2;
	const smart_caching = 3;

	public static function read_name($device)
	{
		return phodevi::read_property($device, 'identifier');
	}
	public static function available_hardware_devices()
	{
		return array(
		'Processor' => 'cpu',
		'Motherboard' => 'motherboard',
		'Chipset' => 'chipset',
		'Memory' => 'memory',
		'Disk' => 'disk',
		'Graphics' => 'gpu',
		'Audio' => 'audio',
		'Monitor' => 'monitor',
		'Network' => 'network'
		);
	}
	public static function available_software_components()
	{
		return array(
		'OS' => array('system', 'operating-system'),
		'Kernel' => array('system', 'kernel-string'),
		'Desktop' => array('system', 'desktop-environment'),
		'Display Server' => array('system', 'display-server'),
		'Display Driver' => array('system', 'display-driver-string'),
		'OpenGL' => array('system', 'opengl-driver'),
		'Compiler' => array('system', 'compiler'),
		'File-System' => array('system', 'filesystem'),
		'Screen Resolution' => array('gpu', 'screen-resolution-string'),
		'System Layer' => array('system', 'system-layer')
		);
	}
	public static function load_sensors()
	{
		foreach(glob(dirname(__FILE__) . '/sensors/*') as $sensor_obj_file)
		{
			$sensor_obj_name = basename($sensor_obj_file, '.php');

			if(!class_exists($sensor_obj_name, false))
			{
				include($sensor_obj_file);
			}

			$type = call_user_func(array($sensor_obj_name, 'get_type'));
			$sensor = call_user_func(array($sensor_obj_name, 'get_sensor'));

			if($type != null && $sensor != null)
			{
				self::$sensors[$type][$sensor] = $sensor_obj_name;
			}
		}
	}
	public static function available_sensors()
	{
		static $available_sensors = null;

		if($available_sensors == null)
		{
			$available_sensors = array();

			foreach(self::$sensors as $sensor_type => &$sensor)
			{
				foreach(array_keys($sensor) as $sensor_senses)
				{
					array_push($available_sensors, array($sensor_type, $sensor_senses));
				}
			}
		}

		return $available_sensors;
	}
	public static function supported_sensors()
	{
		static $supported_sensors = null;

		if($supported_sensors == null)
		{
			$supported_sensors = array();

			foreach(self::available_sensors() as $sensor)
			{
				if(self::sensor_supported($sensor))
				{
					array_push($supported_sensors, $sensor);
				}
			}
		}

		return $supported_sensors;
	}
	public static function unsupported_sensors()
	{
		static $unsupported_sensors = null;

		if($unsupported_sensors == null)
		{
			$unsupported_sensors = array();
			$supported_sensors = self::supported_sensors();

			foreach(self::available_sensors() as $sensor)
			{
				if(!in_array($sensor, $supported_sensors))
				{
					array_push($unsupported_sensors, $sensor);
				}
			}
		}

		return $unsupported_sensors;
	}
	public static function read_sensor($sensor)
	{
		$value = false;

		if(isset(self::$sensors[$sensor[0]][$sensor[1]]))
		{
			$value = call_user_func(array(self::$sensors[$sensor[0]][$sensor[1]], 'read_sensor'));
		}

		return $value;
	}
	public static function read_sensor_unit($sensor)
	{
		return call_user_func(array(self::$sensors[$sensor[0]][$sensor[1]], 'get_unit'));
	}
	public static function sensor_supported($sensor)
	{
		return isset(self::$sensors[$sensor[0]][$sensor[1]]) && call_user_func(array(self::$sensors[$sensor[0]][$sensor[1]], 'support_check'));
	}
	public static function sensor_identifier($sensor)
	{
		return $sensor[0] . '.' . $sensor[1];
	}
	public static function sensor_name($sensor)
	{
		$type = call_user_func(array(self::$sensors[$sensor[0]][$sensor[1]], 'get_type'));
		$sensor = call_user_func(array(self::$sensors[$sensor[0]][$sensor[1]], 'get_sensor'));

		if(strlen($type) < 4)
		{
			$formatted = strtoupper($type);
		}
		else
		{
			$formatted = ucwords($type);
		}

		switch($formatted)
		{
			case 'SYS':
				$formatted = 'System';
				break;
			case 'HDD':
				$formatted = 'Drive';
				break;
		}

		$formatted .= ' ';

		switch($sensor)
		{
			case 'temp':
				$formatted .= 'Temperature';
				break;
			case 'freq':
				$formatted .= 'Frequency';
				break;
			case 'memory':
				$formatted .= 'Memory Usage';
				break;
			case 'power':
				$formatted .= 'Power Consumption';
				break;
			default:
				$formatted .= ucwords(str_replace('-', ' ', $sensor));
				break;
		}

		return $formatted;
	}
	public static function system_hardware($return_as_string = true)
	{
		return self::system_information_parse(self::available_hardware_devices(), $return_as_string);
	}
	public static function system_software($return_as_string = true)
	{
		return self::system_information_parse(self::available_software_components(), $return_as_string);
	}
	public static function system_id_string()
	{
		$components = array(phodevi::read_property('cpu', 'model'), phodevi::read_name('motherboard'), phodevi::read_property('system', 'operating-system'), phodevi::read_property('system', 'compiler'));
		return base64_encode(implode('__', $components));
	}
	public static function read_device_notes($device)
	{
		$devices = phodevi::available_hardware_devices();

		if(isset($devices[$device]))
		{
			$notes_r = call_user_func(array('phodevi_' . $devices[$device], 'device_notes'));
		}
		else
		{
			$notes_r = array();
		}

		return is_array($notes_r) ? $notes_r : array();
	}
	public static function read_special_settings_string($device)
	{
		$devices = phodevi::available_hardware_devices();

		if(isset($devices[$device]))
		{
			$settings_special = call_user_func(array('phodevi_' . $devices[$device], 'special_settings_string'));
		}
		else
		{
			$settings_special = null;
		}

		return $settings_special;
	}
	public static function read_property($device, $read_property)
	{
		$value = false;

		if(method_exists('phodevi_' . $device, 'read_property'))
		{
			$property = call_user_func(array('phodevi_' . $device, 'read_property'), $read_property);

			if(!($property instanceof phodevi_device_property))
			{
				return false;
			}

			$cache_code = $property->cache_code();

			if($cache_code != phodevi::no_caching && phodevi::$allow_phodevi_caching && isset(self::$device_cache[$device][$read_property]))
			{
				$value = self::$device_cache[$device][$read_property];
			}
			else
			{
				$dev_function_r = pts_arrays::to_array($property->get_device_function());
				$dev_function = $dev_function_r[0];
				$function_pass = array();

				for($i = 1; $i < count($dev_function_r); $i++)
				{
					array_push($function_pass, $dev_function_r[$i]);
				}

				if(method_exists('phodevi_' . $device, $dev_function))
				{
					$value = call_user_func_array(array('phodevi_' . $device, $dev_function), $function_pass);

					if(!is_array($value) && $value != null)
					{
						$value = pts_strings::strip_string($value);
					}

					if($cache_code != phodevi::no_caching)
					{
						self::$device_cache[$device][$read_property] = $value;

						if($cache_code == phodevi::smart_caching)
						{
							// TODO: For now just copy the smart cache to other var, but come up with better yet efficient way
							self::$smart_cache[$device][$read_property] = $value;
						}
					}
				}
			}
		}

		return $value;
	}
	public static function set_property($device, $set_property, $pass_args = array())
	{
		$return_value = false;

		if(method_exists('phodevi_' . $device, 'set_property'))
		{
			$return_value = call_user_func(array('phodevi_' . $device, 'set_property'), $set_property, $pass_args);
		}

		return $return_value;
	}
	public static function create_vfs()
	{
		self::$vfs = new phodevi_vfs();
	}
	public static function initial_setup()
	{
		// Operating System Detection
		$supported_operating_systems = pts_types::operating_systems();
		$uname_s = strtolower(php_uname('s'));

		foreach($supported_operating_systems as $os_check)
		{
			for($i = 0; $i < count($os_check); $i++)
			{
				if(strpos($uname_s, strtolower($os_check[$i])) !== false) // Check for OS
				{
					self::$operating_system = $os_check[0];
					self::$operating_systems[strtolower($os_check[0])] = true;
					break;
				}
			}

			if(self::$operating_system != null)
			{
				break;
			}
		}

		if(self::operating_system() == false)
		{
			self::$operating_system = 'Unknown';
		}

		// OpenGL / graphics detection
		$graphics_detection = array('NVIDIA', array('ATI', 'AMD', 'fglrx'), array('Mesa', 'SGI'));
		$opengl_driver = phodevi::read_property('system', 'opengl-vendor') . ' ' . phodevi::read_property('system', 'opengl-driver') . ' ' . phodevi::read_property('system', 'dri-display-driver');
		$opengl_driver = trim(str_replace('Corporation', null, $opengl_driver)); // Prevents a possible false positive for ATI being in CorporATIon

		foreach($graphics_detection as $gpu_check)
		{
			if(!is_array($gpu_check))
			{
				$gpu_check = array($gpu_check);
			}

			for($i = 0; $i < count($gpu_check); $i++)
			{
				if(stripos($opengl_driver, $gpu_check[$i]) !== false) // Check for GPU
				{
					self::$graphics[(strtolower($gpu_check[0]))] = true;
					break;
				}
			}
		}

		self::load_sensors();
	}
	public static function set_device_cache($cache_array)
	{
		if(is_array($cache_array) && !empty($cache_array))
		{
			self::$smart_cache = array_merge(self::$smart_cache, $cache_array);
			self::$device_cache = array_merge(self::$device_cache, $cache_array);
		}
	}
	public static function get_phodevi_cache_object($store_dir, $client_version = 0)
	{
		return new phodevi_cache(self::$smart_cache, $store_dir, $client_version);
	}
	protected static function system_information_parse($component_array, $return_as_string = true)
	{
		// Returns string of hardware information
		$info = array();

		foreach($component_array as $string => $id)
		{
			if(is_array($id) && count($id) == 2)
			{
				$value = self::read_property($id[0], $id[1]);
			}
			else
			{
				$value = self::read_name($id);
			}

			if($value != -1 && !empty($value))
			{
				$info[$string] = $value;
			}
		}

		if($return_as_string)
		{
			$info_array = $info;
			$info = null;

			foreach($info_array as $type => $value)
			{
				if($info != null)
				{
					$info .= ', ';
				}

				$info .= $type . ': ' . $value;
			}
		}

		return $info;
	}
	public static function system_uptime()
	{
		// Returns the system's uptime in seconds
		$uptime = 1;

		if(is_file('/proc/uptime'))
		{
			$uptime = pts_strings::first_in_string(pts_file_io::file_get_contents('/proc/uptime'));
		}
		else if(($uptime_cmd = pts_client::executable_in_path('uptime')) != false)
		{
			$uptime_counter = 0;
			$uptime_output = shell_exec($uptime_cmd . ' 2>&1');
			$uptime_output = substr($uptime_output, strpos($uptime_output, ' up') + 3);
			$uptime_output = substr($uptime_output, 0, strpos($uptime_output, ' user'));
			$uptime_output = substr($uptime_output, 0, strrpos($uptime_output, ',')) . ' ';

			if(($day_end_pos = strpos($uptime_output, ' day')) !== false)
			{
				$day_output = substr($uptime_output, 0, $day_end_pos);
				$day_output = substr($day_output, strrpos($day_output, ' ') + 1);

				if(is_numeric($day_output))
				{
					$uptime_counter += $day_output * 86400;
				}
			}

			if(($mins_end_pos = strpos($uptime_output, ' mins')) !== false)
			{
				$mins_output = substr($uptime_output, 0, $day_end_pos);
				$mins_output = substr($mins_output, strrpos($mins_output, ' ') + 1);

				if(is_numeric($mins_output))
				{
					$uptime_counter += $mins_output * 60;
				}
			}

			if(($time_split_pos = strpos($uptime_output, ':')) !== false)
			{
				$hours_output = substr($uptime_output, 0, $time_split_pos);
				$hours_output = substr($hours_output, strrpos($hours_output, ' ') + 1);
				$mins_output = substr($uptime_output, $time_split_pos + 1);
				$mins_output = substr($mins_output, 0, strpos($mins_output, ' '));

				if(is_numeric($hours_output))
				{
					$uptime_counter += $hours_output * 3600;
				}
				if(is_numeric($mins_output))
				{
					$uptime_counter += $mins_output * 60;
				}
			}

			if(is_numeric($uptime_counter) && $uptime_counter > 0)
			{
				$uptime = $uptime_counter;
			}
		}

		return intval($uptime);
	}
	public static function cpu_arch_compatible($check_against)
	{
		$compatible = true;
		$this_arch = phodevi::read_property('system', 'kernel-architecture');
		$check_against = pts_arrays::to_array($check_against);

		if(isset($this_arch[2]) && substr($this_arch, -2) == '86')
		{
			$this_arch = 'x86';
		}
		if(!in_array($this_arch, $check_against))
		{
			$compatible = false;
		}

		return $compatible;
	}
	public static function is_vendor_string($vendor)
	{
		return isset($vendor[2]) && pts_strings::string_only_contains($vendor, (pts_strings::CHAR_LETTER | pts_strings::CHAR_NUMERIC | pts_strings::CHAR_DECIMAL | pts_strings::CHAR_SPACE | pts_strings::CHAR_DASH)) && !pts_strings::has_in_istring($vendor, array('manufacturer', 'vendor', 'unknown', 'generic', 'warning')) && (!isset($vendor[7]) || strpos($vendor, ' ') !== false || pts_strings::times_occurred($vendor, pts_strings::CHAR_NUMERIC) == 0) && pts_strings::string_contains($vendor, pts_strings::CHAR_LETTER) && (isset($vendor[4]) || pts_strings::times_occurred($vendor, pts_strings::CHAR_LETTER) > 1);
	}
	public static function is_product_string($product)
	{
		return phodevi::is_vendor_string($product) && !pts_strings::has_in_istring($product, array('VBOX', 'QEMU', 'Virtual', 'Family', '440BX'));
	}
	public static function operating_system()
	{
		return self::$operating_system;
	}
	public static function is_linux()
	{
		return self::$operating_systems['linux'];
	}
	public static function is_minix()
	{
		return self::$operating_systems['minix'];
	}
	public static function is_solaris()
	{
		return self::$operating_systems['solaris'];
	}
	public static function is_bsd()
	{
		return self::$operating_systems['bsd'];
	}
	public static function is_macosx()
	{
		return self::$operating_systems['macosx'];
	}
	public static function is_hurd()
	{
		return self::$operating_systems['hurd'];
	}
	public static function is_windows()
	{
		return self::$operating_systems['windows'];
	}
	public static function is_mesa_graphics()
	{
		return self::$graphics['mesa'];
	}
	public static function is_ati_graphics()
	{
		return self::$graphics['ati'];
	}
	public static function is_nvidia_graphics()
	{
		return self::$graphics['nvidia'];
	}
	public static function is_root()
	{
		return phodevi::read_property('system', 'username') == 'root';
	}
}

?>
