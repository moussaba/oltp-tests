<?php

/*
	Phoronix Test Suite
	URLs: http://www.phoronix.com, http://www.phoronix-test-suite.com/
	Copyright (C) 2009 - 2011, Phoronix Media
	Copyright (C) 2009 - 2011, Michael Larabel

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

class cpu_temp implements phodevi_sensor
{
	public static function get_type()
	{
		return 'cpu';
	}
	public static function get_sensor()
	{
		return 'temp';
	}
	public static function get_unit()
	{
		return 'Celsius';
	}
	public static function support_check()
	{
		$test = self::read_sensor();
		return is_numeric($test) && $test != -1;
	}
	public static function read_sensor()
	{
		// Read the processor temperature
		$temp_c = -1;

		if(phodevi::is_bsd())
		{

			$cpu_temp = phodevi_bsd_parser::read_sysctl(array('hw.sensors.acpi_tz0.temp0', 'dev.cpu.0.temperature', 'hw.sensors.cpu0.temp0'));

			if($cpu_temp != false)
			{
				if(($end = strpos($cpu_temp, 'degC')) || ($end = strpos($cpu_temp, 'C')) > 0)
				{
					$cpu_temp = substr($cpu_temp, 0, $end);
				}

				if(is_numeric($cpu_temp))
				{
					$temp_c = $cpu_temp;
				}
			}
			else
			{
				$acpi = phodevi_bsd_parser::read_sysctl('hw.acpi.thermal.tz0.temperature');

				if(($end = strpos($acpi, 'C')) > 0)
				{
					$acpi = substr($acpi, 0, $end);
				}

				if(is_numeric($acpi))
				{
					$temp_c = $acpi;
				}
			}
		}
		else if(phodevi::is_linux())
		{
			// Try hwmon interface
			$raw_temp = phodevi_linux_parser::read_sysfs_node('/sys/class/hwmon/hwmon*/device/temp1_input', 'POSITIVE_NUMERIC', array('name' => 'coretemp'));

			if($raw_temp == -1)
			{
				$raw_temp = phodevi_linux_parser::read_sysfs_node('/sys/class/hwmon/hwmon*/device/temp1_input', 'POSITIVE_NUMERIC', array('name' => 'k10temp'));
			}

			if($raw_temp == -1)
			{
				// Try ACPI thermal
				// Assuming the system thermal sensor comes 2nd to the ACPI CPU temperature
				// It appears that way on a ThinkPad T60, but TODO find a better way to validate
				$raw_temp = phodevi_linux_parser::read_sysfs_node('/sys/class/thermal/thermal_zone*/temp', 'POSITIVE_NUMERIC', null, 2);
			}

			if($raw_temp != -1)
			{
				if($raw_temp > 1000)
				{
					$raw_temp = $raw_temp / 1000;
				}

				$temp_c = pts_math::set_precision($raw_temp, 2);	
			}

			if($temp_c == -1)
			{
				// Try LM_Sensors
				$sensors = phodevi_linux_parser::read_sensors(array('CPU Temp', 'Core 0', 'Core0 Temp', 'Core1 Temp'));

				if($sensors != false && is_numeric($sensors) && $sensors > 0)
				{
					$temp_c = $sensors;
				}
			}
		}

		return $temp_c;
	}
}

?>
