<?php

/*
	Phoronix Test Suite
	URLs: http://www.phoronix.com, http://www.phoronix-test-suite.com/
	Copyright (C) 2008 - 2011, Phoronix Media
	Copyright (C) 2008 - 2011, Michael Larabel
	toggle_screensaver.php: A module to toggle the screensaver while tests are running on GNOME

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

class toggle_screensaver extends pts_module_interface
{
	const module_name = 'Toggle Screensaver';
	const module_version = '1.4.0';
	const module_description = 'This module toggles the system\'s screensaver while the Phoronix Test Suite is running. At this time, the GNOME and KDE screensavers are supported.';
	const module_author = 'Phoronix Media';

	static $xdg_screensaver_available = false;
	static $xset = false;
	static $screensaver_halted = false;
	static $gnome2_screensaver_halted = false;
	static $gnome3_screensaver_halted = false;
	static $kde_screensaver_halted = false;
	static $gnome_gconftool = false;
	static $sleep_display_ac = false;

	public static function module_environmental_variables()
	{
		return array('HALT_SCREENSAVER');
	}
	public static function __startup()
	{
		$halt_screensaver = pts_module::read_variable('HALT_SCREENSAVER');
		if(!empty($halt_screensaver) && !pts_strings::string_bool($halt_screensaver))
		{
			return pts_module::MODULE_UNLOAD;
		}

		// GNOME Screensaver?
		if(($gt = pts_client::executable_in_path('gconftool')) != false || ($gt = pts_client::executable_in_path('gconftool-2')) != false)
		{
			self::$gnome_gconftool = $gt;
		}

		if(self::$gnome_gconftool != false)
		{
			$is_gnome_screensaver_enabled = trim(shell_exec(self::$gnome_gconftool . ' -g /apps/gnome-screensaver/idle_activation_enabled 2>&1'));

			if($is_gnome_screensaver_enabled == 'true')
			{
				// Stop the GNOME Screensaver
				shell_exec(self::$gnome_gconftool . ' --type bool --set /apps/gnome-screensaver/idle_activation_enabled false 2>&1');
				self::$gnome2_screensaver_halted = true;
			}

			$sleep_display_ac = trim(shell_exec(self::$gnome_gconftool . ' -g /apps/gnome-power-manager/timeout/sleep_display_ac 2>&1'));

			if($sleep_display_ac != 0)
			{
				// Don't sleep the display when on AC power
				shell_exec(self::$gnome_gconftool . ' --type int --set /apps/gnome-power-manager/timeout/sleep_display_ac 0 2>&1');
				self::$sleep_display_ac = $sleep_display_ac;
			}
		}

		if(pts_client::executable_in_path('qdbus'))
		{
			// KDE Screensaver?
			$is_kde_screensaver_enabled = trim(shell_exec('qdbus org.freedesktop.ScreenSaver /ScreenSaver org.freedesktop.ScreenSaver.GetActive 2>&1'));

			if($is_kde_screensaver_enabled == 'true')
			{
				// Stop the KDE Screensaver
				shell_exec('qdbus org.freedesktop.ScreenSaver  /ScreenSaver SimulateUserActivity 2>&1');
				self::$kde_screensaver_halted = true;
			}
		}

		if(pts_client::executable_in_path('gsettings'))
		{
			// GNOME 3.x Screensaver?
			$is_gnome3_screensaver_enabled = trim(shell_exec('gsettings get org.gnome.desktop.screensaver idle-activation-enabled 2>&1'));

			if($is_gnome3_screensaver_enabled == 'true')
			{
				// Stop the GNOME 3.x Screensaver
				shell_exec('gsettings set org.gnome.desktop.screensaver idle-activation-enabled false 2>&1');
				self::$gnome3_screensaver_halted = true;
			}

			// GNOME 3.x Sleep Dispaly?
			$is_gnome3_sleep = trim(shell_exec('gsettings get org.gnome.settings-daemon.plugins.power sleep-display-ac 2>&1'));

			if($is_gnome3_sleep > 0)
			{
				// Stop the GNOME 3.x Display Sleep
				shell_exec('gsettings set org.gnome.settings-daemon.plugins.power sleep-display-ac 0 2>&1');
				self::$sleep_display_ac = $is_gnome3_sleep;
			}
		}

		if(getenv('DISPLAY') != false && (self::$xset = pts_client::executable_in_path('xset')))
		{
			shell_exec('xset s off');
		}

		if(self::$gnome2_screensaver_halted || self::$gnome3_screensaver_halted || self::$kde_screensaver_halted)
		{
			self::$screensaver_halted = true;
		}

		if(($xdg = pts_client::executable_in_path('xdg-screensaver')) == false)
		{
			self::$xdg_screensaver_available = $xdg;
		}
	}
	public static function __shutdown()
	{
		if(self::$sleep_display_ac)
		{
			// Restore the screen sleep state when on AC power
			if(pts_client::executable_in_path('gsettings'))
			{
				shell_exec('gsettings set org.gnome.settings-daemon.plugins.power sleep-display-ac ' . self::$sleep_display_ac . ' 2>&1');
			}
			else
			{
				shell_exec(self::$gnome_gconftool . ' --type int --set /apps/gnome-power-manager/timeout/sleep_display_ac ' . self::$sleep_display_ac . ' 2>&1');
			}
		}

		if(self::$gnome2_screensaver_halted == true)
		{
			// Restore the GNOME Screensaver
			shell_exec(self::$gnome_gconftool . ' --type bool --set /apps/gnome-screensaver/idle_activation_enabled true 2>&1');
		}
		if(self::$gnome3_screensaver_halted == true)
		{
			// Restore the GNOME Screensaver
			shell_exec('gsettings set org.gnome.desktop.screensaver idle-activation-enabled true 2>&1');
		}
		if(self::$kde_screensaver_halted == true)
		{
			// Restore the KDE Screensaver
			shell_exec('qdbus org.freedesktop.ScreenSaver /ScreenSaver org.freedesktop.ScreenSaver.SetActive true 2>&1');
		}
		if(self::$xset)
		{
			shell_exec('xset s default');
		}
	}
	public static function xdg_screensaver_reset()
	{
		if(!self::$screensaver_halted && self::$xdg_screensaver_available)
		{
			shell_exec(self::$xdg_screensaver_available . ' reset 2>&1');
		}
	}
	public static function __pre_option_process()
	{
		self::xdg_screensaver_reset();
	}
	public static function __pre_run_process()
	{
		self::xdg_screensaver_reset();
	}
	public static function __pre_test_run()
	{
		self::xdg_screensaver_reset();
	}
	public static function __post_run_process()
	{
		self::xdg_screensaver_reset();
	}
}

?>
