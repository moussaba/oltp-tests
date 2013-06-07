<?php

/*
	Phoronix Test Suite
	URLs: http://www.phoronix.com, http://www.phoronix-test-suite.com/
	Copyright (C) 2010 - 2011, Phoronix Media
	Copyright (C) 2010 - 2011, Michael Larabel

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

class pts_config_nye_XmlReader extends nye_XmlReader
{
	protected $override_values;

	public function __construct($new_values = null)
	{
		if(is_file(PTS_USER_PATH . 'user-config.xml'))
		{
			$file = PTS_USER_PATH . 'user-config.xml';
		}
		else if(PTS_IS_CLIENT && is_file(($t = PTS_CORE_STATIC_PATH . phodevi::read_property('system', 'vendor-identifier') . '-user-config-template.xml')))
		{
			$file = $t;
		}
		else if(is_file(PTS_CORE_STATIC_PATH . 'user-config-template.xml'))
		{
			$file = PTS_CORE_STATIC_PATH . 'user-config-template.xml';
		}
		else if(is_file(PTS_CORE_STATIC_PATH . 'user-config-defaults.xml'))
		{
			$file = PTS_CORE_STATIC_PATH . 'user-config-defaults.xml';
		}
		else
		{
			$file = null;
		}

		$this->override_values = (is_array($new_values) ? $new_values : false);

		parent::__construct($file);
	}
	public function handleXmlZeroTagFallback($xml_tag, $fallback_value)
	{
		static $fallback_reader = null;

		if($fallback_reader != null || is_file(PTS_CORE_STATIC_PATH . 'user-config-defaults.xml'))
		{
			if($fallback_reader == null)
			{
				$fallback_reader = new nye_XmlReader(PTS_CORE_STATIC_PATH . 'user-config-defaults.xml');
			}

			$fallback_value = $fallback_reader->getXMLValue($xml_tag);
		}
		else if(PTS_IS_CLIENT)
		{
			echo "\nUndefined Config Option: $xml_tag\n";
		}

		return $fallback_value;
	}
	public function getXMLValue($xml_tag, $fallback_value = false)
	{
		if($this->override_values != false)
		{
			if(isset($this->override_values[$xml_tag]))
			{
				return $this->override_values[$xml_tag];
			}
			else if(isset($this->override_values[($bn = basename($xml_tag))]))
			{
				return $this->override_values[$bn];
			}
		}

		return parent::getXMLValue($xml_tag, $fallback_value);
	}
}
?>
